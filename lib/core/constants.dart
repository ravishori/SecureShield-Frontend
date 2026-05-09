import 'package:secureshield_app/core/app_config.dart';

class AppConstants {
  /// Dynamic base URL — resolved by AppConfig at startup.
  static String get baseUrl => AppConfig.baseUrl;

  // Storage keys
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey       = 'user_id';
  static const String userPhoneKey    = 'user_phone';

  // ── Auth endpoints ────────────────────────────────────────────────────────
  static const String sendOtp      = '/auth/send-otp';
  static const String verifyOtp    = '/auth/verify-otp';
  static const String register     = '/auth/register';
  static const String checkUser    = '/auth/check-user';
  static const String googleAuth   = '/auth/google-signin';
  static const String refreshToken = '/auth/refresh';
  static const String getMe        = '/auth/me';
  static const String updateMe     = '/auth/me';

  // ── Other endpoints ───────────────────────────────────────────────────────
  static const String devices        = '/devices';
  static const String registerDevice = '/devices/register';

  static const String appScan        = '/app-scanner/scan';
  static const String appScanResults = '/app-scanner/results';

  static const String linkScan    = '/link-scanner/scan';
  static const String linkHistory = '/link-scanner/history';

  static const String alerts     = '/alerts';
  static const String panicAlert = '/alerts/panic';

  static const String scamCallReport  = '/scam-calls/report';
  static const String scamCallHistory = '/scam-calls/history';

  static const String evidenceUpload = '/evidence/upload';
  static const String evidence       = '/evidence';

  static const String familyMembers = '/family/members';

  static const String dailyReport   = '/reports/daily';
  static const String reportHistory = '/reports/history';

  static const String wifiScan    = '/wifi/scan';
  static const String wifiHistory = '/wifi/history';

  static const String aiChat          = '/ai/chat';
  static const String generateEmail   = '/ai/generate-complaint-email';

  // ── Emergency Contacts ───────────────────────────────────────────────────
  static const String emergencyContacts = '/emergency-contacts';
}
