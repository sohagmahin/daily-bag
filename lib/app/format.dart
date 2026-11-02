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

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// The money symbol in use; set from the "Currency" setting.
String currencySymbol = '৳';

/// `1540` → `৳1,540`, `12.5` → `৳12.50`, in the chosen currency.
String formatMoney(double value) => '$currencySymbol${formatAmount(value)}';

String formatAmount(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAll(_thousands, ',');
  return digits(parts[1] == '00' ? whole : '$whole.${parts[1]}');
}

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
