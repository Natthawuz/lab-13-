import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';

class AddEditTransactionScreen extends StatefulWidget {
  const AddEditTransactionScreen({super.key, this.transaction});

  final MyTransaction? transaction;

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  late TransactionType _type;
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _title = TextEditingController(text: transaction?.title ?? '');
    _amount = TextEditingController(
      text: transaction?.amount.toStringAsFixed(2) ?? '',
    );
    _note = TextEditingController(text: transaction?.note ?? '');
    _date = transaction?.date ?? DateTime.now();
    _type = transaction?.type ?? TransactionType.expense;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String? _validateAmount(String? text) {
    final input = text?.trim().replaceAll(',', '.') ?? '';
    final value = double.tryParse(input);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input) ||
        value == null ||
        !value.isFinite ||
        value <= 0) {
      return 'กรอกจำนวนเงินมากกว่า 0 และทศนิยมไม่เกิน 2 ตำแหน่ง';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final provider = context.read<TransactionProvider>();
    final amount = double.parse(_amount.text.trim().replaceAll(',', '.'));
    try {
      if (_isEditing) {
        await provider.updateTransaction(
          widget.transaction!.id!,
          MyTransaction(
            title: _title.text.trim(),
            amount: amount,
            date: _date,
            type: _type,
            note: _note.text.trim(),
          ),
        );
      } else {
        await provider.addTransaction(
          _title.text,
          amount,
          _date,
          _type,
          note: _note.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'ประเภทรายการ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('รายรับ'),
                        icon: Icon(Icons.south_west),
                      ),
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('รายจ่าย'),
                        icon: Icon(Icons.north_east),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (selection) =>
                              setState(() => _type = selection.single),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('title_field'),
                    controller: _title,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อรายการ',
                      hintText: 'เช่น เงินเดือน หรือค่าอาหาร',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    validator: (text) => text == null || text.trim().isEmpty
                        ? 'กรุณากรอกชื่อรายการ'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('amount_field'),
                    controller: _amount,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนเงิน',
                      suffixText: 'บาท',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: _validateAmount,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    key: const Key('date_button'),
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'วันที่ ${DateFormat('d MMM yyyy', 'th_TH').format(_date)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('note_field'),
                    controller: _note,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'หมายเหตุ (ไม่บังคับ)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('save_button'),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกรายการ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
