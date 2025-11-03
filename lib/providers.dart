
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/admin_service.dart';
import 'services/hce_service.dart';
import 'services/nfc_reader_service.dart';
import 'services/qr_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final adminServiceProvider = Provider<AdminService>((ref) => AdminService(ref.read));
final hceServiceProvider = Provider<HceService>((ref) => HceService());
final nfcReaderServiceProvider = Provider<NfcReaderService>((ref) => NfcReaderService());
final qrServiceProvider = Provider<QrService>((ref) => QrService());
