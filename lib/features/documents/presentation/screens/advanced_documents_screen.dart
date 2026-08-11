import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class AdvancedDocumentsScreen extends StatefulWidget {
  final String declarationId;

  const AdvancedDocumentsScreen({super.key, required this.declarationId});

  @override
  State<AdvancedDocumentsScreen> createState() => _AdvancedDocumentsScreenState();
}

class _AdvancedDocumentsScreenState extends State<AdvancedDocumentsScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _documentTypes = [
    {'type': 'invoice', 'name': 'الفاتورة', 'icon': Icons.receipt_long},
    {'type': 'bill_of_lading', 'name': 'بوليصة الشحن', 'icon': Icons.description},
    {'type': 'certificate_of_origin', 'name': 'شهادة المنشأ', 'icon': Icons.verified},
    {'type': 'packing_list', 'name': 'قائمة التعبئة', 'icon': Icons.list_alt},
    {'type': 'customs_declaration', 'name': 'البيان الجمركي', 'icon': Icons.article},
    {'type': 'other', 'name': 'أخرى', 'icon': Icons.folder},
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final docs = await db.query(
      'documents',
      where: 'declaration_id = ?',
      whereArgs: [widget.declarationId],
      orderBy: 'uploaded_at DESC',
    );
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Future<void> _showDocumentPicker() async {
    final docType = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('نوع المستند'),
        children: _documentTypes.map((type) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, type['type'] as String),
            child: Row(
              children: [
                Icon(type['icon'] as IconData, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(type['name'] as String),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (docType == null || !mounted) return;

    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.success),
              title: const Text('معرض الصور'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: AppColors.error),
              title: const Text('ملف PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.file_present, color: AppColors.warning),
              title: const Text('أي ملف'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    await _pickAndSaveFile(docType, source);
  }

  Future<void> _pickAndSaveFile(String docType, String source) async {
    String? filePath;
    String? fileName;
    String? extension;

    try {
      if (source == 'camera' || source == 'gallery') {
        final picker = ImagePicker();
        final imageSource = source == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final picked = await picker.pickImage(source: imageSource, imageQuality: 80);
        if (picked != null) {
          filePath = picked.path;
          fileName = '${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          extension = 'jpg';
        }
      } else if (source == 'pdf') {
        final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        if (picked != null && picked.files.isNotEmpty) {
          filePath = picked.files.first.path;
          fileName = picked.files.first.name;
          extension = 'pdf';
        }
      } else {
        final picked = await FilePicker.platform.pickFiles();
        if (picked != null && picked.files.isNotEmpty) {
          filePath = picked.files.first.path;
          fileName = picked.files.first.name;
          extension = picked.files.first.extension;
        }
      }

      if (filePath != null) {
        final db = await _dbHelper.database;
        final now = DateTime.now().toIso8601String();
        final file = File(filePath);

        await db.insert('documents', {
          'id': const Uuid().v4(),
          'declaration_id': widget.declarationId,
          'document_type': docType,
          'file_path': filePath,
          'file_name': fileName ?? 'document',
          'file_extension': extension,
          'file_size': await file.length(),
          'uploaded_at': now,
        });

        _loadDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفع المستند بنجاح'), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteDocument(String id) async {
    final db = await _dbHelper.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
    _loadDocuments();
  }

  String _getDocumentTypeName(String type) {
    return _documentTypes.firstWhere((t) => t['type'] == type, orElse: () => {'name': type})['name'] as String;
  }

  IconData _getDocumentTypeIcon(String type) {
    return _documentTypes.firstWhere((t) => t['type'] == type, orElse: () => {'icon': Icons.folder})['icon'] as IconData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مرفقات الإقرار')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : _buildDocumentsGrid(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDocumentPicker,
        icon: const Icon(Icons.add),
        label: const Text('إضافة مرفق'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('لا توجد مرفقات', style: GoogleFonts.cairo(fontSize: 20, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Text(
            'قم بإضافة الفاتورة، بوليصة الشحن،\nوشهادة المنشأ والمستندات الأخرى',
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _showDocumentPicker,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول مرفق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _documents.length + 1,
      itemBuilder: (context, index) {
        if (index == _documents.length) {
          return _buildAddButton();
        }
        return _buildDocumentCard(_documents[index]);
      },
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _showDocumentPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary.withOpacity(0.05),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 45, color: AppColors.primary),
            SizedBox(height: 8),
            Text('إضافة', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final docType = doc['document_type'] as String? ?? 'other';
    final ext = doc['file_extension'] as String?;
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isImage)
                Expanded(
                  child: Image.file(
                    File(doc['file_path'] as String),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                )
              else
                Expanded(
                  child: Container(
                    color: AppColors.primary.withOpacity(0.05),
                    child: Icon(_getDocumentTypeIcon(docType), size: 50, color: AppColors.primary),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                color: Theme.of(context).cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getDocumentTypeName(docType),
                      style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      doc['file_name'] as String? ?? '',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _deleteDocument(doc['id'] as String),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
