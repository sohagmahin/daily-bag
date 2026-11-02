import 'strings.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _banglaMonths = [
  'জানুয়ারি',
  'ফেব্রুয়ারি',
  'মার্চ',
  'এপ্রিল',
  'মে',
  'জুন',
  'জুলাই',
  'আগস্ট',
  'সেপ্টেম্বর',
  'অক্টোবর',
  'নভেম্বর',
  'ডিসেম্বর',
];

const _banglaWeekdays = [
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
  'রবিবার',
];

final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');
final _lakhs = RegExp(r'\B(?=(\d{2})*\d{3}(?!\d))');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// How money is written in one currency.
class MoneyFormat {
  const MoneyFormat(this.symbol, {this.cents = false});

  final String symbol;

  /// Thousands grouping with two decimals always (`\$1,220.00`); otherwise
  /// lakh grouping with decimals only when there are any (`৳1,22,000`).
  final bool cents;

  /// `1540` → `৳1,540`, `12.5` → `৳12.50`.
  String call(double value) => '$symbol${amount(value)}';

  String amount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAll(cents ? _thousands : _lakhs, ',');
    return digits(cents || parts[1] != '00' ? '$whole.${parts[1]}' : whole);
  }
}

/// The money format in use; set from the "Currency" setting.
MoneyFormat money = const MoneyFormat('৳');

String get currencySymbol => money.symbol;

/// `1540` → `৳1,540`, in the chosen currency.
String formatMoney(double value) => money(value);

String formatAmount(double value) => money.amount(value);

/// The plain form shown inside an editable amount field.
String editableAmount(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String monthName(DateTime d) => (bangla ? _banglaMonths : _months)[d.month - 1];

/// `Feb`; Bangla has no short month names, so it keeps the whole word.
String shortMonthName(DateTime d) =>
    bangla ? monthName(d) : monthName(d).substring(0, 3);
String weekdayName(DateTime d) =>
    (bangla ? _banglaWeekdays : _weekdays)[d.weekday - 1];

/// Always ASCII: also builds the database's day keys.
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// `12 Feb 2026`, `১২ ফেব্রুয়ারি ২০২৬`.
String dayTitle(DateTime d) =>
    '${digits(d.day)} ${shortMonthName(d)} ${digits(d.year)}';

/// `12 Feb`
String shortDay(DateTime d) => '${digits(d.day)} ${shortMonthName(d)}';

/// `20 February`: used in spoken labels.
String dayAndMonth(DateTime d) => '${digits(d.day)} ${monthName(d)}';

/// `February 2026`
String monthTitle(DateTime d) => '${monthName(d)} ${digits(d.year)}';

/// `Monday, 2 March`
String longDay(DateTime d) =>
    '${weekdayName(d)}, ${digits(d.day)} ${monthName(d)}';
