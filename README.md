# lab-13-

ปฏิบัติการบทที่ 13 แอปบัญชีรายรับ–รายจ่ายด้วย **Flutter, Provider และ SQLite**

โปรเจกต์ชื่อ `expense_tracker_provider` ทำตามปฏิบัติการท้ายบท รวมหน้าฟอร์มเพิ่ม/แก้ไขที่เป็นการบ้าน และความท้าทายเพิ่มเติมทั้ง 3 ข้อ ข้อมูลเก็บในไฟล์ `expenses.db` บนอุปกรณ์ โหลดกลับเมื่อเปิดแอป และใช้งานได้โดยไม่ต้องเชื่อมต่ออินเทอร์เน็ต

## ความสามารถ

- เพิ่มรายรับหรือรายจ่าย พร้อมชื่อ จำนวนเงิน วันที่ และหมายเหตุ
- แสดงรายการล่าสุดก่อน พร้อมยอดรายรับ รายจ่าย และยอดคงเหลือ
- แตะรายการเพื่อเปิดฟอร์มแก้ไขที่เติมข้อมูลเดิมให้
- กดไอคอนถังขยะและยืนยันเพื่อลบรายการ
- ตรวจชื่อที่ว่าง จำนวนเงินที่ไม่มากกว่า 0 และทศนิยมเกิน 2 ตำแหน่ง
- แสดงสถานะกำลังทำงาน ข้อผิดพลาด และปุ่มลองอีกครั้ง
- รองรับข้อความและตัวเลือกวันที่ภาษาไทย รวมทั้งหน้าจอแนวตั้งและแนวนอน

## ส่วนที่ตรงกับโจทย์

| กระบวนการ | ไฟล์และการทำงาน |
| --- | --- |
| 1 เตรียมโปรเจกต์ | `pubspec.yaml`: sqflite, path, provider, intl |
| 2 Model และฐานข้อมูล | `MyTransaction.toMap/fromMap` และ `TransactionProvider._initDatabase` |
| 3 Insert | `addTransaction` บันทึกรายการและอ่านข้อมูลกลับ |
| 4 Read | `fetchAndSetTransactions` และ `Consumer<TransactionProvider>` |
| 5 Update | `updateTransaction` ใช้ `where: 'id = ?'` กับ `whereArgs` |
| 6 Delete | `deleteTransaction` และกล่องยืนยันในหน้ารายการ |
| การบ้าน | `AddEditTransactionScreen` ใช้ Form, validation และ Navigator |

Provider ถือการเชื่อมต่อ SQLite และ state ตามสถาปัตยกรรมของปฏิบัติการ หน้าจอเรียก Provider โดยไม่ใช้ SQL โดยตรง ใช้ `getDatabasesPath()` และ `path.join()` จึงไม่ต้องเพิ่ม `path_provider`

## โครงสร้าง

```text
lib/
  main.dart
  models/my_transaction.dart
  providers/transaction_provider.dart
  screens/transaction_list_screen.dart
  screens/add_edit_transaction_screen.dart
test/
  my_transaction_test.dart
  transaction_provider_test.dart
  transaction_screen_test.dart
android/   # โปรเจกต์ Android
ios/       # โปรเจกต์ iOS
macos/     # โปรเจกต์ macOS
```

## วิธีรัน

ใช้ Flutter stable ที่รองรับ Dart 3.10 ขึ้นไป พร้อมเครื่องมือของแพลตฟอร์มที่จะรัน โปรเจกต์นี้ตรวจสอบด้วย Flutter **3.47.1** / Dart **3.13.1**

```bash
git clone https://github.com/Natthawuz/lab-13-.git
cd lab-13-
flutter pub get
flutter devices
flutter run
```

เลือกอุปกรณ์ Android/iOS หรือใช้ `flutter run -d macos` บน Mac ที่ติดตั้ง Xcode แล้ว โปรเจกต์นี้สร้างสำหรับ Android, iOS และ macOS ตามการรองรับของ sqflite ไม่ได้ตั้งค่า Flutter Web

หากเครื่อง Mac ติดตั้ง Flutter ไว้ที่ `~/flutter` แต่ยังไม่อยู่ใน PATH ใช้ `~/flutter/bin/flutter` แทนคำว่า `flutter` ในคำสั่งข้างต้น

## ความท้าทายเพิ่มเติม

**1. หมายเหตุและ migration:** ฐานข้อมูลเวอร์ชัน 2 เพิ่มคอลัมน์ `note` ด้วย `onUpgrade` เมื่อพบฐานข้อมูลเวอร์ชัน 1 โดยไม่ลบตารางหรือรายการเดิม การทดสอบสร้างไฟล์เวอร์ชัน 1 ตาม schema ในเอกสาร แล้วเปิดด้วย Provider เวอร์ชันใหม่และตรวจข้อมูลเดิมครบทุกฟิลด์

**2. ยอดคงเหลือจาก SQL:** `_reload` ใช้ `rawQuery` กับ `SUM`, `CASE` และ `COALESCE` เพื่อหายอดรวมรายรับและรายจ่ายจากฐานข้อมูล ยอดคงเหลือคือรายรับลบรายจ่าย ไม่วนบวกรายการใน Dart อ่านรายการและยอดรวมภายใน transaction เดียวกัน

**3. นำเข้า 100 รายการ:** กดไอคอนนำเข้าข้างปุ่มรีเฟรช แล้วเลือก “ทีละรายการ” หรือ “Batch” แต่ละครั้งเพิ่มรายการจริง 100 รายการ และแสดงเวลาล่าสุดของแต่ละวิธีเพื่อเปรียบเทียบ

- ทีละรายการเรียก `addTransaction` 100 ครั้ง จึงอ่านรายการกลับ 100 ครั้งตามกระบวนการปกติ
- Batch ใช้ `txn.batch()` ภายใน `db.transaction()` แล้วอ่านกลับครั้งเดียว หากคำสั่งใดล้มเหลวจะย้อนกลับทั้งชุด
- ใช้ `Stopwatch` วัดเวลารวมการบันทึกและอ่านกลับ ตัวเลขจึงเปรียบเทียบทั้ง workflow ไม่ใช่เฉพาะคำสั่ง INSERT และแต่ละรอบมีจำนวนข้อมูลเดิมต่างกัน
- แบบทีละรายการอาจบันทึกได้บางส่วนหากเกิดข้อผิดพลาดกลางทาง ส่วน Batch สำเร็จหรือล้มเหลวพร้อมกันทั้งหมด

## การตรวจสอบ

```bash
flutter analyze
flutter test --reporter expanded
```

การทดสอบใช้ SQLite จริงผ่าน `sqflite_common_ffi` ในไฟล์ชั่วคราวแยกแต่ละกรณี ครอบคลุมการแปลง Model, CRUD, การเปิดฐานข้อมูลใหม่, SQL totals, migration, คำขอพร้อมกัน, การกู้คืนหลังคำสั่งล้มเหลว, การนำเข้าทั้งสองวิธี, batch rollback และการกดเพิ่ม/แก้ไข/ยกเลิกการลบ/ยืนยันลบใน UI

ตรวจ compile Flutter assets สำหรับ macOS ด้วย:

```bash
flutter build bundle --target-platform=darwin --debug --no-pub
```

เครื่องที่จัดทำโปรเจกต์ไม่มี Android SDK และไม่มี Xcode แบบเต็ม จึงยังไม่ได้ build APK, IPA หรือแอป macOS แบบติดตั้งจริง การ compile assets และการทดสอบไม่แทนการทดสอบบนอุปกรณ์จริง

ทดสอบการคงอยู่ของข้อมูลเพิ่มเติมบนมือถือได้โดยเพิ่มรายการ ปิดแอปจากรายการแอปล่าสุด แล้วเปิดใหม่ รายการต้องยังอยู่ การถอนการติดตั้งแอปจะลบฐานข้อมูลของแอปตามพฤติกรรมระบบปฏิบัติการ

## เอกสารประกอบ

- [Flutter — Persist data with SQLite](https://docs.flutter.dev/cookbook/persistence/sqlite)
- [sqflite](https://pub.dev/packages/sqflite)
- [Provider](https://pub.dev/packages/provider)
