int? parseAmountPaise(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(normalized)) {
    return null;
  }

  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  final fraction = parts.length == 1
      ? 0
      : int.tryParse(parts[1].padRight(2, '0'));
  if (whole == null || fraction == null) return null;

  const maxPaise = 0x7fffffffffffffff;
  if (whole > (maxPaise - fraction) ~/ 100) return null;

  final amount = whole * 100 + fraction;
  return amount > 0 ? amount : null;
}
