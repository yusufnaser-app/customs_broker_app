import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _accounts = [];
  Map<String, List<Map<String, dynamic>>> _transactions = {};
  bool _isLoading = true;
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    
    final accounts = await db.query('bank_accounts', where: 'is_active = 1', orderBy: 'bank_name ASC');
    
    final transactions = <String, List<Map<String, dynamic>>>{};
    for (final account in accounts) {
      final accountTransactions = await db.query(
        'bank_transactions',
        where: 'bank_account_id = ?',
        whereArgs: [account['id']],
        orderBy: 'transaction_date DESC',
        limit: 10,
      );
      transactions[account['id'] as String] = accountTransactions;
    }
    
    setState(() {
      _accounts = accounts;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  Future<void> _showAccountDialog({String? accountId}) async {
    final bankNameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final accountNameController = TextEditingController();
    
    if (accountId != null) {
      final account = _accounts.firstWhere((a) => a['id'] == accountId);
      bankNameController.text = account['bank_name'] as String;
      accountNumberController.text = account['account_number'] as String;
      accountNameController.text = account['account_name'] as String;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accountId != null ? 'تعديل حساب' : 'حساب بنكي جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: bankNameController, decoration: const InputDecoration(labelText: 'اسم البنك *')),
            const SizedBox(height: 12),
            TextField(controller: accountNumberController, decoration: const InputDecoration(labelText: 'رقم الحساب *')),
            const SizedBox(height: 12),
            TextField(controller: accountNameController, decoration: const InputDecoration(labelText: 'اسم صاحب الحساب *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (bankNameController.text.isEmpty || accountNumberController.text.isEmpty) return;
              
              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();
              
              final data = <String, dynamic>{
                'bank_name': bankNameController.text,
                'account_number': accountNumberController.text,
                'account_name': accountNameController.text,
                'updated_at': now,
              };
              
              if (accountId != null) {
                await db.update('bank_accounts', data, where: 'id = ?', whereArgs: [accountId]);
              } else {
                data['id'] = const Uuid().v4();
                data['currency'] = 'YER';
                data['balance'] = 0;
                data['is_active'] = 1;
                data['created_at'] = now;
                await db.insert('bank_accounts', data);
              }
              
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    
    if (result == true) _loadData();
  }

  Future<void> _showTransactionDialog(String accountId) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'deposit';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('معاملة جديدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'deposit', label: Text('إيداع'), icon: Icon(Icons.arrow_downward)),
                    ButtonSegment(value: 'withdrawal', label: Text('سحب'), icon: Icon(Icons.arrow_upward)),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (v) => setDialogState(() => selectedType = v.first),
                ),
                const SizedBox(height: 12),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ *'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'البيان'), maxLines: 2),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0) return;
                  
                  final db = await _dbHelper.database;
                  final now = DateTime.now().toIso8601String();
                  
                  await db.insert('bank_transactions', {
                    'id': const Uuid().v4(),
                    'bank_account_id': accountId,
                    'type': selectedType,
                    'amount': amount,
                    'description': descriptionController.text,
                    'transaction_date': now,
                    'created_at': now,
                  });
                  
                  // تحديث رصيد الحساب
                  final operator = selectedType == 'deposit' ? '+' : '-';
                  await db.rawUpdate(
                    'UPDATE bank_accounts SET balance = balance $operator ?, updated_at = ? WHERE id = ?',
                    [amount, now, accountId],
                  );
                  
                  Navigator.pop(context, true);
                },
                child: const Text('تنفيذ'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');
    
    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات البنكية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('لا توجد حسابات بنكية', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAccountDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة حساب'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final accountTransactions = _transactions[account['id']] ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(account['bank_name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(account['account_number'] as String, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${currencyFormatter.format(account['balance'])} ر.ي',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showTransactionDialog(account['id'] as String),
                                    icon: const Icon(Icons.swap_horiz, size: 16),
                                    label: const Text('معاملة'),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showAccountDialog(accountId: account['id'] as String),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('تعديل'),
                                  ),
                                ),
                              ],
                            ),
                            if (accountTransactions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              Text('آخر المعاملات:', style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ...accountTransactions.take(3).map((t) {
                                final isDeposit = t['type'] == 'deposit';
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isDeposit ? AppColors.success : AppColors.error,
                                    size: 18,
                                  ),
                                  title: Text(t['description'] as String? ?? (isDeposit ? 'إيداع' : 'سحب'), style: GoogleFonts.cairo(fontSize: 13)),
                                  trailing: Text(
                                    '${isDeposit ? '+' : '-'}${currencyFormatter.format(t['amount'])}',
                                    style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: isDeposit ? AppColors.success : AppColors.error),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
