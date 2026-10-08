import 'dart:async';
import 'dart:io';

import 'package:expense_tracker_provider/main.dart';
import 'package:expense_tracker_provider/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets(
    'Thai form validates, adds, edits, and confirms deletion on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory directory;
      late TransactionProvider provider;
      await tester.runAsync(() async {
        await initializeDateFormatting('th_TH');
        directory = await Directory.systemTemp.createTemp('lab13_ui_');
        provider = TransactionProvider(
          factory: databaseFactoryFfi,
          databasePath: p.join(directory.path, 'expenses.db'),
        );
        await provider.initialization;
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: provider, child: const MyApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('ยังไม่มีรายการ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('add_transaction_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('save_button')));
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();
      expect(find.text('กรุณากรอกชื่อรายการ'), findsOneWidget);
      expect(provider.transactions, isEmpty);

      await tester.enterText(find.byKey(const Key('title_field')), 'ค่าอาหาร');
      await tester.enterText(find.byKey(const Key('amount_field')), '120.50');
      await tester.enterText(
        find.byKey(const Key('note_field')),
        'มื้อกลางวัน',
      );
      await tester.ensureVisible(find.byKey(const Key('save_button')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('save_button')));
        await provider.fetchAndSetTransactions();
      });
      await tester.pumpAndSettle();
      expect(find.text('ค่าอาหาร'), findsOneWidget);
      expect(find.text('มื้อกลางวัน'), findsOneWidget);
      expect(provider.balance, -120.50);
      final id = provider.transactions.single.id;

      await tester.tap(find.byKey(ValueKey('transaction_$id')));
      await tester.pumpAndSettle();
      expect(find.text('แก้ไขรายการ'), findsOneWidget);
      expect(find.text('120.50'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('amount_field')), '150');
      await tester.tap(find.text('รายรับ'));
      await tester.ensureVisible(find.byKey(const Key('save_button')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('save_button')));
        await provider.fetchAndSetTransactions();
      });
      await tester.pumpAndSettle();
      expect(provider.transactions.single.id, id);
      expect(provider.balance, 150);

      await tester.runAsync(() => tester.tap(find.byTooltip('ลบ ค่าอาหาร')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(provider.transactions, hasLength(1));
      await tester.runAsync(() => tester.tap(find.byTooltip('ลบ ค่าอาหาร')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final deleted = Completer<void>();
        void onChange() {
          if (provider.transactions.isEmpty && !deleted.isCompleted) {
            deleted.complete();
          }
        }

        provider.addListener(onChange);
        try {
          await tester.tap(find.text('ลบรายการ'));
          await deleted.future.timeout(const Duration(seconds: 10));
        } finally {
          provider.removeListener(onChange);
        }
      });
      await tester.pumpAndSettle();
      expect(provider.transactions, isEmpty);
      expect(find.text('ยังไม่มีรายการ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await provider.close();
        provider.dispose();
        await directory.delete(recursive: true);
      });
    },
  );
}
