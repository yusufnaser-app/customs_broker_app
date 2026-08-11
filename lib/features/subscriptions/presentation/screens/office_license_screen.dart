import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class OfficeLicenseScreen extends StatefulWidget {
  const OfficeLicenseScreen({super.key});

  @override
  State<OfficeLicenseScreen> createState() => _OfficeLicenseScreenState();
}

class _OfficeLicenseScreenState extends State<OfficeLicenseScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _offices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final offices = await db.query('offices', orderBy: 'office_name ASC');

    final result = <Map<String, dynamic>>[];
    for (final office in offices) {
      final subs = await db.query('office_subscriptions', where: 'office_id = ?', whereArgs: [office['id']], limit: 1);
      result.add({
        'office': office,
        'subscription': subs.isNotEmpty ? subs.first : null,
      });
    }

    if (mounted) {
      setState(() {
        _offices = result;
        _isLoading = false;
      });
    }
  }

  String _statusLabel(Map<String, dynamic>? sub) {
    if (sub == null) return 'بدون اشتراك';
    final status = sub['status'] as String? ?? 'active';
    final endDateStr = sub['end_date'] as String?;
    if (status == 'stopped') return 'موقوف';
    if (endDateStr != null) {
      final endDate = DateTime.tryParse(endDateStr);
      if (endDate != null && DateTime.now().isAfter(endDate)) return 'منتهي';
    }
    return 'نشط';
  }

  Color _statusColor(String label) {
    switch (label) {
      case 'نشط':
        return AppColors.success;
      case 'منتهي':
        return AppColors.error;
      case 'موقوف':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _showExtendDialog(Map<String, dynamic> office, Map<String, dynamic>? sub) async {
    String selectedPlan = 'monthly';
    final planDays = {'monthly': 30, 'semi_annual': 180, 'annual': 365, 'trial': 30};
    final planLabels = {'monthly': 'شهري', 'semi_annual': 'نصف سنوي', 'annual': 'سنوي', 'trial': 'تجريبي'};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('تفعيل / تمديد اشتراك ${office['office_name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPlan,
                  decoration: const InputDecoration(labelText: 'الباقة'),
                  items: planLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedPlan = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  final db = await _dbHelper.database;
                  final now = DateTime.now();
                  final days = planDays[selectedPlan]!;
                  final newEnd = now.add(Duration(days: days)).toIso8601String();

                  if (sub != null) {
                    await db.update(
                      'office_subscriptions',
                      {
                        'plan_type': selectedPlan,
                        'start_date': now.toIso8601String(),
                        'end_date': newEnd,
                        'status': 'active',
                        'updated_at': now.toIso8601String(),
                      },
                      where: 'id = ?',
                      whereArgs: [sub['id']],
                    );
                  } else {
                    await db.insert('office_subscriptions', {
                      'id': const Uuid().v4(),
                      'office_id': office['id'],
                      'plan_type': selectedPlan,
                      'start_date': now.toIso8601String(),
                      'end_date': newEnd,
                      'status': 'active',
                      'max_users': office['max_users'] ?? 5,
                      'notes': '',
                      'created_at': now.toIso8601String(),
                      'updated_at': now.toIso8601String(),
                    });
                  }

                  if (context.mounted) Navigator.pop(context);
                  _loadOffices();
                },
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _stopSubscription(Map<String, dynamic> sub) async {
    final db = await _dbHelper.database;
    await db.update(
      'office_subscriptions',
      {'status': 'stopped', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sub['id']],
    );
    _loadOffices();
  }

  Future<void> _showOfficeDialog({Map<String, dynamic>? office}) async {
    final nameController = TextEditingController(text: office?['office_name'] as String? ?? '');
    final licenseKeyController = TextEditingController(text: office?['license_key'] as String? ?? '');
    final phoneController = TextEditingController(text: office?['phone'] as String? ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(office != null ? 'تعديل بيانات المكتب' : 'مكتب جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المكتب *'), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: licenseKeyController, decoration: const InputDecoration(labelText: 'مفتاح الترخيص *')),
            const SizedBox(height: 12),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || licenseKeyController.text.isEmpty) return;

              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();

              if (office != null) {
                await db.update(
                  'offices',
                  {
                    'office_name': nameController.text,
                    'license_key': licenseKeyController.text,
                    'phone': phoneController.text,
                    'updated_at': now,
                  },
                  where: 'id = ?',
                  whereArgs: [office['id']],
                );
              } else {
                final newId = const Uuid().v4();
                await db.insert('offices', {
                  'id': newId,
                  'office_name': nameController.text,
                  'license_key': licenseKeyController.text,
                  'license_number': '',
                  'tax_number': '',
                  'phone': phoneController.text,
                  'email': '',
                  'address': '',
                  'max_users': 5,
                  'created_at': now,
                  'updated_at': now,
                });
              }

              if (context.mounted) Navigator.pop(context);
              _loadOffices();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(title: const Text('التراخيص والاشتراكات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _offices.isEmpty
              ? Center(child: Text('لا توجد مكاتب مسجلة', style: GoogleFonts.cairo(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offices.length,
                  itemBuilder: (context, index) {
                    final entry = _offices[index];
                    final office = entry['office'] as Map<String, dynamic>;
                    final sub = entry['subscription'] as Map<String, dynamic>?;
                    final statusLabel = _statusLabel(sub);
                    final statusColor = _statusColor(statusLabel);
                    final endDateStr = sub?['end_date'] as String?;
                    final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(office['office_name'] as String, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('مفتاح الترخيص: ${office['license_key']}', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                            if (sub != null) ...[
                              Text('الباقة: ${sub['plan_type']}', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                              if (endDate != null)
                                Text('ينتهي في: ${dateFormatter.format(endDate)}', style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                            if (statusLabel == 'منتهي')
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'انتهت صلاحية اشتراك هذا المكتب. للتجديد: ${office['phone'] ?? '775477377'}',
                                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.error),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showExtendDialog(office, sub),
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('تفعيل / تمديد'),
                                ),
                                if (sub != null && statusLabel != 'موقوف')
                                  OutlinedButton.icon(
                                    onPressed: () => _stopSubscription(sub),
                                    icon: const Icon(Icons.pause_circle_outline, size: 16),
                                    label: const Text('إيقاف'),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: () => _showOfficeDialog(office: office),
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('تعديل بيانات المكتب'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showOfficeDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_business),
      ),
    );
  }
}
