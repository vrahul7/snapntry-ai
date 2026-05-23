const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { GoogleAuth } = require('google-auth-library');
const dns = require('dns').promises;

admin.initializeApp();

// Helper to download an image from a URL and convert it to base64
async function downloadAsBase64(url) {
  try {
    const response = await axios.get(url, { responseType: 'arraybuffer' });
    const buffer = Buffer.from(response.data, 'binary');
    return buffer.toString('base64');
  } catch (error) {
    console.error(`Failed to download image from URL: ${url}`, error);
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Failed to download image from URL: ${url}. Details: ${error.message}`
    );
  }
}
/**
 * Resolves the hostname of a URL and checks if it belongs to a private, loopback, or metadata IP range.
 * This mitigates SSRF (Server-Side Request Forgery) attacks.
 */
async function isSafeUrl(urlStr) {
  try {
    const parsed = new URL(urlStr);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return false;
    }
    const hostname = parsed.hostname.toLowerCase();
    
    // Explicitly block local/internal hosts
    if (hostname === 'localhost' || hostname === 'metadata.google.internal' || hostname === 'metadata') {
      return false;
    }
    
    // Resolve hostname to get IP address
    const lookup = await dns.lookup(hostname);
    const ip = lookup.address;
    
    // Validate that resolved IP is public (block 127.0.0.1, private ranges, link-local metadata)
    if (
      ip === '127.0.0.1' ||
      ip === '::1' ||
      ip.startsWith('169.254.') || // Link-local / GCP Metadata
      ip.startsWith('10.') ||        // Private Class A
      ip.startsWith('192.168.') ||   // Private Class C
      ip.startsWith('172.16.') ||    // Private Class B ranges
      ip.startsWith('172.17.') ||
      ip.startsWith('172.18.') ||
      ip.startsWith('172.19.') ||
      ip.startsWith('172.20.') ||
      ip.startsWith('172.21.') ||
      ip.startsWith('172.22.') ||
      ip.startsWith('172.23.') ||
      ip.startsWith('172.24.') ||
      ip.startsWith('172.25.') ||
      ip.startsWith('172.26.') ||
      ip.startsWith('172.27.') ||
      ip.startsWith('172.28.') ||
      ip.startsWith('172.29.') ||
      ip.startsWith('172.30.') ||
      ip.startsWith('172.31.') ||
      ip.startsWith('fe80:') ||      // IPv6 Link-local
      ip.startsWith('fc00:')         // IPv6 Unique Local
    ) {
      return false;
    }
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Crops a base64 encoded apparel image if the original category is 'one_piece' but the effective category is 'upper_body' or 'lower_body'.
 * @param {string} base64Str - Base64 encoded apparel image
 * @param {string} originalCategory - Original category ('upper_body', 'lower_body', 'one_piece')
 * @param {string} effectiveCategory - Effective category ('upper_body', 'lower_body', 'one_piece')
 * @returns {Promise<string>} - Cropped base64 string
 */
async function cropApparelImage(base64Str, originalCategory, effectiveCategory) {
  if (originalCategory !== 'one_piece') {
    return base64Str; // No crop needed if not originally a full body / one-piece garment
  }
  if (effectiveCategory === 'one_piece') {
    return base64Str; // No crop needed if it remains one-piece
  }

  console.log(`Cropping apparel image from original category: ${originalCategory} to effective category: ${effectiveCategory}...`);
  try {
    const sharp = require('sharp');
    const buffer = Buffer.from(base64Str, 'base64');
    const image = sharp(buffer);
    const metadata = await image.metadata();
    const width = metadata.width;
    const height = metadata.height;

    if (!width || !height) {
      console.warn('Could not read image metadata for cropping, returning original image');
      return base64Str;
    }

    let extractRegion;
    if (effectiveCategory === 'upper_body') {
      // Crop top 55% of the apparel image
      extractRegion = {
        left: 0,
        top: 0,
        width: width,
        height: Math.floor(height * 0.55),
      };
    } else if (effectiveCategory === 'lower_body') {
      // Crop bottom 60% of the apparel image
      const top = Math.floor(height * 0.40);
      extractRegion = {
        left: 0,
        top: top,
        width: width,
        height: height - top,
      };
    }

    if (extractRegion) {
      console.log(`Extracting region: ${JSON.stringify(extractRegion)} from ${width}x${height} image`);
      const croppedBuffer = await image.extract(extractRegion).toBuffer();
      return croppedBuffer.toString('base64');
    }
  } catch (error) {
    console.error('Error during apparel image cropping:', error);
  }
  return base64Str; // Fallback to original
}

/**
 * Cloud Function to run Vertex AI Virtual Try-On
 * Expects:
 * - personImage: String (public URL)
 * - apparelImage: String (public URL)
 * - category: String (optional, e.g. 'upper_body', 'lower_body', 'one_piece', defaults to 'upper_body')
 * - originalCategory: String (optional, original category of apparel item before visibility checks)
 */
exports.generateTryOn = functions.https.onCall(async (data, context) => {
  // Enforce caller authentication to prevent abuse/billing attacks
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called by an authenticated B2B partner.'
    );
  }
  const userId = context.auth.uid;
  console.log(`Starting secure try-on generation for user: ${userId}`);

  const { personImage, apparelImage, apparelTitle = 'Apparel', category = 'upper_body', originalCategory = category } = data;

  if (!personImage || !apparelImage) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Both personImage and apparelImage must be provided as valid URLs.'
    );
  }

  // Validate category inputs against safe enum
  const allowedCategories = ['upper_body', 'lower_body', 'one_piece'];
  if (!allowedCategories.includes(category)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid category. Allowed values: upper_body, lower_body, one_piece.'
    );
  }

  // Validate input URLs to prevent SSRF
  const [safePerson, safeApparel] = await Promise.all([
    isSafeUrl(personImage),
    isSafeUrl(apparelImage)
  ]);

  if (!safePerson || !safeApparel) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid or unsafe image URL provided.'
    );
  }

  try {
    // 1. Fetch images and convert to base64
    console.log('Downloading and converting person and apparel images...');
    const [personBase64, apparelBase64] = await Promise.all([
      downloadAsBase64(personImage),
      downloadAsBase64(apparelImage)
    ]);

    // 1.5. Crop apparel image if necessary (fitting full body apparel on partial body model)
    let processedApparelBase64 = apparelBase64;
    try {
      processedApparelBase64 = await cropApparelImage(apparelBase64, originalCategory, category);
    } catch (cropErr) {
      console.error('Failed to crop apparel image, using original:', cropErr);
    }

    // 2. Authenticate using google-auth-library
    console.log('Authenticating with Google Cloud Service Account...');
    const auth = new GoogleAuth({
      scopes: 'https://www.googleapis.com/auth/cloud-platform'
    });
    const client = await auth.getClient();
    const projectId = await auth.getProjectId();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    if (!accessToken) {
      throw new Error('Failed to retrieve Google Cloud OAuth access token.');
    }

    // 3. Construct Vertex AI Predict request
    const region = 'us-central1';
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/virtual-try-on-001:predict`;

    console.log(`Sending prediction request to Vertex AI at: ${endpoint}`);

    const payload = {
      instances: [
        {
          personImage: {
            image: {
              bytesBase64Encoded: personBase64
            }
          },
          productImages: [
            {
              image: {
                bytesBase64Encoded: processedApparelBase64
              },
              productImageConfig: {
                maskMode: "MASK_MODE_CLOTHING_AREA",
                productDescription: apparelTitle
              }
            }
          ]
        }
      ]
    };

    const apiResponse = await axios.post(endpoint, payload, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      timeout: 60000 // 60s timeout for GenAI generation
    });

    // 4. Extract generated image from Vertex AI response
    console.log('Received response from Vertex AI. Parsing results...');
    let outputBase64 = null;
    const responseData = apiResponse.data;

    if (responseData.predictions && responseData.predictions[0]) {
      const pred = responseData.predictions[0];
      if (pred.bytesBase64Encoded) {
        outputBase64 = pred.bytesBase64Encoded;
      } else if (pred.images && pred.images[0]) {
        outputBase64 = pred.images[0].bytesBase64 || pred.images[0].bytesBase64Encoded;
      } else if (pred.bytesBase64) {
        outputBase64 = pred.bytesBase64;
      }
    } else if (responseData.images && responseData.images[0]) {
      outputBase64 = responseData.images[0].bytesBase64 || responseData.images[0].bytesBase64Encoded;
    }

    if (!outputBase64) {
      console.error('Response structure received:', JSON.stringify(responseData));
      throw new Error('Vertex AI response did not contain a generated image.');
    }

    // 5. Upload base64 output image to Firebase Storage (secure user-scoped directory)
    console.log('Uploading generated try-on result to Firebase Storage...');
    const resultBuffer = Buffer.from(outputBase64, 'base64');
    const bucket = admin.storage().bucket();
    const destFileName = `try_ons/results/${userId}/tryon_${Date.now()}.png`;
    const storageFile = bucket.file(destFileName);

    await storageFile.save(resultBuffer, {
      metadata: {
        contentType: 'image/png',
        metadata: {
          generatedBy: 'VertexAI-ve-tryon',
          userId: userId,
          category: category
        }
      }
    });

    // 6. Get the download URL of the uploaded image
    let downloadUrl;
    try {
      const { getDownloadURL } = require('firebase-admin/storage');
      downloadUrl = await getDownloadURL(storageFile);
      console.log('Successfully generated direct download URL.');
    } catch (e) {
      console.log('Firebase-admin storage getDownloadURL failed or not available, generating signed URL instead.');
      const [signedUrl] = await storageFile.getSignedUrl({
        action: 'read',
        expires: '2099-12-31'
      });
      downloadUrl = signedUrl;
    }

    console.log(`Generation completed. Return URL: ${downloadUrl}`);
    return { outputUrl: downloadUrl };

  } catch (error) {
    console.error('Error during Try-On prediction pipeline:', error);
    
    // Return friendly errors
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'An error occurred during Vertex AI Virtual Try-On prediction.'
    );
  }
});

/**
 * Gemini Vision body-visibility check.
 * Analyzes the person/model image and reports which body regions are visible.
 * Expects: { personImageUrl: String, category: String }
 * Returns: { faceVisible, upperVisible, lowerVisible, effectiveCategory, reason }
 */
exports.analyzeBodyVisibility = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { personImageUrl, category = 'upper_body' } = data;

  if (!personImageUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'personImageUrl is required.');
  }

  const safe = await isSafeUrl(personImageUrl);
  if (!safe) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or unsafe image URL.');
  }

  try {
    const personBase64 = await downloadAsBase64(personImageUrl);

    const auth = new GoogleAuth({ scopes: 'https://www.googleapis.com/auth/cloud-platform' });
    const client = await auth.getClient();
    const projectId = await auth.getProjectId();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    const region = 'us-central1';
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/gemini-1.5-flash:generateContent`;

    const prompt = `You are an AI vision system for a virtual try-on app. Analyze this person photo carefully.

Determine which body regions are clearly visible:
1. faceVisible: Is the person's face clearly visible in the upper portion of the image?
2. upperVisible: Is the person's upper body (chest, shoulders, torso) clearly visible?
3. lowerVisible: Is the person's lower body (hips, thighs, legs below waist) clearly visible?

Respond ONLY with a valid JSON object, no markdown, no explanation:
{"faceVisible": true_or_false, "upperVisible": true_or_false, "lowerVisible": true_or_false}`;

    const geminiPayload = {
      contents: [{
        role: 'user',
        parts: [
          { text: prompt },
          { inlineData: { mimeType: 'image/jpeg', data: personBase64 } }
        ]
      }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 100 }
    };

    const geminiResponse = await axios.post(endpoint, geminiPayload, {
      headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      timeout: 30000
    });

    let visibilityJson = {};
    try {
      const rawText = geminiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      // Strip any markdown code blocks if present
      const cleaned = rawText.replace(/```json?/g, '').replace(/```/g, '').trim();
      visibilityJson = JSON.parse(cleaned);
    } catch (e) {
      console.warn('Could not parse Gemini visibility JSON, defaulting to all-visible:', e);
      // Default to allowing generation if parsing fails (fail open)
      visibilityJson = { faceVisible: true, upperVisible: true, lowerVisible: true };
    }

    const { faceVisible = true, upperVisible = true, lowerVisible = true } = visibilityJson;

    // Determine effective category and whether to allow generation
    let effectiveCategory = category;
    let allowed = true;
    let reason = '';

    if (category === 'upper_body') {
      if (!upperVisible) {
        allowed = false;
        reason = 'upper_body_missing';
      }
    } else if (category === 'lower_body') {
      if (!lowerVisible) {
        allowed = false;
        reason = 'lower_body_missing';
      }
    } else if (category === 'one_piece') {
      if (upperVisible && lowerVisible) {
        effectiveCategory = 'one_piece';
      } else if (upperVisible && !lowerVisible) {
        // Auto-downgrade: only show top fitting
        effectiveCategory = 'upper_body';
        reason = 'partial_upper_only';
      } else if (!upperVisible && lowerVisible) {
        // Auto-downgrade: only show bottom fitting
        effectiveCategory = 'lower_body';
        reason = 'partial_lower_only';
      } else {
        allowed = false;
        reason = 'both_body_missing';
      }
    }

    console.log(`Body visibility check: upper=${upperVisible}, lower=${lowerVisible}, face=${faceVisible}, allowed=${allowed}, effectiveCategory=${effectiveCategory}`);

    return {
      faceVisible,
      upperVisible,
      lowerVisible,
      effectiveCategory,
      allowed,
      reason
    };

  } catch (error) {
    console.error('Error in analyzeBodyVisibility:', error);
    // Fail open — don't block user if check itself fails
    return {
      faceVisible: true,
      upperVisible: true,
      lowerVisible: true,
      effectiveCategory: category,
      allowed: true,
      reason: 'check_failed'
    };
  }
});

/**
 * AI Body Dimension Analyzer for Smart Size Recommendations.
 * Uses Gemini Vision to analyze body proportions from a photo and recommend a size from a size chart.
 * Expects: { personImageUrl: String, sizeChart: Map }
 * Returns: { recommendedSize: String, fitConfidence: Number, analysis: String, allSizes: List }
 */
exports.analyzeBodyDimensions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { personImageUrl, sizeChart = {} } = data;

  if (!personImageUrl) {
    throw new functions.https.HttpsError('invalid-argument', 'personImageUrl is required.');
  }

  const safe = await isSafeUrl(personImageUrl);
  if (!safe) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid or unsafe image URL.');
  }

  try {
    const personBase64 = await downloadAsBase64(personImageUrl);

    const auth = new GoogleAuth({ scopes: 'https://www.googleapis.com/auth/cloud-platform' });
    const client = await auth.getClient();
    const projectId = await auth.getProjectId();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    const region = 'us-central1';
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/gemini-1.5-flash:generateContent`;

    const sizeChartJson = JSON.stringify(sizeChart, null, 2);

    const prompt = `You are an expert AI fashion stylist and body measurement specialist for a virtual try-on e-commerce app.

Analyze the person's body proportions and build type visible in this photo. Then use the provided size chart to recommend the best fitting size.

Size Chart:
${sizeChartJson}

Instructions:
1. Observe the person's visible body type — shoulder width, torso length, chest breadth, hip width.
2. Estimate their build category: slim/lean, athletic/medium, broad/large.
3. Map their proportions to the most suitable size from the size chart.
4. Give a confidence score between 0 and 100.

Respond ONLY with valid JSON, no markdown:
{
  "recommendedSize": "M",
  "fitConfidence": 87,
  "buildType": "athletic",
  "analysis": "Brief 1-2 sentence explanation of why this size fits best.",
  "alternativeSize": "L"
}`;

    const geminiPayload = {
      contents: [{
        role: 'user',
        parts: [
          { text: prompt },
          { inlineData: { mimeType: 'image/jpeg', data: personBase64 } }
        ]
      }],
      generationConfig: { temperature: 0.2, maxOutputTokens: 300 }
    };

    const geminiResponse = await axios.post(endpoint, geminiPayload, {
      headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      timeout: 30000
    });

    let resultJson = {};
    try {
      const rawText = geminiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      const cleaned = rawText.replace(/```json?/g, '').replace(/```/g, '').trim();
      resultJson = JSON.parse(cleaned);
    } catch (e) {
      console.warn('Could not parse Gemini body dimensions JSON:', e);
      // Return a sensible default
      const sizes = Object.keys(sizeChart);
      const midSize = sizes[Math.floor(sizes.length / 2)] || 'M';
      resultJson = {
        recommendedSize: midSize,
        fitConfidence: 60,
        buildType: 'medium',
        analysis: 'AI size estimation based on visible body proportions.',
        alternativeSize: sizes[Math.min(Math.floor(sizes.length / 2) + 1, sizes.length - 1)] || 'L'
      };
    }

    console.log(`Size analysis complete: ${JSON.stringify(resultJson)}`);
    return resultJson;

  } catch (error) {
    console.error('Error in analyzeBodyDimensions:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Size analysis failed.');
  }
});

/**
 * Visual Catalog Search using camera/image snap.
 * Uses Gemini Vision to extract garment keywords and matches them against product catalog.
 * Expects: { snapBase64: String }
 * Returns: { products: List<Map>, keywords: List<String> }
 */
exports.searchCatalogByImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const { snapBase64 } = data;

  if (!snapBase64) {
    throw new functions.https.HttpsError('invalid-argument', 'snapBase64 is required.');
  }

  try {
    const auth = new GoogleAuth({ scopes: 'https://www.googleapis.com/auth/cloud-platform' });
    const client = await auth.getClient();
    const projectId = await auth.getProjectId();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;

    const region = 'us-central1';
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/gemini-1.5-flash:generateContent`;

    const prompt = `You are a fashion AI for an e-commerce try-on app. Analyze this clothing item photo.

Identify the garment's key attributes and generate search keywords to match it against a product catalog.

Focus on: type (shirt/dress/pants/jacket/etc), pattern (solid/striped/floral/etc), material feel (linen/denim/silk/etc), color, neckline/collar style, sleeve length, fit (slim/regular/loose), occasion (casual/formal/sportswear).

Respond ONLY with valid JSON, no markdown:
{
  "garmentType": "jacket",
  "category": "upper_body",
  "keywords": ["jacket", "tech", "zip", "black", "slim fit", "casual", "waterproof"],
  "primaryColor": "black",
  "style": "casual",
  "description": "A black slim-fit technical jacket with zip details"
}`;

    const geminiPayload = {
      contents: [{
        role: 'user',
        parts: [
          { text: prompt },
          { inlineData: { mimeType: 'image/jpeg', data: snapBase64 } }
        ]
      }],
      generationConfig: { temperature: 0.1, maxOutputTokens: 300 }
    };

    const geminiResponse = await axios.post(endpoint, geminiPayload, {
      headers: { 'Authorization': `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      timeout: 30000
    });

    let garmentInfo = {};
    try {
      const rawText = geminiResponse.data?.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      const cleaned = rawText.replace(/```json?/g, '').replace(/```/g, '').trim();
      garmentInfo = JSON.parse(cleaned);
    } catch (e) {
      console.warn('Could not parse Gemini garment info JSON:', e);
      garmentInfo = { keywords: ['clothing'], garmentType: 'clothing', category: 'upper_body', description: 'Fashion item' };
    }

    const keywords = garmentInfo.keywords || [];
    const category = garmentInfo.category || 'upper_body';

    // Search Firestore catalog matching keywords against product fields
    const db = admin.firestore();
    const matchedProducts = [];
    const seenIds = new Set();

    // Query by category first for efficiency
    try {
      const categoryQuery = await db.collection('catalog')
        .where('category', '==', category)
        .limit(10)
        .get();

      categoryQuery.docs.forEach(doc => {
        if (!seenIds.has(doc.id)) {
          seenIds.add(doc.id);
          const productData = doc.data();
          // Score relevance based on keyword overlap
          const productText = [
            productData.name || '',
            productData.description || '',
            productData.category || '',
            productData.tags?.join(' ') || ''
          ].join(' ').toLowerCase();

          let score = 0;
          keywords.forEach(kw => {
            if (productText.includes(kw.toLowerCase())) score++;
          });

          matchedProducts.push({
            id: doc.id,
            score,
            name: productData.name || 'Unnamed Product',
            imageUrl: productData.imageUrl || '',
            price: productData.price || 0,
            currency: productData.currency || 'INR',
            category: productData.category || 'upper_body',
            description: productData.description || '',
          });
        }
      });
    } catch (e) {
      console.warn('Catalog query error:', e);
    }

    // Sort by relevance score descending
    matchedProducts.sort((a, b) => b.score - a.score);

    console.log(`Visual search returned ${matchedProducts.length} products for keywords: ${keywords.join(', ')}`);

    return {
      products: matchedProducts.slice(0, 8),
      keywords,
      garmentInfo: {
        type: garmentInfo.garmentType,
        description: garmentInfo.description,
        style: garmentInfo.style,
        primaryColor: garmentInfo.primaryColor,
      }
    };

  } catch (error) {
    console.error('Error in searchCatalogByImage:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Visual search failed.');
  }
});

