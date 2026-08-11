import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  final List<Map<String, String>> _roles = [
    {'value': 'super_admin', 'label': 'مدير عام'},
    {'value': 'owner', 'label': 'مالك المكتب'},
    {'value': 'manager', 'label': 'مدير'},
    {'value': 'accountant', 'label': 'محاسب'},
    {'value': 'broker', 'label': 'مخلص جمركي'},
    {'value': 'employee', 'label': 'موظف'},
    {'value': 'readonly', 'label': 'للقراءة فقط'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final users = await db.query('users', orderBy: 'created_at DESC');
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _showUserDialog({String? userId}) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRole = 'employee';
    
    if (userId != null) {
      final user = _users.firstWhere((u) => u['id'] == userId);
      usernameController.text = user['username'] as String;
      fullNameController.text = user['full_name'] as String;
      emailController.text = user['email'] as String? ?? '';
      phoneController.text = user['phone'] as String? ?? '';
      selectedRole = user['role'] as String;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(userId != null ? 'تعديل مستخدم' : 'مستخدم جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: fullNameController, decoration: const InputDecoration(labelText: 'الاسم الكامل *')),
                  const SizedBox(height: 12),
                  TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'اسم المستخدم *')),
                  const SizedBox(height: 12),
                  TextField(controller: passwordController, decoration: InputDecoration(
                    labelText: userId != null ? 'كلمة المرور (اترك فارغاً لعدم التغيير)' : 'كلمة المرور *',
                  ), obscureText: true),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'الصلاحية *'),
                    items: _roles.map((r) => DropdownMenuItem(value: r['value'], child: Text(r['label']!))).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  if (fullNameController.text.isEmpty || usernameController.text.isEmpty) return;
                  if (userId == null && passwordController.text.isEmpty) return;
                  
                  final db = await _dbHelper.database;
                  final now = DateTime.now().toIso8601String();
                  
                  final data = <String, dynamic>{
                    'username': usernameController.text,
                    'full_name': fullNameController.text,
                    'role': selectedRole,
                    'email': emailController.text,
                    'phone': phoneController.text,
                    'updated_at': now,
                  };
                  
                  if (passwordController.text.isNotEmpty) {
                    data['password'] = passwordController.text;
                  }
                  
                  if (userId != null) {
                    await db.update('users', data, where: 'id = ?', whereArgs: [userId]);
                  } else {
                    data['id'] = const Uuid().v4();
                    data['is_active'] = 1;
                    data['created_at'] = now;
                    await db.insert('users', data);
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
    
    if (result == true) _loadUsers();
  }

  String _getRoleLabel(String role) {
    return _roles.firstWhere((r) => r['value'] == role, orElse: () => {'label': role})['label']!;
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin': return AppColors.error;
      case 'owner': return AppColors.primary;
      case 'manager': return AppColors.info;
      case 'accountant': return AppColors.success;
      case 'broker': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمين والصلاحيات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final roleColor = _getRoleColor(user['role'] as String);
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: roleColor.withOpacity(0.1),
                      child: Text(
                        (user['full_name'] as String)[0],
                        style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(user['full_name'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    subtitle: Text('@${user['username']}', style: GoogleFonts.cairo(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRoleLabel(user['role'] as String),
                            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor),
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                            const PopupMenuItem(value: 'toggle', child: Text('تفعيل/تعطيل')),
                          ],
                          onSelected: (v) async {
                            if (v == 'edit') {
                              _showUserDialog(userId: user['id'] as String);
                            } else {
                              final db = await _dbHelper.database;
                              final newStatus = (user['is_active'] as int) == 1 ? 0 : 1;
                              await db.update('users', {'is_active': newStatus}, where: 'id = ?', whereArgs: [user['id']]);
                              _loadUsers();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
