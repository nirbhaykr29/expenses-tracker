import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'monee_expenses.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database case final database?) return database;
    final databasePath = path.join(await getDatabasesPath(), _databaseName);
    final database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL CHECK (type IN ('credit', 'debit')),
            amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
            category TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_transactions_date ON transactions(date DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_transactions_type_date ON transactions(type, date DESC)',
        );
      },
    );
    _database = database;
    return database;
  }
}
