import '../../state/settings_store.dart';

/// The Settings screen's copy in English and Bangla, from the design.
class SettingsStrings {
  const SettingsStrings._({
    required this.back,
    required this.title,
    required this.appearance,
    required this.theme,
    required this.language,
    required this.preferences,
    required this.currency,
    required this.currencyNote,
    required this.haptics,
    required this.hapticsSub,
    required this.data,
    required this.export,
    required this.exportSub,
    required this.version,
    required String exportedPrefix,
    required String exportedSuffix,
    required Map<ThemeChoice, String> themeNames,
    required bool bangla,
  }) : _exportedPrefix = exportedPrefix,
       _exportedSuffix = exportedSuffix,
       _themeNames = themeNames,
       _bangla = bangla;

  static SettingsStrings of(AppLanguage language) =>
      language == AppLanguage.bn ? _bn : _en;

  final String back;
  final String title;
  final String appearance;
  final String theme;
  final String language;
  final String preferences;
  final String currency;

  /// Under the currency list: amounts keep their numbers.
  final String currencyNote;
  final String haptics;
  final String hapticsSub;
  final String data;
  final String export;
  final String exportSub;
  final String version;
  final String _exportedPrefix;
  final String _exportedSuffix;
  final Map<ThemeChoice, String> _themeNames;
  final bool _bangla;

  String themeName(ThemeChoice t) => _themeNames[t]!;

  String currencyName(Currency c) => _bangla ? c.banglaName : c.englishName;

  /// The export toast: `Saved Daily-Bag-2026.xlsx`.
  String exported(String fileName) =>
      '$_exportedPrefix$fileName$_exportedSuffix';

  static const _en = SettingsStrings._(
    back: 'Back',
    title: 'Settings',
    appearance: 'Appearance',
    theme: 'Theme',
    language: 'Language',
    preferences: 'Preferences',
    currency: 'Currency',
    currencyNote:
        'Only the symbol and format change. Your amounts aren’t converted.',
    haptics: 'Haptic feedback',
    hapticsSub: 'Gentle taps when you tick or save',
    data: 'Data',
    export: 'Export to Excel',
    exportSub: 'All expenses as an .xlsx file',
    version: 'Daily Bag · Version 1.0',
    exportedPrefix: 'Saved ',
    exportedSuffix: '',
    themeNames: {
      ThemeChoice.system: 'System',
      ThemeChoice.light: 'Light',
      ThemeChoice.dark: 'Dark',
    },
    bangla: false,
  );

  static const _bn = SettingsStrings._(
    back: 'ফিরে যান',
    title: 'সেটিংস',
    appearance: 'চেহারা',
    theme: 'থিম',
    language: 'ভাষা',
    preferences: 'পছন্দসমূহ',
    currency: 'মুদ্রা',
    currencyNote:
        'শুধু চিহ্ন বদলাবে। আপনার পরিমাণ অন্য মুদ্রায় রূপান্তর হবে না।',
    haptics: 'হ্যাপটিক ফিডব্যাক',
    hapticsSub: 'টিক বা সেভ করলে হালকা কম্পন',
    data: 'ডেটা',
    export: 'এক্সেলে এক্সপোর্ট',
    exportSub: 'সব খরচ একটি .xlsx ফাইলে',
    version: 'ডেইলি ব্যাগ · ভার্সন ১.০',
    exportedPrefix: '',
    exportedSuffix: ' সেভ হয়েছে',
    themeNames: {
      ThemeChoice.system: 'সিস্টেম',
      ThemeChoice.light: 'লাইট',
      ThemeChoice.dark: 'ডার্ক',
    },
    bangla: true,
  );
}
