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
