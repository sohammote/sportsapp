import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String _selectedFilter = 'All Time';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = FirebaseFirestore.instance
        .collectionGroup('logs')
        .where('uid', isEqualTo: uid)
        .orderBy('at', descending: true)
        .limit(50);

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All Time', child: Text('All Time')),
              const PopupMenuItem(value: 'This Month', child: Text('This Month')),
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
              const PopupMenuItem(value: 'Today', child: Text('Today')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (ctx, snap) {
          // ── Error state ──
          if (snap.hasError) {
            final error = snap.error.toString();
            final isIndexError = error.contains('index') ||
                error.contains('indexes') ||
                error.contains('FAILED_PRECONDITION');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIndexError ? Icons.storage : Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isIndexError
                          ? 'Database Index Missing'
                          : 'Something went wrong',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isIndexError
                          ? 'Please deploy Firestore indexes:\n\nfirebase deploy --only firestore:indexes'
                          : error,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textLight,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Loading state ──
          if (!snap.hasData ||
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          // Group logs by date
          final groupedLogs = _groupLogsByDate(docs);
          final totalLogs = docs.length;

          return Column(
            children: [
              // Stats summary
              Container(
                padding: const EdgeInsets.all(20),
                color: AppTheme.primaryBlue.withOpacity(0.1),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        context,
                        Icons.event_available,
                        'Total Check-ins',
                        totalLogs.toString(),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.textLight.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        Icons.calendar_today,
                        'Days Active',
                        groupedLogs.length.toString(),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter chip
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.filter_list, size: 18),
                    label: Text(_selectedFilter),
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  ),
                ),
              ),

              // History list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: groupedLogs.length,
                  itemBuilder: (context, index) {
                    final dateKey = groupedLogs.keys.elementAt(index);
                    final logsForDate = groupedLogs[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            dateKey,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),

                        // Logs for this date
                        ...logsForDate.map((doc) => _buildHistoryCard(doc)),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppTheme.textLight.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Attendance History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start checking in to events to build your history',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textLight,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final at = (data['at'] as Timestamp?)?.toDate().toLocal();
    final method = data['method']?.toString().toUpperCase() ?? 'UNKNOWN';
    final eventId = doc.reference.parent.parent?.id ?? 'Unknown Event';

    final methodIcon = _getMethodIcon(method);
    final methodColor = _getMethodColor(method);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Method icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: methodColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                methodIcon,
                color: methodColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatEventName(eventId),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        at != null ? _formatTime(at) : 'Unknown time',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: methodColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(methodIcon, size: 14, color: methodColor),
                        const SizedBox(width: 4),
                        Text(
                          method,
                          style: TextStyle(
                            color: methodColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Map<String, List<DocumentSnapshot>> _groupLogsByDate(
      List<DocumentSnapshot> docs,
      ) {
    final grouped = <String, List<DocumentSnapshot>>{};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final at = (data['at'] as Timestamp?)?.toDate().toLocal();

      if (at == null) continue;

      final dateKey = _getDateKey(at);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(doc);
    }

    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(recordDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatEventName(String eventId) {
    if (eventId.isEmpty || eventId == 'Unknown Event') {
      return 'Unknown Event';
    }
    // Show shortened event ID — will be replaced with real name in future
    return 'Event #${eventId.substring(0, 6).toUpperCase()}';
  }

  IconData _getMethodIcon(String method) {
    final methodLower = method.toLowerCase();
    if (methodLower.contains('qr')) {
      return Icons.qr_code;
    } else if (methodLower.contains('nfc') || methodLower.contains('hce')) {
      return Icons.nfc;
    } else if (methodLower.contains('phone')) {
      return Icons.phone_android;
    }
    return Icons.check_circle;
  }

  Color _getMethodColor(String method) {
    final methodLower = method.toLowerCase();
    if (methodLower.contains('qr')) {
      return AppTheme.primaryBlue;
    } else if (methodLower.contains('nfc') || methodLower.contains('hce')) {
      return AppTheme.secondaryGreen;
    } else if (methodLower.contains('phone')) {
      return AppTheme.accentOrange;
    }
    return AppTheme.textLight;
  }
}