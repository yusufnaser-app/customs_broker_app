import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT i.*, c.name as client_name, d.declaration_number
      FROM invoices i
      LEFT JOIN clients c ON i.client_id = c.id
      LEFT JOIN declarations d ON i.declaration_id = d.id
      ORDER BY i.created_at DESC
    ''');
    setState(() {
      _invoices = result;
      _isLoading = false;
    });
  }

  Future<void> _showInvoiceDialog({String? invoiceId}) async {
    final db = await _dbHelper.database;
    final clients = await db.query('clients', where: 'is_archived = 0');
    final declarations = await db.query('declarations', where: 'status = ?', whereArgs: ['completed']);
    
    String? selectedClientId;
    String? selectedDeclarationId;
    final feesController = TextEditingController();
    final expensesController = TextEditingController();
    final notesController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    
    if (invoiceId != null) {
      final invoice = _invoices.firstWhere((i) => i['id'] == invoiceId);
      selectedClientId = invoice['client_id'] as String?;
      selectedDeclarationId = invoice['declaration_id'] as String?;
      feesController.text = (invoice['fees_amount'] as num?)?.toString() ?? '0';
      expensesController.text = (invoice['expenses_amount'] as num?)?.toString() ?? '0';
      notesController.text = invoice['notes'] as String? ?? '';
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final feesAmount = double.tryParse(feesController.text) ?? 0;
          final expensesAmount = double.tryParse(expensesController.text) ?? 0;
          final total = feesAmount + expensesAmount;
          
          return AlertDialog(
            title: Text(invoiceId != null ? 'تعديل فاتورة' : 'فاتورة أتعاب جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedClientId,
                    decoration: const InputDecoration(labelText: 'العميل *'),
                    items: clients.map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name'] as String),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedClientId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedDeclarationId,
                    decoration: const InputDecoration(labelText: 'الإقرار (اختياري)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('بدون إقرار')),
                      ...declarations.map((d) => DropdownMenuItem(
                        value: d['id'] as String,
                        child: Text('إقرار #${d['declaration_number']}'),
                      )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDeclarationId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feesController,
                    decoration: const InputDecoration(labelText: 'الأتعاب *'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expensesController,
                    decoration: const InputDecoration(labelText: 'النثريات'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الإجمالي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        Text(
                          '${NumberFormat('#,##0').format(total)} ر.ي',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedClientId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار العميل')));
                    return;
                  }
                  
                  final now = DateTime.now().toIso8601String();
                  final data = {
                    'client_id': selectedClientId!,
                    'declaration_id': selectedDeclarationId,
                    'fees_amount': double.tryParse(feesController.text) ?? 0,
                    'expenses_amount': double.tryParse(expensesController.text) ?? 0,
                    'total_amount': total,
                    'payment_status': 'unpaid',
                    'notes': notesController.text,
                    'updated_at': now,
                  };
                  
                  if (invoiceId != null) {
                    await db.update('invoices', data, where: 'id = ?', whereArgs: [invoiceId]);
                  } else {
                    data['id'] = const Uuid().v4();
                    final count = await db.rawQuery('SELECT COUNT(*) as count FROM invoices');
                    final nextNumber = ((count.first['count'] as int?) ?? 0) + 1;
                    data['invoice_number'] = 'INV-${DateTime.now().year}-${nextNumber.toString().padLeft(4, '0')}';
                    data['created_at'] = now;
                    await db.insert('invoices', data);
                    
                    // تحديث رصيد العميل
                    await db.rawUpdate(
                      'UPDATE clients SET balance = balance + ?, updated_at = ? WHERE id = ?',
                      [total, now, selectedClientId],
                    );
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
    
    if (result == true) _loadInvoices();
  }

  Future<void> _recordPayment(String invoiceId) async {
    final db = await _dbHelper.database;
    final invoice = _invoices.firstWhere((i) => i['id'] == invoiceId);
    final amountController = TextEditingController(text: (invoice['total_amount'] as num?)?.toString() ?? '0');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الفاتورة: ${invoice['invoice_number']}', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ *'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              
              final now = DateTime.now().toIso8601String();
              
              // تسجيل الدفعة
              await db.insert('payments', {
                'id': const Uuid().v4(),
                'client_id': invoice['client_id'],
                'invoice_id': invoiceId,
                'amount': amount,
                'payment_method': 'نقدي',
                'payment_date': now,
                'created_at': now,
              });
              
              // تحديث الفاتورة
              await db.update('invoices', {
                'payment_status': 'paid',
                'updated_at': now,
              }, where: 'id = ?', whereArgs: [invoiceId]);
              
              // تحديث رصيد العميل
              await db.rawUpdate(
                'UPDATE clients SET balance = balance - ?, updated_at = ? WHERE id = ?',
                [amount, now, invoice['client_id']],
              );
              
              // إضافة للصندوق
              await db.insert('fund_transactions', {
                'id': const Uuid().v4(),
                'type': 'income',
                'amount': amount,
                'description': 'تحصيل فاتورة ${invoice['invoice_number']}',
                'reference_type': 'invoice',
                'reference_id': invoiceId,
                'transaction_date': now,
                'created_at': now,
              });
              
              Navigator.pop(context, true);
            },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    
    if (result == true) _loadInvoices();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return AppColors.success;
      case 'unpaid': return AppColors.error;
      case 'partial': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid': return 'مدفوع';
      case 'unpaid': return 'غير مدفوع';
      case 'partial': return 'مدفوع جزئياً';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');
    
    return Scaffold(
      appBar: AppBar(title: const Text('فواتير الأتعاب')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('لا توجد فواتير', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    final status = invoice['payment_status'] as String? ?? 'unpaid';
                    final statusColor = _getStatusColor(status);
                    final statusLabel = _getStatusLabel(status);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  invoice['invoice_number'] as String? ?? '',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(statusLabel, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.person_outline, 'العميل', invoice['client_name'] as String? ?? '-'),
                            if (invoice['declaration_number'] != null)
                              _buildInfoRow(Icons.description_outlined, 'الإقرار', '#${invoice['declaration_number']}'),
                            _buildInfoRow(Icons.attach_money, 'الأتعاب', '${currencyFormatter.format(invoice['fees_amount'] ?? 0)} ر.ي'),
                            _buildInfoRow(Icons.money_off, 'النثريات', '${currencyFormatter.format(invoice['expenses_amount'] ?? 0)} ر.ي'),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الإجمالي:', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                Text(
                                  '${currencyFormatter.format(invoice['total_amount'] ?? 0)} ر.ي',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                                ),
                              ],
                            ),
                            if (status == 'unpaid') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _recordPayment(invoice['id'] as String),
                                  icon: const Icon(Icons.payment, size: 18),
                                  label: const Text('تسجيل دفعة'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInvoiceDialog(),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
