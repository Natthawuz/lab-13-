import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _money = NumberFormat('#,##0.00', 'th_TH');
  Duration? _individualTime;
  Duration? _batchTime;

  Future<void> _openForm([MyTransaction? transaction]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(transaction: transaction),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกรายการเรียบร้อยแล้ว')),
      );
    }
  }

  Future<void> _refresh() async {
    try {
      await context.read<TransactionProvider>().fetchAndSetTransactions();
    } catch (_) {
      // Consumer displays the provider's error and retry action.
    }
  }

  Future<void> _delete(MyTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text(
          '“${transaction.title}” จำนวน ${_money.format(transaction.amount)} บาท',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบรายการ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<TransactionProvider>().deleteTransaction(
        transaction.id!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลบรายการเรียบร้อยแล้ว')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบไม่สำเร็จ กรุณาลองอีกครั้ง')),
      );
    }
  }

  Future<void> _importSamples() async {
    final useBatch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('นำเข้าตัวอย่าง 100 รายการ'),
        content: const Text(
          'เลือกวิธีนำเข้าเพื่อจับเวลาเปรียบเทียบ แต่ละครั้งจะเพิ่มข้อมูลจริงอีก 100 รายการในแอป',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ทีละรายการ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batch'),
          ),
        ],
      ),
    );
    if (useBatch == null || !mounted) return;
    try {
      final result = await context.read<TransactionProvider>().importSamples(
        useBatch: useBatch,
      );
      if (!mounted) return;
      setState(() {
        if (useBatch) {
          _batchTime = result.elapsed;
        } else {
          _individualTime = result.elapsed;
        }
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('นำเข้าเรียบร้อยแล้ว'),
          content: Text(
            'เพิ่ม ${result.count} รายการ\n\n'
            'ทีละรายการ: ${_formatTime(_individualTime)}\n'
            'Batch: ${_formatTime(_batchTime)}\n\n'
            'เวลารวมการบันทึกและอ่านข้อมูลกลับเข้า Provider '
            'แบบทีละรายการอ่านกลับ 100 ครั้ง ส่วน Batch อ่านกลับครั้งเดียว '
            'ผลขึ้นกับอุปกรณ์และจำนวนข้อมูลเดิม',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('นำเข้าไม่สำเร็จ กรุณาตรวจสอบรายการแล้วลองอีกครั้ง'),
        ),
      );
    }
  }

  String _formatTime(Duration? time) => time == null
      ? 'ยังไม่ได้ทดสอบ'
      : '${(time.inMicroseconds / 1000).toStringAsFixed(2)} ms';

  @override
  Widget build(BuildContext context) => Consumer<TransactionProvider>(
    builder: (context, provider, child) => Scaffold(
      appBar: AppBar(
        title: const Text('รายรับ–รายจ่าย'),
        actions: [
          IconButton(
            tooltip: 'โหลดข้อมูลใหม่',
            onPressed: provider.isBusy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'นำเข้าตัวอย่าง 100 รายการ',
            onPressed: provider.isBusy ? null : _importSamples,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (provider.isBusy)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  SliverToBoxAdapter(child: _buildSummary(provider)),
                  if (provider.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Text(
                              provider.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: provider.isBusy ? null : _refresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text('ลองอีกครั้ง'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'รายการทั้งหมด',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text('${provider.transactions.length} รายการ'),
                        ],
                      ),
                    ),
                  ),
                  if (provider.transactions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 64,
                                color: Colors.teal,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                provider.isBusy
                                    ? 'กำลังโหลดข้อมูล...'
                                    : 'ยังไม่มีรายการ',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'กด “เพิ่มรายการ” เพื่อเริ่มบันทึกรายรับและรายจ่าย',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: provider.transactions.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildTransaction(
                          provider.transactions[index],
                          provider.isBusy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_transaction_button'),
        onPressed: provider.isBusy ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรายการ'),
      ),
    ),
  );

  Widget _buildSummary(TransactionProvider provider) => Container(
    margin: const EdgeInsets.all(20),
    padding: const EdgeInsets.all(20),
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF075E54),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ยอดคงเหลือ', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Text(
          '${_money.format(provider.balance)} บาท',
          key: const Key('balance_text'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _summaryAmount('รายรับ', provider.totalIncome, Icons.south_west),
            _summaryAmount('รายจ่าย', provider.totalExpense, Icons.north_east),
          ],
        ),
      ],
    ),
  );

  Widget _summaryAmount(String label, double amount, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '${_money.format(amount)} บาท',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildTransaction(MyTransaction transaction, bool busy) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? const Color(0xFF087F72) : const Color(0xFFB3422C);
    return Card(
      key: ValueKey('transaction_${transaction.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : () => _openForm(transaction),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isIncome ? 'รายรับ' : 'รายจ่าย'} · ${DateFormat('d MMM yyyy', 'th_TH').format(transaction.date)}',
                    ),
                    if (transaction.note.isNotEmpty)
                      Text(
                        transaction.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${isIncome ? '+' : '−'}${_money.format(transaction.amount)} บาท',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ลบ ${transaction.title}',
                onPressed: busy ? null : () => _delete(transaction),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
