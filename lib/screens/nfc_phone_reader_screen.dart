import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

// AppTheme colors
class AppTheme {
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color secondaryGreen = Color(0xFF43A047);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color backgroundGrey = Color(0xFFF5F5F5);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
}

enum NFCStatus {
  waiting,
  reading,
  success,
  failed,
}

class NfcPhoneReaderScreen extends ConsumerStatefulWidget {
  const NfcPhoneReaderScreen({super.key});

  @override
  ConsumerState<NfcPhoneReaderScreen> createState() => _NfcPhoneReaderScreenState();
}

class _NfcPhoneReaderScreenState extends ConsumerState<NfcPhoneReaderScreen>
    with SingleTickerProviderStateMixin {
  NFCStatus _status = NFCStatus.waiting;
  String? _statusMessage;
  String? _resultMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _readAttendanceToken() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() {
      _status = NFCStatus.reading;
      _statusMessage = 'Reading attendance token...';
      _resultMessage = null;
    });

    try {
      await ref.read(nfcReaderServiceProvider).readPhoneHceAttendance(uid: uid);

      setState(() {
        _status = NFCStatus.success;
        _statusMessage = 'Attendance Recorded!';
        _resultMessage = 'Your check-in has been successfully recorded';
      });

      _animationController.stop();
      _showSnackBar('Attendance recorded successfully!');
    } catch (e) {
      setState(() {
        _status = NFCStatus.failed;
        _statusMessage = 'Check-In Failed';
        _resultMessage = e.toString();
      });

      _animationController.stop();
      _showSnackBar('Failed to record attendance: $e', isError: true);
    }
  }

  Future<void> _readRewardToken() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() {
      _status = NFCStatus.reading;
      _statusMessage = 'Reading reward token...';
      _resultMessage = null;
    });

    try {
      await ref.read(nfcReaderServiceProvider).readPhoneHceReward(uid: uid);

      setState(() {
        _status = NFCStatus.success;
        _statusMessage = 'Reward Redeemed!';
        _resultMessage = 'Your reward has been successfully claimed';
      });

      _animationController.stop();
      _showSnackBar('Reward redeemed successfully!');
    } catch (e) {
      setState(() {
        _status = NFCStatus.failed;
        _statusMessage = 'Redemption Failed';
        _resultMessage = e.toString();
      });

      _animationController.stop();
      _showSnackBar('Failed to redeem reward: $e', isError: true);
    }
  }

  void _retry() {
    _animationController.repeat(reverse: true);
    setState(() {
      _status = NFCStatus.waiting;
      _statusMessage = null;
      _resultMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Phone-to-Phone NFC'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Info card
              Card(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hold your phone near the admin\'s phone to receive the token',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Animated phone illustration
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Column(
                    children: [
                      // Top phone (admin)
                      Transform.translate(
                        offset: Offset(0, -30 * _animationController.value),
                        child: _buildPhoneIcon(_getStatusColor(), true),
                      ),

                      SizedBox(height: 20 * (1 - _animationController.value)),

                      // Connection indicator
                      if (_status == NFCStatus.waiting || _status == NFCStatus.reading)
                        Opacity(
                          opacity: 0.3 + (0.4 * _animationController.value),
                          child: Column(
                            children: [
                              Icon(
                                Icons.wifi,
                                size: 40,
                                color: _getStatusColor(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'NFC',
                                style: TextStyle(
                                  color: _getStatusColor(),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: 20 * (1 - _animationController.value)),

                      // Bottom phone (user)
                      Transform.translate(
                        offset: Offset(0, 30 * _animationController.value),
                        child: _buildPhoneIcon(_getStatusColor(), false),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),

              // Status text
              Text(
                _getStatusTitle(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                _getStatusDescription(),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textLight,
                ),
                textAlign: TextAlign.center,
              ),

              // Result card
              if (_resultMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _status == NFCStatus.success
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _status == NFCStatus.success
                          ? AppTheme.successGreen
                          : AppTheme.errorRed,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _status == NFCStatus.success
                            ? Icons.check_circle
                            : Icons.error,
                        size: 48,
                        color: _status == NFCStatus.success
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _resultMessage!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _status == NFCStatus.success
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Action buttons
              if (_status == NFCStatus.waiting || _status == NFCStatus.failed) ...[
                // Attendance button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _status == NFCStatus.reading ? null : _readAttendanceToken,
                    icon: const Icon(Icons.event_available),
                    label: const Text('Read Attendance Token'),
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
                const SizedBox(height: 12),

                // Reward button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _status == NFCStatus.reading ? null : _readRewardToken,
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Read Reward Token'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              // Retry button
              if (_status == NFCStatus.failed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              // Done button
              if (_status == NFCStatus.success) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneIcon(Color color, bool isTop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_android,
            size: 48,
            color: color,
          ),
          const SizedBox(height: 4),
          Text(
            isTop ? 'Admin' : 'You',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_status) {
      case NFCStatus.waiting:
      case NFCStatus.reading:
        return AppTheme.primaryBlue;
      case NFCStatus.success:
        return AppTheme.successGreen;
      case NFCStatus.failed:
        return AppTheme.errorRed;
    }
  }

  String _getStatusTitle() {
    if (_statusMessage != null) return _statusMessage!;

    switch (_status) {
      case NFCStatus.waiting:
        return 'Ready to Read';
      case NFCStatus.reading:
        return 'Reading Token...';
      case NFCStatus.success:
        return 'Success!';
      case NFCStatus.failed:
        return 'Failed';
    }
  }

  String _getStatusDescription() {
    switch (_status) {
      case NFCStatus.waiting:
        return 'Select an action below to start reading';
      case NFCStatus.reading:
        return 'Keep phones close together';
      case NFCStatus.success:
        return 'Operation completed successfully';
      case NFCStatus.failed:
        return 'Unable to read token. Please try again';
    }
  }
}