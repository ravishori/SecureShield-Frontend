import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/features/link_scanner/screens/link_scanner_screen.dart';
import 'package:secureshield_app/features/message_analyzer/screens/message_analyzer_screen.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

import '../../features/auth/fake_http.dart';

/// The two approved safe-default corrections: a MISSING field must never read as "safe" / "verified".
Widget app(Widget home) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  tearDown(() => DioClient().dio.httpClientAdapter = IOHttpClientAdapterPlaceholder.instance());

  testWidgets('message result: a missing is_safe is NOT shown as safe', (t) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    var isSafe = false;
    DioClient().dio.httpClientAdapter = FakeAdapter((o) {
      final body = <String, dynamic>{
        'risk_level': 'unknown',
        'risk_score': 0.0,
        'scam_type': 'none',
        'explanation': 'e',
        'action': 'a',
        'red_flags': <String>[],
        'detected_patterns': <String>[],
        'analyzed_at': '2026-11-14T10:00:00',
        if (isSafe) 'is_safe': true, // present and true: shown as safe
      };
      return jsonBody(200, body); // is_safe absent in the first run
    });
    await t.pumpWidget(app(const MessageAnalyzerScreen()));
    await t.enterText(find.byType(TextField).last, 'hello there');
    await t.tap(find.byType(ElevatedButton).first);
    await t.pumpAndSettle();
    expect(find.text('Suspicious Message!'), findsOneWidget);
    expect(find.text('Message Appears Safe'), findsNothing);
    expect(find.text('No warning signs found'), findsNothing);

    isSafe = true;
    await t.tap(find.byType(ElevatedButton).first);
    await t.pumpAndSettle();
    expect(find.text('No warning signs found'), findsOneWidget);
  });

  testWidgets('link result: a missing scan_provider is shown as "unable to verify", not as a verified scan', (t) async {
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    DioClient().dio.httpClientAdapter = FakeAdapter((o) {
      if (o.method == 'GET') return jsonBody(200, <Object>[]);
      return jsonBody(200, {
        'id': '11111111-1111-1111-1111-111111111111',
        'user_id': '22222222-2222-2222-2222-222222222222',
        'url': 'https://example.com',
        'is_phishing': false,
        'is_malicious': false,
        'risk_score': 0.0,
        'threat_category': null,
        // scan_provider deliberately absent
        'gsb_threats': null,
        'scanned_at': '2026-11-14T10:00:00',
      });
    });
    await t.pumpWidget(app(const LinkScannerScreen()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'https://example.com');
    await t.tap(find.byType(ElevatedButton).first);
    await t.pumpAndSettle();
    expect(find.text('Internal heuristics only (no live threat feed)'), findsWidgets); // the fallback badge, not the neutral "Internal scan"
    expect(find.text('Internal scan'), findsNothing);
  });
}

/// Restores a plain adapter after each test so other suites in the same process are unaffected.
class IOHttpClientAdapterPlaceholder {
  static HttpClientAdapter instance() => FakeAdapter((_) => jsonBody(404, {'detail': 'x'}));
}
