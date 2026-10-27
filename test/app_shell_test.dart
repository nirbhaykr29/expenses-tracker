import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expenses_traker/models/transaction_model.dart';
import 'package:expenses_traker/repositories/transaction_repository.dart';
import 'package:expenses_traker/screens/app_shell.dart';

void main() {
  testWidgets('dashboard shows totals and recent transactions', (tester) async {
    final repository = _FakeTransactionRepository([
      _sampleTransaction(),
      _sampleTransaction(
        id: 2,
        type: TransactionType.credit,
        amountPaise: 10000,
        category: 'Salary',
        date: '2026-10-26',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('₹49.50'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);
    expect(find.text('₹50.50'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Food'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Food'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Salary'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('history type filter only shows matching transactions', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([
      _sampleTransaction(),
      _sampleTransaction(
        id: 2,
        type: TransactionType.credit,
        amountPaise: 10000,
        category: 'Salary',
        date: '2026-10-26',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  testWidgets('canceling the delete confirmation preserves the transaction', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([_sampleTransaction()]);
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: repository)),
    );
    await tester.pumpAndSettle();

    await _openDeleteConfirmation(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets(
    'confirmed deletion removes the transaction and refreshes history',
    (tester) async {
      final repository = _FakeTransactionRepository([_sampleTransaction()]);
      await tester.pumpWidget(
        MaterialApp(home: AppShell(repository: repository)),
      );
      await tester.pumpAndSettle();

      await _openDeleteConfirmation(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleteCalls, 1);
      expect(find.text('Food'), findsNothing);
      expect(find.text('No transactions found'), findsOneWidget);
    },
  );

  testWidgets('a stale delete reports that no transaction was removed', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository([
      _sampleTransaction(),
    ], deleteResult: 0);
    await tester.pumpWidget(
      MaterialApp(home: AppShell(repository: repository)),
    );
    await tester.pumpAndSettle();

    await _openDeleteConfirmation(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('This transaction was already removed.'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });
}

Future<void> _openDeleteConfirmation(WidgetTester tester) async {
  await tester.tap(find.text('History'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Transaction options'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  expect(find.text('Delete transaction?'), findsOneWidget);
}

TransactionModel _sampleTransaction({
  int id = 1,
  TransactionType type = TransactionType.debit,
  int amountPaise = 5050,
  String category = 'Food',
  String date = '2026-10-25',
}) => TransactionModel(
  id: id,
  type: type,
  amountPaise: amountPaise,
  category: category,
  date: date,
  createdAt: '${date}T12:00:00.000',
);

class _FakeTransactionRepository extends TransactionRepository {
  _FakeTransactionRepository(this.transactions, {this.deleteResult = 1});

  final List<TransactionModel> transactions;
  final int deleteResult;
  int deleteCalls = 0;

  @override
  Future<TransactionSummary> getSummary() async {
    var credit = 0;
    var debit = 0;
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.credit) {
        credit += transaction.amountPaise;
      } else {
        debit += transaction.amountPaise;
      }
    }
    return TransactionSummary(
      totalCreditPaise: credit,
      totalDebitPaise: debit,
      transactionCount: transactions.length,
    );
  }

  @override
  Future<List<TransactionModel>> getAll({
    TransactionType? type,
    String? date,
    int? limit,
  }) async {
    final filtered = transactions.where((transaction) {
      return (type == null || transaction.type == type) &&
          (date == null || transaction.date == date);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return limit == null ? filtered : filtered.take(limit).toList();
  }

  @override
  Future<int> delete(int id) async {
    deleteCalls++;
    if (deleteResult == 0) return 0;
    final initialLength = transactions.length;
    transactions.removeWhere((transaction) => transaction.id == id);
    return initialLength - transactions.length;
  }
}
