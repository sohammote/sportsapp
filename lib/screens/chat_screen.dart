import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

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

class ChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final bool isCommunity;

  const ChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isCommunity,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _userName;
  bool _isMember = false;
  bool _isPending = false;
  bool _checkingMembership = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndMembership();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndMembership() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final profileSnap = await ref
        .read(firestoreServiceProvider)
        .profiles()
        .doc(uid)
        .get();
    final data = profileSnap.data() as Map<String, dynamic>?;
    final name = data?['name'] as String? ?? 'User';

    final isMember = await ref
        .read(chatServiceProvider)
        .isMember(widget.groupId, uid);
    final isPending = await ref
        .read(chatServiceProvider)
        .hasPendingRequest(widget.groupId, uid);

    if (mounted) {
      setState(() {
        _userName = name;
        _isMember = isMember;
        _isPending = isPending;
        _checkingMembership = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    _messageController.clear();

    await ref.read(chatServiceProvider).sendMessage(
      groupId: widget.groupId,
      uid: uid,
      senderName: _userName ?? 'User',
      text: text,
      groupName: widget.groupName,
    );

    // Scroll to bottom
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _requestJoin() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await ref.read(chatServiceProvider).requestToJoin(
        groupId: widget.groupId,
        uid: uid,
        userName: _userName ?? 'User',
      );
      setState(() => _isPending = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Join request sent! Waiting for admin approval.'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.isCommunity
                    ? Icons.public
                    : Icons.group,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.groupName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(
                    widget.isCommunity
                        ? 'Community'
                        : 'Event Group',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _checkingMembership
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Messages or non-member view
          Expanded(
            child: _isMember
                ? _buildMessagesList(uid)
                : _buildNonMemberView(),
          ),

          // Input bar (only for members)
          if (_isMember) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessagesList(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .orderBy('at', descending: false)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 60,
                    color:
                    AppTheme.textLight.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('No messages yet',
                    style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Be the first to say something!',
                    style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 13)),
              ],
            ),
          );
        }

        // Auto scroll to bottom on new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data =
            docs[i].data() as Map<String, dynamic>;
            final isMe = data['uid'] == uid;
            final isAdmin =
                FirebaseAuth.instance.currentUser != null;

            return _buildMessageBubble(
              doc: docs[i],
              data: data,
              isMe: isMe,
              canDelete: isMe,
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required DocumentSnapshot doc,
    required Map<String, dynamic> data,
    required bool isMe,
    required bool canDelete,
  }) {
    final text = data['text'] as String? ?? '';
    final senderName =
        data['senderName'] as String? ?? 'User';
    final at = (data['at'] as Timestamp?)
        ?.toDate()
        .toLocal();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
              AppTheme.primaryBlue.withOpacity(0.2),
              child: Text(
                senderName.isNotEmpty
                    ? senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: canDelete
                  ? () => _confirmDeleteMessage(doc.id)
                  : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth:
                  MediaQuery.of(context).size.width *
                      0.72,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppTheme.primaryBlue
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft:
                    const Radius.circular(16),
                    topRight:
                    const Radius.circular(16),
                    bottomLeft: Radius.circular(
                        isMe ? 16 : 4),
                    bottomRight: Radius.circular(
                        isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        senderName,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue
                                .withOpacity(0.8)),
                      ),
                    if (!isMe) const SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(
                          fontSize: 14,
                          color: isMe
                              ? Colors.white
                              : AppTheme.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      at != null
                          ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
                          : '',
                      style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white60
                              : AppTheme.textLight),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message'),
        content: const Text(
            'Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(chatServiceProvider)
                  .deleteMessage(
                  widget.groupId, messageId);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization:
                  TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                        color: AppTheme.textLight),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonMemberView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isCommunity
                    ? Icons.public
                    : Icons.group,
                size: 60,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.groupName,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isPending
                  ? 'Your join request is pending admin approval'
                  : 'You need to join this group to view messages',
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!_isPending)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestJoin,
                  icon: const Icon(Icons.send),
                  label: const Text('Request to Join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.accentOrange
                          .withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top,
                        color: AppTheme.accentOrange,
                        size: 18),
                    SizedBox(width: 8),
                    Text('Request Pending',
                        style: TextStyle(
                            color: AppTheme.accentOrange,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}