import 'dart:async';

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

  test('transaction map rejects unsupported persisted types', () {
    final map = TransactionModel(
      id: 3,
      type: TransactionType.debit,
      amountPaise: 25050,
      category: 'Food',
      date: '2026-10-25',
      createdAt: '2026-10-25T12:00:00.000',
    ).toMap()..['type'] = 'transfer';

    expect(() => TransactionModel.fromMap(map), throwsFormatException);
  });

  test('currency formatting uses Indian grouping and retains paise', () {
    expect(formatRupees(25050), '₹250.50');
    expect(formatRupees(12345600), '₹1,23,456');
    expect(formatRupees(-505), '-₹5.05');
  });

  test('balance subtraction stays within the signed paise range', () {
    const maxPaise = 0x7fffffffffffffff;
    expect(
      const TransactionSummary(
        totalCreditPaise: maxPaise,
        totalDebitPaise: 0,
        transactionCount: 1,
      ).balancePaise,
      maxPaise,
    );
    expect(
      const TransactionSummary(
        totalCreditPaise: 0,
        totalDebitPaise: maxPaise,
        transactionCount: 1,
      ).balancePaise,
      -maxPaise,
    );
  });

  test('strict date parsing accepts leap days and rejects invalid dates', () {
    expect(dateFromIso('1900-01-01'), DateTime(1900, 1, 1));
    expect(dateFromIso('2024-02-29'), DateTime(2024, 2, 29));
    expect(dateFromIso('2100-12-31'), maximumTransactionDate);
    expect(() => dateFromIso('2025-02-29'), throwsFormatException);
    expect(() => dateFromIso('2026-02-31'), throwsFormatException);
    expect(() => dateFromIso('2026-13-01'), throwsFormatException);
    expect(() => dateFromIso('2026-04-31'), throwsFormatException);
    expect(() => dateFromIso('1899-12-31'), throwsFormatException);
    expect(() => dateFromIso('2101-01-01'), throwsFormatException);
    expect(() => dateFromIso('2026-2-01'), throwsFormatException);
    expect(() => dateFromIso('not-a-date'), throwsFormatException);
  });

  test('ISO dates preserve calendar days without timezone conversion', () {
    expect(isoDate(DateTime(2026, 1, 2)), '2026-01-02');
    expect(formatDate('2026-01-02'), '2 Jan 2026');
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

  testWidgets('rapid save taps trigger only one insert', (tester) async {
    final repository = _RecordingTransactionRepository()
      ..insertCompleter = Completer<int>();
    await tester.pumpWidget(
      MaterialApp(home: TransactionFormScreen(repository: repository)),
    );

    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.ensureVisible(find.text('Save transaction'));
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save transaction'),
    );
    saveButton.onPressed!();
    saveButton.onPressed!();
    await tester.pump();

    expect(repository.insertCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('valid add and edit saves integer paise values', (tester) async {
    final repository = _RecordingTransactionRepository();
    await tester.pumpWidget(_formRouteHarness(repository));

    await _openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '10.5');
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(repository.insertCalls, 1);
    expect(repository.lastInserted?.amountPaise, 1050);

    final original = TransactionModel(
      id: 42,
      type: TransactionType.credit,
      amountPaise: 1000,
      category: 'Salary',
      date: '2026-10-25',
      createdAt: '2026-10-25T12:00:00.000',
    );
    await tester.pumpWidget(
      _formRouteHarness(repository, transaction: original),
    );
    await _openForm(tester);
    await tester.enterText(find.byType(TextFormField).first, '12.34');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.lastUpdated?.id, 42);
    expect(repository.lastUpdated?.amountPaise, 1234);
  });

  testWidgets('an update affecting no rows reports a save failure', (
    tester,
  ) async {
    final repository = _RecordingTransactionRepository()..updateResult = 0;
    final transaction = TransactionModel(
      id: 9,
      type: TransactionType.debit,
      amountPaise: 1000,
      category: 'Food',
      date: '2026-10-25',
      createdAt: '2026-10-25T12:00:00.000',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionFormScreen(
          repository: repository,
          transaction: transaction,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(
      find.text(
        'Could not save transaction: Bad state: This transaction no longer exists.',
      ),
      findsOneWidget,
    );
    expect(find.text('Edit transaction'), findsOneWidget);
  });
}

class _RecordingTransactionRepository extends TransactionRepository {
  int insertCalls = 0;
  int updateCalls = 0;
  int updateResult = 1;
  Completer<int>? insertCompleter;
  TransactionModel? lastInserted;
  TransactionModel? lastUpdated;

  @override
  Future<int> insert(TransactionModel transaction) {
    insertCalls++;
    lastInserted = transaction;
    return insertCompleter?.future ?? Future.value(1);
  }

  @override
  Future<int> update(TransactionModel transaction) async {
    updateCalls++;
    lastUpdated = transaction;
    return updateResult;
  }
}

Widget _formRouteHarness(
  TransactionRepository repository, {
  TransactionModel? transaction,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(
              repository: repository,
              transaction: transaction,
            ),
          ),
        ),
        child: const Text('Open form'),
      ),
    ),
  ),
);

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}
