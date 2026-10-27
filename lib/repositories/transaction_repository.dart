import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/transaction_model.dart';
import '../utils/formatters.dart';

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
    if (date != null) dateFromIso(date);
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
    return rows
        .map((row) {
          final transaction = TransactionModel.fromMap(row);
          dateFromIso(transaction.date);
          if (transaction.amountPaise <= 0 ||
              transaction.category.trim().isEmpty ||
              transaction.createdAt.trim().isEmpty) {
            throw const FormatException('Stored transaction data is invalid.');
          }
          return transaction;
        })
        .toList(growable: false);
  }

  Future<TransactionSummary> getSummary() async {
    final db = await _databaseHelper.database;
    final rows = await db.query(
      'transactions',
      columns: ['type', 'amount_paise'],
    );
    var totalCreditPaise = 0;
    var totalDebitPaise = 0;
    const maxPaise = 0x7fffffffffffffff;
    for (final row in rows) {
      final amountPaise = row['amount_paise'];
      if (amountPaise is! int || amountPaise <= 0) {
        throw const FormatException('Stored transaction amount is invalid.');
      }
      switch (row['type']) {
        case 'credit':
          if (totalCreditPaise > maxPaise - amountPaise) {
            throw StateError('Total income exceeds the supported amount.');
          }
          totalCreditPaise += amountPaise;
        case 'debit':
          if (totalDebitPaise > maxPaise - amountPaise) {
            throw StateError('Total expenses exceed the supported amount.');
          }
          totalDebitPaise += amountPaise;
        default:
          throw const FormatException('Stored transaction type is invalid.');
      }
    }
    return TransactionSummary(
      totalCreditPaise: totalCreditPaise,
      totalDebitPaise: totalDebitPaise,
      transactionCount: rows.length,
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
    if (transaction.category.trim().isEmpty ||
        transaction.createdAt.trim().isEmpty) {
      throw ArgumentError('Category and creation time are required.');
    }
    dateFromIso(transaction.date);
  }
}
