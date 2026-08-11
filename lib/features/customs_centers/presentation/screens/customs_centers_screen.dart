import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class CustomsCentersScreen extends StatefulWidget {
  const CustomsCentersScreen({super.key});

  @override
  State<CustomsCentersScreen> createState() => _CustomsCentersScreenState();
}

class _CustomsCentersScreenState extends State<CustomsCentersScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _centers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    _centers = await db.query('customs_centers', orderBy: 'name ASC');
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showCenterDialog({String? centerId}) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final locationController = TextEditingController();

    if (centerId != null) {
      final center = _centers.firstWhere((c) => c['id'] == centerId);
      nameController.text = center['name'] as String;
      codeController.text = center['code'] as String? ?? '';
      locationController.text = center['location'] as String? ?? '';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(centerId != null ? 'تعديل مركز جمركي' : 'مركز جمركي جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المركز *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'الكود')),
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

              final data = {
                'name': nameController.text,
                'code': codeController.text,
                'location': locationController.text,
              };

              if (centerId != null) {
                await db.update('customs_centers', data, where: 'id = ?', whereArgs: [centerId]);
              } else {
                await db.insert('customs_centers', {
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

    if (result == true) _loadCenters();
  }

  Future<void> _deleteCenter(String id) async {
    final db = await _dbHelper.database;
    await db.delete('customs_centers', where: 'id = ?', whereArgs: [id]);
    _loadCenters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المراكز الجمركية')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _centers.isEmpty
              ? Center(child: Text('لا توجد مراكز جمركية', style: GoogleFonts.cairo(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _centers.length,
                  itemBuilder: (context, index) {
                    final center = _centers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.location_on, color: AppColors.primary),
                        ),
                        title: Text(center['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                        subtitle: Text('الكود: ${center['code'] ?? '-'} | ${center['location'] ?? '-'}'),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                            const PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') _showCenterDialog(centerId: center['id'] as String);
                            if (v == 'delete') _deleteCenter(center['id'] as String);
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCenterDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
