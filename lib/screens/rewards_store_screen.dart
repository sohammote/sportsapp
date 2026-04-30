import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../routes.dart';

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

class RewardsStoreScreen extends ConsumerStatefulWidget {
  const RewardsStoreScreen({super.key});

  @override
  ConsumerState<RewardsStoreScreen> createState() =>
      _RewardsStoreScreenState();
}

class _RewardsStoreScreenState extends ConsumerState<RewardsStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>>? _leaderboard;
  bool _loadingLeaderboard = false;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Store, Redeemed, Leaderboard
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _leaderboard == null) {
        _loadLeaderboard();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loadingLeaderboard = true);
    try {
      final data =
      await ref.read(firestoreServiceProvider).getLeaderboard();
      setState(() => _leaderboard = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leaderboard: $e')),
        );
      }
    }
    setState(() => _loadingLeaderboard = false);
  }

  // ── Show scan method picker bottom sheet ──
  void _showScanOptions(BuildContext context, String rewardTitle) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Redeem: $rewardTitle',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask admin to show the reward QR or tap via NFC',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight),
            ),
            const SizedBox(height: 24),

            // QR Scan option
            _buildScanOption(
              context,
              icon: Icons.qr_code_scanner,
              color: AppTheme.primaryBlue,
              title: 'Scan QR Code',
              subtitle: 'Scan admin\'s reward QR code',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, Routes.qrScanner)
                    .then((result) {
                  if (result != null &&
                      (result as Map)['success'] == true) {
                    _showSuccessSnack('Reward redeemed successfully! 🎉');
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // NFC option
            _buildScanOption(
              context,
              icon: Icons.nfc,
              color: AppTheme.secondaryGreen,
              title: 'NFC Tap',
              subtitle: 'Tap your phone to admin\'s phone',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, Routes.nfcPhoneReader);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLight)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.card_giftcard), text: 'Store'),
            Tab(icon: Icon(Icons.history), text: 'Redeemed'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTab(),
          _buildRedeemedTab(),
          _buildLeaderboardTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 1 — STORE
  // ═══════════════════════════════════════════
  Widget _buildStoreTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: ref
          .read(firestoreServiceProvider)
          .profiles()
          .doc(uid)
          .snapshots(),
      builder: (ctx, profileSnap) {
        final profileData =
        profileSnap.data?.data() as Map<String, dynamic>?;
        final userPoints = (profileData?['points'] ?? 0) as int;
        return Column(
          children: [
            _buildPointsBanner(userPoints),
            Expanded(child: _buildRewardsGrid(userPoints)),
          ],
        );
      },
    );
  }

  Widget _buildPointsBanner(int userPoints) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.stars, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Balance',
                  style:
                  TextStyle(color: Colors.white70, fontSize: 14)),
              Text('$userPoints pts',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const Text('Scan QR or NFC to redeem rewards',
                  style: TextStyle(
                      color: Colors.white60, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsGrid(int userPoints) {
    return StreamBuilder<QuerySnapshot>(
      stream: ref
          .read(firestoreServiceProvider)
          .rewards()
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) =>
              _buildRewardListCard(docs[i], userPoints),
        );
      },
    );
  }

  Widget _buildRewardListCard(DocumentSnapshot doc, int userPoints) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Reward';
    final description = data['description'] as String? ?? '';
    final costPoints = (data['costPoints'] ?? 0) as int;
    final canAfford = userPoints >= costPoints;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Reward icon placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: canAfford
                    ? AppTheme.primaryBlue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.card_giftcard,
                color: canAfford
                    ? AppTheme.primaryBlue
                    : AppTheme.textLight,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textDark)),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.stars,
                          size: 14, color: AppTheme.accentOrange),
                      const SizedBox(width: 4),
                      Text('$costPoints pts',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: canAfford
                                  ? AppTheme.accentOrange
                                  : AppTheme.errorRed)),
                      if (!canAfford) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Need ${costPoints - userPoints} more',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.errorRed),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Redeem button
            ElevatedButton(
              onPressed: canAfford
                  ? () => _showScanOptions(context, title)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford
                    ? AppTheme.secondaryGreen
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: canAfford ? 2 : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    canAfford ? Icons.qr_code_scanner : Icons.lock,
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    canAfford ? 'Redeem' : 'Locked',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_giftcard,
              size: 80,
              color: AppTheme.textLight.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No Rewards Yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text('Check back soon for exciting rewards!',
              style:
              TextStyle(fontSize: 14, color: AppTheme.textLight)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 2 — REDEEMED HISTORY
  // ═══════════════════════════════════════════
  Widget _buildRedeemedTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('redemptions')
          .where('uid', isEqualTo: uid)
          .orderBy('at', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        // Error state
        if (snap.hasError) {
          final isIndex = snap.error.toString().contains('index') ||
              snap.error.toString().contains('FAILED_PRECONDITION');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 60, color: AppTheme.errorRed),
                  const SizedBox(height: 16),
                  Text(
                    isIndex
                        ? 'Missing Firestore Index\n\nRun:\nfirebase deploy --only firestore:indexes'
                        : snap.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textLight, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // Loading
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        // Empty state
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.redeem,
                    size: 80,
                    color: AppTheme.textLight.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('No Redemptions Yet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark)),
                const SizedBox(height: 8),
                const Text(
                  'Redeem your first reward by scanning\nan admin\'s QR code or NFC',
                  style: TextStyle(
                      fontSize: 14, color: AppTheme.textLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      _tabController.animateTo(0),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Browse Rewards'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // List of redemptions
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              // Header
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.successGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${docs.length} reward${docs.length == 1 ? '' : 's'} redeemed',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                    ),
                  ],
                ),
              );
            }

            final doc = docs[i - 1];
            return _buildRedemptionCard(doc);
          },
        );
      },
    );
  }

  Widget _buildRedemptionCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rewardTitle =
        data['rewardTitle'] as String? ?? 'Unknown Reward';
    final pointsSpent = (data['pointsSpent'] ?? 0) as int;
    final method =
    (data['method'] as String? ?? 'unknown').toUpperCase();
    final at = (data['at'] as Timestamp?)?.toDate().toLocal();

    // Method icon and color
    IconData methodIcon;
    Color methodColor;
    if (method.contains('QR')) {
      methodIcon = Icons.qr_code;
      methodColor = AppTheme.primaryBlue;
    } else if (method.contains('NFC')) {
      methodIcon = Icons.nfc;
      methodColor = AppTheme.secondaryGreen;
    } else {
      methodIcon = Icons.redeem;
      methodColor = AppTheme.textLight;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Method icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: methodColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
              Icon(methodIcon, color: methodColor, size: 26),
            ),
            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rewardTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 4),

                  // Date and time
                  if (at != null)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 12, color: AppTheme.textLight),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(at),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.access_time,
                            size: 12, color: AppTheme.textLight),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(at),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),

                  // Method badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: methodColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(methodIcon,
                            size: 11, color: methodColor),
                        const SizedBox(width: 4),
                        Text(method,
                            style: TextStyle(
                                fontSize: 10,
                                color: methodColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Points spent
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars,
                          size: 13, color: AppTheme.errorRed),
                      const SizedBox(width: 3),
                      Text('-$pointsSpent',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.errorRed)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text('pts spent',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ═══════════════════════════════════════════
  // TAB 3 — LEADERBOARD
  // ═══════════════════════════════════════════
  Widget _buildLeaderboardTab() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    if (_loadingLeaderboard) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_leaderboard == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard,
                size: 60,
                color: AppTheme.textLight.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('See who\'s on top!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadLeaderboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Load Leaderboard'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      );
    }

    if (_leaderboard!.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_leaderboard!.length >= 3)
            _buildPodium(
                _leaderboard!.take(3).toList(), currentUid),
          const SizedBox(height: 16),
          const Text('All Rankings',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          ...List.generate(_leaderboard!.length, (i) {
            final entry = _leaderboard![i];
            final isMe = entry['uid'] == currentUid;
            return _buildLeaderboardRow(entry, i + 1, isMe);
          }),
        ],
      ),
    );
  }

  Widget _buildPodium(
      List<Map<String, dynamic>> top3, String currentUid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primaryBlue.withOpacity(0.1),
          AppTheme.accentOrange.withOpacity(0.1)
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🏆 Top Champions',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (top3.length > 1)
                _buildPodiumItem(
                    top3[1], 2, 75, Colors.grey, currentUid),
              _buildPodiumItem(top3[0], 1, 100,
                  const Color(0xFFFFD700), currentUid),
              if (top3.length > 2)
                _buildPodiumItem(top3[2], 3, 60,
                    const Color(0xFFCD7F32), currentUid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> entry, int rank,
      double height, Color color, String currentUid) {
    final isMe = entry['uid'] == currentUid;
    final name = entry['name'] as String? ?? 'User';
    final points = entry['points'] as int? ?? 0;

    return Column(
      children: [
        if (isMe)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('You',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: rank == 1 ? 28 : 22,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: rank == 1 ? 22 : 16,
                fontWeight: FontWeight.bold,
                color: color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name.length > 8 ? '${name.substring(0, 8)}..' : name,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text('$points pts',
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text('#$rank',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color)),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(
      Map<String, dynamic> entry, int rank, bool isMe) {
    final name = entry['name'] as String? ?? 'User';
    final points = entry['points'] as int? ?? 0;
    final attendance = entry['totalAttendance'] as int? ?? 0;

    Color rankColor = AppTheme.textLight;
    if (rank == 1) rankColor = const Color(0xFFFFD700);
    if (rank == 2) rankColor = Colors.grey;
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isMe ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMe
            ? const BorderSide(color: AppTheme.primaryBlue, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text('#$rank',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: rankColor)),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isMe
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textDark)),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('You',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text('$attendance check-ins',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars,
                        size: 16, color: AppTheme.accentOrange),
                    const SizedBox(width: 4),
                    Text('$points',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.accentOrange)),
                  ],
                ),
                const Text('points',
                    style: TextStyle(
                        fontSize: 10, color: AppTheme.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}