import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers.dart';
import '../services/payload_codec.dart';

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

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _eventName = TextEditingController();
  final _pointsController = TextEditingController(text: '10');
  DateTime _start = DateTime.now().add(const Duration(minutes: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 1));
  String? _eventId;

  String? _lastAttendanceToken;
  String? _lastRewardToken;
  bool _isBroadcasting = false;

  // ── Auto-refresh QR state ──
  static const int _qrTtlSeconds = 30;
  bool _isAutoRefreshing = false;
  int _attendanceCountdown = 0;
  Timer? _attendanceTimer;
  String? _autoRefreshUid;

  // ── Reward countdown ──
  int _rewardCountdown = 0;
  Timer? _rewardTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _eventName.dispose();
    _pointsController.dispose();
    _tabController.dispose();
    _attendanceTimer?.cancel();
    _rewardTimer?.cancel();
    super.dispose();
  }

  // ── Start auto-refresh: generates new token every 30s ──
  Future<void> _startAutoRefresh(String uid) async {
    if (_eventId == null || _eventId!.isEmpty) {
      _showSnackBar('Please enter an event ID first', isError: true);
      return;
    }
    _autoRefreshUid = uid;
    setState(() => _isAutoRefreshing = true);
    await _generateAndSchedule();
  }

  Future<void> _generateAndSchedule() async {
    // Generate a fresh token
    try {
      final tokenId = await ref.read(adminServiceProvider).createAttendanceToken(
        eventId: _eventId!,
        createdBy: _autoRefreshUid!,
        ttl: const Duration(seconds: _qrTtlSeconds),
      );
      if (!mounted) return;
      setState(() {
        _lastAttendanceToken = tokenId;
        _attendanceCountdown = _qrTtlSeconds;
      });
      _attendanceTimer?.cancel();
      _attendanceTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) { t.cancel(); return; }
        if (_attendanceCountdown <= 1) {
          t.cancel();
          if (_isAutoRefreshing) {
            // Auto-generate next token
            await _generateAndSchedule();
          } else {
            setState(() {
              _attendanceCountdown = 0;
              _lastAttendanceToken = null;
            });
          }
        } else {
          setState(() => _attendanceCountdown--);
        }
      });
    } catch (e) {
      _showSnackBar('Error generating token: $e', isError: true);
      setState(() => _isAutoRefreshing = false);
    }
  }

  void _stopAutoRefresh() {
    _attendanceTimer?.cancel();
    setState(() {
      _isAutoRefreshing = false;
      _attendanceCountdown = 0;
      _lastAttendanceToken = null;
    });
    _showSnackBar('Auto-refresh stopped');
  }

  void _startRewardCountdown() {
    _rewardTimer?.cancel();
    setState(() => _rewardCountdown = 60);
    _rewardTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_rewardCountdown <= 1) {
        t.cancel();
        setState(() {
          _rewardCountdown = 0;
          _lastRewardToken = null;
        });
      } else {
        setState(() => _rewardCountdown--);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.event), text: 'Events'),
            Tab(icon: Icon(Icons.qr_code), text: 'Tokens'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Rewards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventsTab(user),
          _buildTokensTab(user),
          _buildRewardsTab(user),
        ],
      ),
    );
  }

  // ==================== EVENTS TAB ====================
  Widget _buildEventsTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Create Event',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Set up a new event for attendance tracking',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),

          // Event form card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event name
                  TextField(
                    controller: _eventName,
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      hintText: 'e.g., Basketball Practice',
                      prefixIcon: const Icon(Icons.event),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.access_time,
                        color: AppTheme.secondaryGreen,
                      ),
                    ),
                    title: const Text('Start Time'),
                    subtitle: Text(_formatDateTime(_start)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _pickDateTime(true),
                    ),
                  ),
                  const Divider(),

                  // End time
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.alarm_off,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    title: const Text('End Time'),
                    subtitle: Text(_formatDateTime(_end)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _pickDateTime(false),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Points per attendance
                  TextField(
                    controller: _pointsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points per Check-In',
                      hintText: 'e.g., 10',
                      prefixIcon: const Icon(Icons.stars, color: AppTheme.accentOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _createEvent(user.uid),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryGreen,
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

          // Created event display
          if (_eventId != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppTheme.successGreen.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Event Created Successfully!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Event ID: $_eventId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _eventId!));
                        _showSnackBar('Event ID copied to clipboard');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TOKENS TAB ====================
  Widget _buildTokensTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Attendance Tokens',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate one-time tokens for event check-in (TTL: 60s)',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 16),

          // Token generation card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event ID input
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Event ID',
                      hintText: _eventId ?? 'Enter event ID',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    controller: TextEditingController(text: _eventId ?? ''),
                    onChanged: (v) => setState(() => _eventId = v),
                  ),
                  const SizedBox(height: 16),

                  // Generate / Stop button
                  SizedBox(
                    width: double.infinity,
                    child: _isAutoRefreshing
                        ? ElevatedButton.icon(
                      onPressed: _stopAutoRefresh,
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('Stop Auto-Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                        : ElevatedButton.icon(
                      onPressed: () => _startAutoRefresh(user.uid),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Start QR Check-In'),
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

          // ── QR Code Display with Auto-Refresh ──
          if (_lastAttendanceToken != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.qr_code_2,
                              color: AppTheme.secondaryGreen),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Live QR Check-In',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text('Auto-refreshes every 30 seconds',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textLight)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: Colors.white),
                              SizedBox(width: 4),
                              Text('LIVE',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── BIG QR CODE with AnimatedSwitcher ──
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_lastAttendanceToken),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _attendanceCountdown > 8
                                  ? AppTheme.secondaryGreen
                                  : AppTheme.errorRed,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: PayloadCodec.buildAttendanceUri(
                              _lastAttendanceToken!,
                              _eventId!,
                            ).toString(),
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── PROGRESS BAR ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.refresh,
                                size: 16,
                                color: _attendanceCountdown > 8
                                    ? AppTheme.secondaryGreen
                                    : AppTheme.errorRed),
                            const SizedBox(width: 4),
                            Text(
                              'New QR in $_attendanceCountdown s',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _attendanceCountdown > 8
                                    ? AppTheme.secondaryGreen
                                    : AppTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$_attendanceCountdown / $_qrTtlSeconds s',
                          style: TextStyle(
                            fontSize: 13,
                            color: _attendanceCountdown > 8
                                ? AppTheme.secondaryGreen
                                : AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _attendanceCountdown / _qrTtlSeconds,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _attendanceCountdown > 8
                              ? AppTheme.secondaryGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Stop session button ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _stopAutoRefresh,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop Check-In Session'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: const BorderSide(color: AppTheme.errorRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── HCE Broadcast controls ──
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Phone-to-Phone NFC Broadcast',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isBroadcasting
                                ? null
                                : () => _startHCEBroadcast(user.uid),
                            icon: const Icon(Icons.cast),
                            label: const Text('Start Broadcast'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryGreen,
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !_isBroadcasting
                                ? null
                                : () => _stopHCEBroadcast(),
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorRed,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isBroadcasting) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.broadcast_on_personal,
                                color: AppTheme.successGreen),
                            SizedBox(width: 8),
                            Text('Broadcasting HCE attendance for 60s',
                                style: TextStyle(
                                    color: AppTheme.successGreen,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== REWARDS TAB ====================

  // Reward form controllers
  final _rewardTitle = TextEditingController();
  final _rewardDesc = TextEditingController();
  final _rewardPoints = TextEditingController();
  bool _isCreatingReward = false;
  String? _selectedRewardId;

  Widget _buildRewardsTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rewards Management',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 4),
          const Text('Create, manage and issue reward tokens',
              style: TextStyle(fontSize: 14, color: AppTheme.textLight)),
          const SizedBox(height: 16),

          // ── Create Reward Form ──
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create New Reward',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _rewardTitle,
                    decoration: InputDecoration(
                      labelText: 'Reward Title',
                      hintText: 'e.g. Water Bottle',
                      prefixIcon: const Icon(Icons.card_giftcard),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rewardDesc,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Branded sports water bottle',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rewardPoints,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Points Required',
                      hintText: 'e.g. 50',
                      prefixIcon: const Icon(Icons.stars),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingReward
                          ? null
                          : () => _createReward(user.uid),
                      icon: _isCreatingReward
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: Text(
                          _isCreatingReward ? 'Creating...' : 'Create Reward'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Existing Rewards List ──
          const Text('Existing Rewards',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rewards')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No rewards yet. Create one above!',
                        style: TextStyle(color: AppTheme.textLight)),
                  ),
                );
              }
              return Column(
                children: docs
                    .map((doc) => _buildAdminRewardTile(doc, user.uid))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Issue Reward Token ──
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Issue Reward Token',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                      'Select a reward and issue a 60s scannable token',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textLight)),
                  const SizedBox(height: 16),

                  // Reward selector
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rewards')
                        .where('active', isEqualTo: true)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData || snap.data!.docs.isEmpty) {
                        return const Text('No active rewards found',
                            style:
                            TextStyle(color: AppTheme.textLight));
                      }
                      final docs = snap.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: _selectedRewardId,
                        decoration: InputDecoration(
                          labelText: 'Select Reward',
                          prefixIcon: const Icon(Icons.card_giftcard),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: docs.map((doc) {
                          final data =
                          doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                                '${data['title']} (${data['costPoints']} pts)'),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedRewardId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedRewardId == null
                          ? null
                          : () => _issueRewardToken(user.uid),
                      icon: const Icon(Icons.local_activity),
                      label: const Text('Issue Reward Token'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Reward Token QR ──
          if (_lastRewardToken != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Colors.purple),
                        SizedBox(width: 8),
                        Text('Reward QR Code',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _rewardCountdown > 10
                                  ? Colors.purple
                                  : AppTheme.errorRed,
                              width: 3),
                        ),
                        child: QrImageView(
                          data: PayloadCodec.buildRewardUri(
                            _lastRewardToken!,
                            _selectedRewardId ?? 'AUTO',
                          ).toString(),
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expires in $_rewardCountdown s',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _rewardCountdown > 10
                                ? Colors.purple
                                : AppTheme.errorRed,
                          ),
                        ),
                        Text('$_rewardCountdown / 60 s',
                            style: const TextStyle(
                                color: AppTheme.textLight)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _rewardCountdown / 60,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            _rewardCountdown > 10
                                ? Colors.purple
                                : AppTheme.errorRed),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _startRewardBroadcast(user.uid),
                        icon: const Icon(Icons.broadcast_on_personal),
                        label: const Text('Start NFC Broadcast'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryGreen,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminRewardTile(DocumentSnapshot doc, String uid) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Reward';
    final description = data['description'] ?? '';
    final int costPoints = data['costPoints'] ?? 0;
    final bool active = data['active'] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _rewardPlaceholder(),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? AppTheme.textDark : AppTheme.textLight)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            Row(
              children: [
                const Icon(Icons.stars, size: 13, color: AppTheme.accentOrange),
                const SizedBox(width: 3),
                Text('$costPoints pts',
                    style: const TextStyle(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.successGreen.withOpacity(0.1)
                        : AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    active ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleRewardAction(value, doc, uid, active),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit')
                ])),
            PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                      active
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(active ? 'Deactivate' : 'Activate')
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(color: Colors.red))
                ])),
          ],
        ),
      ),
    );
  }

  Widget _rewardPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: AppTheme.primaryBlue.withOpacity(0.1),
      child: const Icon(Icons.card_giftcard,
          color: AppTheme.primaryBlue, size: 28),
    );
  }

  void _handleRewardAction(
      String action, DocumentSnapshot doc, String uid, bool active) {
    switch (action) {
      case 'edit':
        _showEditRewardDialog(doc, uid);
        break;
      case 'toggle':
        FirebaseFirestore.instance
            .collection('rewards')
            .doc(doc.id)
            .update({'active': !active});
        _showSnackBar(active ? 'Reward deactivated' : 'Reward activated');
        break;
      case 'delete':
        _confirmDeleteReward(doc.id);
        break;
    }
  }

  void _confirmDeleteReward(String rewardId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reward'),
        content: const Text(
            'Are you sure? This will permanently delete the reward.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseFirestore.instance
                  .collection('rewards')
                  .doc(rewardId)
                  .delete();
              _showSnackBar('Reward deleted');
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditRewardDialog(DocumentSnapshot doc, String uid) {
    final data = doc.data() as Map<String, dynamic>;
    final titleCtrl = TextEditingController(text: data['title'] ?? '');
    final descCtrl =
    TextEditingController(text: data['description'] ?? '');
    final ptsCtrl =
    TextEditingController(text: '${data['costPoints'] ?? 0}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Reward'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
                controller: descCtrl,
                decoration:
                const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 8),
            TextField(
                controller: ptsCtrl,
                keyboardType: TextInputType.number,
                decoration:
                const InputDecoration(labelText: 'Points Required')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('rewards')
                  .doc(doc.id)
                  .update({
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'costPoints': int.tryParse(ptsCtrl.text) ?? 0,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
              _showSnackBar('Reward updated!');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createReward(String uid) async {
    if (_rewardTitle.text.trim().isEmpty) {
      _showSnackBar('Please enter a reward title', isError: true);
      return;
    }
    final pts = int.tryParse(_rewardPoints.text);
    if (pts == null || pts <= 0) {
      _showSnackBar('Please enter valid points', isError: true);
      return;
    }

    setState(() => _isCreatingReward = true);
    try {
      await ref.read(adminServiceProvider).createReward(
        title: _rewardTitle.text.trim(),
        description: _rewardDesc.text.trim(),
        costPoints: pts,
        createdBy: uid,
      );
      _rewardTitle.clear();
      _rewardDesc.clear();
      _rewardPoints.clear();
      _showSnackBar('Reward created successfully!');
    } catch (e) {
      _showSnackBar('Error creating reward: $e', isError: true);
    }
    setState(() => _isCreatingReward = false);
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildCopyableField(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  _showSnackBar('$label copied to clipboard');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================
  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _start : _end),
    );

    if (time == null) return;

    setState(() {
      final newDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );

      if (isStart) {
        _start = newDateTime;
      } else {
        _end = newDateTime;
      }
    });
  }

  // ==================== API CALLS ====================
  Future<void> _createEvent(String uid) async {
    if (_eventName.text.trim().isEmpty) {
      _showSnackBar('Please enter an event name', isError: true);
      return;
    }
    final pts = int.tryParse(_pointsController.text) ?? 10;

    try {
      final id = await ref.read(adminServiceProvider).createEvent(
        ownerUid: uid,
        name: _eventName.text.trim(),
        startsAt: _start,
        endsAt: _end,
        pointsPerAttendance: pts,
      );
      setState(() => _eventId = id);
      _showSnackBar('Event created! ($pts pts per check-in)');
    } catch (e) {
      _showSnackBar('Error creating event: $e', isError: true);
    }
  }

  Future<void> _startHCEBroadcast(String uid) async {
    try {
      final base64url = PayloadCodec.encodeAttendance(
        tokenId: _lastAttendanceToken!,
        eventId: _eventId!,
      );
      await ref.read(hceServiceProvider).startAttendanceBroadcast(
        base64url,
        ttlSeconds: 60,
      );
      setState(() => _isBroadcasting = true);
      _showSnackBar('HCE broadcast started');
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) setState(() => _isBroadcasting = false);
      });
    } catch (e) {
      _showSnackBar('Error starting broadcast: $e', isError: true);
    }
  }

  Future<void> _stopHCEBroadcast() async {
    try {
      await ref.read(hceServiceProvider).stopBroadcast();
      setState(() => _isBroadcasting = false);
      _showSnackBar('HCE broadcast stopped');
    } catch (e) {
      _showSnackBar('Error stopping broadcast: $e', isError: true);
    }
  }

  Future<void> _issueRewardToken(String uid) async {
    if (_selectedRewardId == null) {
      _showSnackBar('Please select a reward', isError: true);
      return;
    }
    try {
      final tokenId = await ref.read(adminServiceProvider).createRewardToken(
        rewardId: _selectedRewardId!,
        createdBy: uid,
        ttl: const Duration(seconds: 60),
      );
      setState(() => _lastRewardToken = tokenId);
      _startRewardCountdown();
      _showSnackBar('Reward token issued!');
    } catch (e) {
      _showSnackBar('Error issuing token: $e', isError: true);
    }
  }

  Future<void> _startRewardBroadcast(String uid) async {
    try {
      final base64url = PayloadCodec.encodeReward(
        tokenId: _lastRewardToken!,
        rewardId: _selectedRewardId ?? 'AUTO',
      );
      await ref.read(hceServiceProvider).startRewardBroadcast(
        base64url,
        ttlSeconds: 60,
      );
      _showSnackBar('HCE reward broadcast started');
    } catch (e) {
      _showSnackBar('Error starting broadcast: $e', isError: true);
    }
  }
}