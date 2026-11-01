import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/tokens.dart';
import 'data/expense_database.dart';
import 'screens/home/home_screen.dart';
import 'state/expense_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // A few kilobytes of rows: loads well within the launch screen.
  final store = await ExpenseStore.load(await ExpenseDatabase.open());
  runApp(
    ChangeNotifierProvider.value(value: store, child: const LittleExpenseApp()),
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
