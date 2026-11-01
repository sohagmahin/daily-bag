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

final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// `1540` → `৳1,540`, `12.5` → `৳12.50`.
String formatTaka(double value) => '৳${formatAmount(value)}';

String formatAmount(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAll(_thousands, ',');
  return parts[1] == '00' ? whole : '$whole.${parts[1]}';
}

/// The plain form shown inside an editable amount field.
String editableAmount(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String monthName(DateTime d) => _months[d.month - 1];
String shortMonthName(DateTime d) => monthName(d).substring(0, 3);
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];
String twoDigits(int n) => n.toString().padLeft(2, '0');

/// `12 Feb 2026`
String dayTitle(DateTime d) => '${d.day} ${shortMonthName(d)} ${d.year}';

/// `12 Feb`
String shortDay(DateTime d) => '${d.day} ${shortMonthName(d)}';

/// `February 2026`
String monthTitle(DateTime d) => '${monthName(d)} ${d.year}';

/// `Monday, 2 March`
String longDay(DateTime d) => '${weekdayName(d)}, ${d.day} ${monthName(d)}';

String plural(int n, String word) => '$n ${n == 1 ? word : '${word}s'}';
