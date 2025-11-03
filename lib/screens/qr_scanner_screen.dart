
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool _handled = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (_handled) return;
              final barcode = capture.barcodes.firstOrNull;
              final raw = barcode?.rawValue;
              if (raw == null) return;
              _handled = true;
              try {
                final uri = Uri.parse(raw);
                final uid = FirebaseAuth.instance.currentUser!.uid;
                if (uri.host == 'checkin') {
                  await ref.read(qrServiceProvider).consumeAttendanceFromUri(uri: uri, uid: uid, method: 'qr');
                  setState(() => _status = 'Attendance recorded!');
                } else if (uri.host == 'reward') {
                  await ref.read(qrServiceProvider).redeemRewardFromUri(uri: uri, uid: uid, method: 'qr');
                  setState(() => _status = 'Reward redeemed!');
                } else {
                  setState(() => _status = 'Unknown QR');
                }
              } catch (e) {
                setState(() => _status = 'Error: $e');
              }
            },
          ),
          if (_status != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(12),
                child: Text(_status!, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
