import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class RepresentativesScreen extends StatefulWidget {
  const RepresentativesScreen({super.key});

  @override
  State<RepresentativesScreen> createState() => _RepresentativesScreenState();
}

class _RepresentativesScreenState extends State<RepresentativesScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _representatives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRepresentatives();
  }

  Future<void> _loadRepresentatives() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    _representatives = await db.query('representatives', orderBy: 'name ASC');
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showRepDialog({String? repId}) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final idNumberController = TextEditingController();

    if (repId != null) {
      final rep = _representatives.firstWhere((r) => r['id'] == repId);
      nameController.text = rep['name'] as String;
      phoneController.text = rep['phone'] as String? ?? '';
      idNumberController.text = rep['id_number'] as String? ?? '';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(repId != null ? 'تعديل مندوب' : 'مندوب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المندوب *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: idNumberController, decoration: const InputDecoration(labelText: 'رقم الهوية')),
          ],
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
                'id_number': idNumberController.text,
              };

              if (repId != null) {
                await db.update('representatives', data, where: 'id = ?', whereArgs: [repId]);
              } else {
                await db.insert('representatives', {
                  ...data,
                  'id': const Uuid().v4(),
                  'is_active': 1,
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

    if (result == true) _loadRepresentatives();
  }

  Future<void> _deleteRep(String id) async {
    final db = await _dbHelper.database;
    await db.delete('representatives', where: 'id = ?', whereArgs: [id]);
    _loadRepresentatives();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المندوبون')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _representatives.isEmpty
              ? Center(child: Text('لا يوجد مندوبون', style: GoogleFonts.cairo(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _representatives.length,
                  itemBuilder: (context, index) {
                    final rep = _representatives[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.badge_outlined, color: AppColors.primary),
                        ),
                        title: Text(rep['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                        subtitle: Text('${rep['phone'] ?? '-'} | ${rep['id_number'] ?? '-'}'),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                            const PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') _showRepDialog(repId: rep['id'] as String);
                            if (v == 'delete') _deleteRep(rep['id'] as String);
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRepDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
