# SnapnTry AI — B2B Virtual Try-On Platform
## Product Requirement Document (PRD) & Technical Specification

| Metadata | Value |
| :--- | :--- |
| **Product Name** | SnapnTry AI (Formerly B2B GenA2Z) |
| **Status** | Approved & Deployed |
| **Author** | Antigravity AI |
| **Firebase Project** | `b2b-gena2z-prod-8898` |
| **Local Port** | `http://localhost:8081` |
| **Target Launch** | Q3 2026 |

---

## 1. Executive Summary

**SnapnTry AI** is an executive-grade wholesale fashion portal designed for retail procurement buyers and wholesale fashion brands in India. By bridging the gap between digital catalogs and physical fitments, the platform introduces a seamless, non-blocking **AI Virtual Try-On (VTON)** interface. Retailers can upload custom headshots/body profiles or pick preset models, map catalog clothes to them in real time, and immediately evaluate fitments. 

The primary business goal is to **mitigate wholesale sample returns** and **compress purchase order cycles** by providing immediate high-fidelity visualization, replacing traditional, static wholesale catalogs with a premium interactive experience.

---

## 2. Product Flow & User Journey

The application is structured around a streamlined B2B buyer flow designed to mimic consumer catalog discovery in modern retail exploration portals while securing corporate workflows.

### 2.1 The Visual Discover Feed (SNAPNTRY AI FEED)
* **Description**: The landing page presents a dark, premium interface showing new releases, circular category pills, global searches, and active catalog products. The catalog is restricted strictly to high-quality Indian retail clothing resources (like H&M and Zara India) to maintain platform focus.
* **Product Action**: Buyers can browse catalogs, filter items, and tap directly on any clothing item card to send it into the AI Try-On Studio.

---

### 2.2 TikTok-Style swipe Explore (Swipe Feed)
* **Description**: Allows retailers to browse items via an immersive portrait feed. 
* **Product Action**: Right-side action overlay provides instant mapping controls:
  * **Try-On**: Instantly redirects the buyer to the Try-On Studio and pre-loads the selected garment.
  * **Save**: Adds the garment to the company’s digital wardrobe.
  * **Buy**: Launches quick sample order dialogs.
* **Swipe Feed Layout**:
  - Implements full-screen portrait product presentation with a floating action overlay.
  - Double-tap gesture enables instant AI virtual try-on using default model parameters.

---

### 2.3 The AI Try-On Studio (Fitting Room)
* **Description**: A side-by-side mapping interface where the selected **Apparel Product** (left) is mapped onto the **Target Model** (right). 
* **Model Selection Options**: 
  * Select from pre-configured professional models (Model Alpha, Beta, Gamma).
  * Upload a custom model photo using **Camera Capture** or **Gallery Upload**.

---

### 2.4 Custom Apparel & Category Picker
* **Description**: Retailers are not limited to catalog items. Tapping "Upload Custom" on the apparel panel lets them upload any apparel photo.
* **AI Assistance Dialog**: Because Vertex AI requires explicit clothing category maps, a popup selector categorizes the garment before uploading to ensure the model maps sleeves and hems correctly:
  * **Tops / Shirts / Jackets** (`upper_body`)
  * **Pants / Shorts / Skirts** (`lower_body`)
  * **Dresses / One-Pieces** (`one_piece`)

---

## 3. Technical Architecture

SnapnTry AI is built as a hybrid serverless system. The mobile-responsive Flutter frontend interacts with Firebase Services for data management and routes image predictions through a secure Cloud Function to Google Cloud's Vertex AI.

```mermaid
graph TD
    subgraph Frontend [Flutter Web Client - Port 8081]
        App[SnapnTry App] --> Views[Views: Feed / Studio / Swipe]
        Views --> AuthSvc[FirebaseAuthService]
        Views --> FSSvc[FirestoreService]
        Views --> StorageSvc[StorageService]
    end

    subgraph Firebase [Firebase Suite - Project b2b-gena2z-prod-8898]
        Auth[Firebase Auth]
        Firestore[(Cloud Firestore)]
        Storage[(Firebase Storage)]
        CF[Callable Cloud Function: generateTryOn]
    end

    subgraph GoogleCloud [Google Cloud Platform]
        Vertex[Vertex AI - virtual-try-on-001]
    end

    %% Client Connections
    AuthSvc -->|Authenticate User| Auth
    StorageSvc -->|Secure Uploads /models/ & /try_ons/| Storage
    FSSvc -->|Get Catalog / Seed Products| Firestore
    FSSvc -->|Log Try-On Transactions| Firestore

    %% Cloud Function Flow
    Views -->|Call generateTryOn (category & originalCategory)| CF
    CF -->|SSRF Validation / IP Resolve| CF
    CF -->|Server-Side Cropping via sharp (one_piece to partial)| CF
    CF -->|Fetch Service Account Tokens| GoogleCloud
    CF -->|Secure REST POST Payload| Vertex
    Vertex -->|Return base64 tryon output| CF
    CF -->|Write PNG image| Storage
    CF -->|Return Direct downloadURL| Views
```

### 3.1 Asynchronous Sequence Flow
When a user triggers an AI generation, the request is dispatched securely to prevent client-side secrets exposure.

```mermaid
sequenceDiagram
    autonumber
    actor User as Flutter Client
    participant CF as Cloud Function (generateTryOn)
    participant Storage as Firebase Storage
    participant Vertex as Vertex AI (virtual-try-on-001)
    participant Firestore as Cloud Firestore

    User->>CF: Call generateTryOn(personImage, apparelImage, category, originalCategory, apparelTitle)
    Note over CF: 1. Validate Auth & Categories<br/>2. Execute DNS Lookup SSRF filter
    CF->>CF: Download Images & convert to Base64 buffers
    Note over CF: 3. Dynamic Server-Side Cropping (sharp):<br/>If original: one_piece and target: upper/lower_body,<br/>crop top 55% / bottom 60% of garment
    CF->>CF: Request Google Cloud OAuth Access Token
    CF->>Vertex: HTTP POST to /virtual-try-on-001:predict (Base64 Tensors)
    Note over Vertex: AI Generation & Draping Pipeline (8-12 seconds)
    Vertex-->>CF: HTTP 200 (Result bytesBase64Encoded)
    CF->>Storage: Save PNG bytes to /try_ons/results/{userId}/tryon_{epoch}.png
    CF->>Storage: Generate Download URL / Signed URL
    CF->>Firestore: Log Transaction log (user, garment, model, outputUrl, status: 'success')
    CF-->>User: Return { outputUrl }
    Note over User: Render generated fit image on UI
```

---

## 4. Frontend Design System & Codebase

The frontend codebase is built with **Flutter Web**, optimized for mobile screen aspect ratios and compiled using Skia/HTML engines.

### 4.1 Visual Aesthetics (Instagram Dark Mode)
The styling guidelines are configured in [theme.dart](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/lib/config/theme.dart):
* **Backgrounds**: Pure Black (`0xFF000000`) for the scaffold to reduce fatigue and deliver a sleek, luxurious product catalog backdrop.
* **Cards & Surfaces**: Dark Charcoal (`0xFF121212`) paired with thin border layouts (`0xFF262626`) for separation of cards without using harsh solid whites.
* **Gradients & Accents**: A vibrant multi-stop Instagram brand gradient (Purple-Magenta-Pink-Orange-Yellow) used for primary call-to-actions, try-on buttons, and active borders.

### 4.2 Seamless B2B Login Bypass
To resolve friction during retail partner testing, [login_screen.dart](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/lib/views/auth/login_screen.dart) is pre-configured with authorized testing B2B credentials:
* **Email**: `vgrahul7@gmail.com`
* **Password**: `12345679`
Tapping "Enter Partner Portal" automatically signs in and initializes the user session.

### 4.3 Catalog Self-Healing Mechanism
In [firestore_service.dart](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/lib/services/firestore_service.dart), a self-healing check runs upon catalog retrieval. If old, non-clothing assets (e.g., legacy "Duffel Bag" or "Pen" cards) are detected, the system executes `forceReSeedProducts()`, purging the database and re-seeding it with fresh Zara and H&M India clothing items (linens, blazers, hoodies, cargo pants).

---

## 5. Backend Implementation Details

The backend processes transactions and communicates with Google Cloud APIs inside a secure serverless container.

### 5.1 Cloud Function Implementation (`generateTryOn`)
The Node.js 20 HTTPS Callable function is written in [index.js](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/functions/index.js). It performs four core steps:

1. **Security & Input Sanitization**:
   * Rejects unauthenticated requests (`HttpsError('unauthenticated')`).
   * Validates categories against enum: `['upper_body', 'lower_body', 'one_piece']`.
2. **Server-Side Request Forgery (SSRF) DNS Validation**:
   * Standard URL validation is bypassable by malicious IP mappings. The function resolves hostnames using DNS lookups and checks resolved IPs against local, private, Class A/B/C networks, and Google Metadata endpoints (`169.254.169.254`), throwing immediate rejections for unsafe IPs.
3. **Smart Apparel Cropping (via sharp library)**:
   * To prevent warped fittings, the function detects if the original apparel category is `one_piece` (full-body suit/dress) but the target model visibility region requires an `upper_body` or `lower_body` fit.
   * If target is `upper_body`, it crops the top 55% of the apparel image.
   * If target is `lower_body`, it crops the bottom 60% of the apparel image (using a 40% height offset).
4. **Google IAM Access Control**:
   * Uses `google-auth-library` to fetch the GCP Project ID and an OAuth access token under the Firestore App service account, preventing hardcoded api keys.

#### Request Payload Schema (Google Vertex AI)
```json
POST https://us-central1-aiplatform.googleapis.com/v1/projects/b2b-gena2z-prod-8898/locations/us-central1/publishers/google/models/virtual-try-on-001:predict
Authorization: Bearer <GCP_OAUTH_TOKEN>
Content-Type: application/json

{
  "instances": [
    {
      "personImage": {
        "image": {
          "bytesBase64Encoded": "<BASE64_ENCODED_TARGET_MODEL_IMAGE>"
        }
      },
      "productImages": [
        {
          "image": {
            "bytesBase64Encoded": "<BASE64_ENCODED_GARMENT_IMAGE>"
          },
          "productImageConfig": {
            "maskMode": "MASK_MODE_CLOTHING_AREA",
            "productDescription": "Zara Linen-Blend Blazer"
          }
        }
      ]
    }
  ]
}
```

---

### 5.2 Storage & Firestore Rules Setups

#### Firebase Storage Security Rules (`storage.rules`)
Ensures that B2B partner uploads cannot be viewed by other organizations.
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Read-only catalog resources
    match /catalog/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    // Organization model uploads
    match /models/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    // Generated Try-On results
    match /try_ons/results/{userId}/{allPaths=**} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if false; // Cloud Functions writes under admin bypass; direct client writes blocked
    }
  }
}
```

#### Firestore Security Rules (`firestore.rules`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /products/{productId} {
      allow read: if request.auth != null;
      allow write: if false; // Admin/seeder write access only
    }
    match /try_ons/{tryOnId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 6. Custom Local ML Pipeline (Cat-VTON Architecture)

To reduce dependency on external APIs and enable offline model training, the system features a complete custom VTON pipeline under [tryon_pipeline/](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/tryon_pipeline/).

### 6.1 Preprocessing Flow
1. **Human Parser (SCHP)**: Splits the target model image into 18 semantic segmentation indices.
2. **DensePose Estimation**: Identifies 3D coordinates ($U, V$ maps) mapped onto the 2D surface of the human body.
3. **Agnostic Mask Generation**: Dilates the clothing region by a $5 \times 5$ kernel to prevent edge artifacts.

### 6.2 Cat-VTON Latent Concatenation
The model concatenates the inputs directly inside the latent space:

$$\mathbf{X}_{\text{concat}} = \text{Concat}\Big(z_t, \text{VAE}(I_{\text{agnostic}}), M_{\text{agnostic}}, \text{VAE}(I_{\text{garment}})\Big)$$

The modified UNet accepts a **13-channel spatial tensor** (4 channels noisy latent, 4 channels agnostic latent, 1 channel mask, 4 channels garment latent) instead of the base Stable Diffusion 9-channel tensor.

```
                    +-----------------------------+
                    |   Noisy Latent (4 ch)       |
                    |   Agnostic Latent (4 ch)    |
                    |   Agnostic Mask (1 ch)      |
                    |   Garment Latent (4 ch)     |
                    +--------------┬--------------+
                                   │
                                   v Concatenation
                    +─────────────────────────────+
                    |  Input Latent (13 channels) |
                    +──────────────┬──────────────+
                                   │
                                   v
                    +─────────────────────────────+
                    | Modified Denoising UNet     |
                    | (Attention Layers Unfrozen) |
                    +─────────────────────────────+
```

### 6.3 Trainable Parameter Allocation & Loss
* **Trainable Parameters**: We employ Parameter-Efficient Fine-Tuning (PEFT). By freezing the convolution layers and training only the attention blocks, the total trainable parameters are restricted to **`49,574,080` (5.77% of the model)**, allowing training on standard consumer GPUs (under 12GB VRAM).
* **Loss Function**:
  $$L_{\text{total}} = \lambda_{\text{MSE}} L_{\text{MSE}} + \lambda_{\text{LPIPS}} L_{\text{LPIPS}} + \lambda_{\text{adv}} L_{\text{adv}}$$
  * $L_{\text{MSE}}$: Latent noise prediction error.
  * $L_{\text{LPIPS}}$: Perceptual similarity computed via a frozen VGG-16 backbone.
  * $L_{\text{adv}}$: Conditional Patch-Adversarial loss to maintain knit fabric patterns, textures, and typography legibility.

### 6.4 Model Validation Thresholds
The validation suite [validate.py](file:///C:/Users/NC24008_Rahul/.gemini/antigravity/scratch/b2b_gena2z/tryon_pipeline/validate.py) enforces automated quality controls:
* **Structural Similarity (SSIM)**: Must be $\ge 0.88$.
* **Peak Signal-to-Noise Ratio (PSNR)**: Must be $\ge 22.0\text{ dB}$.
* **Learned Perceptual Image Patch Similarity (LPIPS)**: Must be $\le 0.09$.
* **Sobel Edge Check**: Flag if edge variance deviates by $>25\%$.
* **Delta E Color Check**: Flag if RGB color shift deviates by $>15.0$.

---

## 7. Technical Validation & Deployment Status

1. **Flutter Web Server**: Active at `http://localhost:8081` on web-server binding `0.0.0.0`.
2. **Dart Static Analysis**: `flutter analyze` passes with **0 warnings / 0 errors**.
3. **Firebase Deployments**: Complete for indexes, Firestore rules, Storage rules, Authentication providers, and Callable Functions.
4. **Vertex AI Connection**: Verified; payload parsing extracts generated frames and persists output PNGs in isolated folder schemas.
5. **Local Pipeline Unit Tests**: Preprocessing, dataset dimensions, model channel shapes, mock training epochs, validation metrics, and end-to-end inference scripts compile and pass local testing.

---

## 8. Future Roadmap & Technical Improvements

To elevate SnapnTry AI from a B2B product to an industry-standard virtual fitting room, the following technical enhancements should be prioritized:

### 1. High-Fidelity DensePose V2 Transition
* **Limitation**: DensePose V1 struggles with baggy clothing or complex sitting poses, causing model arms to blend into shirts.
* **Improvement**: Migrate the human parser preprocessing script from SCHP to **DensePose V2 (ViT-based)**, providing finer mesh coordinates for pose estimation.

### 2. Multi-Garment Layering Support (Upper + Lower Body)
* **Limitation**: The current Vertex AI `virtual-try-on-001` and Cat-VTON architectures accept only a single garment at a time. Trying on pants replaces the model's pants but drops previously tested shirts.
* **Improvement**: Re-architecture the input pipeline to feed a sequence of garment images into the UNet model. Apply multi-mask processing where the latent space is conditioned on multiple masks: $M_{\text{upper}} \cup M_{\text{lower}}$.

### 3. Real-Time WebSocket Generation Notifications
* **Limitation**: The client currently waits for the HTTP Callable function to complete, keeping the connection active for 10-15 seconds.
* **Improvement**: Implement an asynchronous task queue. The client triggers the job and immediately receives a task ID. The client listens to the task state via Firestore realtime listeners or WebSockets, and receives a push notification once the image is ready.

### 4. GPU Inference Optimizations (TensorRT & ONNX Runtime)
* **Limitation**: Local Python inference runs raw PyTorch tensors, which takes 6-8 seconds per generation.
* **Improvement**: Export the unfrozen, trained UNet and base VAE models into **TensorRT** (for NVIDIA clusters) or **ONNX Runtime** (for cross-platform execution), cutting latency down to under 2 seconds.

### 5. Garment Semantic Edge Smoothing
* **Limitation**: Occasionally, draped sleeves have jagged boundaries when mapped onto dark backgrounds.
* **Improvement**: Apply a post-processing **Laplacian Pyramid Blending** filter to merge the edges of the generated garment with the target model's skin pixels.

---

## 9. Commerce Pivot & AI Convenience Features

To transition SnapnTry AI from a pure B2B procurement showcase into a high-converting **direct e-commerce platform**, the application has incorporated specialized consumer-centric AI features focusing on user convenience, purchase confidence, and shopping engagement.

### 9.1 Key Business Improvement Metrics
From a retail/business standpoint, e-commerce success is determined by four key operational metrics:
1. **Conversion Rate (CR)**: Elevate browser-to-buyer conversions by making try-on engaging, non-blocking, and friction-free.
2. **Average Order Value (AOV)**: Incentivize cross-selling and multi-item checkouts.
3. **Return Rate (RR)**: Minimize the massive e-commerce overhead of returns due to poor sizing/fit (typically ~25-30% in apparel).
4. **User Engagement & Session Length**: Keep users interactive in-app, building a direct emotional connection with garments.

### 9.2 Implemented AI & Commerce Features (Commerce Pivot)

```
       +-----------------------------------------------------------------+
       |               AI-Centric Commerce Convenience                   |
       +-------------------------------+---------------------------------+
                                       │
            ┌──────────────────────────┼──────────────────────────┐
            ▼                          ▼                          ▼
+───────────────────────+  +───────────────────────+  +───────────────────────+
|  Smart Sizing Scan    |  |  "Complete the Look"  |  |  Snap & Shop Search   |
|  Estimates user size  |  |  Recommends matching  |  |  Upload real photos   |
|  to lower Return Rate |  |  items to double AOV  |  |  to find match in db  |
+───────────────────────+  +───────────────────────+  +───────────────────────+
```

#### A. AI Visual Fit & Size Recommendation (Reduce Return Rates)
* **Convenience Feature**: Users select a model/garment in the Try-On Studio and tap "Scan for Recommended Size". The `analyzeBodyDimensions` Firebase Callable Cloud Function executes Gemini 1.5 Flash to estimate body proportions relative to height indicators and returns size mapping results (S, M, L, XL) showing confidence levels.
* **Business Impact**: Directly reduces return rates by eliminating sizing ambiguity across different brands and cuts.
* **Analytics Event**: Tracked via `virtual_try_on` with parameter `success: 1` or `success: 0` alongside product characteristics.

#### B. AI "Complete the Look" Stylist (Increase AOV)
* **Convenience Feature**: Scrolling down from the generated try-on result presents a styled matching selection (Complete the Look). Each curated matching apparel card includes a quick "Try On" utility to overlay the recommended item on the active model instantly.
* **Business Impact**: Increases Average Order Value (AOV) by encouraging buyers to purchase complete, matching styles instead of single garments.

#### C. Snap & Shop Camera Integration (High Engagement)
* **Convenience Feature**: The Camera search utility in the catalog feed allows customers to snap/upload real-world photos. The `searchCatalogByImage` Cloud Function processes the image via Gemini Vision to return matching catalog garments, falling back to a full catalog list if connectivity issues arise.
* **Business Impact**: Shortens the path from visual inspiration to try-on and conversion, boosting engagement.
* **Analytics Event**: Tracked via `visual_search` with parameters: `{ success: 1 }` (Cloud function matched) or `{ success: 0 }` (Fallback activated).

#### D. E-Commerce Cart & Wishlist System (Maximize CR)
* **Convenience Features**: 
  - **Swipe-to-Buy / Add to Cart**: Added a dedicated `CartScreen` containing quantity increments, item summaries, and a checkout button. Buying from the swipe feed or catalog instantly populates the cart with live count badges.
  - **Save / Wishlist**: A digital wardrobe (`WishlistScreen`) stores liked garments, allowing customers to easily add them to the cart or trigger try-ons later.
* **Business Impact**: Maximizes Conversion Rate (CR) by capitalizing on the try-on "wow" factor, providing a seamless transaction flow.
* **Analytics Events**:
  - `add_to_cart`: Logged when items are added to the cart via `CartService`.
  - `add_to_wishlist`: Logged when items are added to wishlist via `WishlistService`.
  - `begin_checkout`: Logged when the checkout flow is initiated.
  - `purchase`: Logged when a sample order is completed, logging the transaction ID, cart items, prices, and quantities.

### 9.3 Firebase Analytics Event Schema
```json
{
  "event_name": "purchase",
  "parameters": {
    "transaction_id": "txn_1716503923402",
    "value": 3898.00,
    "currency": "INR",
    "items": [
      {
        "item_id": "premium_linen_shirt",
        "item_name": "Premium Linen Shirt",
        "price": 1299.00,
        "quantity": 2
      },
      {
        "item_id": "urban_cargo_pants",
        "item_name": "Urban Cargo Pants",
        "price": 1300.00,
        "quantity": 1
      }
    ]
  }
}
```
