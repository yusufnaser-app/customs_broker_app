import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class FeeSettingsScreen extends StatefulWidget {
  const FeeSettingsScreen({super.key});

  @override
  State<FeeSettingsScreen> createState() => _FeeSettingsScreenState();
}

class _FeeSettingsScreenState extends State<FeeSettingsScreen> with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper();
  late TabController _tabController;

  List<Map<String, dynamic>> _relativeFees = [];
  List<Map<String, dynamic>> _fixedFees = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;

    _relativeFees = await db.query('relative_fees', orderBy: 'execution_order ASC');
    _fixedFees = await db.query('fixed_fees', orderBy: 'code ASC');
    _categories = await db.query('fee_categories', where: 'is_active = 1');

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showRelativeFeeDialog({String? feeId}) async {
    final rateController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedCategory;
    String selectedBase = 'invoice_value';
    final hsCodeController = TextEditingController();

    if (feeId != null) {
      final fee = _relativeFees.firstWhere((f) => f['id'] == feeId);
      rateController.text = (fee['rate'] as num).toString();
      nameController.text = fee['name'] as String;
      selectedCategory = fee['category_id'] as String?;
      selectedBase = fee['calculation_base'] as String? ?? 'invoice_value';
      hsCodeController.text = fee['hs_code_filter'] as String? ?? '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(feeId != null ? 'تعديل رسم نسبي' : 'رسم نسبي جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الرسم *')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    decoration: const InputDecoration(labelText: 'النسبة % *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBase,
                    decoration: const InputDecoration(labelText: 'أساس الاحتساب'),
                    items: const [
                      DropdownMenuItem(value: 'invoice_value', child: Text('قيمة الفاتورة')),
                      DropdownMenuItem(value: 'after_duty', child: Text('بعد الرسم الجمركي')),
                      DropdownMenuItem(value: 'after_st', child: Text('بعد ضريبة المبيعات')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedBase = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'الفئة'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('بدون فئة')),
                      ..._categories.map((c) => DropdownMenuItem<String?>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: hsCodeController, decoration: const InputDecoration(labelText: 'تحديد HS Code (اختياري)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || rateController.text.isEmpty) return;

                  final db = await _dbHelper.database;
                  final now = DateTime.now().toIso8601String();
                  final data = {
                    'name': nameController.text,
                    'rate': double.tryParse(rateController.text) ?? 0,
                    'calculation_base': selectedBase,
                    'category_id': selectedCategory,
                    'hs_code_filter': hsCodeController.text.isEmpty ? null : hsCodeController.text,
                    'effective_date': now,
                  };

                  if (feeId != null) {
                    await db.update('relative_fees', data, where: 'id = ?', whereArgs: [feeId]);
                  } else {
                    await db.insert('relative_fees', {
                      ...data,
                      'id': const Uuid().v4(),
                      'code': 'FEE${DateTime.now().millisecondsSinceEpoch}',
                      'execution_order': _relativeFees.length + 1,
                      'is_active': 1,
                      'created_at': now,
                    });
                  }

                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showFixedFeeDialog({String? feeId}) async {
    final amountController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedCategory;
    final hsCodeController = TextEditingController();

    if (feeId != null) {
      final fee = _fixedFees.firstWhere((f) => f['id'] == feeId);
      amountController.text = (fee['amount'] as num).toString();
      nameController.text = fee['name'] as String;
      selectedCategory = fee['category_id'] as String?;
      hsCodeController.text = fee['hs_code_filter'] as String? ?? '';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(feeId != null ? 'تعديل رسم ثابت' : 'رسم ثابت جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الرسم *')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'المبلغ (ريال يمني) *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'الفئة'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('بدون فئة')),
                      ..._categories.map((c) => DropdownMenuItem<String?>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategory = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: hsCodeController, decoration: const InputDecoration(labelText: 'تحديد HS Code (اختياري)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || amountController.text.isEmpty) return;

                  final db = await _dbHelper.database;
                  final now = DateTime.now().toIso8601String();
                  final data = {
                    'name': nameController.text,
                    'amount': double.tryParse(amountController.text) ?? 0,
                    'category_id': selectedCategory,
                    'hs_code_filter': hsCodeController.text.isEmpty ? null : hsCodeController.text,
                    'effective_date': now,
                  };

                  if (feeId != null) {
                    await db.update('fixed_fees', data, where: 'id = ?', whereArgs: [feeId]);
                  } else {
                    await db.insert('fixed_fees', {
                      ...data,
                      'id': const Uuid().v4(),
                      'code': 'FIX${DateTime.now().millisecondsSinceEpoch}',
                      'unit': 'YER',
                      'is_active': 1,
                      'created_at': now,
                    });
                  }

                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleFeeActive(String table, String id, int currentStatus) async {
    final db = await _dbHelper.database;
    await db.update(table, {'is_active': currentStatus == 1 ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الرسوم'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'الرسوم النسبية'),
            Tab(text: 'الرسوم الثابتة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRelativeFeesList(),
                _buildFixedFeesList(currencyFormatter),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabController.index == 0 ? _showRelativeFeeDialog() : _showFixedFeeDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRelativeFeesList() {
    if (_relativeFees.isEmpty) {
      return Center(child: Text('لا توجد رسوم نسبية', style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _relativeFees.length,
      itemBuilder: (context, index) {
        final fee = _relativeFees[index];
        final isActive = (fee['is_active'] as int?) == 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Switch(
              value: isActive,
              onChanged: (_) => _toggleFeeActive('relative_fees', fee['id'] as String, isActive ? 1 : 0),
              activeColor: AppColors.success,
            ),
            title: Text(fee['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النسبة: ${fee['rate']}% | أساس: ${fee['calculation_base']}'),
                if (fee['hs_code_filter'] != null && (fee['hs_code_filter'] as String).isNotEmpty)
                  Text('HS Code: ${fee['hs_code_filter']}', style: const TextStyle(color: AppColors.accent)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showRelativeFeeDialog(feeId: fee['id'] as String),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedFeesList(NumberFormat formatter) {
    if (_fixedFees.isEmpty) {
      return Center(child: Text('لا توجد رسوم ثابتة', style: GoogleFonts.cairo(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fixedFees.length,
      itemBuilder: (context, index) {
        final fee = _fixedFees[index];
        final isActive = (fee['is_active'] as int?) == 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Switch(
              value: isActive,
              onChanged: (_) => _toggleFeeActive('fixed_fees', fee['id'] as String, isActive ? 1 : 0),
              activeColor: AppColors.success,
            ),
            title: Text(fee['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبلغ: ${formatter.format(fee['amount'])} ${fee['unit'] ?? 'YER'}'),
                if (fee['hs_code_filter'] != null && (fee['hs_code_filter'] as String).isNotEmpty)
                  Text('HS Code: ${fee['hs_code_filter']}', style: const TextStyle(color: AppColors.accent)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showFixedFeeDialog(feeId: fee['id'] as String),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
