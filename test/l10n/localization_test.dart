import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

void main() {
  const locales = ['en', 'hi', 'mr', 'bn', 'ta', 'te'];

  test('all six languages define exactly the same keys as English', () {
    Set<String> keys(String l) => (json.decode(
          File('lib/l10n/app_$l.arb').readAsStringSync(),
        ) as Map<String, dynamic>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    final en = keys('en');
    for (final l in locales) {
      expect(keys(l), en, reason: 'app_$l.arb differs from app_en.arb');
    }
  });

  test('every translation keeps the same {placeholders} as English', () {
    Map<String, dynamic> load(String l) =>
        json.decode(File('lib/l10n/app_$l.arb').readAsStringSync())
            as Map<String, dynamic>;
    final en = load('en');
    final ph = RegExp(r'\{(\w+)\}');
    for (final l in locales.where((l) => l != 'en')) {
      final tr = load(l);
      for (final k in en.keys.where((k) => !k.startsWith('@'))) {
        final want =
            ph.allMatches(en[k] as String).map((m) => m.group(1)).toSet();
        final got =
            ph.allMatches(tr[k] as String).map((m) => m.group(1)).toSet();
        expect(got, want, reason: '$l/$k placeholders differ');
        expect((tr[k] as String).trim(), isNotEmpty, reason: '$l/$k is empty');
      }
    }
  });

  testWidgets('family strings with placeholders render in Hindi',
      (tester) async {
    late AppLocalizations t;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('hi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        t = AppLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    expect(t.familyTabInvites(3), 'निमंत्रण (3)');
    expect(t.inviteTitle('Asha'), contains('Asha'));
    expect(t.navHome, 'होम');
  });

  for (final code in locales) {
    testWidgets('screens render $code strings', (tester) async {
      late AppLocalizations t;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          t = AppLocalizations.of(context);
          return Text(t.signIn);
        }),
      ));
      expect(t.signIn, isNotEmpty);
      expect(t.verifyTitle, isNotEmpty);
      expect(t.seniorCitizenMode, isNotEmpty);
      if (code != 'en') {
        expect(t.signIn, isNot('Sign In'), reason: '$code is not translated');
        expect(t.settings, isNot('Settings'));
      }
      expect(find.text(t.signIn), findsOneWidget);
    });
  }
}
