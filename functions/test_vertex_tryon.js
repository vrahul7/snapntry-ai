const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { GoogleAuth } = require('google-auth-library');

async function testTryOn() {
  const brainDir = "C:\\Users\\NC24008_Rahul\\.gemini\\antigravity\\brain\\ea96354e-8a37-4063-85ea-701de3090b0b";
  const garmentPath = path.join(brainDir, "media__1779479417506.png");
  const personPath = path.join(brainDir, "media__1779479417522.png");
  
  console.log(`Reading garment image from: ${garmentPath}`);
  console.log(`Reading person image from: ${personPath}`);
  
  if (!fs.existsSync(garmentPath) || !fs.existsSync(personPath)) {
    console.error("One or both input images are missing!");
    return;
  }
  
  // Read images and convert to base64
  const garmentBase64 = fs.readFileSync(garmentPath).toString('base64');
  const personBase64 = fs.readFileSync(personPath).toString('base64');
  
  try {
    console.log("Authenticating with Google Cloud Application Default Credentials...");
    const auth = new GoogleAuth({
      scopes: 'https://www.googleapis.com/auth/cloud-platform'
    });
    const client = await auth.getClient();
    const projectId = await auth.getProjectId();
    const tokenResponse = await client.getAccessToken();
    const accessToken = tokenResponse.token;
    
    if (!accessToken) {
      throw new Error("Failed to retrieve OAuth access token.");
    }
    
    console.log(`Authenticated. Project ID: ${projectId}`);
    
    const region = 'us-central1';
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${region}/publishers/google/models/virtual-try-on-001:predict`;
    
    console.log(`Sending request to Vertex AI Try-On endpoint...`);
    
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
                bytesBase64Encoded: garmentBase64
              },
              productImageConfig: {
                maskMode: "MASK_MODE_CLOTHING_AREA",
                productDescription: "Zara Slim-Fit Structured Blazer Suit"
              }
            }
          ]
        }
      ]
    };
    
    const response = await axios.post(endpoint, payload, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      timeout: 120000 // 2 minutes timeout
    });
    
    console.log("Response received successfully!");
    
    let outputBase64 = null;
    const responseData = response.data;
    
    if (responseData.predictions && responseData.predictions[0]) {
      const pred = responseData.predictions[0];
      if (pred.bytesBase64Encoded) {
        outputBase64 = pred.bytesBase64Encoded;
      } else if (pred.images && pred.images[0]) {
        outputBase64 = pred.images[0].bytesBase64 || pred.images[0].bytesBase64Encoded;
      } else if (pred.bytesBase64) {
        outputBase64 = pred.bytesBase64;
      }
    }
    
    if (outputBase64) {
      const outputPath = path.join(__dirname, "test_vertex_result.png");
      fs.writeFileSync(outputPath, Buffer.from(outputBase64, 'base64'));
      console.log(`SUCCESS: Saved generated try-on image to: ${outputPath}`);
    } else {
      console.error("No image found in prediction response. Response structure:");
      console.error(JSON.stringify(responseData, null, 2));
    }
    
  } catch (error) {
    console.error("Error executing Vertex AI prediction:");
    if (error.response) {
      console.error(`Status: ${error.response.status}`);
      console.error(JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
  }
}

testTryOn();
