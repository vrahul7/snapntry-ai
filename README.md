# B2B GenA2Z: Hybrid AI Virtual Try-On Mobile App

Welcome to **B2B GenA2Z**, a premium, production-ready corporate commerce and AI-powered virtual try-on application. This project integrates the latest **Google Cloud Vertex AI Virtual Try-On (`ve-tryon`)** pipeline with a **Firebase** serverless backend.

---

## 🚀 Key Features
1. **Instagram-Style Navigation**: Clean bottom bar featuring Home (New Brand Postings/Community Releases), Endless Try-On Feed, Virtual Fitting Room, and Account Management.
2. **Vertex AI Try-On Integration**: Integrates directly with `ve-tryon:predict` via HTTPS Callable Firebase Cloud Functions.
3. **Custom Photo Selection**: Allows buyers to select custom models/photos using the gallery (`image_picker`), upload them to Firebase Storage, and view predictions.
4. **Hybrid / Fallback Architecture**: The app automatically detects if Firebase is configured. If unconfigured or offline, it gracefully falls back to a high-fidelity mock engine, preventing crashes.
5. **Wholesale Credit System**: Pre-loaded with unlimited try-on credits for B2B partners, removing constraints for business users.

---

## 🛠️ Technology Stack
- **Frontend**: Flutter (Dart)
- **Backend Services**: Firebase Core, Firestore Database, Firebase Storage, and Firebase Cloud Functions (Node.js)
- **AI Infrastructure**: Google Cloud Vertex AI (US-Central1)

---

## 📱 How to Run the App on Your Phone (Sideloading the APK)

We have already compiled the production release APK for you. You can try the app out-of-the-box in **Offline Mock Hybrid mode** directly on your device.

### 1. Get the APK File
The compiled APK is located in:
`C:\Users\NC24008_Rahul\.gemini\antigravity\scratch\b2b_gena2z\build\app\outputs\flutter-apk\app-release.apk`

### 2. Transfer the APK to Your Android Phone
You can move the `app-release.apk` using one of these methods:
* **USB Cable**: Plug your phone into your computer, choose "File Transfer" mode, and copy the `.apk` file into your phone's downloads folder.
* **Google Drive / Cloud**: Upload the APK to Google Drive, then download it onto your phone.
* **Local Web Server**: Run a quick python server from the build directory on your PC and download it via your local network:
  ```powershell
  cd C:\Users\NC24008_Rahul\.gemini\antigravity\scratch\b2b_gena2z\build\app\outputs\flutter-apk
  python -m http.server 8000
  ```
  Then navigate to `http://<your-pc-ip>:8000` on your phone's browser to download `app-release.apk`.

### 3. Install and Trust
* Open your phone's file manager, locate `app-release.apk`, and tap to install.
* If prompted to allow installation from "Unknown Sources" or your web browser/file manager, toggle it to **Allow**.
* Tap **Install Anyway** if Google Play Protect shows a warning (common for test packages not published to the Google Play Store).

---

## 🛡️ Live Production Activation (Firebase & Vertex AI)

Once you want to transition from Mock Hybrid mode to **Live Vertex AI Try-On** with database persistence:

### 1. Enable Vertex AI in Google Cloud
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select your Firebase project.
3. Search for **Vertex AI API** and click **Enable**.

### 2. Deploy the Firebase Cloud Functions
Ensure you have Node.js and NPM installed, then run:
```bash
# 1. Install Firebase CLI globally (if not already installed)
npm install -g firebase-tools

# 2. Login to your Firebase/Google account
firebase login

# 3. Connect to your active Firebase project
firebase use --add

# 4. Deploy functions and security rules
firebase deploy
```

### 3. Configure the Flutter Client
1. Install the FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. Run configuration in the root directory:
   ```bash
   flutterfire configure
   ```
3. Regenerate and compile your release APK:
   ```bash
   flutter build apk --release
   ```
The app will auto-detect the live initialization and start sending requests to your Cloud Functions and Google Vertex AI model!
