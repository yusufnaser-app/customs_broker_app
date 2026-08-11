import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _expenses = [];
  Map<String, double> _categoryTotals = {};
  double _totalExpenses = 0;
  bool _isLoading = true;
  String _selectedPeriod = 'all';

  final List<String> _categories = [
    'الرواتب', 'الإيجار', 'الكهرباء', 'الوقود', 'الصيانة', 'الاتصالات', 'مصروفات متنوعة'
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    
    String? dateFilter;
    final now = DateTime.now();
    if (_selectedPeriod == 'today') {
      dateFilter = DateFormat('yyyy-MM-dd').format(now);
    } else if (_selectedPeriod == 'month') {
      dateFilter = DateFormat('yyyy-MM').format(now);
    }
    
    List<Map<String, dynamic>> expenses;
    if (dateFilter != null) {
      expenses = await db.rawQuery(
        "SELECT * FROM expenses WHERE date(expense_date) = ? OR strftime('%Y-%m', expense_date) = ? ORDER BY expense_date DESC",
        [dateFilter, dateFilter],
      );
    } else {
      expenses = await db.query('expenses', orderBy: 'expense_date DESC');
    }
    
    // حساب المجاميع حسب الفئة
    final categoryTotals = <String, double>{};
    double total = 0;
    for (final expense in expenses) {
      final category = expense['category'] as String;
      final amount = (expense['amount'] as num).toDouble();
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      total += amount;
    }
    
    setState(() {
      _expenses = expenses;
      _categoryTotals = categoryTotals;
      _totalExpenses = total;
      _isLoading = false;
    });
  }

  Future<void> _showExpenseDialog({String? expenseId}) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    String selectedCategory = _categories[0];
    
    if (expenseId != null) {
      final expense = _expenses.firstWhere((e) => e['id'] == expenseId);
      amountController.text = (expense['amount'] as num).toString();
      descriptionController.text = expense['description'] as String? ?? '';
      selectedCategory = expense['category'] as String;
      dateController.text = expense['expense_date'] as String? ?? '';
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(expenseId != null ? 'تعديل مصروف' : 'مصروف جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'الفئة *'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'المبلغ *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(labelText: 'التاريخ', suffixIcon: Icon(Icons.calendar_today)),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(date);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0) return;
                  
                  final db = await _dbHelper.database;
                  final now = DateTime.now().toIso8601String();
                  
                  final data = {
                    'category': selectedCategory,
                    'amount': amount,
                    'description': descriptionController.text,
                    'expense_date': dateController.text,
                    'created_at': now,
                  };
                  
                  if (expenseId != null) {
                    await db.update('expenses', data, where: 'id = ?', whereArgs: [expenseId]);
                  } else {
                    data['id'] = const Uuid().v4();
                    data['payment_method'] = 'نقدي';
                    await db.insert('expenses', data);
                    
                    // إضافة للصندوق
                    await db.insert('fund_transactions', {
                      'id': const Uuid().v4(),
                      'type': 'expense',
                      'amount': amount,
                      'description': 'مصروف: $selectedCategory - ${descriptionController.text}',
                      'reference_type': 'expense',
                      'reference_id': data['id'],
                      'transaction_date': now,
                      'created_at': now,
                    });
                  }
                  
                  Navigator.pop(context, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    
    if (result == true) _loadExpenses();
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final db = await _dbHelper.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      _loadExpenses();
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'الرواتب': return Icons.people;
      case 'الإيجار': return Icons.home;
      case 'الكهرباء': return Icons.flash_on;
      case 'الوقود': return Icons.local_gas_station;
      case 'الصيانة': return Icons.build;
      case 'الاتصالات': return Icons.phone;
      default: return Icons.money_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('المصروفات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _selectedPeriod = v);
              _loadExpenses();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'today', child: Text('اليوم')),
              const PopupMenuItem(value: 'month', child: Text('هذا الشهر')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ملخص الفئات
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text('إجمالي المصروفات', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${currencyFormatter.format(_totalExpenses)} ر.ي',
                          style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // توزيع المصروفات
                  if (_categoryTotals.isNotEmpty) ...[
                    Text('توزيع المصروفات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._categoryTotals.entries.map((entry) {
                      final percentage = _totalExpenses > 0 ? (entry.value / _totalExpenses * 100) : 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getCategoryIcon(entry.key), size: 18, color: AppColors.error),
                                    const SizedBox(width: 6),
                                    Text(entry.key, style: GoogleFonts.cairo(fontSize: 14)),
                                  ],
                                ),
                                Text(
                                  '${currencyFormatter.format(entry.value)} ر.ي (${percentage.toStringAsFixed(1)}%)',
                                  style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                  
                  // قائمة المصروفات
                  Text('سجل المصروفات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  ..._expenses.map((expense) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.error.withOpacity(0.1),
                        child: Icon(_getCategoryIcon(expense['category'] as String), color: AppColors.error, size: 20),
                      ),
                      title: Text(expense['category'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (expense['description'] != null)
                            Text(expense['description'] as String, style: GoogleFonts.cairo(fontSize: 12)),
                          Text(expense['expense_date'] as String? ?? '', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${currencyFormatter.format(expense['amount'])} ر.ي',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.error),
                          ),
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                            onSelected: (v) {
                              if (v == 'edit') {
                                _showExpenseDialog(expenseId: expense['id'] as String);
                              } else if (v == 'delete') {
                                _deleteExpense(expense['id'] as String);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseDialog(),
        backgroundColor: AppColors.error,
        child: const Icon(Icons.add),
      ),
    );
  }
}
