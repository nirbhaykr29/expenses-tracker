import 'package:intl/intl.dart';

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
  final parts = date.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String formatDate(String date, {String pattern = 'd MMM yyyy'}) =>
    DateFormat(pattern).format(dateFromIso(date));
