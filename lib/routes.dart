import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/nfc_phone_reader_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/rewards_store_screen.dart';
import 'screens/attendance_history_screen.dart';
import 'screens/events_calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/chat_screen.dart';

class Routes {
  static const login = '/';
  static const home = '/home';
  static const qrScanner = '/qr';
  static const nfcTag = '/nfc-tag';
  static const nfcPhoneReader = '/nfc-phone-reader';
  static const adminPanel = '/admin';
  static const rewards = '/rewards';
  static const history = '/history';
  static const eventsCalendar = '/events-calendar';
  static const profile = '/profile';
  static const groups = '/groups';
  static const chat = '/chat';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case qrScanner:
        return MaterialPageRoute(builder: (_) => const QrScannerScreen());
      case nfcPhoneReader:
        return MaterialPageRoute(builder: (_) => const NfcPhoneReaderScreen());
      case adminPanel:
        return MaterialPageRoute(builder: (_) => const AdminPanelScreen());
      case rewards:
        return MaterialPageRoute(builder: (_) => const RewardsStoreScreen());
      case history:
        return MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen());
      case eventsCalendar:
        return MaterialPageRoute(builder: (_) => const EventsCalendarScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case groups:
        return MaterialPageRoute(builder: (_) => const GroupsScreen());
      case chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            groupId: args['groupId'] as String,
            groupName: args['groupName'] as String,
            isCommunity: args['isCommunity'] as bool? ?? false,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
              body: Center(child: Text('Unknown route'))),
        );
    }
  }
}