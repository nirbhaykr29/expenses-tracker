import 'package:intl/intl.dart';

final minimumTransactionDate = DateTime(1900, 1, 1);
final maximumTransactionDate = DateTime(2100, 12, 31);

final _rupeeFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String formatRupees(int amountPaise, {bool includePaise = true}) {
  final isNegative = amountPaise < 0;
  final absolutePaise = amountPaise.abs();
  final rupees = absolutePaise ~/ 100;
  final paise = absolutePaise % 100;
  final sign = isNegative ? '-' : '';
  final formatted = '$sign${_rupeeFormatter.format(rupees)}';
  if (!includePaise || paise == 0) return formatted;
  return '$formatted.${paise.toString().padLeft(2, '0')}';
}

DateTime dateFromIso(String date) {
  if (date.length != 10 ||
      !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(date)) {
    throw FormatException('Expected a valid YYYY-MM-DD date.', date);
  }

  final year = int.parse(date.substring(0, 4));
  final month = int.parse(date.substring(5, 7));
  final day = int.parse(date.substring(8, 10));
  if (year < minimumTransactionDate.year ||
      year > maximumTransactionDate.year) {
    throw FormatException('Date is outside the supported range.', date);
  }

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Date is not a valid calendar day.', date);
  }
  if (parsed.isBefore(minimumTransactionDate) ||
      parsed.isAfter(maximumTransactionDate)) {
    throw FormatException('Date is outside the supported range.', date);
  }
  return parsed;
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String formatDate(String date, {String pattern = 'd MMM yyyy'}) =>
    DateFormat(pattern).format(dateFromIso(date));
