import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/declaration.dart';
import 'declaration_form_screen.dart';
import 'declaration_details_screen.dart';
import '../../../../core/utils/subscription_guard.dart';

class DeclarationsListScreen extends StatefulWidget {
  const DeclarationsListScreen({super.key});

  @override
  State<DeclarationsListScreen> createState() => _DeclarationsListScreenState();
}

class _DeclarationsListScreenState extends State<DeclarationsListScreen> {
  List<Declaration> _declarations = [];
  List<Declaration> _filteredDeclarations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadDeclarations();
  }

  Future<void> _loadDeclarations() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT d.*, c.name as client_name, t.name as trader_name, s.name as supplier_name
        FROM declarations d
        LEFT JOIN clients c ON d.client_id = c.id
        LEFT JOIN traders t ON d.trader_id = t.id
        LEFT JOIN suppliers s ON d.supplier_id = s.id
        ORDER BY d.created_at DESC
      ''');
      
      final declarations = result.map((map) {
        return Declaration.fromMap(
          map,
          clientName: map['client_name'] as String?,
          traderName: map['trader_name'] as String?,
          supplierName: map['supplier_name'] as String?,
        );
      }).toList();
      
      setState(() {
        _declarations = declarations;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    _filteredDeclarations = _declarations.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.declarationNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d.clientName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      final matchesStatus = _statusFilter == 'all' || d.status == _statusFilter;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإقرارات الجمركية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'بحث برقم الإقرار أو اسم العميل...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          
          // عداد النتائج
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredDeclarations.length} إقرار',
                  style: GoogleFonts.cairo(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _loadDeclarations(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('تحديث'),
                ),
              ],
            ),
          ),
          
          // قائمة الإقرارات
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDeclarations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredDeclarations.length,
                        itemBuilder: (context, index) {
                          return _buildDeclarationCard(_filteredDeclarations[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final canProceed = await SubscriptionGuard.ensureActiveOrWarn(context);
          if (!canProceed || !context.mounted) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeclarationFormScreen(),
            ),
          );
          if (result == true) {
            _loadDeclarations();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إقرار جديد'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDeclarationCard(Declaration declaration) {
    final statusColors = {
      'draft': AppColors.warning,
      'processing': AppColors.info,
      'completed': AppColors.success,
      'cancelled': AppColors.error,
    };
    
    final statusLabels = {
      'draft': 'مسودة',
      'processing': 'قيد المعالجة',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
    };
    
    final color = statusColors[declaration.status] ?? AppColors.textSecondary;
    final label = statusLabels[declaration.status] ?? declaration.status;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeclarationDetailsScreen(declarationId: declaration.id),
            ),
          );
          if (result == true) {
            _loadDeclarations();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'إقرار #${declaration.declarationNumber}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInfoRow(Icons.person_outline, 'العميل', declaration.clientName ?? 'غير محدد'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.attach_money, 'قيمة الفاتورة', '${NumberFormat('#,##0.00').format(declaration.invoiceValueUsd)} \$'),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.calendar_today, 'التاريخ', declaration.statementDate ?? declaration.createdAt.substring(0, 10)),
              if (declaration.notes != null && declaration.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  declaration.notes!,
                  style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا توجد إقرارات',
            style: GoogleFonts.cairo(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على زر + لإضافة إقرار جديد',
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تصفية الإقرارات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('all', 'الكل'),
              _buildFilterOption('draft', 'مسودة'),
              _buildFilterOption('processing', 'قيد المعالجة'),
              _buildFilterOption('completed', 'مكتمل'),
              _buildFilterOption('cancelled', 'ملغي'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: _statusFilter,
      onChanged: (val) {
        setState(() {
          _statusFilter = val!;
          _applyFilters();
        });
        Navigator.pop(context);
      },
    );
  }
}
