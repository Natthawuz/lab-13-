import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/my_transaction.dart';

class ImportResult {
  const ImportResult({required this.useBatch, required this.elapsed});

  final bool useBatch;
  final Duration elapsed;
  int get count => 100;
}

/// Owns both the application state and the SQLite connection, as in Lab 13.
class TransactionProvider extends ChangeNotifier {
  TransactionProvider({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath {
    initialization = _loadInitially();
  }

  static const databaseName = 'expenses.db';
  static const tableName = 'transactions';
  static const databaseVersion = 2;

  final DatabaseFactory _factory;
  final String? _databasePath;
  late final Future<void> initialization;
  Database? _database;
  Future<void> _operationTail = Future<void>.value();
  List<MyTransaction> _transactions = [];
  double _income = 0;
  double _expense = 0;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _disposed = false;
  String? _error;

  List<MyTransaction> get transactions => List.unmodifiable(_transactions);
  double get totalIncome => _income;
  double get totalExpense => _expense;
  double get balance => _income - _expense;
  bool get isLoading => _isLoading;
  bool get isBusy => _isLoading || _isImporting;
  String? get error => _error;

  Future<void> _loadInitially() async {
    try {
      await fetchAndSetTransactions();
    } catch (_) {
      // The error is exposed to the screen with a retry button.
    }
  }

  Future<Database> _initDatabase() async {
    if (_database != null) return _database!;
    final path =
        _databasePath ??
        p.join(await _factory.getDatabasesPath(), databaseName);
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              amount REAL NOT NULL CHECK(amount > 0),
              date TEXT NOT NULL,
              type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
              note TEXT NOT NULL DEFAULT ''
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // onUpgrade is already inside a transaction. Preserve all v1 rows.
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN note TEXT NOT NULL DEFAULT ''",
            );
          }
        },
      ),
    );
    return _database!;
  }

  /// Serialize startup and writes so concurrent requests cannot show stale data.
  Future<T> _run<T>(Future<T> Function(Database db) action) {
    final operation = _operationTail.then((_) async {
      if (_disposed) throw StateError('Provider has been disposed.');
      _isLoading = true;
      _error = null;
      _notify();
      try {
        return await action(await _initDatabase());
      } catch (e) {
        _error = 'ไม่สามารถอ่านหรือบันทึกข้อมูลได้ กรุณาลองอีกครั้ง';
        debugPrint('SQLite operation failed: $e');
        rethrow;
      } finally {
        _isLoading = false;
        _notify();
      }
    });
    // A failed request must not prevent the next request or retry from running.
    _operationTail = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<void> _reload(Database db) async {
    // Read the list and its totals from the same snapshot.
    await db.transaction((txn) async {
      final rows = await txn.query(tableName, orderBy: 'date DESC, id DESC');
      final totals = await txn.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
          COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
        FROM transactions
      ''');
      _transactions = rows.map(MyTransaction.fromMap).toList();
      _income = (totals.single['income'] as num).toDouble();
      _expense = (totals.single['expense'] as num).toDouble();
    });
  }

  Future<void> fetchAndSetTransactions() => _run(_reload);

  Future<void> addTransaction(
    String title,
    double amount,
    DateTime date,
    TransactionType type, {
    String note = '',
  }) => _run((db) async {
    final transaction = MyTransaction(
      title: title.trim(),
      amount: amount,
      date: date,
      type: type,
      note: note.trim(),
    );
    _validate(transaction);
    await db.insert(tableName, transaction.toMap());
    await _reload(db);
  });

  Future<void> updateTransaction(int id, MyTransaction transaction) =>
      _run((db) async {
        _validate(transaction);
        // The id in the WHERE clause is the only id used for an update.
        final values = transaction.toMap()..remove('id');
        values['title'] = transaction.title.trim();
        values['note'] = transaction.note.trim();
        final changed = await db.update(
          tableName,
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (changed != 1) throw StateError('Transaction $id no longer exists.');
        await _reload(db);
      });

  Future<void> deleteTransaction(int id) => _run((db) async {
    final changed = await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (changed != 1) throw StateError('Transaction $id no longer exists.');
    await _reload(db);
  });

  /// Additional exercise: compare 100 calls to addTransaction with one batch.
  Future<ImportResult> importSamples({required bool useBatch}) async {
    if (_isImporting) throw StateError('An import is already running.');
    _isImporting = true;
    _notify();
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final samples = List.generate(
      100,
      (i) => MyTransaction(
        title: 'ตัวอย่าง ${i + 1}',
        amount: (i + 1) * 10.0,
        date: startDate.subtract(Duration(days: i % 30)),
        type: i % 5 == 0 ? TransactionType.income : TransactionType.expense,
        note: 'ข้อมูลตัวอย่างสำหรับปฏิบัติการที่ 13',
      ),
    );
    final stopwatch = Stopwatch()..start();
    try {
      if (useBatch) {
        await _run((db) async {
          await db.transaction((txn) async {
            final batch = txn.batch();
            for (final transaction in samples) {
              batch.insert(tableName, transaction.toMap());
            }
            await batch.commit(noResult: true);
          });
          await _reload(db);
        });
      } else {
        for (final transaction in samples) {
          await addTransaction(
            transaction.title,
            transaction.amount,
            transaction.date,
            transaction.type,
            note: transaction.note,
          );
        }
      }
      stopwatch.stop();
      return ImportResult(useBatch: useBatch, elapsed: stopwatch.elapsed);
    } finally {
      _isImporting = false;
      _notify();
    }
  }

  void _validate(MyTransaction transaction) {
    if (transaction.title.trim().isEmpty ||
        !transaction.amount.isFinite ||
        transaction.amount <= 0) {
      throw ArgumentError('A title and a positive finite amount are required.');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> close() async {
    await _operationTail;
    await _database?.close();
    _database = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
