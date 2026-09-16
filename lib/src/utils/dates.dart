import 'package:intl/intl.dart';

String formatDate(DateTime date, String pattern) =>
    DateFormat(pattern).format(date);

String formatDateTime(DateTime date) =>
    DateFormat('dd MMM yyyy, HH:mm').format(date);

/// Parses a `yyyy-MM-dd` or ISO-8601 string into a local [DateTime].
DateTime? parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
