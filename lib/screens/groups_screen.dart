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

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Auto-join community groups on open
    _autoJoin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _autoJoin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profileSnap = await ref
        .read(firestoreServiceProvider)
        .profiles()
        .doc(user.uid)
        .get();
    final data = profileSnap.data() as Map<String, dynamic>?;
    final name = data?['name'] as String? ?? 'User';
    await ref
        .read(chatServiceProvider)
        .autoJoinCommunityGroups(user.uid, name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'My Groups'),
            Tab(
                icon: Icon(Icons.explore),
                text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyGroupsTab(),
          _buildDiscoverTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TAB 1 — MY GROUPS
  // ═══════════════════════════════════════════
  Widget _buildMyGroupsTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .snapshots(),
      builder: (ctx, groupsSnap) {
        if (!groupsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allGroups = groupsSnap.data!.docs;

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _getMyGroups(uid, allGroups),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator());
            }

            final myGroups = snap.data!;

            if (myGroups.isEmpty) {
              return _buildEmptyMyGroups();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myGroups.length,
              itemBuilder: (ctx, i) =>
                  _buildGroupCard(myGroups[i], isMember: true),
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getMyGroups(
      String uid, List<DocumentSnapshot> allGroups) async {
    final List<DocumentSnapshot> myGroups = [];
    for (final group in allGroups) {
      final memberSnap = await FirebaseFirestore.instance
          .collection('groups')
          .doc(group.id)
          .collection('members')
          .doc(uid)
          .get();
      if (memberSnap.exists) myGroups.add(group);
    }
    return myGroups;
  }

  // ═══════════════════════════════════════════
  // TAB 2 — DISCOVER
  // ═══════════════════════════════════════════
  Widget _buildDiscoverTab() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return _buildEmptyDiscover();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) =>
              _buildDiscoverGroupCard(docs[i], uid),
        );
      },
    );
  }

  Widget _buildGroupCard(DocumentSnapshot doc,
      {required bool isMember}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Group';
    final description =
        data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'event';
    final memberCount =
    (data['memberCount'] ?? 0) as int;
    final lastMessage =
    data['lastMessage'] as String?;
    final isCommunity = type == 'community';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          Routes.chat,
          arguments: {
            'groupId': doc.id,
            'groupName': name,
            'isCommunity': isCommunity,
          },
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Group avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isCommunity
                      ? AppTheme.primaryBlue
                      : AppTheme.secondaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCommunity
                      ? Icons.public
                      : Icons.group,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Group info
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textDark),
                          ),
                        ),
                        if (isCommunity)
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: const Text('Community',
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                    AppTheme.primaryBlue,
                                    fontWeight:
                                    FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lastMessage ?? description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.people,
                            size: 12,
                            color: AppTheme.textLight),
                        const SizedBox(width: 3),
                        Text(
                          '$memberCount member${memberCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverGroupCard(
      DocumentSnapshot doc, String uid) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Group';
    final description =
        data['description'] as String? ?? '';
    final type = data['type'] as String? ?? 'event';
    final memberCount =
    (data['memberCount'] ?? 0) as int;
    final isCommunity = type == 'community';

    return FutureBuilder<Map<String, dynamic>>(
      future: _getGroupStatus(doc.id, uid),
      builder: (ctx, statusSnap) {
        final isMember =
            statusSnap.data?['isMember'] ?? false;
        final isPending =
            statusSnap.data?['isPending'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isCommunity
                            ? AppTheme.primaryBlue
                            : AppTheme.secondaryGreen,
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCommunity
                            ? Icons.public
                            : Icons.group,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 15,
                                  color:
                                  AppTheme.textDark)),
                          Text(
                            '$memberCount member${memberCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    ),
                    // Join/Status button
                    _buildJoinButton(
                        doc.id, name, uid, isMember,
                        isPending, isCommunity),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLight)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getGroupStatus(
      String groupId, String uid) async {
    final isMember = await ref
        .read(chatServiceProvider)
        .isMember(groupId, uid);
    final isPending = await ref
        .read(chatServiceProvider)
        .hasPendingRequest(groupId, uid);
    return {'isMember': isMember, 'isPending': isPending};
  }

  Widget _buildJoinButton(
      String groupId,
      String name,
      String uid,
      bool isMember,
      bool isPending,
      bool isCommunity) {
    if (isMember) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check,
                size: 14, color: AppTheme.successGreen),
            SizedBox(width: 4),
            Text('Joined',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Pending',
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.accentOrange,
                fontWeight: FontWeight.bold)),
      );
    }

    return ElevatedButton(
      onPressed: () => _joinGroup(
          groupId, name, uid, isCommunity),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCommunity
            ? AppTheme.primaryBlue
            : AppTheme.secondaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        minimumSize: Size.zero,
        tapTargetSize:
        MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isCommunity ? 'Join' : 'Request',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _joinGroup(String groupId, String name,
      String uid, bool isCommunity) async {
    try {
      final profileSnap = await ref
          .read(firestoreServiceProvider)
          .profiles()
          .doc(uid)
          .get();
      final data =
      profileSnap.data() as Map<String, dynamic>?;
      final userName =
          data?['name'] as String? ?? 'User';

      if (isCommunity) {
        // Direct join for community
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(uid)
            .set({
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({
          'memberCount': FieldValue.increment(1),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined $name!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          setState(() {});
        }
      } else {
        // Request to join event group
        await ref.read(chatServiceProvider).requestToJoin(
          groupId: groupId,
          uid: uid,
          userName: userName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Join request sent for "$name"! Waiting for admin approval.'),
              backgroundColor: AppTheme.accentOrange,
            ),
          );
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildEmptyMyGroups() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group,
                size: 80,
                color:
                AppTheme.textLight.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No Groups Yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            const SizedBox(height: 8),
            const Text(
              'Discover and join groups in the Discover tab!',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  _tabController.animateTo(1),
              icon: const Icon(Icons.explore),
              label: const Text('Discover Groups'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDiscover() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore,
              size: 80,
              color:
              AppTheme.textLight.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('No Groups Available',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text(
            'Ask your admin to create groups!',
            style: TextStyle(
                fontSize: 14, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }
}