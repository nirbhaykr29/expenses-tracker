import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/transaction_model.dart';

class TransactionSummary {
  const TransactionSummary({
    required this.totalCreditPaise,
    required this.totalDebitPaise,
    required this.transactionCount,
  });

  final int totalCreditPaise;
  final int totalDebitPaise;
  final int transactionCount;

  int get balancePaise => totalCreditPaise - totalDebitPaise;
}

class TransactionRepository {
  TransactionRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> insert(TransactionModel transaction) async {
    _validate(transaction);
    final db = await _databaseHelper.database;
    return db.insert(
      'transactions',
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> update(TransactionModel transaction) async {
    _validate(transaction);
    final id = transaction.id;
    if (id == null) {
      throw ArgumentError.value(id, 'transaction.id', 'An id is required.');
    }
    final db = await _databaseHelper.database;
    return db.update(
      'transactions',
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _databaseHelper.database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionModel>> getAll({
    TransactionType? type,
    String? date,
    int? limit,
  }) async {
    final db = await _databaseHelper.database;
    final conditions = <String>[];
    final arguments = <Object>[];
    if (type != null) {
      conditions.add('type = ?');
      arguments.add(type.value);
    }
    if (date != null) {
      conditions.add('date = ?');
      arguments.add(date);
    }
    final rows = await db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'date DESC, created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromMap).toList(growable: false);
  }

  Future<TransactionSummary> getSummary() async {
    final db = await _databaseHelper.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = ? THEN amount_paise ELSE 0 END), 0)
          AS total_credit_paise,
        COALESCE(SUM(CASE WHEN type = ? THEN amount_paise ELSE 0 END), 0)
          AS total_debit_paise,
        COUNT(*) AS transaction_count
      FROM transactions
    ''',
      [TransactionType.credit.value, TransactionType.debit.value],
    );
    final row = rows.single;
    return TransactionSummary(
      totalCreditPaise: row['total_credit_paise'] as int,
      totalDebitPaise: row['total_debit_paise'] as int,
      transactionCount: row['transaction_count'] as int,
    );
  }

  void _validate(TransactionModel transaction) {
    if (transaction.amountPaise <= 0) {
      throw ArgumentError.value(
        transaction.amountPaise,
        'amountPaise',
        'Amount must be greater than zero.',
      );
    }
    if (transaction.category.trim().isEmpty || transaction.date.isEmpty) {
      throw ArgumentError('Category and date are required.');
    }
  }
}
