import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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

class EventsCalendarScreen extends StatefulWidget {
  const EventsCalendarScreen({super.key});

  @override
  State<EventsCalendarScreen> createState() => _EventsCalendarScreenState();
}

class _EventsCalendarScreenState extends State<EventsCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadEvents();
  }

  // ── Load all events from Firestore ──
  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('startsAt', descending: false)
          .get();

      final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final startsAt = (data['startsAt'] as Timestamp?)?.toDate().toLocal();
        if (startsAt == null) continue;

        // Normalize to date only (no time)
        final dateKey =
        DateTime(startsAt.year, startsAt.month, startsAt.day);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Event',
          'startsAt': startsAt,
          'endsAt':
          (data['endsAt'] as Timestamp?)?.toDate().toLocal(),
          'pointsPerAttendance':
          (data['pointsPerAttendance'] ?? 10) as int,
          'ownerUid': data['ownerUid'] ?? '',
        });
      }

      setState(() {
        _eventsByDay = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Get events for a specific day
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  // Get events for selected day
  List<Map<String, dynamic>> get _selectedEvents {
    if (_selectedDay == null) return [];
    return _getEventsForDay(_selectedDay!);
  }

  // ── Upcoming events (next 30 days) ──
  List<Map<String, dynamic>> get _upcomingEvents {
    final now = DateTime.now();
    final limit = now.add(const Duration(days: 30));
    final List<Map<String, dynamic>> upcoming = [];

    for (final entry in _eventsByDay.entries) {
      if (entry.key.isAfter(now.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(limit)) {
        upcoming.addAll(entry.value);
      }
    }

    upcoming.sort((a, b) =>
        (a['startsAt'] as DateTime).compareTo(b['startsAt'] as DateTime));

    return upcoming;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Events Calendar'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Refresh events',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Calendar ──
              _buildCalendar(),

              // ── Selected day events ──
              if (_selectedDay != null) ...[
                _buildSectionHeader(
                  icon: Icons.today,
                  title: _isToday(_selectedDay!)
                      ? 'Today\'s Events'
                      : 'Events on ${_formatHeaderDate(_selectedDay!)}',
                  color: AppTheme.primaryBlue,
                ),
                _selectedEvents.isEmpty
                    ? _buildNoDayEvents()
                    : Column(
                  children: _selectedEvents
                      .map((e) => _buildEventCard(e,
                      highlight: true))
                      .toList(),
                ),
              ],

              // ── Upcoming events ──
              _buildSectionHeader(
                icon: Icons.upcoming,
                title: 'Upcoming Events (Next 30 Days)',
                color: AppTheme.accentOrange,
              ),
              _upcomingEvents.isEmpty
                  ? _buildNoUpcomingEvents()
                  : Column(
                children: _upcomingEvents
                    .map((e) => _buildEventCard(e))
                    .toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Calendar Widget ──
  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,

        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },

        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },

        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },

        // Styling
        calendarStyle: CalendarStyle(
          // Today
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.bold,
          ),

          // Selected day
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),

          // Event dot
          markerDecoration: const BoxDecoration(
            color: AppTheme.accentOrange,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 6,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),

          // Weekend
          weekendTextStyle:
          const TextStyle(color: AppTheme.errorRed),

          outsideDaysVisible: false,
        ),

        headerStyle: HeaderStyle(
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryBlue),
            borderRadius: BorderRadius.circular(12),
          ),
          formatButtonTextStyle:
          const TextStyle(color: AppTheme.primaryBlue),
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left,
              color: AppTheme.primaryBlue),
          rightChevronIcon: const Icon(Icons.chevron_right,
              color: AppTheme.primaryBlue),
        ),

        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppTheme.textLight,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: AppTheme.errorRed,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Event Card ──
  Widget _buildEventCard(Map<String, dynamic> event,
      {bool highlight = false}) {
    final name = event['name'] as String;
    final startsAt = event['startsAt'] as DateTime;
    final endsAt = event['endsAt'] as DateTime?;
    final points = event['pointsPerAttendance'] as int;
    final isToday = _isToday(startsAt);
    final isPast = startsAt
        .isBefore(DateTime.now().subtract(const Duration(hours: 1)));
    final isUpcoming = !isPast;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight && isToday
            ? Border.all(color: AppTheme.primaryBlue, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey.withOpacity(0.1)
                    : isToday
                    ? AppTheme.primaryBlue
                    : AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _monthAbbr(startsAt.month),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPast
                          ? AppTheme.textLight
                          : isToday
                          ? Colors.white70
                          : AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    '${startsAt.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPast
                          ? AppTheme.textLight
                          : isToday
                          ? Colors.white
                          : AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    '${startsAt.year}',
                    style: TextStyle(
                      fontSize: 9,
                      color: isPast
                          ? AppTheme.textLight
                          : isToday
                          ? Colors.white60
                          : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event name + status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isPast
                                ? AppTheme.textLight
                                : AppTheme.textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(isToday, isPast),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Time
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: AppTheme.textLight),
                      const SizedBox(width: 4),
                      Text(
                        endsAt != null
                            ? '${_formatTime(startsAt)} – ${_formatTime(endsAt)}'
                            : _formatTime(startsAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Points
                  Row(
                    children: [
                      const Icon(Icons.stars,
                          size: 13, color: AppTheme.accentOrange),
                      const SizedBox(width: 4),
                      Text(
                        '$points pts for attending',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Today reminder
                  if (isToday && isUpcoming) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner,
                              size: 13,
                              color: AppTheme.successGreen),
                          SizedBox(width: 5),
                          Text(
                            'Happening today — scan to check in!',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isToday, bool isPast) {
    if (isPast) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Past',
            style: TextStyle(
                fontSize: 10,
                color: AppTheme.textLight,
                fontWeight: FontWeight.bold)),
      );
    }
    if (isToday) {
      return Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.successGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6, color: Colors.white),
            SizedBox(width: 3),
            Text('Today',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('Upcoming',
          style: TextStyle(
              fontSize: 10,
              color: AppTheme.accentOrange,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildNoDayEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.event_busy, color: AppTheme.textLight),
            SizedBox(width: 12),
            Text('No events on this day',
                style: TextStyle(
                    color: AppTheme.textLight, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUpcomingEvents() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_available,
                size: 60, color: AppTheme.textLight.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('No upcoming events in the next 30 days',
                style:
                TextStyle(color: AppTheme.textLight, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 60, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            const Text('Failed to load events',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: const TextStyle(
                    color: AppTheme.textLight, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatHeaderDate(DateTime dt) {
    return '${dt.day} ${_monthFull(dt.month)} ${dt.year}';
  }

  String _monthAbbr(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }

  String _monthFull(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}