import 'package:flutter/foundation.dart';

import '../app/format.dart';
import '../app/haptics.dart';
import '../app/strings.dart';
import '../data/expense_database.dart';

enum ThemeChoice { system, light, dark }

enum AppLanguage { en, bn }

enum Currency {
  bdt('BDT', '৳', 'Bangladeshi Taka', 'বাংলাদেশি টাকা'),
  inr('INR', '₹', 'Indian Rupee', 'ভারতীয় রুপি'),
  usd('USD', r'$', 'US Dollar', 'মার্কিন ডলার'),
  eur('EUR', '€', 'Euro', 'ইউরো');

  const Currency(this.code, this.symbol, this.englishName, this.banglaName);

  final String code;
  final String symbol;
  final String englishName;
  final String banglaName;
}

/// The Settings screen's choices, saved on the device.
///
/// Haptics, currency and language are global switches ([Haptics.enabled],
/// [currencySymbol], [bangla]); this keeps them in step with what is stored.
class SettingsStore extends ChangeNotifier {
  SettingsStore({
    ThemeChoice theme = ThemeChoice.system,
    AppLanguage language = AppLanguage.en,
    Currency currency = Currency.bdt,
    bool haptics = true,
    ExpenseDatabase? database,
  }) : _theme = theme,
       _language = language,
       _currency = currency,
       _haptics = haptics,
       _database = database {
    _apply();
  }

  static const _themeKey = 'theme';
  static const _languageKey = 'language';
  static const _currencyKey = 'currency';
  static const _hapticsKey = 'haptics';

  static Future<SettingsStore> load(ExpenseDatabase database) async {
    final saved = await database.loadSettings();
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[saved[key]] ?? fallback;
    return SettingsStore(
      theme: pick(ThemeChoice.values, _themeKey, ThemeChoice.system),
      language: pick(AppLanguage.values, _languageKey, AppLanguage.en),
      currency: pick(Currency.values, _currencyKey, Currency.bdt),
      haptics: saved[_hapticsKey] != 'false',
      database: database,
    );
  }

  final ExpenseDatabase? _database;
  ThemeChoice _theme;
  AppLanguage _language;
  Currency _currency;
  bool _haptics;
  Future<void> _writes = Future.value();

  ThemeChoice get theme => _theme;
  AppLanguage get language => _language;
  Currency get currency => _currency;
  bool get haptics => _haptics;

  set theme(ThemeChoice value) {
    if (value == _theme) return;
    _theme = value;
    _changed(_themeKey, value.name);
  }

  set language(AppLanguage value) {
    if (value == _language) return;
    _language = value;
    _changed(_languageKey, value.name);
  }

  set currency(Currency value) {
    if (value == _currency) return;
    _currency = value;
    _changed(_currencyKey, value.name);
  }

  set haptics(bool value) {
    if (value == _haptics) return;
    _haptics = value;
    _changed(_hapticsKey, '$value');
  }

  /// Completes once every change made so far has been written.
  Future<void> flush() => _writes;

  void _apply() {
    Haptics.enabled = _haptics;
    currencySymbol = _currency.symbol;
    bangla = _language == AppLanguage.bn;
  }

  void _changed(String key, String value) {
    _apply();
    notifyListeners();
    final db = _database;
    if (db == null) return;
    _writes = _writes.then((_) async {
      try {
        await db.saveSetting(key, value);
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'daily_bag',
            context: ErrorDescription('while saving settings'),
          ),
        );
      }
    });
  }
}
