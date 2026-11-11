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
    required this.spendingMap,
    required this.dailySpending,
    required this.less,
    required this.more,
    required this.noSpending,
    required this.lastThreeWeeks,
    required this.showFullMap,
    required this.showingOneDay,
    required this.showAllDays,
    required this.nothingThisDay,
    required this.weekdaysAbbr,
    required this.monthsAbbr,
    required this.levelNames,
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
    required this.scanToFill,
    required this.scanWithCamera,
    required this.closeScanner,
    required this.flash,
    required this.whatAreYouScanning,
    required this.receipt,
    required this.writtenList,
    required this.fitReceipt,
    required this.fitList,
    required this.readingItems,
    required this.noItemsFound,
    required this.noCamera,
    required this.choosePhoto,
    required this.scan,
    required this.typeInstead,
    required this.checkPrice,
    required this.fromWrittenList,
    required this.retake,
    required bool isBangla,
  }) : _isBn = isBangla;

  final bool _isBn;

  final String dailyBag;
  final String viewOptions;
  final String bazarNote;
  final String holdToRead;
  final String holdToAdd;
  final String noExpenses;
  final String spendingMap;
  final String dailySpending;
  final String less;
  final String more;
  final String noSpending;
  final String lastThreeWeeks;
  final String showFullMap;
  final String showingOneDay;
  final String showAllDays;
  final String nothingThisDay;

  /// Sunday first, for the spending map: `Fri, 20 Feb`.
  final List<String> weekdaysAbbr;
  final List<String> monthsAbbr;

  /// How heavy a day was, by its shade on the spending map.
  final List<String> levelNames;
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
  final String scanToFill;
  final String scanWithCamera;
  final String closeScanner;
  final String flash;
  final String whatAreYouScanning;
  final String receipt;
  final String writtenList;
  final String fitReceipt;
  final String fitList;
  final String readingItems;
  final String noItemsFound;
  final String noCamera;
  final String choosePhoto;
  final String scan;
  final String typeInstead;
  final String checkPrice;
  final String fromWrittenList;
  final String retake;

  /// `3 items`, `৩টি আইটেম`.
  String items(int n) =>
      _isBn ? '${digits(n)}টি আইটেম' : '$n ${n == 1 ? 'item' : 'items'}';

  /// `2 days`, `২ দিন`.
  String days(int n) =>
      _isBn ? '${digits(n)} দিন' : '$n ${n == 1 ? 'day' : 'days'}';

  String bazarNoteLeft(int n) => _isBn
      ? 'বাজার নোট, আরও ${digits(n)}টি জিনিস কেনা বাকি'
      : 'Bazar Note, ${items(n)} left to buy';

  /// The spending map's footnote: `Last 16 weeks · ৳5,470`.
  String lastWeeks(String money) =>
      _isBn ? '${digits(16)} সপ্তাহ · $money' : 'Last 16 weeks · $money';

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

  String foundItems(int n) => _isBn
      ? '${digits(n)}টি আইটেম পাওয়া গেছে'
      : 'Found $n ${n == 1 ? 'item' : 'items'}';

  String fromReceipt(String? store) => _isBn
      ? (store == null ? 'রশিদ থেকে' : 'রশিদ থেকে · $store')
      : (store == null ? 'From receipt' : 'From receipt · $store');

  String leaveOut(String name) => _isBn ? 'বাদ দিন: $name' : 'Leave out: $name';

  String include(String name) => _isBn ? 'যোগ করুন: $name' : 'Include: $name';

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
    spendingMap: 'Spending map',
    dailySpending: 'Daily spending, last 16 weeks',
    less: 'Less',
    more: 'More',
    noSpending: 'No spending',
    lastThreeWeeks: 'Last 3 weeks',
    showFullMap: 'Show the full spending map',
    showingOneDay: 'Showing one day',
    showAllDays: 'Show all days',
    nothingThisDay: 'Nothing in the bag this day',
    weekdaysAbbr: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    monthsAbbr: [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    levelNames: ['Empty', 'Light', 'Moderate', 'Busy', 'Heavy'],
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
    scanToFill: 'Scan to fill',
    scanWithCamera: 'Scan a receipt or list with the camera',
    closeScanner: 'Close scanner',
    flash: 'Flash',
    whatAreYouScanning: 'What are you scanning?',
    receipt: 'Receipt',
    writtenList: 'Written list',
    fitReceipt: 'Fit the receipt inside the frame',
    fitList: 'Fit your written list inside the frame',
    readingItems: 'Reading items…',
    noItemsFound: 'No items found. Try closer, in good light.',
    noCamera: 'Camera unavailable. Choose a photo instead.',
    choosePhoto: 'Choose a photo',
    scan: 'Scan',
    typeInstead: 'Type it instead',
    checkPrice: 'Check the price',
    fromWrittenList: 'From your written list',
    retake: 'Retake',
  );

  static const _bn = Strings._(
    isBangla: true,
    dailyBag: 'ডেইলি ব্যাগ',
    viewOptions: 'দেখার অপশন',
    bazarNote: 'বাজার নোট',
    holdToRead: 'ভাবনা দেখতে চেপে ধরুন',
    holdToAdd: 'ভাবনা লিখতে চেপে ধরুন',
    noExpenses: 'এখনো কোনো খরচ নেই',
    spendingMap: 'খরচের ম্যাপ',
    dailySpending: 'গত ১৬ সপ্তাহের দৈনিক খরচ',
    less: 'কম',
    more: 'বেশি',
    noSpending: 'কোনো খরচ নেই',
    lastThreeWeeks: 'গত ৩ সপ্তাহ',
    showFullMap: 'পুরো খরচের ম্যাপ দেখুন',
    showingOneDay: 'একটি দিনের খরচ',
    showAllDays: 'সব দিন দেখুন',
    nothingThisDay: 'এই দিনে ব্যাগ খালি ছিল',
    weekdaysAbbr: ['রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি'],
    monthsAbbr: [
      'জানু',
      'ফেব্রু',
      'মার্চ',
      'এপ্রি',
      'মে',
      'জুন',
      'জুলা',
      'আগ',
      'সেপ্টে',
      'অক্টো',
      'নভে',
      'ডিসে',
    ],
    levelNames: ['খরচ নেই', 'হালকা', 'মাঝারি', 'ব্যস্ত', 'ভারী'],
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
    scanToFill: 'স্ক্যান করে ভরুন',
    scanWithCamera: 'ক্যামেরায় রশিদ বা তালিকা স্ক্যান করুন',
    closeScanner: 'স্ক্যানার বন্ধ করুন',
    flash: 'ফ্ল্যাশ',
    whatAreYouScanning: 'কী স্ক্যান করছেন?',
    receipt: 'রশিদ',
    writtenList: 'লেখা তালিকা',
    fitReceipt: 'রশিদটি ফ্রেমের ভেতরে রাখুন',
    fitList: 'লেখা তালিকাটি ফ্রেমের ভেতরে রাখুন',
    readingItems: 'আইটেম পড়া হচ্ছে…',
    noItemsFound: 'কোনো আইটেম পাওয়া যায়নি। আরও কাছে, ভালো আলোতে চেষ্টা করুন।',
    noCamera: 'ক্যামেরা চালু হয়নি। একটি ছবি বাছুন।',
    choosePhoto: 'ছবি বাছুন',
    scan: 'স্ক্যান',
    typeInstead: 'হাতে লিখুন',
    checkPrice: 'দাম দেখে নিন',
    fromWrittenList: 'আপনার লেখা তালিকা থেকে',
    retake: 'আবার তুলুন',
  );
}
