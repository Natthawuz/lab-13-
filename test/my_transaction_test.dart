import 'package:expense_tracker_provider/models/my_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new records omit id and encode enum and date as text', () {
    final transaction = MyTransaction(
      title: 'เงินเดือน',
      amount: 20000,
      date: DateTime(2026, 10, 1),
      type: TransactionType.income,
      note: 'ตุลาคม',
    );
    final map = transaction.toMap();
    expect(map.containsKey('id'), isFalse);
    expect(map['type'], 'income');
    expect(map['date'], '2026-10-01T00:00:00.000');
    final restored = MyTransaction.fromMap({...map, 'id': 1});
    expect(restored.amount, transaction.amount);
    expect(restored.date, transaction.date);
    expect(restored.note, transaction.note);
  });

  test(
    'integer SQLite amounts and legacy records without notes are accepted',
    () {
      final transaction = MyTransaction.fromMap({
        'id': 7,
        'title': 'ค่าอาหาร',
        'amount': 120,
        'date': '2026-10-02T00:00:00.000',
        'type': 'expense',
      });
      expect(transaction.amount, 120.0);
      expect(transaction.note, '');
      expect(transaction.toMap()['id'], 7);
    },
  );
}
