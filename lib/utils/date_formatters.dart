const List<String> frMonthNames = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatFrenchMonthYear(DateTime date) {
  return '${frMonthNames[date.month - 1]} ${date.year}';
}

String formatDayMonth(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String formatFrenchLongDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} ${frMonthNames[date.month - 1]} ${date.year}';
}

String formatDayHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Aujourd\'hui';
  if (d == today.subtract(const Duration(days: 1))) return 'Hier';
  return formatFrenchLongDate(date);
}
