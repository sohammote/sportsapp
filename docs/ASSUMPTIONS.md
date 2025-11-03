docs/ASSUMPTIONS.md
- Package name used: com.example.sportsapp (you can rename via Android Studio Refactor if needed).
- Latest stable Flutter/Dart assumed (SDK >= 3.5).
- HCE AID: F0 12 34 56 78 90 encoded as F01234567890 (manifest/xml/kotlin align).
- NFC phone-to-phone HCE is Android-only. iOS uses QR and NDEF read/write fallback.
- Tokens have 60s TTL in the demo; adjust in Admin Panel when issuing.
- Reward HCE demo uses rewardId="AUTO" in UI; in production bind real rewardId.
