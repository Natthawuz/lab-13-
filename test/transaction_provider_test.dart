import 'dart:io';

import 'package:expense_tracker_provider/models/my_transaction.dart';
import 'package:expense_tracker_provider/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  final providers = <TransactionProvider>[];

  TransactionProvider createProvider() {
    final provider = TransactionProvider(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    providers.add(provider);
    return provider;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lab13_test_');
    path = p.join(directory.path, 'expenses.db');
  });

  tearDown(() async {
    for (final provider in providers) {
      await provider.close();
      provider.dispose();
    }
    providers.clear();
    await directory.delete(recursive: true);
  });

  test(
    'CRUD persists across reopening, preserves ids, and calculates SQL totals',
    () async {
      final provider = createProvider();
      await provider.initialization;
      expect(provider.error, isNull);
      expect(provider.balance, 0);

      await provider.addTransaction(
        'เงินเดือน',
        20000,
        DateTime(2026, 10, 1),
        TransactionType.income,
      );
      await provider.addTransaction(
        'ค่าอาหาร',
        120.50,
        DateTime(2026, 10, 2),
        TransactionType.expense,
        note: 'มื้อกลางวัน',
      );
      expect(provider.transactions.first.title, 'ค่าอาหาร');
      expect(provider.totalIncome, 20000);
      expect(provider.totalExpense, 120.50);
      expect(provider.balance, 19879.50);

      final expenseId = provider.transactions.first.id!;
      final salaryId = provider.transactions.last.id!;
      // No id in the replacement model: UPDATE must preserve the original key.
      await provider.updateTransaction(
        expenseId,
        MyTransaction(
          title: "ค่าอาหาร 'พิเศษ'",
          amount: 150,
          date: DateTime(2026, 10, 3),
          type: TransactionType.expense,
          note: 'แก้ไขแล้ว',
        ),
      );
      expect(provider.transactions.first.id, expenseId);
      expect(provider.balance, 19850);

      await provider.close();
      final reopened = createProvider();
      await reopened.initialization;
      expect(reopened.transactions, hasLength(2));
      expect(reopened.transactions.first.title, "ค่าอาหาร 'พิเศษ'");
      expect(reopened.transactions.first.note, 'แก้ไขแล้ว');

      await reopened.deleteTransaction(salaryId);
      expect(reopened.balance, -150);
      await reopened.close();
      final reopenedAgain = createProvider();
      await reopenedAgain.initialization;
      expect(reopenedAgain.transactions.single.id, expenseId);
      expect(reopenedAgain.totalIncome, 0);
    },
  );

  test(
    'v1 migration preserves every field and adds note without reinstalling',
    () async {
      final oldDb = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute(
            'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type TEXT)',
          ),
        ),
      );
      final id = await oldDb.insert('transactions', {
        'title': 'รายการเดิม',
        'amount': 250,
        'date': '2026-09-30T00:00:00.000',
        'type': 'income',
      });
      await oldDb.close();

      final provider = createProvider();
      await provider.initialization;
      expect(provider.error, isNull);
      final original = provider.transactions.single;
      expect(original.id, id);
      expect(original.title, 'รายการเดิม');
      expect(original.amount, 250.0);
      expect(original.date, DateTime(2026, 9, 30));
      expect(original.type, TransactionType.income);
      expect(original.note, '');
      await provider.updateTransaction(
        id,
        MyTransaction(
          title: original.title,
          amount: original.amount,
          date: original.date,
          type: original.type,
          note: 'เพิ่มหลังอัปเกรด',
        ),
      );
      expect(provider.transactions.single.note, 'เพิ่มหลังอัปเกรด');
    },
  );

  test(
    'concurrent startup and inserts retain every row and notify listeners',
    () async {
      final provider = createProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);
      await Future.wait(
        List.generate(
          20,
          (i) => provider.addTransaction(
            'รายการ $i',
            10,
            DateTime(2026, 10, 8),
            TransactionType.income,
          ),
        ),
      );
      expect(provider.transactions, hasLength(20));
      expect(provider.transactions.map((tx) => tx.id).toSet(), hasLength(20));
      expect(provider.totalIncome, 200);
      expect(notifications, greaterThan(0));
      expect(provider.isBusy, isFalse);
    },
  );

  test(
    'failed writes remain visible as errors and the next request succeeds',
    () async {
      final provider = createProvider();
      await provider.initialization;
      for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          provider.addTransaction(
            'ผิด',
            amount,
            DateTime.now(),
            TransactionType.expense,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        provider.addTransaction(
          '   ',
          10,
          DateTime.now(),
          TransactionType.expense,
        ),
        throwsArgumentError,
      );
      expect(provider.error, isNotNull);
      expect(provider.transactions, isEmpty);
      await provider.addTransaction(
        'ถูกต้อง',
        10,
        DateTime.now(),
        TransactionType.income,
      );
      expect(provider.error, isNull);
      expect(provider.transactions, hasLength(1));
      await expectLater(provider.deleteTransaction(99999), throwsStateError);
      expect(provider.transactions, hasLength(1));
    },
  );

  test('both import methods add exactly 100 identical sample values', () async {
    final provider = createProvider();
    await provider.initialization;
    final individual = await provider.importSamples(useBatch: false);
    expect(individual.count, 100);
    expect(provider.transactions, hasLength(100));
    final firstIncome = provider.totalIncome;
    final firstExpense = provider.totalExpense;
    final firstValues = provider.transactions
        .map((tx) => tx.toMap()..remove('id'))
        .toList();

    final batch = await provider.importSamples(useBatch: true);
    expect(batch.count, 100);
    expect(provider.transactions, hasLength(200));
    expect(provider.totalIncome, firstIncome * 2);
    expect(provider.totalExpense, firstExpense * 2);
    final imported = provider.transactions
        .where((tx) => tx.id! > 100)
        .map((tx) => tx.toMap()..remove('id'))
        .toList();
    expect(imported, firstValues);
    expect(provider.isBusy, isFalse);
  });

  test('a failed batch rolls back all its rows', () async {
    final provider = createProvider();
    await provider.initialization;
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('''
      CREATE TRIGGER reject_sample BEFORE INSERT ON transactions
      WHEN NEW.title = 'ตัวอย่าง 50'
      BEGIN SELECT RAISE(ABORT, 'test failure'); END;
    ''');
    await expectLater(
      provider.importSamples(useBatch: true),
      throwsA(isA<DatabaseException>()),
    );
    await provider.fetchAndSetTransactions();
    expect(provider.transactions, isEmpty);
    expect(provider.balance, 0);
  });
}
