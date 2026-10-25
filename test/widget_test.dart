import 'package:flutter_test/flutter_test.dart';
import 'package:expenses_traker/models/transaction_model.dart';
import 'package:expenses_traker/utils/formatters.dart';

void main() {
  test('transaction map stores the integer paise value', () {
    final transaction = TransactionModel(
      id: 3,
      type: TransactionType.debit,
      amountPaise: 25050,
      category: 'Food',
      date: '2026-10-25',
      createdAt: '2026-10-25T12:00:00.000',
    );

    final restored = TransactionModel.fromMap(transaction.toMap());

    expect(restored.amountPaise, 25050);
    expect(restored.type, TransactionType.debit);
    expect(restored.date, '2026-10-25');
  });

  test('currency formatting uses Indian grouping and retains paise', () {
    expect(formatRupees(25050), '₹250.50');
    expect(formatRupees(12345600), '₹1,23,456');
    expect(formatRupees(-505), '-₹5.05');
  });
}
