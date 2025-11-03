
# Run Instructions (Android Studio)

1. Open project ➜ wait for Gradle sync.
2. Add Firebase configs:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
3. In Android Studio Terminal:
   flutter pub get
   flutter run
4. Use **Run ▶** to deploy to device/emulator.
5. For HCE tests: use two real Android phones with NFC enabled.
6. Logcat filters: "HceService" or "HostApduService" or "Flutter".
