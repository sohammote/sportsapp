import 'package:cloud_firestore/cloud_firestore.dart';

// ── Badge definitions ──
class AppBadge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final String condition;

  const AppBadge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.condition,
  });
}

class BadgeService {
  final _db = FirebaseFirestore.instance;

  // ── All available badges ──
  static const List<AppBadge> allBadges = [
    AppBadge(
      id: 'first_step',
      emoji: '🥇',
      title: 'First Step',
      description: 'Attended your first event',
      condition: '1 check-in',
    ),
    AppBadge(
      id: 'on_fire',
      emoji: '🔥',
      title: 'On Fire',
      description: 'Maintained a 3-week streak',
      condition: '3 week streak',
    ),
    AppBadge(
      id: 'unstoppable',
      emoji: '⚡',
      title: 'Unstoppable',
      description: 'Maintained a 5-week streak',
      condition: '5 week streak',
    ),
    AppBadge(
      id: 'dedicated',
      emoji: '🎯',
      title: 'Dedicated',
      description: 'Attended 10 events',
      condition: '10 events',
    ),
    AppBadge(
      id: 'champion',
      emoji: '🏆',
      title: 'Champion',
      description: 'Attended 25 events',
      condition: '25 events',
    ),
    AppBadge(
      id: 'point_collector',
      emoji: '⭐',
      title: 'Point Collector',
      description: 'Earned 100 points total',
      condition: '100 points',
    ),
    AppBadge(
      id: 'elite',
      emoji: '💎',
      title: 'Elite',
      description: 'Earned 500 points total',
      condition: '500 points',
    ),
  ];

  // ── Check and award badges after check-in ──
  Future<List<AppBadge>> checkAndAwardBadges({
    required String uid,
    required int totalAttendance,
    required int totalPoints,
    required int currentStreak,
  }) async {
    final List<AppBadge> newlyEarned = [];

    // Get already earned badges
    final profileSnap =
    await _db.collection('profiles').doc(uid).get();
    final data = profileSnap.data() as Map<String, dynamic>?;
    final earnedIds = List<String>.from(
        data?['badges'] as List? ?? []);

    for (final badge in allBadges) {
      if (earnedIds.contains(badge.id)) continue;

      bool earned = false;

      switch (badge.id) {
        case 'first_step':
          earned = totalAttendance >= 1;
          break;
        case 'on_fire':
          earned = currentStreak >= 3;
          break;
        case 'unstoppable':
          earned = currentStreak >= 5;
          break;
        case 'dedicated':
          earned = totalAttendance >= 10;
          break;
        case 'champion':
          earned = totalAttendance >= 25;
          break;
        case 'point_collector':
          earned = totalPoints >= 100;
          break;
        case 'elite':
          earned = totalPoints >= 500;
          break;
      }

      if (earned) {
        newlyEarned.add(badge);
        earnedIds.add(badge.id);
      }
    }

    // Save newly earned badges to Firestore
    if (newlyEarned.isNotEmpty) {
      await _db.collection('profiles').doc(uid).update({
        'badges': earnedIds,
      });
    }

    return newlyEarned;
  }

  // ── Update streak after check-in ──
  Future<int> updateStreak(String uid) async {
    final profileSnap =
    await _db.collection('profiles').doc(uid).get();
    final data = profileSnap.data() as Map<String, dynamic>?;

    final lastCheckIn =
    (data?['lastCheckIn'] as Timestamp?)?.toDate();
    final currentStreak = (data?['streak'] ?? 0) as int;

    final now = DateTime.now();

    int newStreak = currentStreak;

    if (lastCheckIn == null) {
      // First ever check-in
      newStreak = 1;
    } else {
      // Get week numbers
      final lastWeek = _weekNumber(lastCheckIn);
      final currentWeek = _weekNumber(now);
      final lastYear = lastCheckIn.year;
      final currentYear = now.year;

      if (currentYear == lastYear && currentWeek == lastWeek) {
        // Same week — streak unchanged
        newStreak = currentStreak;
      } else if ((currentYear == lastYear &&
          currentWeek == lastWeek + 1) ||
          (currentYear == lastYear + 1 &&
              lastWeek >= 52 &&
              currentWeek == 1)) {
        // Consecutive week — increment streak
        newStreak = currentStreak + 1;
      } else {
        // Missed a week — reset streak
        newStreak = 1;
      }
    }

    // Save streak and last check-in
    await _db.collection('profiles').doc(uid).update({
      'streak': newStreak,
      'lastCheckIn': Timestamp.fromDate(now),
    });

    return newStreak;
  }

  // ── Get week number of a date ──
  int _weekNumber(DateTime date) {
    final dayOfYear = int.parse(
      DateTime(date.year, date.month, date.day)
          .difference(DateTime(date.year, 1, 1))
          .inDays
          .toString(),
    );
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  // ── Get badge by ID ──
  static AppBadge? getBadgeById(String id) {
    try {
      return allBadges.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Get all earned badges for user ──
  static List<AppBadge> getEarnedBadges(List<String> earnedIds) {
    return allBadges
        .where((b) => earnedIds.contains(b.id))
        .toList();
  }

  // ── Get all unearned badges for user ──
  static List<AppBadge> getUnearnedBadges(List<String> earnedIds) {
    return allBadges
        .where((b) => !earnedIds.contains(b.id))
        .toList();
  }
}