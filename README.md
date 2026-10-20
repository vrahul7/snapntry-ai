# SnapnTry AI

> **B2B Generative AI Virtual Try-On & Automated Catalog Studio for Ethnic and Global Fashion**

[![Flutter](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.0-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase)](https://firebase.google.com)
[![Google Cloud Vertex AI](https://img.shields.io/badge/Google%20Cloud-Vertex%20AI%20Imagen-4285F4?logo=googlecloud)](https://cloud.google.com/vertex-ai)
[![License](https://img.shields.io/badge/License-Proprietary-blue.svg)](#license)

---

## 📌 Overview

**SnapnTry AI** is an enterprise-grade virtual fitting room and automated catalog production platform engineered for apparel e-commerce. By combining 2D geometric warping, physical drape synthesis (sarees, lehengas, dupattas), asynchronous 3D mesh rendering, and Google Cloud Vertex AI Imagen post-processing, SnapnTry AI replaces costly studio photoshoots and slashes return rates from ~35% down to under 15%.

---

## 🚀 Key Features

* **Dual-Tier Virtual Try-On**:
  * **Fast 2D Interactive Tier**: Keypoint-guided Thin Plate Spline (TPS) warping with spline-guided pleat and pallu draping physics for real-time mobile shopper previews (< 3s latency).
  * **Elite 3D Mesh Studio Tier**: Asynchronous 3D mesh scene photography using rigged `.obj` human mannequins, headless Blender camera automation, and Vertex AI Imagen dynamic lighting and background harmonization.
* **Modern MVVM Architecture**: Monolithic UI deconstructed into clean, single-responsibility components coordinated by a centralized `TryOnProvider`.
* **Zero-Flicker Asset Rendering**: `AppNetworkImage` caching with dark shimmering skeleton loaders and error fallbacks.
* **Hybrid / Fallback Resilience**: Automatically detects live Firebase connectivity. If unconfigured or offline, gracefully defaults to high-fidelity mock data and unlimited wholesale try-on credits.
* **Hardened Security Rules**: User-isolated Cloud Firestore subcollections (`/cart`, `/wishlist`, `/3d_renders`) and strict Cloud Storage validation.

---

## 📂 Repository Structure

```
snapntry-ai/
├── lib/
│   ├── config/             # Theme, routes, and design tokens
│   ├── models/             # Domain models (Product, Cart, Wishlist, User)
│   ├── services/           # TryOnProvider, Firestore, Auth, Cache, Analytics
│   ├── views/              # View layer (Catalog, Explore, Cart, Try-On Studio)
│   │   └── try_on/
│   │       ├── components/ # Decoupled studio components (Preview, Tier, Background, etc.)
│   │       └── try_on_screen.dart
│   └── widgets/            # Reusable UI components (AppNetworkImage, GlassCard)
├── tryon_pipeline/
│   ├── 3d_render_pipeline/ # Headless Blender scripts, mesh mapping, multi-angle camera rigs
│   ├── saree_pipeline/     # Spline pleat generation, pallu trajectory, and TPS warping
│   └── requirements.txt    # Python dependencies for ML/3D pipelines
├── functions/              # Firebase Cloud Functions (Node.js orchestrator)
├── test/                   # Unit & Widget test suite (100% passing)
├── product_requirement_document.md # Comprehensive PRD & technical architecture specification
└── pubspec.yaml            # Flutter package dependencies
```

---

## 🛠️ Prerequisites

* **Flutter SDK**: `>= 3.3.0` (Recommended: Flutter `3.44.0` / Dart `3.12.0`)
* **Android SDK**: API level 21 or higher (Android 5.0+)
* **Node.js**: `18+` (for Firebase Cloud Functions)
* **Python**: `3.10+` (for local 3D Blender & Saree warping microservices)

---

## ⚡ Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/vrahul7/snapntry-ai.git
cd snapntry-ai
```

### 2. Install Flutter Dependencies
```bash
flutter pub get
```

### 3. Run the App
To launch on a connected device or emulator:
```bash
flutter run
```

### 4. Build Universal Production Release APK
To compile a universal APK that supports all architectures (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`):
```bash
flutter build apk --release
```
The output binary will be generated at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔑 Demo Authentication

The application features frictionless auto-provisioning for evaluation:
* **Email**: `partner@acme.com` *(or any valid email)*
* **Password**: `password123` *(or any password with 6+ characters)*

If running offline, the app defaults to demo mode with unlimited credits. If connected to Firebase, it automatically registers the account on first sign-in.

---

## 🧪 Testing & Code Quality

Run static code analysis:
```bash
flutter analyze
```

Execute the automated test suite:
```bash
flutter test
```

---

## 📖 Detailed Specifications

For in-depth market opportunity analysis, unit economics, Generative AI pipeline mathematics, and security architecture, see:
* **[Product Requirement & Architecture Document](product_requirement_document.md)**

---

## 📄 License

This repository is proprietary and confidential. All rights reserved.
