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
 * Cloud Function to run Vertex AI Virtual Try-On
 * Expects:
 * - personImage: String (public URL)
 * - apparelImage: String (public URL)
 * - category: String (optional, e.g. 'upper_body', 'lower_body', 'one_piece', defaults to 'upper_body')
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

  const { personImage, apparelImage, apparelTitle = 'Apparel', category = 'upper_body' } = data;

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
                bytesBase64Encoded: apparelBase64
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
