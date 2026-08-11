import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/utils/subscription_guard.dart';

class DeclarationFormScreen extends StatefulWidget {
  final String? declarationId;

  const DeclarationFormScreen({super.key, this.declarationId});

  @override
  State<DeclarationFormScreen> createState() => _DeclarationFormScreenState();
}

class _DeclarationFormScreenState extends State<DeclarationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  // Controllers
  final _declarationNumberController = TextEditingController();
  final _statementNumberController = TextEditingController();
  final _statementDateController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _invoiceDateController = TextEditingController();
  final _invoiceValueController = TextEditingController();
  final _exchangeRateController = TextEditingController(text: '1250');
  final _containerNumberController = TextEditingController();
  final _vesselNameController = TextEditingController();
  final _notesController = TextEditingController();

  // Dropdown values
  String? _selectedClientId;
  String? _selectedTraderId;
  String? _selectedSupplierId;
  String? _selectedCustomsCenterId;
  String? _selectedRepresentativeId;
  String _selectedStatementType = 'استيراد';
  String _selectedOriginCountry = 'اليمن';
  String _selectedExportCountry = 'الصين';
  String _selectedTransportMethod = 'بحري';
  String _selectedCurrency = 'USD';

  // Lists for dropdowns
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _traders = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _customsCenters = [];
  List<Map<String, dynamic>> _representatives = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _statementTypes = ['استيراد', 'تصدير', 'ترانزيت', 'إعادة تصدير'];
  final List<String> _countries = ['اليمن', 'السعودية', 'الإمارات', 'الصين', 'الهند', 'تركيا', 'مصر', 'الأردن', 'عمان', 'الكويت'];
  final List<String> _transportMethods = ['بحري', 'جوي', 'بري'];
  final List<String> _currencies = ['USD', 'EUR', 'SAR', 'AED'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = await _dbHelper.database;

    final clientsResult = await db.query('clients', where: 'is_archived = 0');
    final tradersResult = await db.query('traders');
    final suppliersResult = await db.query('suppliers');
    final centersResult = await db.query('customs_centers', where: 'is_active = 1', orderBy: 'name ASC');
    final representativesResult = await db.query('representatives', where: 'is_active = 1', orderBy: 'name ASC');

    _clients = clientsResult;
    _traders = tradersResult;
    _suppliers = suppliersResult;
    _customsCenters = centersResult;
    _representatives = representativesResult;

    if (widget.declarationId != null) {
      await _loadExistingDeclaration(db);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // تحميل بيانات الإقرار الموجود عند التعديل، بدل ترك النموذج فارغًا
  Future<void> _loadExistingDeclaration(dynamic db) async {
    final rows = await db.query('declarations', where: 'id = ?', whereArgs: [widget.declarationId]);
    if (rows.isEmpty) return;

    final d = rows.first as Map<String, dynamic>;

    _declarationNumberController.text = d['declaration_number'] as String? ?? '';
    _statementNumberController.text = d['statement_number'] as String? ?? '';
    _statementDateController.text = d['statement_date'] as String? ?? '';
    _invoiceNumberController.text = d['invoice_number'] as String? ?? '';
    _invoiceDateController.text = d['invoice_date'] as String? ?? '';
    _invoiceValueController.text = (d['invoice_value_usd'] as num?)?.toString() ?? '';
    _exchangeRateController.text = (d['exchange_rate'] as num?)?.toString() ?? '1250';
    _containerNumberController.text = d['container_number'] as String? ?? '';
    _vesselNameController.text = d['vessel_name'] as String? ?? '';
    _notesController.text = d['notes'] as String? ?? '';

    _selectedStatementType = (d['statement_type'] as String?)?.isNotEmpty == true ? d['statement_type'] as String : _selectedStatementType;
    _selectedClientId = d['client_id'] as String?;
    _selectedTraderId = d['trader_id'] as String?;
    _selectedSupplierId = d['supplier_id'] as String?;
    _selectedCustomsCenterId = d['customs_center_id'] as String?;
    _selectedRepresentativeId = d['representative_id'] as String?;
    _selectedOriginCountry = (d['origin_country'] as String?)?.isNotEmpty == true ? d['origin_country'] as String : _selectedOriginCountry;
    _selectedExportCountry = (d['export_country'] as String?)?.isNotEmpty == true ? d['export_country'] as String : _selectedExportCountry;
    _selectedTransportMethod = (d['transport_method'] as String?)?.isNotEmpty == true ? d['transport_method'] as String : _selectedTransportMethod;
    _selectedCurrency = (d['currency'] as String?)?.isNotEmpty == true ? d['currency'] as String : _selectedCurrency;

    // إن كان المركز الجمركي المحفوظ لم يعد ضمن القائمة المفعّلة (تم تعطيله أو حذفه)، لا نترك قيمة يتيمة تكسر القائمة
    if (_selectedCustomsCenterId != null && !_customsCenters.any((c) => c['id'] == _selectedCustomsCenterId)) {
      _selectedCustomsCenterId = null;
    }
    if (_selectedTraderId != null && !_traders.any((t) => t['id'] == _selectedTraderId)) {
      _selectedTraderId = null;
    }
    if (_selectedSupplierId != null && !_suppliers.any((s) => s['id'] == _selectedSupplierId)) {
      _selectedSupplierId = null;
    }
    if (_selectedRepresentativeId != null && !_representatives.any((r) => r['id'] == _selectedRepresentativeId)) {
      _selectedRepresentativeId = null;
    }
  }

  Future<void> _saveDeclaration() async {
    if (!_formKey.currentState!.validate()) return;

    final canProceed = await SubscriptionGuard.ensureActiveOrWarn(context);
    if (!canProceed || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final id = widget.declarationId ?? _uuid.v4();

      String? centerName;
      if (_selectedCustomsCenterId != null) {
        final match = _customsCenters.firstWhere(
          (c) => c['id'] == _selectedCustomsCenterId,
          orElse: () => <String, dynamic>{},
        );
        centerName = match['name'] as String?;
      }

      String? representativeName;
      if (_selectedRepresentativeId != null) {
        final match = _representatives.firstWhere(
          (r) => r['id'] == _selectedRepresentativeId,
          orElse: () => <String, dynamic>{},
        );
        representativeName = match['name'] as String?;
      }

      final declarationData = {
        'id': id,
        'declaration_number': _declarationNumberController.text,
        'statement_number': _statementNumberController.text,
        'statement_date': _statementDateController.text,
        'statement_type': _selectedStatementType,
        'customs_center': centerName,
        'customs_center_id': _selectedCustomsCenterId,
        'customs_center_name': centerName,
        'representative_id': _selectedRepresentativeId,
        'representative_name': representativeName,
        'vessel_name': _vesselNameController.text,
        'client_id': _selectedClientId,
        'trader_id': _selectedTraderId,
        'supplier_id': _selectedSupplierId,
        'origin_country': _selectedOriginCountry,
        'export_country': _selectedExportCountry,
        'transport_method': _selectedTransportMethod,
        'container_number': _containerNumberController.text,
        'invoice_number': _invoiceNumberController.text,
        'invoice_date': _invoiceDateController.text,
        'invoice_value_usd': double.tryParse(_invoiceValueController.text) ?? 0,
        'currency': _selectedCurrency,
        'exchange_rate': double.tryParse(_exchangeRateController.text) ?? 1250,
        'notes': _notesController.text,
        'updated_at': now,
      };

      if (widget.declarationId != null) {
        await db.update('declarations', declarationData, where: 'id = ?', whereArgs: [widget.declarationId]);
      } else {
        await db.insert('declarations', {
          ...declarationData,
          'items_count': 0,
          'status': 'draft',
          'created_at': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الإقرار بنجاح'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // إضافة سريعة لمركز جمركي جديد دون مغادرة نموذج الإقرار
  Future<void> _quickAddCustomsCenter() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مركز جمركي جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المركز *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'الموقع')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();
              final newId = _uuid.v4();
              await db.insert('customs_centers', {
                'id': newId,
                'name': nameController.text,
                'code': null,
                'location': locationController.text,
                'is_active': 1,
                'created_at': now,
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = await _dbHelper.database;
      final centersResult = await db.query('customs_centers', where: 'is_active = 1', orderBy: 'name ASC');
      setState(() {
        _customsCenters = centersResult;
        // اختيار آخر مركز تمت إضافته تلقائيًا
        if (_customsCenters.isNotEmpty) {
          _selectedCustomsCenterId = _customsCenters.last['id'] as String;
        }
      });
    }
  }

  // إضافة سريعة لمستورد (مرسل إليه) جديد
  Future<void> _quickAddTrader() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مستورد / مرسل إليه جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();
              await db.insert('traders', {
                'id': _uuid.v4(),
                'name': nameController.text,
                'phone': phoneController.text,
                'email': '',
                'address': '',
                'tax_number': '',
                'commercial_register': '',
                'created_at': now,
                'updated_at': now,
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = await _dbHelper.database;
      final tradersResult = await db.query('traders');
      setState(() {
        _traders = tradersResult;
        if (_traders.isNotEmpty) {
          _selectedTraderId = _traders.last['id'] as String;
        }
      });
    }
  }

  // إضافة سريعة لمورد جديد
  Future<void> _quickAddSupplier() async {
    final nameController = TextEditingController();
    final countryController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مورد جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المورد *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: countryController, decoration: const InputDecoration(labelText: 'الدولة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();
              await db.insert('suppliers', {
                'id': _uuid.v4(),
                'name': nameController.text,
                'country': countryController.text,
                'phone': '',
                'email': '',
                'address': '',
                'created_at': now,
                'updated_at': now,
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) {
      final db = await _dbHelper.database;
      final suppliersResult = await db.query('suppliers');
      setState(() {
        _suppliers = suppliersResult;
        if (_suppliers.isNotEmpty) {
          _selectedSupplierId = _suppliers.last['id'] as String;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.declarationId != null ? 'تعديل إقرار' : 'إقرار جديد'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('معلومات الإقرار'),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الإقرار', _declarationNumberController, required: true),
                    const SizedBox(height: 12),
                    _buildTextField('رقم البيان', _statementNumberController),
                    const SizedBox(height: 12),
                    _buildDateField('تاريخ البيان', _statementDateController),
                    const SizedBox(height: 12),
                    _buildDropdown('نوع البيان', _selectedStatementType, _statementTypes, (val) => setState(() => _selectedStatementType = val!)),
                    const SizedBox(height: 12),
                    _buildCustomsCenterDropdown(),
                    const SizedBox(height: 12),
                    _buildRepresentativeDropdown(),

                    const SizedBox(height: 24),
                    _buildSectionTitle('معلومات العميل والمستورد'),
                    const SizedBox(height: 12),
                    _buildClientDropdown(),
                    const SizedBox(height: 12),
                    _buildTraderDropdown(),
                    const SizedBox(height: 12),
                    _buildSupplierDropdown(),

                    const SizedBox(height: 24),
                    _buildSectionTitle('معلومات الشحن والفاتورة'),
                    const SizedBox(height: 12),
                    _buildDropdown('بلد المنشأ', _selectedOriginCountry, _countries, (val) => setState(() => _selectedOriginCountry = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('بلد التصدير', _selectedExportCountry, _countries, (val) => setState(() => _selectedExportCountry = val!)),
                    const SizedBox(height: 12),
                    _buildDropdown('وسيلة النقل', _selectedTransportMethod, _transportMethods, (val) => setState(() => _selectedTransportMethod = val!)),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الحاوية / الشاحنة', _containerNumberController),
                    const SizedBox(height: 12),
                    _buildTextField('اسم السفينة', _vesselNameController),
                    const SizedBox(height: 12),
                    _buildTextField('رقم الفاتورة', _invoiceNumberController),
                    const SizedBox(height: 12),
                    _buildDateField('تاريخ الفاتورة', _invoiceDateController),
                    const SizedBox(height: 12),
                    _buildTextField('قيمة الفاتورة (دولار)', _invoiceValueController, required: true, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildDropdown('العملة', _selectedCurrency, _currencies, (val) => setState(() => _selectedCurrency = val!)),
                    const SizedBox(height: 12),
                    _buildTextField('سعر الصرف', _exchangeRateController, keyboardType: TextInputType.number),

                    const SizedBox(height: 24),
                    _buildTextField('ملاحظات', _notesController, maxLines: 3),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveDeclaration,
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(widget.declarationId != null ? 'تحديث الإقرار' : 'حفظ الإقرار', style: GoogleFonts.cairo(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
      ),
      validator: required ? (value) => (value == null || value.isEmpty) ? 'هذا الحقل مطلوب' : null : null,
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCustomsCenterDropdown() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedCustomsCenterId,
            decoration: const InputDecoration(labelText: 'المركز الجمركي'),
            isExpanded: true,
            items: _customsCenters.map((center) {
              return DropdownMenuItem(
                value: center['id'] as String,
                child: Text(center['name'] as String, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCustomsCenterId = val),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppColors.primary),
          tooltip: 'إضافة مركز جديد',
          onPressed: _quickAddCustomsCenter,
        ),
      ],
    );
  }

  Widget _buildRepresentativeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRepresentativeId,
      decoration: const InputDecoration(labelText: 'المندوب'),
      isExpanded: true,
      items: [
        const DropdownMenuItem(value: null, child: Text('غير محدد')),
        ..._representatives.map((rep) {
          return DropdownMenuItem(
            value: rep['id'] as String,
            child: Text(rep['name'] as String, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (val) => setState(() => _selectedRepresentativeId = val),
    );
  }

  Widget _buildClientDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedClientId,
      decoration: const InputDecoration(labelText: 'العميل *'),
      isExpanded: true,
      items: _clients.map((client) {
        return DropdownMenuItem(
          value: client['id'] as String,
          child: Text(client['name'] as String, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedClientId = val),
      validator: (value) => value == null ? 'العميل مطلوب' : null,
    );
  }

  Widget _buildTraderDropdown() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedTraderId,
            decoration: const InputDecoration(labelText: 'المستورد / المرسل إليه'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('غير محدد')),
              ..._traders.map((trader) {
                return DropdownMenuItem(
                  value: trader['id'] as String,
                  child: Text(trader['name'] as String, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (val) => setState(() => _selectedTraderId = val),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppColors.primary),
          tooltip: 'إضافة مستورد جديد',
          onPressed: _quickAddTrader,
        ),
      ],
    );
  }

  Widget _buildSupplierDropdown() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedSupplierId,
            decoration: const InputDecoration(labelText: 'المورد'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('غير محدد')),
              ..._suppliers.map((supplier) {
                return DropdownMenuItem(
                  value: supplier['id'] as String,
                  child: Text(supplier['name'] as String, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (val) => setState(() => _selectedSupplierId = val),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppColors.primary),
          tooltip: 'إضافة مورد جديد',
          onPressed: _quickAddSupplier,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _declarationNumberController.dispose();
    _statementNumberController.dispose();
    _statementDateController.dispose();
    _invoiceNumberController.dispose();
    _invoiceDateController.dispose();
    _invoiceValueController.dispose();
    _exchangeRateController.dispose();
    _containerNumberController.dispose();
    _vesselNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
