import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenses_traker/models/transaction_model.dart';
import 'package:expenses_traker/repositories/transaction_repository.dart';
import 'package:expenses_traker/screens/transaction_form_screen.dart';
import 'package:expenses_traker/utils/amount_parser.dart';
import 'package:expenses_traker/utils/formatters.dart';

void main() {
  group('parseAmountPaise', () {
    test('converts valid amounts to integer paise', () {
      expect(parseAmountPaise('10'), 1000);
      expect(parseAmountPaise('10.5'), 1050);
      expect(parseAmountPaise('10.50'), 1050);
      expect(parseAmountPaise('0.01'), 1);
    });

    test('rejects amounts with more than two decimal places', () {
      expect(parseAmountPaise('10.001'), isNull);
      expect(parseAmountPaise('10.000'), isNull);
    });

    test('rejects zero and negative amounts', () {
      expect(parseAmountPaise('0'), isNull);
      expect(parseAmountPaise('0.00'), isNull);
      expect(parseAmountPaise('-1'), isNull);
      expect(parseAmountPaise('-0.01'), isNull);
    });

    test('rejects malformed amounts', () {
      for (final value in [
        '',
        '.5',
        '10.',
        '1..2',
        '10.2.3',
        'abc',
        '1e2',
        '+1',
      ]) {
        expect(parseAmountPaise(value), isNull, reason: value);
      }
    });

    test('accepts the largest signed integer paise amount only', () {
      expect(parseAmountPaise('92233720368547758.07'), 0x7fffffffffffffff);
      expect(parseAmountPaise('92233720368547758.08'), isNull);
      expect(parseAmountPaise('92233720368547759'), isNull);
    });
  });

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

  testWidgets('invalid amount shows the form error and is not saved', (
    tester,
  ) async {
    final repository = _RecordingTransactionRepository();
    await tester.pumpWidget(
      MaterialApp(home: TransactionFormScreen(repository: repository)),
    );

    await tester.enterText(find.byType(TextFormField).first, '10.001');
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter an amount greater than ₹0 (up to 2 decimals).'),
      findsOneWidget,
    );
    expect(repository.insertCalls, 0);
  });
}

class _RecordingTransactionRepository extends TransactionRepository {
  int insertCalls = 0;

  @override
  Future<int> insert(TransactionModel transaction) async {
    insertCalls++;
    return 1;
  }
}
