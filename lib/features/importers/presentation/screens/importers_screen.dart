import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

/// إدارة المستوردين (المرسل إليهم) - تُخزَّن في جدول traders الموجود مسبقًا،
/// حيث يحمل نفس الحقول المطلوبة تمامًا (الاسم، الهاتف، البريد، العنوان، الرقم الضريبي، السجل التجاري).
class ImportersScreen extends StatefulWidget {
  const ImportersScreen({super.key});

  @override
  State<ImportersScreen> createState() => _ImportersScreenState();
}

class _ImportersScreenState extends State<ImportersScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _importers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadImporters();
    _searchController.addListener(_applyFilter);
  }

  Future<void> _loadImporters() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    _importers = await db.query('traders', orderBy: 'name ASC');
    _applyFilter();
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final query = _searchController.text.trim();
    setState(() {
      _filtered = query.isEmpty
          ? _importers
          : _importers.where((i) {
              final name = (i['name'] as String? ?? '').toLowerCase();
              final phone = (i['phone'] as String? ?? '');
              return name.contains(query.toLowerCase()) || phone.contains(query);
            }).toList();
    });
  }

  Future<void> _showImporterDialog({String? importerId}) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final taxNumberController = TextEditingController();
    final commercialRegisterController = TextEditingController();

    if (importerId != null) {
      final importer = _importers.firstWhere((i) => i['id'] == importerId);
      nameController.text = importer['name'] as String? ?? '';
      phoneController.text = importer['phone'] as String? ?? '';
      emailController.text = importer['email'] as String? ?? '';
      addressController.text = importer['address'] as String? ?? '';
      taxNumberController.text = importer['tax_number'] as String? ?? '';
      commercialRegisterController.text = importer['commercial_register'] as String? ?? '';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(importerId != null ? 'تعديل مستورد' : 'مستورد جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم *'), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'العنوان')),
              const SizedBox(height: 12),
              TextField(controller: taxNumberController, decoration: const InputDecoration(labelText: 'الرقم الضريبي')),
              const SizedBox(height: 12),
              TextField(controller: commercialRegisterController, decoration: const InputDecoration(labelText: 'السجل التجاري')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();

              final data = {
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
                'tax_number': taxNumberController.text,
                'commercial_register': commercialRegisterController.text,
                'updated_at': now,
              };

              if (importerId != null) {
                await db.update('traders', data, where: 'id = ?', whereArgs: [importerId]);
              } else {
                await db.insert('traders', {
                  ...data,
                  'id': const Uuid().v4(),
                  'created_at': now,
                });
              }

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result == true) _loadImporters();
  }

  Future<void> _deleteImporter(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المستورد؟'),
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
      await db.delete('traders', where: 'id = ?', whereArgs: [id]);
      _loadImporters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستوردون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text('لا يوجد مستوردون', style: GoogleFonts.cairo(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final importer = _filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                              ),
                              title: Text(importer['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                              subtitle: Text('${importer['phone'] ?? '-'} | ${importer['tax_number'] ?? '-'}'),
                              trailing: PopupMenuButton<String>(
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                                onSelected: (v) {
                                  if (v == 'edit') _showImporterDialog(importerId: importer['id'] as String);
                                  if (v == 'delete') _deleteImporter(importer['id'] as String);
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showImporterDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
