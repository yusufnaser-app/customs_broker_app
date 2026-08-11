import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class ClientsListScreen extends StatefulWidget {
  const ClientsListScreen({super.key});

  @override
  State<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends State<ClientsListScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final result = await db.query('clients', orderBy: 'name ASC');
    setState(() {
      _clients = result;
      _applySearch();
      _isLoading = false;
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredClients = _clients;
    } else {
      _filteredClients = _clients.where((c) {
        final name = (c['name'] as String).toLowerCase();
        final phone = (c['phone'] as String?)?.toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> _showClientDialog({String? clientId}) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final taxNumberController = TextEditingController();
    final commercialRegisterController = TextEditingController();
    final notesController = TextEditingController();
    
    if (clientId != null) {
      final client = _clients.firstWhere((c) => c['id'] == clientId);
      nameController.text = client['name'] as String;
      phoneController.text = client['phone'] as String? ?? '';
      emailController.text = client['email'] as String? ?? '';
      addressController.text = client['address'] as String? ?? '';
      taxNumberController.text = client['tax_number'] as String? ?? '';
      commercialRegisterController.text = client['commercial_register'] as String? ?? '';
      notesController.text = client['notes'] as String? ?? '';
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clientId != null ? 'تعديل عميل' : 'عميل جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم العميل *')),
              const SizedBox(height: 12),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'العنوان'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: taxNumberController, decoration: const InputDecoration(labelText: 'الرقم الضريبي')),
              const SizedBox(height: 12),
              TextField(controller: commercialRegisterController, decoration: const InputDecoration(labelText: 'السجل التجاري')),
              const SizedBox(height: 12),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final db = await _dbHelper.database;
              final now = DateTime.now().toIso8601String();
              
              final data = <String, dynamic>{
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
                'email': emailController.text.trim(),
                'address': addressController.text.trim(),
                'tax_number': taxNumberController.text.trim(),
                'commercial_register': commercialRegisterController.text.trim(),
                'notes': notesController.text.trim(),
                'updated_at': now,
              };
              
              if (clientId != null) {
                await db.update('clients', data, where: 'id = ?', whereArgs: [clientId]);
              } else {
                data['id'] = const Uuid().v4();
                data['balance'] = 0;
                data['is_archived'] = 0;
                data['created_at'] = now;
                await db.insert('clients', data);
              }
              
              Navigator.pop(context, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    
    if (result == true) _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                setState(() {
                  _searchQuery = v;
                  _applySearch();
                });
              },
              decoration: const InputDecoration(
                hintText: 'بحث عن عميل...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('لا يوجد عملاء', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredClients.length,
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  (client['name'] as String)[0],
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(client['name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                              subtitle: Text(client['phone'] as String? ?? 'لا يوجد رقم', style: GoogleFonts.cairo(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(client['balance'] as num?)?.toStringAsFixed(0) ?? '0'} ر.ي',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      color: ((client['balance'] as num?)?.toDouble() ?? 0) >= 0
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                  PopupMenuButton(
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                      const PopupMenuItem(value: 'statement', child: Text('كشف حساب')),
                                      const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                                    ],
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showClientDialog(clientId: client['id'] as String);
                                      } else if (value == 'statement') {
                                        // سيتم إضافة كشف الحساب
                                      } else if (value == 'archive') {
                                        _archiveClient(client['id'] as String);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _archiveClient(String id) async {
    final db = await _dbHelper.database;
    await db.update('clients', {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    _loadClients();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت أرشفة العميل')));
    }
  }
}
