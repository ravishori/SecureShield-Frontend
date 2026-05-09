import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'app_language';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  const AppLanguage({required this.code, required this.name, required this.nativeName});
}

const supportedLanguages = [
  AppLanguage(code: 'en', name: 'English',   nativeName: 'English'),
  AppLanguage(code: 'hi', name: 'Hindi',     nativeName: 'हिंदी'),
  AppLanguage(code: 'mr', name: 'Marathi',   nativeName: 'मराठी'),
  AppLanguage(code: 'bn', name: 'Bengali',   nativeName: 'বাংলা'),
  AppLanguage(code: 'ta', name: 'Tamil',     nativeName: 'தமிழ்'),
  AppLanguage(code: 'te', name: 'Telugu',    nativeName: 'తెలుగు'),
];

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('en') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    if (saved != null) state = saved;
  }

  Future<void> setLanguage(String code) async {
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, code);
  }

  AppLanguage get current =>
      supportedLanguages.firstWhere((l) => l.code == state,
          orElse: () => supportedLanguages.first);

  Locale get locale => Locale(state);
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);

/// Derived provider that exposes the current [Locale] for MaterialApp.
final localeProvider = Provider<Locale>((ref) {
  final code = ref.watch(languageProvider);
  return Locale(code);
});
