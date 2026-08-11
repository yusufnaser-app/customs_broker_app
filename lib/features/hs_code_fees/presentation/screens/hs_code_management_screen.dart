import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/hs_code_fee_engine.dart';

class HsCodeManagementScreen extends StatefulWidget {
  const HsCodeManagementScreen({super.key});

  @override
  State<HsCodeManagementScreen> createState() => _HsCodeManagementScreenState();
}

class _HsCodeManagementScreenState extends State<HsCodeManagementScreen>
    with SingleTickerProviderStateMixin {
  final _dbHelper = DatabaseHelper();
  late HsCodeFeeEngine _engine;
  late TabController _tabController;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initEngine();
  }

  Future<void> _initEngine() async {
    final db = await _dbHelper.database;
    _engine = HsCodeFeeEngine(db);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _categories = await _engine.getHsCodeCategories();
    _rules = await _engine.getHsCodeRules();
    setState(() => _isLoading = false);
  }

  // ============ حوار إضافة/تعديل تصنيف ============
  Future<void> _showCategoryDialog({Map<String, dynamic>? category}) async {
    final codeController = TextEditingController(
      text: category?['category_code'] as String? ?? '',
    );
    final nameController = TextEditingController(
      text: category?['category_name'] as String? ?? '',
    );
    final descController = TextEditingController(
      text: category?['description'] as String? ?? '',
    );

    // رسوم نسبية مؤقتة للتصنيف
    List<Map<String, dynamic>> relativeFees = [];
    List<Map<String, dynamic>> fixedFees = [];
    
    if (category != null) {
      try {
        final relativeJson = category['default_relative_fees_json'] as String? ?? '[]';
        final fixedJson = category['default_fixed_fees_json'] as String? ?? '[]';
        relativeFees = List<Map<String, dynamic>>.from(
          List<dynamic>.from(
            relativeJson.isNotEmpty ? _parseJson(relativeJson) : [],
          ),
        );
        fixedFees = List<Map<String, dynamic>>.from(
          List<dynamic>.from(
            fixedJson.isNotEmpty ? _parseJson(fixedJson) : [],
          ),
        );
      } catch (_) {}
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              category != null ? 'تعديل تصنيف HS Code' : 'تصنيف HS Code جديد',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // كود التصنيف
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'كود التصنيف *',
                      hintText: 'أول 4 أرقام (مثال: 8471)',
                      helperText: 'مثال: 8471 لأجهزة الكمبيوتر',
                      helperStyle: GoogleFonts.cairo(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // اسم التصنيف
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم التصنيف *',
                      hintText: 'مثال: أجهزة كمبيوتر وملحقاتها',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // الوصف
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      hintText: 'وصف مختصر للتصنيف',
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),
                  
                  // ملاحظة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يمكنك تخصيص الرسوم لهذا التصنيف من شاشة إعدادات الرسوم.\n'
                            'التصنيف يطبق على كل HS Code يبدأ بهذا الكود.',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // حذف (للتعديل فقط)
              if (category != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, {'action': 'delete'}),
                  child: const Text('حذف', style: TextStyle(color: AppColors.error)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (codeController.text.trim().isEmpty ||
                      nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الكود والاسم مطلوبان')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'action': category != null ? 'edit' : 'add',
                    'category_code': codeController.text.trim(),
                    'category_name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  });
                },
                child: Text(category != null ? 'تحديث' : 'حفظ'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    if (result['action'] == 'delete' && category != null) {
      await _deleteCategory(category['category_code'] as String);
      return;
    }

    // حفظ التصنيف
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'category_code': result['category_code'] as String,
      'category_name': result['category_name'] as String,
      'description': result['description'] as String? ?? '',
      'is_active': 1,
      'created_at': now,
    };

    if (result['action'] == 'edit' && category != null) {
      await db.update(
        'hs_code_categories',
        data,
        where: 'category_code = ?',
        whereArgs: [category['category_code']],
      );
    } else {
      await db.insert('hs_code_categories', {
        ...data,
        'id': 'hscat-${result['category_code']}',
        'default_relative_fees_json': '[]',
        'default_fixed_fees_json': '[]',
      });
    }
    
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['action'] == 'edit' ? 'تم تحديث التصنيف' : 'تم إضافة التصنيف'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ============ حوار إضافة/تعديل قاعدة خاصة ============
  Future<void> _showRuleDialog({Map<String, dynamic>? rule}) async {
    final hsCodeController = TextEditingController(
      text: rule?['hs_code'] as String? ?? '',
    );
    final categoryController = TextEditingController(
      text: rule?['hs_code_category'] as String? ?? '',
    );
    final typeController = TextEditingController(
      text: rule?['item_type'] as String? ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              rule != null ? 'تعديل قاعدة خاصة' : 'قاعدة HS Code خاصة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: hsCodeController,
                    decoration: const InputDecoration(
                      labelText: 'HS Code كامل *',
                      hintText: 'مثال: 8471.30.00',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // اختيار التصنيف
                  DropdownButtonFormField<String>(
                    value: categoryController.text.isEmpty ? null : categoryController.text,
                    decoration: const InputDecoration(labelText: 'التصنيف (اختياري)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('بدون تصنيف'),
                      ),
                      ..._categories.map((c) => DropdownMenuItem<String>(
                        value: c['category_code'] as String,
                        child: Text(
                          '${c['category_code']} - ${c['category_name']}',
                          style: GoogleFonts.cairo(fontSize: 13),
                        ),
                      )),
                    ],
                    onChanged: (v) {
                      categoryController.text = v ?? '';
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'نوع الصنف',
                      hintText: 'مثال: أجهزة إلكترونية، مواد غذائية',
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه القاعدة ستطبق على HS Code هذا تحديداً.\n'
                            'إذا لم تضف قاعدة خاصة، سيستخدم التصنيف العام.',
                            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (rule != null)
                TextButton(
                  onPressed: () => Navigator.pop(context, {'action': 'delete'}),
                  child: const Text('حذف', style: TextStyle(color: AppColors.error)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (hsCodeController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('HS Code مطلوب')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'action': rule != null ? 'edit' : 'add',
                    'hs_code': hsCodeController.text.trim(),
                    'hs_code_category': categoryController.text.trim(),
                    'item_type': typeController.text.trim(),
                  });
                },
                child: Text(rule != null ? 'تحديث' : 'حفظ'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    if (result['action'] == 'delete' && rule != null) {
      await _deleteRule(rule['hs_code'] as String);
      return;
    }

    // حفظ القاعدة
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final relativeFees = await db.query('relative_fees', where: 'is_active = 1');
    final fixedFees = await db.query('fixed_fees', where: 'is_active = 1');

    await _engine.saveHsCodeRule(
      hsCode: result['hs_code'] as String,
      hsCodeCategory: result['hs_code_category'] as String,
      itemType: result['item_type'] as String,
      relativeFees: relativeFees.map((f) => FeeItem(
        code: f['code'] as String,
        name: f['name'] as String,
        type: 'relative',
        rate: (f['rate'] as num).toDouble(),
        amount: 0,
        calculationBase: f['calculation_base'] as String? ?? 'invoice_value',
      )).toList(),
      fixedFees: fixedFees.map((f) => FeeItem(
        code: f['code'] as String,
        name: f['name'] as String,
        type: 'fixed',
        rate: 0,
        amount: (f['amount'] as num).toDouble(),
        calculationBase: 'fixed',
      )).toList(),
    );
    
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['action'] == 'edit' ? 'تم تحديث القاعدة' : 'تم إضافة القاعدة'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteCategory(String categoryCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التصنيف'),
        content: Text('هل أنت متأكد من حذف التصنيف $categoryCode؟'),
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
      await db.update(
        'hs_code_categories',
        {'is_active': 0},
        where: 'category_code = ?',
        whereArgs: [categoryCode],
      );
      _loadData();
    }
  }

  Future<void> _deleteRule(String hsCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القاعدة'),
        content: Text('هل أنت متأكد من حذف القاعدة الخاصة بـ $hsCode؟'),
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
      await db.update(
        'hs_code_fee_rules',
        {'is_active': 0},
        where: 'hs_code = ?',
        whereArgs: [hsCode],
      );
      _loadData();
    }
  }

  List<dynamic> _parseJson(String json) {
    try {
      return List<dynamic>.from(json as List);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة رسوم HS Code'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'التصنيفات'),
            Tab(text: 'القواعد الخاصة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCategoriesTab(),
                _buildRulesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showCategoryDialog();
          } else {
            _showRuleDialog();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0 ? 'تصنيف جديد' : 'قاعدة جديدة',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ============ تبويب التصنيفات ============
  Widget _buildCategoriesTab() {
    if (_categories.isEmpty) {
      return _buildEmptyState(
        icon: Icons.category_outlined,
        title: 'لا توجد تصنيفات',
        subtitle: 'أضف تصنيفات HS Code لتنظيم الرسوم الجمركية\nحسب فئات البضائع المختلفة',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _showCategoryDialog(category: cat),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // كود التصنيف
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        cat['category_code'] as String? ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // المعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat['category_name'] as String? ?? '',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (cat['description'] != null && (cat['description'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              cat['description'] as String,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // أزرار
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                        onPressed: () => _showCategoryDialog(category: cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        onPressed: () => _deleteCategory(cat['category_code'] as String),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============ تبويب القواعد الخاصة ============
  Widget _buildRulesTab() {
    if (_rules.isEmpty) {
      return _buildEmptyState(
        icon: Icons.rule_outlined,
        title: 'لا توجد قواعد خاصة',
        subtitle: 'أضف قواعد رسوم مخصصة لأصناف محددة\nحسب HS Code الكامل',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rules.length,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _showRuleDialog(rule: rule),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // HS Code
                  Container(
                    width: 80,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        rule['hs_code'] as String? ?? '',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // المعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rule['hs_code_category'] != null && (rule['hs_code_category'] as String).isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'تصنيف: ${rule['hs_code_category']}',
                              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.info),
                            ),
                          ),
                        if (rule['item_type'] != null && (rule['item_type'] as String).isNotEmpty)
                          Text(
                            'النوع: ${rule['item_type']}',
                            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  
                  // أزرار
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                        onPressed: () => _showRuleDialog(rule: rule),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        onPressed: () => _deleteRule(rule['hs_code'] as String),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              if (_tabController.index == 0) {
                _showCategoryDialog();
              } else {
                _showRuleDialog();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              _tabController.index == 0 ? 'إضافة تصنيف' : 'إضافة قاعدة',
              style: GoogleFonts.cairo(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
