import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class DocumentsScreen extends StatefulWidget {
  final String declarationId;

  const DocumentsScreen({super.key, required this.declarationId});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final docs = await db.query('documents', where: 'declaration_id = ?', whereArgs: [widget.declarationId], orderBy: 'uploaded_at DESC');
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _pickFile() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('معرض الصور'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text('ملف PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );
    
    if (result == null) return;
    
    String? filePath;
    String? fileName;
    String? extension;
    
    if (result == 'camera' || result == 'gallery') {
      final picker = ImagePicker();
      final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        filePath = picked.path;
        fileName = picked.name;
        extension = picked.path.split('.').last;
      }
    } else if (result == 'pdf') {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (picked != null && picked.files.isNotEmpty) {
        filePath = picked.files.first.path;
        fileName = picked.files.first.name;
        extension = 'pdf';
      }
    }
    
    if (filePath != null) {
      final db = await _dbHelper.database;
      final now = DateTime.now().toIso8601String();
      final file = File(filePath);
      
      await db.insert('documents', {
        'id': const Uuid().v4(),
        'declaration_id': widget.declarationId,
        'document_type': result == 'pdf' ? 'pdf' : 'image',
        'file_path': filePath,
        'file_name': fileName ?? 'document',
        'file_extension': extension,
        'file_size': await file.length(),
        'uploaded_at': now,
      });
      
      _loadDocuments();
    }
  }

  Future<void> _deleteDocument(String id) async {
    final db = await _dbHelper.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
    _loadDocuments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المستند')));
    }
  }

  IconData _getDocumentIcon(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'image': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستندات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('لا توجد مستندات مرفقة', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة مستند'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _documents.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _documents.length) {
                      return InkWell(
                        onTap: _pickFile,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary.withOpacity(0.3), style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.primary.withOpacity(0.05),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 40, color: AppColors.primary),
                              SizedBox(height: 8),
                              Text('إضافة', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final doc = _documents[index];
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getDocumentIcon(doc['document_type'] as String?), size: 40, color: AppColors.primary),
                              const SizedBox(height: 8),
                              Text(
                                doc['file_name'] as String? ?? '',
                                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                doc['document_type'] == 'pdf' ? 'PDF' : 'صورة',
                                style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteDocument(doc['id'] as String),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
      floatingActionButton: _documents.isNotEmpty
          ? FloatingActionButton(
              onPressed: _pickFile,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
