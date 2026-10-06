import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/features/otp_vault/otp_vault_store.dart';
import 'package:secureshield_app/features/otp_vault/screens/otp_vault_screen.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('OtpVaultStore', () {
    test('stores, reloads, marks read, archives and deletes', () async {
      final s = OtpVaultStore();
      final t = DateTime(2026, 10, 6, 12);
      expect(
          await s.add(
              sender: 'HDFC Bank',
              otp: '482916',
              sourceApp: 'com.hdfc',
              now: t),
          isTrue);
      expect(
          await s.add(
              sender: 'SBI',
              otp: '771204',
              sourceApp: 'com.sbi',
              now: t.add(const Duration(minutes: 5))),
          isTrue);
      var all = await OtpVaultStore()
          .load(); // a fresh instance reads what was persisted
      expect(all.map((e) => e.otp), ['771204', '482916']); // newest first
      await s.markRead(all[0].id);
      await s.setArchived(all[1].id, true);
      all = await s.load();
      expect(all[0].isRead, isTrue);
      expect(all[1].isArchived, isTrue);
      await s.delete(all[0].id);
      expect((await s.load()).length, 1);
      await s.clear();
      expect(await s.load(), isEmpty);
    });

    test(
        'ignores empty codes and the same code from the same sender within two minutes',
        () async {
      final s = OtpVaultStore();
      final t = DateTime(2026, 10, 6, 12);
      expect(
          await s.add(sender: 'A', otp: '', sourceApp: 'x', now: t), isFalse);
      expect(await s.add(sender: 'A', otp: '111111', sourceApp: 'x', now: t),
          isTrue);
      expect(
          await s.add(
              sender: 'A',
              otp: '111111',
              sourceApp: 'x',
              now: t.add(const Duration(seconds: 30))),
          isFalse);
      expect(
          await s.add(
              sender: 'A',
              otp: '111111',
              sourceApp: 'x',
              now: t.add(const Duration(minutes: 3))),
          isTrue);
      expect((await s.load()).length, 2);
    });

    test('is bounded', () async {
      final s = OtpVaultStore(maxEntries: 3);
      final t = DateTime(2026, 10, 6, 12);
      for (var i = 0; i < 6; i++) {
        await s.add(
            sender: 'S$i',
            otp: '10000$i',
            sourceApp: 'x',
            now: t.add(Duration(minutes: i * 5)));
      }
      final all = await s.load();
      expect(all.length, 3);
      expect(all.first.otp, '100005');
    });

    test('corrupt storage reads as an empty vault instead of crashing',
        () async {
      FlutterSecureStorage.setMockInitialValues({'otp_vault_v1': '{not json'});
      expect(await OtpVaultStore().load(), isEmpty);
    });
  });

  group('OtpVaultScreen', () {
    Future<void> pump(WidgetTester tester,
        {required bool unlocks, OtpVaultStore? store}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OtpVaultScreen(store: store, authenticate: () async => unlocks),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('stays locked and shows no OTP when authentication fails',
        (tester) async {
      final s = OtpVaultStore();
      await s.add(sender: 'HDFC', otp: '482916', sourceApp: 'x');
      await pump(tester, unlocks: false, store: s);
      expect(find.text('OTP Vault is locked'), findsOneWidget);
      expect(find.textContaining('482916'), findsNothing);
      expect(find.textContaining('••••••'), findsNothing);
    });

    testWidgets(
        'after unlock codes are masked until tapped, and can be archived and deleted',
        (tester) async {
      final s = OtpVaultStore();
      await s.add(sender: 'HDFC Bank', otp: '482916', sourceApp: 'x');
      await pump(tester, unlocks: true, store: s);
      expect(find.text('••••••'), findsOneWidget);
      expect(find.text('482916'), findsNothing);
      await tester.tap(find.text('••••••'));
      await tester.pumpAndSettle();
      expect(find.text('482916'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('482916'), findsNothing); // moved out of the main list
      await tester.tap(find.byTooltip('Show archived'));
      await tester.pumpAndSettle();
      expect(find.text('••••••'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No archived OTPs'), findsOneWidget);
      expect(await s.load(), isEmpty);
    });

    testWidgets('the locked screen is rendered from the Hindi translation', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('hi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OtpVaultScreen(store: OtpVaultStore(), authenticate: () async => false),
      ));
      await tester.pumpAndSettle();
      expect(find.text('ओटीपी वॉल्ट लॉक है'), findsOneWidget);
      expect(find.text('OTP Vault is locked'), findsNothing);
    });

    testWidgets('shows an empty state when there is nothing saved',
        (tester) async {
      await pump(tester, unlocks: true, store: OtpVaultStore());
      expect(find.textContaining('No OTPs saved yet'), findsOneWidget);
    });
  });
}
