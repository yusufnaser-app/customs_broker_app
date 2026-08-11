import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class FundDashboardScreen extends StatefulWidget {
  const FundDashboardScreen({super.key});

  @override
  State<FundDashboardScreen> createState() => _FundDashboardScreenState();
}

class _FundDashboardScreenState extends State<FundDashboardScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  double _currentBalance = 0;
  double _todayIncome = 0;
  double _todayExpense = 0;
  List<Map<String, dynamic>> _todayTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFundData();
  }

  Future<void> _loadFundData() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // حساب الرصيد الحالي
    final incomeResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM fund_transactions WHERE type = 'income'"
    );
    final expenseResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM fund_transactions WHERE type = 'expense'"
    );
    
    final totalIncome = (incomeResult.first['total'] as num?)?.toDouble() ?? 0;
    final totalExpense = (expenseResult.first['total'] as num?)?.toDouble() ?? 0;
    
    // حركات اليوم
    final todayIncomeResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM fund_transactions WHERE type = 'income' AND date(transaction_date) = ?",
      [today],
    );
    final todayExpenseResult = await db.rawQuery(
      "SELECT SUM(amount) as total FROM fund_transactions WHERE type = 'expense' AND date(transaction_date) = ?",
      [today],
    );
    
    final todayTransactions = await db.rawQuery(
      "SELECT * FROM fund_transactions WHERE date(transaction_date) = ? ORDER BY created_at DESC",
      [today],
    );
    
    setState(() {
      _currentBalance = totalIncome - totalExpense;
      _todayIncome = (todayIncomeResult.first['total'] as num?)?.toDouble() ?? 0;
      _todayExpense = (todayExpenseResult.first['total'] as num?)?.toDouble() ?? 0;
      _todayTransactions = todayTransactions;
      _isLoading = false;
    });
  }

  Future<void> _showVoucherDialog(String type) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'income' ? 'سند قبض' : 'سند صرف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ *'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'البيان'),
              maxLines: 2,
            ),
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
              
              await db.insert('fund_transactions', {
                'id': const Uuid().v4(),
                'type': type,
                'amount': amount,
                'description': descriptionController.text,
                'transaction_date': now,
                'created_at': now,
              });
              
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    
    if (result == true) _loadFundData();
  }

  Future<void> _closeFund() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الصندوق'),
        content: Text('الرصيد الحالي: ${NumberFormat('#,##0').format(_currentBalance)} ر.ي\n\nهل أنت متأكد من إغلاق الصندوق؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إغلاق الصندوق بنجاح'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');
    
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الصندوق')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // بطاقة الرصيد
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text('الرصيد الحالي', style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(
                          '${currencyFormatter.format(_currentBalance)} ر.ي',
                          style: GoogleFonts.cairo(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // ملخص اليوم
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard('إيرادات اليوم', _todayIncome, AppColors.success, Icons.arrow_upward),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard('مصروفات اليوم', _todayExpense, AppColors.error, Icons.arrow_downward),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // أزرار الإجراءات
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showVoucherDialog('income'),
                          icon: const Icon(Icons.add_circle, color: Colors.white),
                          label: const Text('سند قبض', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showVoucherDialog('expense'),
                          icon: const Icon(Icons.remove_circle, color: Colors.white),
                          label: const Text('سند صرف', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _closeFund,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('إغلاق الصندوق'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // حركات اليوم
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('حركات اليوم', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${_todayTransactions.length} حركة', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_todayTransactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text('لا توجد حركات اليوم', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                    )
                  else
                    ..._todayTransactions.map((transaction) {
                      final isIncome = transaction['type'] == 'income';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (isIncome ? AppColors.success : AppColors.error).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? AppColors.success : AppColors.error,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            transaction['description'] as String? ?? (isIncome ? 'سند قبض' : 'سند صرف'),
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            DateFormat('hh:mm a').format(DateTime.parse(transaction['transaction_date'] as String)),
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${currencyFormatter.format(transaction['amount'])} ر.ي',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              color: isIncome ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,##0').format(amount)} ر.ي',
            style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
