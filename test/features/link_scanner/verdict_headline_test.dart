import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/network/dio_client.dart';
import 'package:secureshield_app/core/verdict/scam_verdict.dart';
import 'package:secureshield_app/features/link_scanner/screens/link_scanner_screen.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

import '../../core/verdict/server_verdict_fixtures.dart';
import '../auth/fake_http.dart';

Map<String, dynamic> fx(String name) => jsonDecode(serverVerdictFixtures[name]!) as Map<String, dynamic>;

/// A valid `safe` verdict (positive, non-provider evidence) — no current detector emits one, so it is built by hand.
Map<String, dynamic> safeVerdict() => {
      ...fx('messageLow'),
      'risk_level': 'safe',
      'risk_score': 0,
      'reasons': <Object>[],
      'evidence': [
        {'code': 'sender_registered', 'count': null, 'kind': 'registry_match', 'polarity': 'positive', 'source': 'registry:sender', 'weight': null},
      ],
    };

Map<String, dynamic> legacy({bool malicious = false, bool phishing = false, double score = 0.0, String provider = 'google_safe_browsing+urlhaus'}) => {
      'id': '11111111-1111-1111-1111-111111111111',
      'user_id': '22222222-2222-2222-2222-222222222222',
      'url': 'https://example.com',
      'is_phishing': phishing,
      'is_malicious': malicious,
      'risk_score': score,
      'threat_category': null,
      'scan_provider': provider,
      'gsb_threats': null,
      'scanned_at': '2026-11-14T10:00:00',
    };

Widget app() => const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LinkScannerScreen(),
    );

/// Scans once with the given response body and returns after the result card is shown.
Future<void> scanWith(WidgetTester t, Map<String, dynamic> body) async {
  t.view.physicalSize = const Size(900, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  DioClient().dio.httpClientAdapter = FakeAdapter((o) => o.method == 'GET' ? jsonBody(200, <Object>[]) : jsonBody(200, body));
  await t.pumpWidget(app());
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField).first, 'https://example.com');
  await t.tap(find.byType(ElevatedButton).first);
  await t.pumpAndSettle();
}

const allLabels = ['SAFE', 'LOW RISK', 'SUSPICIOUS', 'HIGH RISK', 'CRITICAL RISK', 'UNABLE TO VERIFY', 'MALICIOUS'];

void expectOnly(String label) {
  for (final l in allLabels) {
    expect(find.text(l), l == label ? findsOneWidget : findsNothing, reason: 'expected only "$label", checking "$l"');
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => DioClient().dio.httpClientAdapter = FakeAdapter((_) => jsonBody(404, {'detail': 'x'})));

  group('verdict-driven headline', () {
    final cases = <String, (Map<String, dynamic> Function(), String)>{
      'safe': (safeVerdict, 'SAFE'),
      'low': (() => fx('urlNotListed'), 'LOW RISK'),
      'medium': (() => fx('urlMedium'), 'SUSPICIOUS'),
      'high': (() => fx('messageHigh'), 'HIGH RISK'),
      'critical': (() => fx('urlCritical'), 'CRITICAL RISK'),
      'unknown': (() => fx('urlOutage'), 'UNABLE TO VERIFY'),
    };
    for (final e in cases.entries) {
      testWidgets('${e.key} verdict -> ${e.value.$2}', (t) async {
        final v = e.value.$1();
        expect(ScamVerdict.tryParse(v), isNotNull, reason: 'fixture must be a valid verdict');
        await scanWith(t, {...legacy(), 'verdict': v});
        expectOnly(e.value.$2);
      });
    }

    testWidgets('the heuristics-only badge never overrides the verdict (low verdict, internal_fallback provider)', (t) async {
      await scanWith(t, {...legacy(provider: 'internal_fallback'), 'verdict': fx('urlNotListed')});
      expectOnly('LOW RISK');
      expect(find.text('Internal heuristics only (no live threat feed)'), findsWidgets);
    });

    testWidgets('an outage with no adverse signal is UNABLE TO VERIFY, with no score bar and never SAFE', (t) async {
      await scanWith(t, {...legacy(provider: 'internal_fallback'), 'verdict': fx('urlOutage')});
      expectOnly('UNABLE TO VERIFY');
      expect(find.textContaining('/100'), findsNothing);
    });

    testWidgets('outage plus an adverse heuristic shows the heuristic level (SUSPICIOUS), not UNABLE TO VERIFY', (t) async {
      await scanWith(t, {...legacy(provider: 'internal_fallback', phishing: true, score: 55), 'verdict': fx('urlOutageAdverse')});
      expectOnly('SUSPICIOUS');
    });
  });

  group('missing or malformed verdict fails closed', () {
    final bad = <String, Object?>{
      'missing': null,
      'string': 'safe',
      'uppercase safe': {...fx('urlNotListed'), 'risk_level': 'SAFE'},
      'safe without evidence': {...fx('messageLow'), 'risk_level': 'safe'},
      'wrong schema version': {...fx('urlNotListed'), 'schema_version': 9},
      'empty object': <String, dynamic>{},
    };
    for (final e in bad.entries) {
      testWidgets('${e.key}: a clean-looking legacy scan is UNABLE TO VERIFY, never SAFE', (t) async {
        await scanWith(t, {...legacy(), if (e.value != null) 'verdict': e.value});
        expectOnly('UNABLE TO VERIFY');
      });
    }
  });

  group('legacy response compatibility', () {
    testWidgets('legacy malicious (no verdict) keeps the MALICIOUS headline', (t) async {
      await scanWith(t, legacy(malicious: true, score: 95));
      expectOnly('MALICIOUS');
      expect(find.text('Do NOT open this URL'), findsOneWidget);
    });

    testWidgets('legacy phishing / medium score (no verdict) keeps the SUSPICIOUS headline', (t) async {
      await scanWith(t, legacy(phishing: true, score: 55));
      expectOnly('SUSPICIOUS');
      expect(find.text('Proceed with caution'), findsOneWidget);
    });
  });
}
