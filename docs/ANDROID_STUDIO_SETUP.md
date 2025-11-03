docs/ANDROID_STUDIO_SETUP.md
# Android Studio + Flutter Setup (Free Firebase, No Cloud Functions)

1) Install Android Studio (latest) and add **Flutter** and **Dart** plugins:
    - File ➜ Settings ➜ Plugins ➜ search "Flutter" (installs Dart automatically).

2) SDK Paths:
    - Android Studio ➜ More Actions ➜ SDK Manager ➜ install latest **Android SDK Platform**, **Build-Tools**, **Platform-Tools**.
    - Note the Android SDK location and ensure `ANDROID_SDK_ROOT` is set (optional).

3) Create AVD:
    - Device Manager ➜ Create Virtual Device ➜ Pixel (API 29+).
    - Note: **HCE (phone-to-phone NFC) requires real Android devices** for both sides.

4) Clone/Open the project in Android Studio:
    - `pub get` runs automatically, or run in Terminal:
      ```
      flutter pub get
      ```

5) Add Firebase (Spark plan, free):
    - Create Firebase Project ➜ Add Android app (package `com.example.sportsapp`) ➜ download **google-services.json** into `android/app/`.
    - Add iOS app ➜ download **GoogleService-Info.plist** into `ios/Runner/`.
    - In Android Studio `android/build.gradle` ensure `classpath 'com.google.gms:google-services:...`
    - In `android/app/build.gradle` apply plugin: `apply plugin: 'com.google.gms.google-services'`

6) Run:
