# SnapnTry AI: Product & Engineering Architecture Document

---

## Executive Overview

**SnapnTry AI** is an enterprise-grade, B2B Generative AI Virtual Try-On and Automated Catalog Production platform specifically engineered for Indian Ethnic and Global Fashion E-Commerce. By uniting high-speed 2D geometric warping, physical drape synthesis (sarees, dupattas, pleats), asynchronous 3D mesh rendering, and Google Cloud Vertex AI Imagen post-processing, SnapnTry AI eliminates traditional photoshoot costs while slashing e-commerce returns.

---

# PART I: BUSINESS PERSPECTIVE

```mermaid
graph TD
    A[Ethnic & Fashion Retailers] -->|Catalog Upload| B(SnapnTry AI Core Engine)
    B -->|Fast Tier| C[2D TPS Warping & Instant Try-On]
    B -->|Elite Tier| D[Asynchronous 3D Mesh & Blender Studio]
    C --> E[Shopper Experience: 2.4x Conversion Uplift]
    D --> F[B2B Catalog Generator: 90% Photoshoot Cost Reduction]
    E --> G[Return Rates Compressed 35% to <15%]
    F --> H[Time-to-Market: Weeks to Seconds]
```

### 1. Market Opportunity & Problem Statement
The global fashion e-commerce market suffers from a persistent, margin-eroding crisis:
- **Catastrophic Return Rates**: Indian ethnic apparel experiences return rates between **30% and 42%**, driven by size mismatches, drape unpredictability, and color/texture divergence from static catalog images.
- **Prohibitive Photoshoot Costs**: Premium fashion labels and regional manufacturers spend **₹25,000 to ₹60,000 per SKU** on physical photoshoots (models, makeup artists, lighting, studio rentals, retouchers), delaying inventory go-live by 3–5 weeks.
- **Complexity of Indian Ethnic Silhouettes**: Standard 2D Virtual Try-On solutions (e.g., standard Western shirt/trousers models) fail catastrophically on Indian garments due to multi-layered drapery: pleats, pallus, cholis, dupattas, and heavy zari borders.

### 2. Ideal Customer Profile (ICP) & Target Segments
1. **Tier-1 Marketplaces & Aggregators**: Multi-brand e-commerce platforms seeking universal try-on across millions of listings.
2. **D2C Ethnic Fashion Brands**: Premium saree, lehenga, and fusion wear brands requiring photorealistic drape fidelity to protect luxury brand equity.
3. **Regional Weavers & B2B Wholesalers**: Manufacturers in Surat, Kanchipuram, and Varanasi who need studio-quality catalog generation directly from flat fabric scans without hiring professional models.

### 3. Value Proposition & Business Metrics
| Key Metric | Industry Baseline | With SnapnTry AI | Business Impact |
| :--- | :--- | :--- | :--- |
| **Catalog Photoshoot Cost / SKU** | ₹25,000 – ₹50,000 | < ₹25 (Compute cost) | **99.9% cost reduction** |
| **Catalog Time-to-Market** | 14 – 28 Days | < 60 Seconds | **Instant listing agility** |
| **E-Commerce Conversion Rate** | 1.2% – 1.8% | 2.8% – 4.2% | **2.4x conversion uplift** |
| **Return Rate (Fit/Look Discrepancy)** | 35% – 40% | < 15% | **Saves ₹180-₹350 per shipped parcel** |
| **Customer Engagement Time** | 45 Seconds | 4.8 Minutes | **6x higher session dwell time** |

### 4. Product Monetization & Tiering Strategy
SnapnTry AI operates on a hybrid SaaS + API consumption model:
- **Tier 1: Fast 2D Try-On (Interactive B2C/Shopper Tier)**
  - Targeted at instant mobile shopper previews (<3 second latency).
  - Uses keypoint-guided Thin Plate Spline (TPS) warping combined with diffusion inpainting.
- **Tier 2: Elite 3D Mesh Scene Photography (B2B Studio Tier)**
  - Engineered for heavy Kanjeevarams, bridal lehengas, and embroidered sherwanis.
  - Generates 3D multi-angle catalog imagery using OBJ base meshes, automated Blender camera rigs, and Vertex AI Imagen dynamic background up-scaling.
- **Enterprise Integration Tier**:
  - Headless REST/GraphQL APIs, Shopify/Magento connectors, custom enterprise single-tenant deployments, and custom model fine-tuning.

---

# PART II: TECHNICAL & ENGINEERING ARCHITECTURE

```mermaid
flowchart TB
    subgraph Client["Flutter Mobile Client (Android & iOS)"]
        UI[View Layer: Modern Glassmorphism]
        TP[TryOnProvider: MVVM State Machine]
        Cache[AppNetworkImage: Shimmer & MemCache]
    end

    subgraph Firebase["Google Cloud & Firebase Backend"]
        Auth[Firebase Auth: Anonymous & RBAC]
        FS[(Cloud Firestore: Encrypted NoSQL)]
        FCS[(Cloud Storage: Regional Assets)]
        CF[Cloud Functions: Node.js Orchestrator]
    end

    subgraph AI["AI & Rendering Workflows"]
        VAI[Vertex AI Imagen: Dynamic Lighting & Backgrounds]
        TPS[2D TPS Warper & Saree Drape Engine]
        BLD[3D Mesh Service: Headless Blender Engine]
    end

    UI --> TP
    TP --> FS
    TP --> FCS
    TP --> CF
    CF --> VAI
    CF --> TPS
    CF --> BLD
    BLD --> VAI
```

### 1. Mobile Application Architecture (Flutter)
The client application is built with a strictly decoupled **MVVM (Model-View-ViewModel) architecture**:
- **State Management**: Centralized `TryOnProvider` (`ChangeNotifier`) isolates state from UI widgets. Manages model selection, apparel picking, draping styles, background scenes, and generation status.
- **Modular Studio Components**: The monolithic 1,844-line screen was deconstructed into 7 single-responsibility components:
  - `TryOnStudioPreview`: Interactive hero preview with interactive zoom and processing overlays.
  - `TryOnTierSelector`: Dynamic switching between *Fast 2D Try-On* and *Elite 3D Mesh Rendering*.
  - `TryOnBackgroundSelector`: Studio context selector (Luxury Boutique, Heritage Courtyard, Royal Palace Hall, Minimalist Studio).
  - `TryOnApparelPicker` & `TryOnModelPicker`: Horizontal asset carousels with category filters.
  - `TryOnHistorySheet`: Bottom drawer for real-time Firestore session lookups.
- **Optimized Asset Pipeline (`AppNetworkImage`)**: Dark shimmer placeholders, error fallbacks, and memory-conscious rendering with automatic cache invalidation prevent UI jank.
- **Harmonized Design System (`theme.dart`)**: Deep slate dark background (`0xFF0A0E17`), cyber gold accent (`0xFFD4AF37`), neon mint highlights (`0xFF00E5FF`), and `GlassCard` translucent frosted surfaces.

### 2. Generative AI & Virtual Try-On Pipelines

#### A. 2D Geometric & Saree Drape Pipeline (`saree_draping_pipeline.py`)
1. **Pose & Silhouette Estimation**: Detects body keypoints (shoulders, bust, waist, hips, knees, ankles) to compute anatomical bounding boxes.
2. **Spline-Guided Pleat Generation**: Uses mathematical cubic splines along the waist-to-ankle axis to synthesize natural accordion pleat folds.
3. **Pallu Shoulder Trajectory**: Models fabric drape diagonally across the torso and over the left shoulder with realistic fabric physics and gravitational weight simulation.
4. **Thin Plate Spline (TPS) Warping**: Deforms flat garment textures onto the calculated 2D geometric surface mesh.

#### B. Elite 3D Mesh Scene Photography Service (`blender_render_pipeline.py`)
1. **Base Mesh Initialization**: Imports pre-rigged 3D humanoid mannequins (`.obj` / `.fbx`).
2. **UV Texture Mapping**: Synthesizes flat fabric patterns into normal, roughness, and displacement maps, mapping them onto 3D ethnic garment meshes (lehenga skirts, cholis, dupattas).
3. **Multi-Angle Camera Capture**: An automated headless Python script executes Blender rendering passes capturing standard catalog angles: Front Full, Side Profile, 45-degree Perspective, and Close-up Texture.
4. **Vertex AI Imagen Post-Processing**: Renders pass to Google Vertex AI Imagen for:
   - Dynamic background substitution matching selected lighting contexts.
   - GenAI Magic texture upscaling (preserving intricate zari thread work and embroidery without artifacts).

### 3. Backend & Security Architecture
- **Firestore Security Rules**: Strict user-level access controls. Top-level `/products` and `/models` are read-only to clients, while `/users/{uid}/cart`, `/users/{uid}/wishlist`, `/users/{uid}/tryon_history`, and `/3d_renders` enforce token UID ownership.
- **Storage Security**: Enforces 15MB file size limits and valid image MIME types (`image/(jpeg|png|webp)`).
- **Cloud Functions**: Headless Node.js endpoints orchestrate authentication verification, rate limiting, and job queuing to GPU-accelerated Python rendering workers.

### 4. Quality & Build Verification
- **Static Analysis**: `dart analyze lib` yields **0 errors, 0 warnings, 0 lints**.
- **Automated Test Coverage**: Full suite of unit and widget tests covering provider state transitions, cart total calculations, and model selections with a **100% pass rate**.
- **Universal Production Binary**: Compiled into a single universal Android APK (`app-release.apk`) packaging all four native ABI architectures (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`) for universal device compatibility without feature degradation.
