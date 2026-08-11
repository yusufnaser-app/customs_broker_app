import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../core/utils/excel_generator.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isGenerating = false;
  String _generatingReport = '';

  Future<void> _generateReport(String type, String format) async {
    setState(() {
      _isGenerating = true;
      _generatingReport = type;
    });
    
    try {
      final db = await _dbHelper.database;
      
      if (type == 'declarations') {
        final declarations = await db.rawQuery('''
          SELECT d.*, c.name as client_name FROM declarations d
          LEFT JOIN clients c ON d.client_id = c.id
          ORDER BY d.created_at DESC
        ''');
        
        if (format == 'pdf') {
          final file = await PdfGenerator.generateDeclarationReport({
            'summary': {
              'count': declarations.length,
              'completed': declarations.where((d) => d['status'] == 'completed').length,
              'processing': declarations.where((d) => d['status'] == 'processing').length,
              'total_value': declarations.fold<double>(0, (sum, d) => sum + ((d['invoice_value_usd'] as num?)?.toDouble() ?? 0)),
            },
            'declarations': declarations,
          });
          await PdfGenerator.sharePdf(file);
        } else {
          final file = await ExcelGenerator.generateDeclarationsExcel(declarations);
          await ExcelGenerator.shareExcel(file);
        }
      } else if (type == 'financial') {
        final revenues = await db.query('revenues', orderBy: 'revenue_date DESC');
        final expenses = await db.query('expenses', orderBy: 'expense_date DESC');
        final totalRevenues = revenues.fold<double>(0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
        final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));
        
        if (format == 'pdf') {
          final file = await PdfGenerator.generateFinancialReport({
            'total_revenues': totalRevenues,
            'total_expenses': totalExpenses,
            'revenues': revenues,
            'expenses': expenses,
          });
          await PdfGenerator.sharePdf(file);
        } else {
          final file = await ExcelGenerator.generateFinancialExcel(revenues: revenues, expenses: expenses);
          await ExcelGenerator.shareExcel(file);
        }
      } else if (type == 'fund') {
        final transactions = await db.query('fund_transactions', orderBy: 'transaction_date DESC');
        final incomeTotal = transactions.where((t) => t['type'] == 'income').fold<double>(0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
        final expenseTotal = transactions.where((t) => t['type'] == 'expense').fold<double>(0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0));
        
        final file = await PdfGenerator.generateFundReport({
          'date': DateTime.now().toString().substring(0, 10),
          'opening_balance': 0,
          'closing_balance': incomeTotal - expenseTotal,
          'transactions': transactions,
        });
        await PdfGenerator.sharePdf(file);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء التقرير بنجاح'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() {
        _isGenerating = false;
        _generatingReport = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = [
      {'title': 'تقرير الإقرارات', 'icon': Icons.description, 'type': 'declarations', 'color': AppColors.info},
      {'title': 'تقرير العملاء', 'icon': Icons.people, 'type': 'clients', 'color': AppColors.success},
      {'title': 'التقرير المالي', 'icon': Icons.account_balance, 'type': 'financial', 'color': AppColors.primary},
      {'title': 'تقرير الصندوق', 'icon': Icons.monetization_on, 'type': 'fund', 'color': AppColors.warning},
      {'title': 'تقرير البنوك', 'icon': Icons.account_balance_wallet, 'type': 'banks', 'color': AppColors.accent},
      {'title': 'تقرير الديون', 'icon': Icons.money_off, 'type': 'debts', 'color': AppColors.error},
      {'title': 'تقرير التحصيل', 'icon': Icons.payments, 'type': 'collection', 'color': AppColors.success},
      {'title': 'تقرير النشاط اليومي', 'icon': Icons.today, 'type': 'daily', 'color': AppColors.info},
    ];
    
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: reports.map((report) {
          final isGeneratingThis = _isGenerating && _generatingReport == report['type'];
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: (report['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(report['icon'] as IconData, color: report['color'] as Color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          report['title'] as String,
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isGeneratingThis ? null : () => _generateReport(report['type'] as String, 'pdf'),
                          icon: isGeneratingThis
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(isGeneratingThis ? 'جاري...' : 'PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.1),
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isGeneratingThis ? null : () => _generateReport(report['type'] as String, 'excel'),
                          icon: isGeneratingThis
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.table_chart, size: 18),
                          label: Text(isGeneratingThis ? 'جاري...' : 'Excel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success.withOpacity(0.1),
                            foregroundColor: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
