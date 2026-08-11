import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class RevenuesScreen extends StatefulWidget {
  const RevenuesScreen({super.key});

  @override
  State<RevenuesScreen> createState() => _RevenuesScreenState();
}

class _RevenuesScreenState extends State<RevenuesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _revenues = [];
  double _totalRevenues = 0;
  bool _isLoading = true;
  String _selectedPeriod = 'all';

  final List<String> _categories = ['أتعاب', 'عمولات', 'خدمات', 'أخرى'];

  @override
  void initState() {
    super.initState();
    _loadRevenues();
  }

  Future<void> _loadRevenues() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    
    List<Map<String, dynamic>> revenues;
    if (_selectedPeriod == 'month') {
      final month = DateFormat('yyyy-MM').format(DateTime.now());
      revenues = await db.rawQuery(
        "SELECT * FROM revenues WHERE strftime('%Y-%m', revenue_date) = ? ORDER BY revenue_date DESC",
        [month],
      );
    } else {
      revenues = await db.query('revenues', orderBy: 'revenue_date DESC');
    }
    
    double total = 0;
    for (final r in revenues) {
      total += (r['amount'] as num).toDouble();
    }
    
    setState(() {
      _revenues = revenues;
      _totalRevenues = total;
      _isLoading = false;
    });
  }

  Future<void> _showRevenueDialog({String? revenueId}) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final sourceController = TextEditingController();
    String selectedCategory = _categories[0];
    
    if (revenueId != null) {
      final revenue = _revenues.firstWhere((r) => r['id'] == revenueId);
      amountController.text = (revenue['amount'] as num).toString();
      descriptionController.text = revenue['description'] as String? ?? '';
      sourceController.text = revenue['source'] as String? ?? '';
      selectedCategory = revenue['category'] as String;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(revenueId != null ? 'تعديل إيراد' : 'إيراد جديد'),
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
                  TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ *'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: sourceController, decoration: const InputDecoration(labelText: 'المصدر')),
                  const SizedBox(height: 12),
                  TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'الوصف'), maxLines: 2),
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
                    'source': sourceController.text,
                    'revenue_date': now,
                    'created_at': now,
                  };
                  
                  if (revenueId != null) {
                    await db.update('revenues', data, where: 'id = ?', whereArgs: [revenueId]);
                  } else {
                    data['id'] = const Uuid().v4();
                    await db.insert('revenues', data);
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
    
    if (result == true) _loadRevenues();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإيرادات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _selectedPeriod = v);
              _loadRevenues();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text('إجمالي الإيرادات', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                          '${currencyFormatter.format(_totalRevenues)} ر.ي',
                          style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('سجل الإيرادات', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._revenues.map((revenue) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.success.withOpacity(0.1),
                        child: const Icon(Icons.trending_up, color: AppColors.success, size: 20),
                      ),
                      title: Text(revenue['category'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (revenue['source'] != null)
                            Text('المصدر: ${revenue['source']}', style: GoogleFonts.cairo(fontSize: 12)),
                          Text(revenue['revenue_date']?.toString().substring(0, 10) ?? '', style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                      trailing: Text(
                        '${currencyFormatter.format(revenue['amount'])} ر.ي',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ),
                  )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRevenueDialog(),
        backgroundColor: AppColors.success,
        child: const Icon(Icons.add),
      ),
    );
  }
}
