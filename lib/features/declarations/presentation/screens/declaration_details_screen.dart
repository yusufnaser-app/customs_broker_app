import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/hs_code_fee_engine.dart';
import '../../domain/entities/declaration.dart';
import '../../domain/entities/declaration_item.dart';
import 'declaration_form_screen.dart';
import '../../../documents/presentation/screens/advanced_documents_screen.dart';
import '../../../../core/utils/declaration_pdf_generator.dart';
import 'package:share_plus/share_plus.dart';

class DeclarationDetailsScreen extends StatefulWidget {
  final String declarationId;

  const DeclarationDetailsScreen({super.key, required this.declarationId});

  @override
  State<DeclarationDetailsScreen> createState() => _DeclarationDetailsScreenState();
}

class _DeclarationDetailsScreenState extends State<DeclarationDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Declaration? _declaration;
  List<DeclarationItem> _items = [];
  DeclarationFeeResult? _feeResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = await _dbHelper.database;

      // تحميل الإقرار
      final declarations = await db.rawQuery('''
        SELECT d.*, c.name as client_name, t.name as trader_name, s.name as supplier_name
        FROM declarations d
        LEFT JOIN clients c ON d.client_id = c.id
        LEFT JOIN traders t ON d.trader_id = t.id
        LEFT JOIN suppliers s ON d.supplier_id = s.id
        WHERE d.id = ?
      ''', [widget.declarationId]);

      if (declarations.isNotEmpty) {
        final declaration = Declaration.fromMap(
          declarations.first,
          clientName: declarations.first['client_name'] as String?,
          traderName: declarations.first['trader_name'] as String?,
          supplierName: declarations.first['supplier_name'] as String?,
        );

        // تحميل الأصناف
        final itemsResult = await db.query(
          'declaration_items',
          where: 'declaration_id = ?',
          whereArgs: [widget.declarationId],
        );

        final items = itemsResult.map((item) => DeclarationItem.fromMap(item)).toList();

        // حساب الرسوم لكل صنف حسب HS Code
        final engine = HsCodeFeeEngine(db);
        final itemMaps = items.map((item) => {
          'item_value': item.value,
          'hs_code': item.hsCode,
          'package_type': item.packageType,
        }).toList();

        final feeResult = await engine.calculateDeclarationFees(
          items: itemMaps,
          exchangeRate: declaration.exchangeRate,
        );

        setState(() {
          _declaration = declaration;
          _items = items;
          _feeResult = feeResult;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Map<String, dynamic> _feeResultToJson(DeclarationFeeResult r) {
    return {
      'exchangeRate': r.exchangeRate,
      'invoiceValueUsd': r.totalInvoiceUsd,
      'invoiceValueYer': r.totalInvoiceYer,
      'relativeFees': r.mergedPercentageFees.map((f) => f.toJson()).toList(),
      'fixedFees': r.mergedFixedFees.map((f) => f.toJson()).toList(),
      'totalRelativeFees': r.grandTotalPercentage,
      'totalFixedFees': r.grandTotalFixed,
      'grandTotal': r.grandTotal,
    };
  }

  Future<void> _printDeclaration(Declaration declaration) async {
    if (_feeResult == null) return;

    final db = await _dbHelper.database;

    final officeRows = await db.query('office_settings', limit: 1);
    final office = officeRows.isNotEmpty
        ? officeRows.first
        : <String, dynamic>{'office_name': 'مكتب التخليص الجمركي'};

    final declRows = await db.query('declarations', where: 'id = ?', whereArgs: [declaration.id]);
    final declarationMap = declRows.isNotEmpty ? declRows.first : <String, dynamic>{};

    final itemMaps = await db.query('declaration_items', where: 'declaration_id = ?', whereArgs: [declaration.id]);

    try {
      final file = await DeclarationPdfGenerator.generate(
        office: office,
        declaration: declarationMap,
        items: itemMaps,
        feeBreakdownJson: _feeResultToJson(_feeResult!),
        representativeName: declarationMap['representative_name'] as String?,
        approvalDate: declaration.status == 'completed'
            ? (declarationMap['updated_at'] as String?)?.split('T').first
            : null,
      );

      await Share.shareXFiles([XFile(file.path)], text: 'إقرار جمركي ${declaration.declarationNumber}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنشاء ملف PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddItemDialog(dbHelper: _dbHelper),
    );

    if (result != null) {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final itemValue = double.tryParse(result['value']!) ?? 0;
      final exchangeRate = _declaration?.exchangeRate ?? 1250;

      await db.insert('declaration_items', {
        'id': const Uuid().v4(),
        'declaration_id': widget.declarationId,
        'hs_code': result['hs_code']!,
        'item_name': result['item_name']!,
        'description': result['description'] ?? '',
        'quantity': double.tryParse(result['quantity']!) ?? 0,
        'weight': double.tryParse(result['weight'] ?? '0'),
        'unit': result['unit']!,
        'value': itemValue,
        'origin_country': result['origin_country'] ?? '',
        'package_type': result['package_type'],
        'packages_count': int.tryParse(result['packages_count'] ?? ''),
        'gross_weight': double.tryParse(result['gross_weight'] ?? ''),
        'net_weight': double.tryParse(result['net_weight'] ?? ''),
        'local_value': itemValue * exchangeRate,
        'created_at': now,
      });

      // تحديث مجاميع الإقرار
      final allItems = await db.query('declaration_items',
          where: 'declaration_id = ?', whereArgs: [widget.declarationId]);
      int totalPackages = 0;
      double totalGrossWeight = 0;
      double totalNetWeight = 0;
      for (final item in allItems) {
        totalPackages += (item['packages_count'] as int?) ?? 0;
        totalGrossWeight += (item['gross_weight'] as num?)?.toDouble() ?? 0;
        totalNetWeight += (item['net_weight'] as num?)?.toDouble() ?? 0;
      }

      await db.update(
        'declarations',
        {
          'items_count': allItems.length,
          'total_packages': totalPackages,
          'total_gross_weight': totalGrossWeight,
          'total_net_weight': totalNetWeight,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [widget.declarationId],
      );

      _loadData();
    }
  }

  Future<void> _confirmDeclaration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإقرار'),
        content: const Text('هل أنت متأكد من اعتماد هذا الإقرار؟ سيتم حفظ نسخة تاريخية من الرسوم ولن تتغير مستقبلاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );

    if (confirm == true && _declaration != null && _feeResult != null) {
      final db = await _dbHelper.database;
      final engine = HsCodeFeeEngine(db);
      final now = DateTime.now().toIso8601String();

      // حفظ نسخة تاريخية
      await db.insert('declaration_snapshots', {
        'id': 'snap-${_declaration!.id}-${DateTime.now().millisecondsSinceEpoch}',
        'declaration_id': _declaration!.id,
        'exchange_rate': _feeResult!.exchangeRate,
        'fees_breakdown': jsonEncode(_feeResultToJson(_feeResult!)),
        'total_fees': _feeResult!.grandTotal,
        'snapshot_date': now,
      });

      // حفظ قواعد رسوم لكل HS Code
      for (final itemResult in _feeResult!.itemResults) {
        if (itemResult.hsCode.isEmpty) continue;
        await engine.saveHsCodeFeeRules(
          hsCode: itemResult.hsCode,
          percentageRules: itemResult.percentageFees.map((f) => {
            'code': f.feeCode,
            'name': f.feeName,
            'rate': f.rate,
            'basis': f.calculationBasis,
          }).toList(),
          fixedRules: itemResult.fixedFees.map((f) => {
            'code': f.feeCode,
            'name': f.feeName,
            'amount': f.fixedAmount,
          }).toList(),
        );
      }

      await db.update(
        'declarations',
        {'status': 'completed', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [widget.declarationId],
      );

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد الإقرار بنجاح'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الإقرار')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_declaration == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الإقرار')),
        body: const Center(child: Text('الإقرار غير موجود')),
      );
    }

    final declaration = _declaration!;
    final currencyFormatter = NumberFormat('#,##0.00');

    return Scaffold(
      appBar: AppBar(
        title: Text('إقرار #${declaration.declarationNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'طباعة الإقرار',
            onPressed: _feeResult != null ? () => _printDeclaration(declaration) : null,
          ),
          IconButton(
            icon: const Icon(Icons.attach_file_rounded),
            tooltip: 'المرفقات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedDocumentsScreen(declarationId: declaration.id),
                ),
              );
            },
          ),
          if (declaration.status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeclarationFormScreen(declarationId: declaration.id),
                  ),
                );
                if (result == true) _loadData();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // حالة الإقرار
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'حالة الإقرار: ${declaration.status == 'draft' ? 'مسودة' : declaration.status == 'completed' ? 'مكتمل' : declaration.status}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // معلومات أساسية
            _buildDetailCard('معلومات الإقرار', [
              _buildDetailRow('رقم الإقرار', declaration.declarationNumber),
              _buildDetailRow('رقم البيان', declaration.statementNumber ?? '-'),
              _buildDetailRow('تاريخ البيان', declaration.statementDate ?? '-'),
              _buildDetailRow('نوع البيان', declaration.statementType ?? '-'),
              _buildDetailRow('المركز الجمركي', declaration.customsCenter ?? declaration.customsCenterName ?? '-'),
              _buildDetailRow('المندوب', declaration.representativeName ?? '-'),
            ]),
            const SizedBox(height: 16),

            _buildDetailCard('معلومات العميل والمستورد', [
              _buildDetailRow('العميل', declaration.clientName ?? '-'),
              _buildDetailRow('المستورد / المرسل إليه', declaration.traderName ?? '-'),
              _buildDetailRow('المورد', declaration.supplierName ?? '-'),
            ]),
            const SizedBox(height: 16),

            _buildDetailCard('معلومات الشحن والفاتورة', [
              _buildDetailRow('بلد المنشأ', declaration.originCountry ?? '-'),
              _buildDetailRow('بلد التصدير', declaration.exportCountry ?? '-'),
              _buildDetailRow('وسيلة النقل', declaration.transportMethod ?? '-'),
              _buildDetailRow('اسم السفينة', declaration.vesselName ?? '-'),
              _buildDetailRow('رقم الحاوية', declaration.containerNumber ?? '-'),
              _buildDetailRow('رقم الفاتورة', declaration.invoiceNumber ?? '-'),
              _buildDetailRow('تاريخ الفاتورة', declaration.invoiceDate ?? '-'),
              _buildDetailRow('قيمة الفاتورة', '${currencyFormatter.format(declaration.invoiceValueUsd)} ${declaration.currency}'),
              _buildDetailRow('سعر الصرف', '${currencyFormatter.format(declaration.exchangeRate)} ريال'),
            ]),
            const SizedBox(height: 16),

            // الأصناف
            _buildItemsSection(),
            const SizedBox(height: 16),

            // كشف الرسوم
            if (_feeResult != null) ...[
              _buildFeesSection(),
              const SizedBox(height: 24),
            ],

            // أزرار الإجراءات
            if (declaration.status == 'draft') ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _confirmDeclaration,
                  icon: const Icon(Icons.check_circle),
                  label: Text('اعتماد الإقرار', style: GoogleFonts.cairo(fontSize: 18)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text('$label:', style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الأصناف (${_items.length})',
                    style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (_declaration?.status == 'draft')
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة صنف'),
                  ),
              ],
            ),
            const Divider(),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('لا توجد أصناف مضافة', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ..._items.map((item) => _buildItemCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(DeclarationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(item.itemName, style: GoogleFonts.cairo(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.hsCode, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _buildItemDetail('الكمية', '${item.quantity} ${item.unit}'),
              _buildItemDetail('القيمة', '${NumberFormat('#,##0.00').format(item.value)} \$'),
              if (item.packageType != null)
                _buildItemDetail('نوع الطرد', item.packageType!),
              if (item.packagesCount != null && item.packagesCount! > 0)
                _buildItemDetail('عدد الطرود', '${item.packagesCount}'),
              if (item.grossWeight != null && item.grossWeight! > 0)
                _buildItemDetail('الوزن القائم', '${item.grossWeight} كجم'),
              if (item.netWeight != null && item.netWeight! > 0)
                _buildItemDetail('الوزن الصافي', '${item.netWeight} كجم'),
              if (item.localValue != null && item.localValue! > 0)
                _buildItemDetail('قاعدة الاحتساب', '${NumberFormat('#,##0').format(item.localValue)} ر.ي'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetail(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFeesSection() {
    final fees = _feeResult!;
    final currencyFormatter = NumberFormat('#,##0');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('كشف الرسوم الجمركية',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(),

            _buildFeesRow('قيمة الفاتورة (ريال)', '${currencyFormatter.format(fees.totalInvoiceYer)} ر.ي'),
            const SizedBox(height: 10),

            // عرض رسوم كل صنف
            ...fees.itemResults.map((itemResult) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HS Code: ${itemResult.hsCode} | القيمة: ${currencyFormatter.format(itemResult.itemValueYer)} ر.ي',
                        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...itemResult.percentageFees.map((fee) => _buildFeesRow(
                      '  ${fee.feeName} (${fee.rate}%)',
                      '${currencyFormatter.format(fee.calculatedAmount)} ر.ي',
                    )),
                    ...itemResult.fixedFees.map((fee) => _buildFeesRow(
                      '  ${fee.feeName}',
                      '${currencyFormatter.format(fee.calculatedAmount)} ر.ي',
                    )),
                    _buildFeesRow('  إجمالي الصنف', '${currencyFormatter.format(itemResult.totalFees)} ر.ي', bold: true),
                  ],
                ),
              );
            }),

            const Divider(thickness: 2),
            const SizedBox(height: 4),

            _buildFeesRow('إجمالي الرسوم النسبية', '${currencyFormatter.format(fees.grandTotalPercentage)} ر.ي', bold: true),
            _buildFeesRow('إجمالي الرسوم الثابتة', '${currencyFormatter.format(fees.grandTotalFixed)} ر.ي', bold: true),
            _buildFeesRow('الإجمالي الكلي', '${currencyFormatter.format(fees.grandTotal)} ر.ي',
                bold: true, color: AppColors.primary, large: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFeesRow(String label, String value, {bool bold = false, Color? color, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.cairo(
                    fontSize: large ? 16 : 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(value,
              style: GoogleFonts.cairo(
                  fontSize: large ? 16 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}

// ============ حوار إضافة صنف ============
class _AddItemDialog extends StatefulWidget {
  final DatabaseHelper dbHelper;

  const _AddItemDialog({required this.dbHelper});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _hsCodeController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _weightController = TextEditingController();
  final _packagesCountController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _netWeightController = TextEditingController();
  final _valueController = TextEditingController();
  String _selectedUnit = 'قطعة';
  String _selectedOriginCountry = 'اليمن';
  String _selectedPackageType = 'كرتون';
  List<Map<String, dynamic>> _tariffSearchResults = [];

  final List<String> _units = ['قطعة', 'كيلوجرام', 'طن', 'متر', 'لتر', 'كرتون', 'صندوق', 'بالة'];
  final List<String> _countries = ['اليمن', 'السعودية', 'الإمارات', 'الصين', 'الهند', 'تركيا'];
  final List<String> _packageTypes = ['كرتون', 'بالة', 'صندوق', 'برميل', 'كيس', 'طرد سائب', 'حاوية'];

  Future<void> _searchTariff(String query) async {
    if (query.length < 2) {
      setState(() => _tariffSearchResults = []);
      return;
    }

    final db = await widget.dbHelper.database;

    // البحث في جدول التعرفة الجديد أولاً
    var results = await db.query(
      'tariff_items',
      where: 'code LIKE ? OR name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 10,
    );

    // إذا لم توجد نتائج، ابحث في الجدول القديم
    if (results.isEmpty) {
      results = await db.query(
        'tariff',
        where: 'hs_code LIKE ? OR item_name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        limit: 10,
      );
    }

    setState(() => _tariffSearchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة صنف جديد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _hsCodeController,
                decoration: const InputDecoration(labelText: 'رمز التعرفة HS Code *'),
                onChanged: _searchTariff,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              if (_tariffSearchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tariffSearchResults.length,
                    itemBuilder: (context, index) {
                      final item = _tariffSearchResults[index];
                      final name = item['name'] as String? ?? item['item_name'] as String? ?? '';
                      final code = item['code'] as String? ?? item['hs_code'] as String? ?? '';
                      return ListTile(
                        dense: true,
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(code, style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          _itemNameController.text = name;
                          _hsCodeController.text = code;
                          setState(() => _tariffSearchResults = []);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(labelText: 'اسم الصنف *'),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(labelText: 'الكمية *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'الوحدة'),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _selectedUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPackageType,
                      decoration: const InputDecoration(labelText: 'نوع الطرد'),
                      items: _packageTypes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => _selectedPackageType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _packagesCountController,
                      decoration: const InputDecoration(labelText: 'عدد الطرود'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _grossWeightController,
                      decoration: const InputDecoration(labelText: 'الوزن القائم (كجم)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _netWeightController,
                      decoration: const InputDecoration(labelText: 'الوزن الصافي (كجم)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(labelText: 'القيمة (\$) *'),
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedOriginCountry,
                decoration: const InputDecoration(labelText: 'بلد المنشأ'),
                items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedOriginCountry = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'hs_code': _hsCodeController.text,
                'item_name': _itemNameController.text,
                'description': _descriptionController.text,
                'quantity': _quantityController.text,
                'weight': _weightController.text,
                'unit': _selectedUnit,
                'value': _valueController.text,
                'origin_country': _selectedOriginCountry,
                'package_type': _selectedPackageType,
                'packages_count': _packagesCountController.text,
                'gross_weight': _grossWeightController.text,
                'net_weight': _netWeightController.text,
              });
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hsCodeController.dispose();
    _itemNameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _packagesCountController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _valueController.dispose();
    super.dispose();
  }
}
