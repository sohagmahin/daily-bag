import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/tokens.dart';
import 'data/expense_database.dart';
import 'screens/home/home_screen.dart';
import 'state/bazar_store.dart';
import 'state/expense_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // A few kilobytes of rows: loads well within the launch screen.
  final database = await ExpenseDatabase.open();
  final store = await ExpenseStore.load(database);
  final bazar = await BazarStore.load(database);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: bazar),
      ],
      child: const LittleExpenseApp(),
    ),
  );
}

class LittleExpenseApp extends StatelessWidget {
  const LittleExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Daily Bag',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: CupertinoTextThemeData(textStyle: AppText.base),
      ),
      builder: (context, child) =>
          DefaultTextStyle(style: AppText.base, child: child!),
      home: const HomeScreen(),
    );
  }
}
