docs/TESTING_GUIDE.md
# Testing

## 1) QR Path (Android & iOS)
- Admin Panel ➜ Create event ➜ Create attendance token ➜ copy URI or show QR (you can render URI as QR with any offline tool for now).
- User ➜ "Scan QR" ➜ Scan `sportsapp://checkin?d=...` ➜ Attendance appears in History.

## 2) Android Phone-to-Phone NFC (HCE)
- Two Android phones with NFC.
- Admin phone (Sender): Admin Panel ➜ Create attendance token ➜ **Start HCE Broadcast** (60s TTL).
- User phone (Reader): Phone-to-Phone NFC screen ➜ **Read Attendance Token**, bring near the admin phone's NFC area.
- Success: "Attendance recorded!". Firestore: `attendance/{eventId}/logs/{tokenId}` doc created.

Rewards: use "Issue Reward Token" + "Read Reward Token" similarly, writes `redemptions/{tokenId}`.

## 3) NFC Tag Fallback
- Admin ➜ Admin Panel ➜ after creating token ➜ **Write NDEF Fallback** to a blank NTAG (or use the separate NFC Tag screen).
- User ➜ NFC Tag screen ➜ **Read Tag & Check-in**.

## 4) Firestore Rules Enforcement (No Cloud Functions)
- Tokens must be active and unexpired; docId must equal tokenId.
- Attempts to reuse or write wrong ID should be **DENIED** by rules.
- Event time windows: keep events' `startsAt/endsAt`. Ensure tokens TTL aligns with event window to minimize writes.

## Common Issues
- **NFC not available**: ensure NFC enabled in Settings; emulators do not support HCE.
- **APDU error**: ensure Reader sends SELECT AID first; keep phones aligned at NFC coils.
- **iOS HCE**: Not supported by platform; use QR or NDEF.
- **Permissions**: Camera permission prompt for QR; NFC has no runtime prompt.
- **Firestore PERMISSION_DENIED**: check you are signed in and Rules file is deployed.
