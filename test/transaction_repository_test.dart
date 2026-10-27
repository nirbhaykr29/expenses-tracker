import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:expenses_traker/database/database_helper.dart';
import 'package:expenses_traker/models/transaction_model.dart';
import 'package:expenses_traker/repositories/transaction_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late TransactionRepository repository;
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    databaseHelper = DatabaseHelper.forTesting(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = TransactionRepository(databaseHelper: databaseHelper);
    database = await databaseHelper.database;
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'CRUD, date and type filtering, and summaries stay consistent',
    () async {
      final creditId = await repository.insert(
        _transaction(
          type: TransactionType.credit,
          amountPaise: 25050,
          date: '2024-02-29',
        ),
      );
      final debitId = await repository.insert(
        _transaction(
          type: TransactionType.debit,
          amountPaise: 1050,
          date: '2026-10-25',
        ),
      );

      var transactions = await repository.getAll();
      expect(transactions.map((transaction) => transaction.id), [
        debitId,
        creditId,
      ]);
      expect(
        (await repository.getAll(
          type: TransactionType.credit,
          date: '2024-02-29',
        )).single.id,
        creditId,
      );

      var summary = await repository.getSummary();
      expect(summary.totalCreditPaise, 25050);
      expect(summary.totalDebitPaise, 1050);
      expect(summary.balancePaise, 24000);
      expect(summary.transactionCount, 2);

      expect(
        await repository.update(
          _transaction(
            id: creditId,
            type: TransactionType.credit,
            amountPaise: 30000,
            date: '2026-10-26',
          ),
        ),
        1,
      );
      summary = await repository.getSummary();
      expect(summary.totalCreditPaise, 30000);
      expect(summary.totalDebitPaise, 1050);
      expect(summary.balancePaise, 28950);
      expect(summary.transactionCount, 2);

      expect(await repository.delete(debitId), 1);
      expect(await repository.delete(debitId), 0);
      expect((await repository.getAll()).single.id, creditId);
      summary = await repository.getSummary();
      expect(summary.totalCreditPaise, 30000);
      expect(summary.totalDebitPaise, 0);
      expect(summary.transactionCount, 1);
    },
  );

  test('invalid dates are rejected by repository writes and filters', () async {
    await expectLater(
      repository.insert(
        _transaction(
          type: TransactionType.debit,
          amountPaise: 100,
          date: '2026-02-31',
        ),
      ),
      throwsFormatException,
    );
    await expectLater(
      repository.getAll(date: '2026-13-01'),
      throwsFormatException,
    );
    expect(await repository.getAll(), isEmpty);
  });

  test(
    'repository rejects invalid amounts and missing required fields',
    () async {
      final valid = _transaction(
        type: TransactionType.debit,
        amountPaise: 100,
        date: '2026-10-25',
      );
      await expectLater(
        repository.insert(
          _transaction(
            type: TransactionType.debit,
            amountPaise: 0,
            date: '2026-10-25',
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.insert(
          TransactionModel(
            type: valid.type,
            amountPaise: valid.amountPaise,
            category: '  ',
            date: valid.date,
            createdAt: valid.createdAt,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.insert(
          TransactionModel(
            type: valid.type,
            amountPaise: valid.amountPaise,
            category: valid.category,
            date: valid.date,
            createdAt: '',
          ),
        ),
        throwsArgumentError,
      );
      expect(await repository.getAll(), isEmpty);
    },
  );

  test(
    'database constraints reject invalid types and non-positive amounts',
    () async {
      final row = _transaction(
        type: TransactionType.debit,
        amountPaise: 100,
        date: '2026-10-25',
      ).toMap()..remove('id');
      await expectLater(
        database.insert('transactions', {...row, 'type': 'transfer'}),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        database.insert('transactions', {...row, 'amount_paise': 0}),
        throwsA(isA<DatabaseException>()),
      );
      expect(await repository.getAll(), isEmpty);
    },
  );

  test('invalid persisted dates fail explicitly when read', () async {
    final row =
        _transaction(
            type: TransactionType.debit,
            amountPaise: 100,
            date: '2026-10-25',
          ).toMap()
          ..remove('id')
          ..['date'] = '2026-02-31';
    await database.insert('transactions', row);

    await expectLater(repository.getAll(), throwsFormatException);
  });

  test('updating a missing row affects zero rows', () async {
    expect(
      await repository.update(
        _transaction(
          id: 500,
          type: TransactionType.debit,
          amountPaise: 100,
          date: '2026-10-25',
        ),
      ),
      0,
    );
  });

  test('summary detects integer overflow across valid transactions', () async {
    const maxAmountPaise = 0x7fffffffffffffff;
    await repository.insert(
      _transaction(
        type: TransactionType.credit,
        amountPaise: maxAmountPaise,
        date: '2026-10-25',
      ),
    );
    await repository.insert(
      _transaction(
        type: TransactionType.credit,
        amountPaise: maxAmountPaise,
        date: '2026-10-26',
      ),
    );

    await expectLater(repository.getSummary(), throwsStateError);
  });

  test('summary detects expense total overflow', () async {
    const maxAmountPaise = 0x7fffffffffffffff;
    await repository.insert(
      _transaction(
        type: TransactionType.debit,
        amountPaise: maxAmountPaise,
        date: '2026-10-25',
      ),
    );
    await repository.insert(
      _transaction(
        type: TransactionType.debit,
        amountPaise: maxAmountPaise,
        date: '2026-10-26',
      ),
    );

    await expectLater(repository.getSummary(), throwsStateError);
  });

  test('concurrent first access shares one initialized database', () async {
    final helper = DatabaseHelper.forTesting(
      factory: createDatabaseFactoryFfi(),
      databasePath: inMemoryDatabasePath,
    );

    final databases = await Future.wait(
      List.generate(8, (_) => helper.database),
    );

    expect(
      databases.every((opened) => identical(opened, databases.first)),
      isTrue,
    );
    expect(await databases.first.query('transactions'), isEmpty);
    await databases.first.close();
  });

  test('transactions persist after closing and reopening SQLite', () async {
    final directory = await Directory.systemTemp.createTemp(
      'expenses-tracker-test-',
    );
    final databasePath = path.join(directory.path, 'monee_test.db');
    try {
      final firstHelper = DatabaseHelper.forTesting(
        factory: createDatabaseFactoryFfi(),
        databasePath: databasePath,
      );
      final firstDatabase = await firstHelper.database;
      try {
        await TransactionRepository(databaseHelper: firstHelper).insert(
          _transaction(
            type: TransactionType.credit,
            amountPaise: 1050,
            date: '2024-02-29',
          ),
        );
      } finally {
        await firstDatabase.close();
      }

      final reopenedHelper = DatabaseHelper.forTesting(
        factory: createDatabaseFactoryFfi(),
        databasePath: databasePath,
      );
      final reopenedDatabase = await reopenedHelper.database;
      try {
        final persisted = await TransactionRepository(
          databaseHelper: reopenedHelper,
        ).getAll();
        expect(persisted, hasLength(1));
        expect(persisted.single.amountPaise, 1050);
        expect(persisted.single.date, '2024-02-29');
      } finally {
        await reopenedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

TransactionModel _transaction({
  int? id,
  required TransactionType type,
  required int amountPaise,
  required String date,
}) => TransactionModel(
  id: id,
  type: type,
  amountPaise: amountPaise,
  category: 'Food',
  date: date,
  createdAt: '${date}T12:00:00.000',
);
