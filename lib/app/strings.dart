/// The app's copy in English and Bangla. [tr] follows the "Language"
/// setting; Bangla copy is from the design's Bangla row.
library;

/// Set from the "Language" setting.
bool bangla = false;

const _bengaliDigits = '০১২৩৪৫৬৭৮৯';

/// `2026` → `২০২৬` in Bangla; unchanged in English.
String digits(Object value) {
  final text = '$value';
  if (!bangla) return text;
  return text.replaceAllMapped(
    RegExp('[0-9]'),
    (m) => _bengaliDigits[int.parse(m[0]!)],
  );
}

/// Bengali digits typed on a Bangla keyboard, read as plain digits.
String asciiDigits(String text) => text.replaceAllMapped(
  RegExp('[০-৯]'),
  (m) => '${_bengaliDigits.indexOf(m[0]!)}',
);

Strings get tr => bangla ? Strings._bn : Strings._en;

class Strings {
  const Strings._({
    required this.dailyBag,
    required this.viewOptions,
    required this.bazarNote,
    required this.holdToRead,
    required this.holdToAdd,
    required this.noExpenses,
    required this.recentSpending,
    required this.spendingChart,
    required this.fillTheBag,
    required this.total,
    required this.showTotal,
    required this.groupExpenses,
    required this.viewByDate,
    required this.viewByMonth,
    required this.settings,
    required this.closeMenu,
    required this.bazarDiary,
    required this.itemPlaceholder,
    required this.addMore,
    required this.bazarThoughts,
    required this.thoughtsPlaceholder,
    required this.totalForToday,
    required this.done,
    required this.remove,
    required this.dismiss,
    required this.untitled,
    required this.closeCalendar,
    required this.chooseDate,
    required this.previousMonth,
    required this.nextMonth,
    required this.weekdaysShort,
    required this.today,
    required this.closeThoughts,
    required this.noThoughts,
    required this.editThoughts,
    required this.addThoughts,
    required this.share,
    required this.deleteThoughts,
    required this.backToDailyBag,
    required this.shoppingList,
    required this.newItem,
    required this.addItemPlaceholder,
    required this.addItem,
    required this.nothingToBuy,
    required this.bazarNoteHelp,
    required this.moveToDailyBag,
    required this.addedToDailyBag,
    required this.viewDailyBag,
    required this.keepListing,
    required bool isBangla,
  }) : _isBn = isBangla;

  final bool _isBn;

  final String dailyBag;
  final String viewOptions;
  final String bazarNote;
  final String holdToRead;
  final String holdToAdd;
  final String noExpenses;
  final String recentSpending;
  final String spendingChart;
  final String fillTheBag;
  final String total;
  final String showTotal;
  final String groupExpenses;
  final String viewByDate;
  final String viewByMonth;
  final String settings;
  final String closeMenu;
  final String bazarDiary;
  final String itemPlaceholder;
  final String addMore;
  final String bazarThoughts;
  final String thoughtsPlaceholder;
  final String totalForToday;
  final String done;
  final String remove;
  final String dismiss;
  final String untitled;
  final String closeCalendar;
  final String chooseDate;
  final String previousMonth;
  final String nextMonth;

  /// Sunday first, as the calendar lays them out.
  final List<String> weekdaysShort;
  final String today;
  final String closeThoughts;
  final String noThoughts;
  final String editThoughts;
  final String addThoughts;
  final String share;
  final String deleteThoughts;
  final String backToDailyBag;
  final String shoppingList;
  final String newItem;
  final String addItemPlaceholder;
  final String addItem;
  final String nothingToBuy;
  final String bazarNoteHelp;
  final String moveToDailyBag;
  final String addedToDailyBag;
  final String viewDailyBag;
  final String keepListing;

  /// `3 items`, `৩টি আইটেম`.
  String items(int n) =>
      _isBn ? '${digits(n)}টি আইটেম' : '$n ${n == 1 ? 'item' : 'items'}';

  /// `2 days`, `২ দিন`.
  String days(int n) =>
      _isBn ? '${digits(n)} দিন' : '$n ${n == 1 ? 'day' : 'days'}';

  String bazarNoteLeft(int n) => _isBn
      ? 'বাজার নোট, আরও ${digits(n)}টি জিনিস কেনা বাকি'
      : 'Bazar Note, ${items(n)} left to buy';

  String hideTotal(String amount) =>
      _isBn ? 'মোট লুকান: $amount' : 'Hide total: $amount';

  /// [day] is a short date such as `20 February`.
  String showThoughtsFor(String day) => _isBn
      ? '${_genitive(day)} বাজারের ভাবনা দেখুন'
      : 'Show Bazar thoughts for $day';

  String thoughtsFor(String day) =>
      _isBn ? 'বাজারের ভাবনা, $day' : 'Bazar thoughts, $day';

  String item(int n) => _isBn ? 'আইটেম ${digits(n)}' : 'Item $n';

  String amountFor(int n) =>
      _isBn ? 'আইটেম ${digits(n)}-এর দাম' : 'Amount for item $n';

  String totalFor(String day) =>
      _isBn ? '${_genitive(day)} মোট' : 'Total for $day';

  String dateBadge(String day) =>
      _isBn ? 'তারিখ: $day। ক্যালেন্ডার খুলুন' : 'Date: $day. Open calendar';

  String progress(int bought, int all) => _isBn
      ? '${digits(bought)} / ${digits(all)} কেনা হয়েছে'
      : '$bought of $all bought';

  String boughtCount(int n) =>
      _isBn ? '${digits(n)}টি আইটেম কেনা হয়েছে' : '${items(n)} bought';

  String markBought(String name) =>
      _isBn ? 'কেনা হয়েছে: $name' : 'Mark bought: $name';

  String markNotBought(String name) =>
      _isBn ? 'কেনা হয়নি: $name' : 'Mark not bought: $name';

  String priceFor(String name) => _isBn ? 'দাম: $name' : 'Price for $name';

  String movedLine(int n, String money) => _isBn
      ? '${digits(n)}টি আইটেম · $money আজকের খরচে যোগ হয়েছে। বাকি আইটেম বাজার নোটে থাকবে।'
      : '${items(n)} · $money added to today’s expenses. '
            'Unticked items stay in your Bazar Note.';

  /// `২০ ফেব্রুয়ারি` → `২০ ফেব্রুয়ারির`, `২ মার্চ` → `২ মার্চের`.
  static String _genitive(String word) =>
      RegExp('[িেইা]\$').hasMatch(word) ? '$wordর' : '$wordের';

  static const _en = Strings._(
    isBangla: false,
    dailyBag: 'Daily Bag',
    viewOptions: 'View options',
    bazarNote: 'Bazar Note',
    holdToRead: 'Hold to read thoughts',
    holdToAdd: 'Hold to add thoughts',
    noExpenses: 'No expenses yet',
    recentSpending: 'Recent spending',
    spendingChart: 'Spending chart',
    fillTheBag: 'Fill the bag',
    total: 'Total',
    showTotal: 'Show total expenses',
    groupExpenses: 'Group expenses',
    viewByDate: 'View by date',
    viewByMonth: 'View by month',
    settings: 'Settings',
    closeMenu: 'Close menu',
    bazarDiary: 'Bazar Diary',
    itemPlaceholder: 'Item',
    addMore: 'Add more',
    bazarThoughts: 'Bazar thoughts',
    thoughtsPlaceholder: 'How did shopping go today?',
    totalForToday: 'Total for today',
    done: 'Done',
    remove: 'Remove',
    dismiss: 'Dismiss',
    untitled: 'Untitled',
    closeCalendar: 'Close calendar',
    chooseDate: 'Choose date',
    previousMonth: 'Previous month',
    nextMonth: 'Next month',
    weekdaysShort: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
    today: 'Today',
    closeThoughts: 'Close thoughts',
    noThoughts: 'No thoughts for this day yet.',
    editThoughts: 'Edit thoughts',
    addThoughts: 'Add thoughts',
    share: 'Share',
    deleteThoughts: 'Delete thoughts',
    backToDailyBag: 'Back to Daily Bag',
    shoppingList: 'Shopping list',
    newItem: 'New item',
    addItemPlaceholder: 'Add an item to buy…',
    addItem: 'Add item',
    nothingToBuy: 'Nothing to buy yet',
    bazarNoteHelp:
        'Tick items as you buy them and add the price. '
        'Unticked items stay here for next time.',
    moveToDailyBag: 'Move to Daily Bag',
    addedToDailyBag: 'Added to Daily Bag',
    viewDailyBag: 'View Daily Bag',
    keepListing: 'Keep listing',
  );

  static const _bn = Strings._(
    isBangla: true,
    dailyBag: 'ডেইলি ব্যাগ',
    viewOptions: 'দেখার অপশন',
    bazarNote: 'বাজার নোট',
    holdToRead: 'ভাবনা দেখতে চেপে ধরুন',
    holdToAdd: 'ভাবনা লিখতে চেপে ধরুন',
    noExpenses: 'এখনো কোনো খরচ নেই',
    recentSpending: 'সাম্প্রতিক খরচ',
    spendingChart: 'খরচের চার্ট',
    fillTheBag: 'ব্যাগ ভরুন',
    total: 'মোট',
    showTotal: 'মোট খরচ দেখুন',
    groupExpenses: 'খরচ সাজান',
    viewByDate: 'তারিখ অনুযায়ী',
    viewByMonth: 'মাস অনুযায়ী',
    settings: 'সেটিংস',
    closeMenu: 'মেনু বন্ধ করুন',
    bazarDiary: 'বাজার ডায়েরি',
    itemPlaceholder: 'আইটেম',
    addMore: 'আরও যোগ করুন',
    bazarThoughts: 'বাজারের ভাবনা',
    thoughtsPlaceholder: 'আজকের বাজার কেমন হলো?',
    totalForToday: 'আজকের মোট',
    done: 'সম্পন্ন',
    remove: 'মুছুন',
    dismiss: 'বন্ধ করুন',
    untitled: 'নাম নেই',
    closeCalendar: 'ক্যালেন্ডার বন্ধ করুন',
    chooseDate: 'তারিখ বাছুন',
    previousMonth: 'আগের মাস',
    nextMonth: 'পরের মাস',
    weekdaysShort: ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি'],
    today: 'আজ',
    closeThoughts: 'ভাবনা বন্ধ করুন',
    noThoughts: 'এই দিনের জন্য এখনো কোনো ভাবনা নেই।',
    editThoughts: 'ভাবনা এডিট করুন',
    addThoughts: 'ভাবনা লিখুন',
    share: 'শেয়ার করুন',
    deleteThoughts: 'ভাবনা মুছুন',
    backToDailyBag: 'ডেইলি ব্যাগে ফিরে যান',
    shoppingList: 'কেনাকাটার তালিকা',
    newItem: 'নতুন আইটেম',
    addItemPlaceholder: 'কেনার জিনিস লিখুন…',
    addItem: 'আইটেম যোগ করুন',
    nothingToBuy: 'কেনার কিছু নেই',
    bazarNoteHelp:
        'কেনার সাথে সাথে টিক দিন ও দাম লিখুন। '
        'টিক না দেওয়া আইটেম পরের বারের জন্য থাকবে।',
    moveToDailyBag: 'ডেইলি ব্যাগে যোগ করুন',
    addedToDailyBag: 'ডেইলি ব্যাগে যোগ হয়েছে',
    viewDailyBag: 'ডেইলি ব্যাগ দেখুন',
    keepListing: 'তালিকা চালিয়ে যান',
  );
}
