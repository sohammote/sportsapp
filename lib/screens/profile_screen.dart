import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../routes.dart';
import '../services/badge_service.dart';

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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _savingName = false;
  int? _userRank;
  bool _loadingRank = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRank();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Load user's leaderboard rank ──
  Future<void> _loadRank() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snap = await ref
          .read(firestoreServiceProvider)
          .profiles()
          .orderBy('points', descending: true)
          .get();

      final rank = snap.docs.indexWhere((d) => d.id == uid) + 1;
      setState(() {
        _userRank = rank > 0 ? rank : null;
        _loadingRank = false;
      });
    } catch (_) {
      setState(() => _loadingRank = false);
    }
  }

  // ── Save updated name ──
  Future<void> _saveName(String uid) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingName = true);
    try {
      await ref
          .read(firestoreServiceProvider)
          .profiles()
          .doc(uid)
          .update({'name': name});
      setState(() => _editingName = false);
      _showSnack('Name updated!', success: true);
    } catch (e) {
      _showSnack('Failed to update name', success: false);
    }
    setState(() => _savingName = false);
  }

  // ── Sign out ──
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, Routes.login, (_) => false);
      }
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor:
        success ? AppTheme.successGreen : AppTheme.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.history), text: 'Points History'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: ref
            .read(firestoreServiceProvider)
            .profiles()
            .doc(user.uid)
            .snapshots(),
        builder: (ctx, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final name = data?['name'] as String? ?? 'User';
          final email = data?['email'] as String? ?? user.email ?? '';
          final points = (data?['points'] ?? 0) as int;
          final totalAttendance =
          (data?['totalAttendance'] ?? 0) as int;
          final isAdmin = data?['isAdmin'] as bool? ?? false;
          final streak = (data?['streak'] ?? 0) as int;
          final earnedBadgeIds =
          List<String>.from(data?['badges'] as List? ?? []);

          // Pre-fill name controller
          if (!_editingName && _nameController.text != name) {
            _nameController.text = name;
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(
                user: user,
                name: name,
                email: email,
                points: points,
                totalAttendance: totalAttendance,
                isAdmin: isAdmin,
                streak: streak,
                earnedBadgeIds: earnedBadgeIds,
              ),
              _buildPointsHistoryTab(user.uid),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 1 — PROFILE
  // ═══════════════════════════════════════════
  Widget _buildProfileTab({
    required User user,
    required String name,
    required String email,
    required int points,
    required int totalAttendance,
    required bool isAdmin,
    required int streak,
    required List<String> earnedBadgeIds,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Avatar + Name ──
          _buildAvatarCard(
              name: name,
              email: email,
              isAdmin: isAdmin,
              uid: user.uid),
          const SizedBox(height: 16),

          // ── Streak Card ──
          _buildStreakCard(streak),
          const SizedBox(height: 16),

          // ── Stats Row ──
          _buildStatsRow(
              points: points,
              totalAttendance: totalAttendance),
          const SizedBox(height: 16),

          // ── Badges ──
          _buildBadgesCard(earnedBadgeIds),
          const SizedBox(height: 16),

          // ── Rank Card ──
          _buildRankCard(points),
          const SizedBox(height: 16),

          // ── Account Info ──
          _buildInfoCard(email: email, uid: user.uid),
          const SizedBox(height: 16),

          // ── Quick Links ──
          _buildQuickLinks(),
          const SizedBox(height: 24),

          // ── Sign Out ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorRed,
                side: const BorderSide(color: AppTheme.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Streak Card ──
  Widget _buildStreakCard(int streak) {
    final streakColor = streak >= 5
        ? Colors.deepOrange
        : streak >= 3
        ? AppTheme.accentOrange
        : AppTheme.primaryBlue;
    final streakEmoji = streak >= 5
        ? '🔥🔥'
        : streak >= 3
        ? '🔥'
        : '📅';

    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              streakColor.withOpacity(0.1),
              streakColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: streakColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Text(streakEmoji,
                  style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak Week${streak == 1 ? '' : 's'} Streak',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: streakColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak == 0
                        ? 'Attend an event to start your streak!'
                        : streak < 3
                        ? 'Keep going! ${3 - streak} more week(s) for 🔥'
                        : streak < 5
                        ? 'Amazing! ${5 - streak} more week(s) for ⚡'
                        : 'You\'re unstoppable! Keep it up! ⚡',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: streakColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '×$streak',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Badges Card ──
  Widget _buildBadgesCard(List<String> earnedBadgeIds) {
    final earnedBadges = BadgeService.getEarnedBadges(earnedBadgeIds);
    final unearnedBadges =
    BadgeService.getUnearnedBadges(earnedBadgeIds);

    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Badges',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${earnedBadges.length}/${BadgeService.allBadges.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.primaryBlue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Earned badges
            if (earnedBadges.isNotEmpty) ...[
              const Text('Earned',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successGreen)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: earnedBadges
                    .map((b) => _buildBadgeTile(b, earned: true))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Unearned badges
            if (unearnedBadges.isNotEmpty) ...[
              const Text('Locked',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLight)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: unearnedBadges
                    .map((b) => _buildBadgeTile(b, earned: false))
                    .toList(),
              ),
            ],

            if (earnedBadges.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attend events to earn your first badge!',
                        style: TextStyle(
                            color: AppTheme.textLight, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTile(AppBadge badge, {required bool earned}) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(badge, earned),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: earned
              ? AppTheme.primaryBlue.withOpacity(0.08)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned
                ? AppTheme.primaryBlue.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            Text(
              earned ? badge.emoji : '🔒',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              badge.title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: earned
                      ? AppTheme.textDark
                      : AppTheme.textLight),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(AppBadge badge, bool earned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              earned ? badge.emoji : '🔒',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              badge.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              badge.description,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: earned
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    earned
                        ? Icons.check_circle
                        : Icons.lock,
                    size: 16,
                    color: earned
                        ? AppTheme.successGreen
                        : AppTheme.textLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    earned
                        ? 'Earned!'
                        : 'Requires: ${badge.condition}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: earned
                            ? AppTheme.successGreen
                            : AppTheme.textLight),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard({
    required String name,
    required String email,
    required bool isAdmin,
    required String uid,
  }) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar circle
            Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                if (isAdmin)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.accentOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Name + edit
            _editingName
                ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      border: OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(12)),
                      contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _savingName
                    ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2))
                    : IconButton(
                  onPressed: () => _saveName(uid),
                  icon: const Icon(Icons.check,
                      color: AppTheme.successGreen),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _editingName = false),
                  icon: const Icon(Icons.close,
                      color: AppTheme.errorRed),
                ),
              ],
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () =>
                      setState(() => _editingName = true),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit,
                        size: 18, color: AppTheme.primaryBlue),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
            Text(email,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textLight)),

            if (isAdmin) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Administrator',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      {required int points, required int totalAttendance}) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            icon: Icons.stars,
            value: '$points',
            label: 'Total Points',
            color: AppTheme.accentOrange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            icon: Icons.event_available,
            value: '$totalAttendance',
            label: 'Events Attended',
            color: AppTheme.secondaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textLight),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRankCard(int points) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.leaderboard,
                  color: AppTheme.primaryBlue, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leaderboard Rank',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  _loadingRank
                      ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2))
                      : Text(
                      _userRank != null
                          ? '#$_userRank globally'
                          : 'Not ranked yet',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLight)),
                ],
              ),
            ),
            // Rank medal
            if (_userRank != null && _userRank! <= 3)
              Text(
                _userRank == 1
                    ? '🥇'
                    : _userRank == 2
                    ? '🥈'
                    : '🥉',
                style: const TextStyle(fontSize: 32),
              )
            else if (_userRank != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#$_userRank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      {required String email, required String uid}) {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildInfoRow(
              icon: Icons.email, label: 'Email', value: email),
          const Divider(height: 1, indent: 56),
          _buildInfoRow(
            icon: Icons.fingerprint,
            label: 'User ID',
            value: uid.length > 16
                ? '${uid.substring(0, 16)}...'
                : uid,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryBlue, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Card(
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildQuickLinkRow(
            icon: Icons.history,
            color: AppTheme.primaryBlue,
            label: 'Attendance History',
            onTap: () => Navigator.pushNamed(context, Routes.history),
          ),
          const Divider(height: 1, indent: 56),
          _buildQuickLinkRow(
            icon: Icons.card_giftcard,
            color: Colors.purple,
            label: 'Rewards Store',
            onTap: () => Navigator.pushNamed(context, Routes.rewards),
          ),
          const Divider(height: 1, indent: 56),
          _buildQuickLinkRow(
            icon: Icons.calendar_month,
            color: AppTheme.accentOrange,
            label: 'Events Calendar',
            onTap: () =>
                Navigator.pushNamed(context, Routes.eventsCalendar),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkRow({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textDark)),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 2 — POINTS HISTORY
  // ═══════════════════════════════════════════
  Widget _buildPointsHistoryTab(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref
          .read(firestoreServiceProvider)
          .ledgers(uid)
          .orderBy('at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style:
                const TextStyle(color: AppTheme.textLight)),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on,
                    size: 70,
                    color: AppTheme.textLight.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('No Points Yet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                const SizedBox(height: 8),
                const Text(
                  'Attend events to start earning points!',
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.textLight),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Calculate totals
        int totalEarned = 0;
        int totalSpent = 0;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final pts = (data['points'] ?? 0) as int;
          if (pts > 0) totalEarned += pts;
          if (pts < 0) totalSpent += pts.abs();
        }

        return Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _buildPointsSummaryItem(
                      label: 'Total Earned',
                      value: '+$totalEarned',
                      color: AppTheme.successGreen,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200),
                  Expanded(
                    child: _buildPointsSummaryItem(
                      label: 'Total Spent',
                      value: '-$totalSpent',
                      color: AppTheme.errorRed,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade200),
                  Expanded(
                    child: _buildPointsSummaryItem(
                      label: 'Balance',
                      value: '${totalEarned - totalSpent}',
                      color: AppTheme.primaryBlue,
                      icon: Icons.account_balance_wallet,
                    ),
                  ),
                ],
              ),
            ),

            // History list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (ctx, i) =>
                    _buildLedgerCard(docs[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPointsSummaryItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textLight),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildLedgerCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final points = (data['points'] ?? 0) as int;
    final type = data['type'] as String? ?? 'earn';
    final reason = data['reason'] as String? ?? '';
    final at = (data['at'] as Timestamp?)?.toDate().toLocal();
    final isEarn = points > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEarn
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEarn ? Icons.add_circle : Icons.remove_circle,
                color: isEarn
                    ? AppTheme.successGreen
                    : AppTheme.errorRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 3),
                  if (at != null)
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: AppTheme.textLight),
                        const SizedBox(width: 3),
                        Text(
                          _formatDateTime(at),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textLight),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Points badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isEarn
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isEarn ? '+$points' : '$points',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isEarn
                        ? AppTheme.successGreen
                        : AppTheme.errorRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
  }
}