import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._({this._factory, this._databasePath});

  DatabaseHelper.forTesting({
    required DatabaseFactory factory,
    required String databasePath,
  }) : this._(factory: factory, databasePath: databasePath);

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'monee_expenses.db';
  static const _databaseVersion = 1;

  final DatabaseFactory? _factory;
  final String? _databasePath;
  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    if (_database case final database?) return database;
    final openingDatabase = _openingDatabase ??= _openDatabase();
    try {
      return await openingDatabase;
    } catch (_) {
      if (identical(_openingDatabase, openingDatabase)) {
        _openingDatabase = null;
      }
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final databasePath =
        _databasePath ?? path.join(await getDatabasesPath(), _databaseName);
    final options = OpenDatabaseOptions(
      version: _databaseVersion,
      onCreate: _createSchema,
    );
    final database = _factory == null
        ? await openDatabase(databasePath, options: options)
        : await _factory.openDatabase(databasePath, options: options);
    _database = database;
    return database;
  }

  static Future<void> _createSchema(Database db, int version) async {
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
  }
}
