import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/tokens.dart';
import 'data/expense_database.dart';
import 'screens/home/home_screen.dart';
import 'state/bazar_store.dart';
import 'state/expense_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // A few kilobytes of rows: loads well within the launch screen.
  final database = await ExpenseDatabase.open();
  final settings = await SettingsStore.load(database);
  final store = await ExpenseStore.load(database);
  final bazar = await BazarStore.load(database);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: bazar),
      ],
      child: const LittleExpenseApp(),
    ),
  );
}

class LittleExpenseApp extends StatefulWidget {
  const LittleExpenseApp({super.key});

  @override
  State<LittleExpenseApp> createState() => _LittleExpenseAppState();
}

class _LittleExpenseAppState extends State<LittleExpenseApp> {
  (Currency, AppLanguage)? _format;

  /// Money and copy come from globals (symbol, language), so a change has
  /// to reach every widget, including routes under the Settings screen.
  void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final format = (settings.currency, settings.language);
    if (_format != null && _format != format) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildEverything();
      });
    }
    _format = format;

    return CupertinoApp(
      title: 'Daily Bag',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final dark = switch (settings.theme) {
          ThemeChoice.light => false,
          ThemeChoice.dark => true,
          ThemeChoice.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        final palette = dark ? Palette.dark : Palette.light;
        return PaletteScope(
          palette: palette,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              primaryColor: AppColors.accent,
              scaffoldBackgroundColor: palette.background,
              textTheme: CupertinoTextThemeData(textStyle: palette.text),
            ),
            child: DefaultTextStyle(style: palette.text, child: child!),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
