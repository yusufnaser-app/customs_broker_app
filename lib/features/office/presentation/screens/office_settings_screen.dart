import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class OfficeSettingsScreen extends StatefulWidget {
  const OfficeSettingsScreen({super.key});

  @override
  State<OfficeSettingsScreen> createState() => _OfficeSettingsScreenState();
}

class _OfficeSettingsScreenState extends State<OfficeSettingsScreen> {
  final _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final _officeNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = await _dbHelper.database;
    final settings = await db.query('office_settings', limit: 1);

    if (settings.isNotEmpty) {
      final s = settings.first;
      _officeNameController.text = s['office_name'] as String? ?? '';
      _licenseController.text = s['license_number'] as String? ?? '';
      _taxNumberController.text = s['tax_number'] as String? ?? '';
      _phoneController.text = s['phone'] as String? ?? '';
      _emailController.text = s['email'] as String? ?? '';
      _addressController.text = s['address'] as String? ?? '';
      _logoPath = s['logo_path'] as String?;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _logoPath = picked.path);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query('office_settings', limit: 1);
    final data = {
      'office_name': _officeNameController.text,
      'license_number': _licenseController.text,
      'tax_number': _taxNumberController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'logo_path': _logoPath,
      'updated_at': now,
    };

    if (existing.isNotEmpty) {
      await db.update('office_settings', data, where: 'id = 1');
    } else {
      await db.insert('office_settings', {'id': 1, ...data, 'created_at': now});
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الإعدادات بنجاح'), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات مكتب التخليص')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickLogo,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: (_logoPath != null && _logoPath!.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(File(_logoPath!), fit: BoxFit.cover),
                                )
                              : const Icon(Icons.add_a_photo, color: AppColors.primary, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField('اسم مكتب التخليص *', _officeNameController),
                    const SizedBox(height: 16),
                    _buildTextField('رقم الترخيص *', _licenseController),
                    const SizedBox(height: 16),
                    _buildTextField('الرقم الضريبي', _taxNumberController),
                    const SizedBox(height: 16),
                    _buildTextField('رقم الهاتف', _phoneController, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField('البريد الإلكتروني', _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildTextField('العنوان', _addressController, maxLines: 3),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text('حفظ الإعدادات', style: GoogleFonts.cairo(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: label.contains('*') ? (v) => v?.isEmpty == true ? 'هذا الحقل مطلوب' : null : null,
    );
  }

  @override
  void dispose() {
    _officeNameController.dispose();
    _licenseController.dispose();
    _taxNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
