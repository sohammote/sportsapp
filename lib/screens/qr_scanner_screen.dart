import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers.dart';

// AppTheme colors
class AppTheme {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color secondaryGreen = Color(0xFF43A047);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
}

enum ScanStatus {
  scanning,
  success,
  error,
}

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _handled = false;
  String? _scanResult;
  ScanStatus _scanStatus = ScanStatus.scanning;
  bool _isFlashOn = false;


  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || !_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;

    _handled = true;
    setState(() {
      _isScanning = false;
      _scanStatus = ScanStatus.scanning;
    });

    await _processQRCode(raw);
  }

  Future<void> _processQRCode(String raw) async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final uri = Uri.parse(raw);
      final uid = FirebaseAuth.instance.currentUser!.uid;

      if (uri.host == 'checkin') {
        await ref.read(qrServiceProvider).consumeAttendanceFromUri(
          uri: uri,
          uid: uid,
          method: 'qr',
        );

        setState(() {
          _scanStatus = ScanStatus.success;
          _scanResult = 'Check-in successful!\nAttendance recorded';
        });
      } else if (uri.host == 'reward') {
        await ref.read(qrServiceProvider).redeemRewardFromUri(
          uri: uri,
          uid: uid,
          method: 'qr',
        );

        setState(() {
          _scanStatus = ScanStatus.success;
          _scanResult = 'Reward redeemed!\nCheck your rewards';
        });
      } else {
        setState(() {
          _scanStatus = ScanStatus.error;
          _scanResult = 'Unknown QR code type';
        });
      }
    } catch (e) {
      setState(() {
        _scanStatus = ScanStatus.error;
        _scanResult = 'Error: ${e.toString()}';
      });
    }

    // Auto-dismiss on success
    if (_scanStatus == ScanStatus.success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, {'success': true});
        }
      });
    }
  }

  void _retry() {
    setState(() {
      _handled = false;
      _isScanning = true;
      _scanStatus = ScanStatus.scanning;
      _scanResult = null;
    });
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isScanning)
            MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            )
          else
            Container(color: Colors.grey.shade900),

          // Scan overlay
          if (_isScanning) _buildScanOverlay(),

          // Result overlay
          if (!_isScanning) _buildResultOverlay(),

          // Top controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Flash toggle (only while scanning)
                  if (_isScanning)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildScanOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scan frame
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Corner indicators
                ...List.generate(4, (index) {
                  return Positioned(
                    top: index < 2 ? 0 : null,
                    bottom: index >= 2 ? 0 : null,
                    left: index % 2 == 0 ? 0 : null,
                    right: index % 2 == 1 ? 0 : null,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: index < 2
                              ? const BorderSide(
                            color: AppTheme.secondaryGreen,
                            width: 4,
                          )
                              : BorderSide.none,
                          bottom: index >= 2
                              ? const BorderSide(
                            color: AppTheme.secondaryGreen,
                            width: 4,
                          )
                              : BorderSide.none,
                          left: index % 2 == 0
                              ? const BorderSide(
                            color: AppTheme.secondaryGreen,
                            width: 4,
                          )
                              : BorderSide.none,
                          right: index % 2 == 1
                              ? const BorderSide(
                            color: AppTheme.secondaryGreen,
                            width: 4,
                          )
                              : BorderSide.none,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Instructions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Text(
                  'Scan QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Position the QR code within the frame',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isSuccess = _scanStatus == ScanStatus.success;
    final color = isSuccess ? AppTheme.successGreen : AppTheme.errorRed;
    final icon = isSuccess ? Icons.check_circle : Icons.error;
    final title = isSuccess ? 'Success!' : 'Scan Failed';

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 80,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              if (_scanResult != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _scanResult!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),

              // Action button
              if (!isSuccess)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}