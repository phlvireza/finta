import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Manages app-wide settings: currency, theme, payday, onboarding status.
class SettingsProvider extends ChangeNotifier {
  static const _keyCurrency = 'currency_code';
  static const _keyThemeMode = 'theme_mode';
  static const _keyPayday = 'payday';
  static const _keyOnboarding = 'has_completed_onboarding';
  static const _keyLocale = 'locale';
  static const _keyHideBalances = 'hide_balances';

  SharedPreferences? _prefs;

  // Defaults
  String _currencyCode = 'IDR';
  String _currencySymbol = 'Rp';
  bool _currencyUseDecimals = false;
  ThemeMode _themeMode = ThemeMode.system;
  int _payday = 1;
  bool _hasCompletedOnboarding = false;
  String _languageCode = 'en'; // Default language
  bool _hideBalances = false;

  // Getters
  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  bool get currencyUseDecimals => _currencyUseDecimals;
  ThemeMode get themeMode => _themeMode;
  int get payday => _payday;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);
  bool get hideBalances => _hideBalances;

  /// Initialize from SharedPreferences. Call once at app startup.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _currencyCode = _prefs!.getString(_keyCurrency) ?? 'IDR';
    _updateCurrencyFromCode(_currencyCode);

    final themeModeStr = _prefs!.getString(_keyThemeMode) ?? 'system';
    _themeMode = _themeModeFromString(themeModeStr);

    _payday = _prefs!.getInt(_keyPayday) ?? 1;
    _hasCompletedOnboarding = _prefs!.getBool(_keyOnboarding) ?? false;
    _languageCode = _prefs!.getString(_keyLocale) ?? 'en';
    _hideBalances = _prefs!.getBool(_keyHideBalances) ?? false;

    notifyListeners();
  }

  Future<void> setHideBalances(bool hide) async {
    _hideBalances = hide;
    await _prefs?.setBool(_keyHideBalances, hide);
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    _currencyCode = code;
    _updateCurrencyFromCode(code);
    await _prefs?.setString(_keyCurrency, code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_keyThemeMode, _themeModeToString(mode));
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await _prefs?.setString(_keyLocale, code);
    notifyListeners();
  }

  Future<void> setPayday(int day) async {
    _payday = day.clamp(1, 31);
    await _prefs?.setInt(_keyPayday, _payday);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _prefs?.setBool(_keyOnboarding, true);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    _hasCompletedOnboarding = false;
    await _prefs?.setBool(_keyOnboarding, false);
    notifyListeners();
  }

  void _updateCurrencyFromCode(String code) {
    final currency = AppConstants.currencies.firstWhere(
      (c) => c.code == code,
      orElse: () => AppConstants.currencies.first,
    );
    _currencySymbol = currency.symbol;
    _currencyUseDecimals = currency.useDecimals;
  }

  ThemeMode _themeModeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
