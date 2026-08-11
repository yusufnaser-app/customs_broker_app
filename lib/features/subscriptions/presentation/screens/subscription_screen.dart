import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/database/database_helper.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _activeSubscription;
  int _declarationsCount = 0;
  int _invoicesCount = 0;
  bool _isTrial = true;
  bool _isLoading = true;

  static const int maxTrialDeclarations = 5;
  static const int maxTrialInvoices = 5;

  final List<Map<String, String>> _plans = [
    {'type': 'monthly', 'name': 'شهري', 'price': '5,000 ر.ي', 'duration': '30 يوم'},
    {'type': 'semi_annual', 'name': 'نصف سنوي', 'price': '25,000 ر.ي', 'duration': '180 يوم'},
    {'type': 'annual', 'name': 'سنوي', 'price': '45,000 ر.ي', 'duration': '365 يوم'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final db = await _dbHelper.database;
    
    // التحقق من الاشتراك النشط
    final subscriptions = await db.query('subscriptions', where: 'is_active = 1', orderBy: 'end_date DESC', limit: 1);
    
    // حساب عدد الإقرارات والفواتير
    final declCount = await db.rawQuery('SELECT COUNT(*) as count FROM declarations');
    final invCount = await db.rawQuery('SELECT COUNT(*) as count FROM invoices');
    
    setState(() {
      _activeSubscription = subscriptions.isNotEmpty ? subscriptions.first : null;
      _declarationsCount = (declCount.first['count'] as int?) ?? 0;
      _invoicesCount = (invCount.first['count'] as int?) ?? 0;
      _isTrial = _activeSubscription == null;
      _isLoading = false;
    });
  }

  bool get canCreateDeclaration {
    if (!_isTrial) return true;
    return _declarationsCount < maxTrialDeclarations;
  }

  bool get canCreateInvoice {
    if (!_isTrial) return true;
    return _invoicesCount < maxTrialInvoices;
  }

  Future<void> _activateSubscription(String planType) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    
    int days;
    switch (planType) {
      case 'monthly': days = 30; break;
      case 'semi_annual': days = 180; break;
      case 'annual': days = 365; break;
      default: days = 30;
    }
    
    final endDate = now.add(Duration(days: days));
    
    // إلغاء الاشتراكات السابقة
    await db.update('subscriptions', {'is_active': 0});
    
    // تفعيل الاشتراك الجديد
    await db.insert('subscriptions', {
      'id': 'sub-${now.millisecondsSinceEpoch}',
      'user_id': 'admin-001',
      'plan_type': planType,
      'start_date': now.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': 1,
      'created_at': now.toIso8601String(),
    });
    
    _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل الاشتراك بنجاح'), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الاشتراكات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // حالة الاشتراك الحالي
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: _isTrial ? AppColors.warning.withOpacity(0.2) as Gradient? : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isTrial ? Icons.timer : Icons.verified,
                          color: _isTrial ? AppColors.warning : Colors.white,
                          size: 50,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isTrial ? 'النسخة التجريبية' : 'اشتراك نشط',
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _isTrial ? AppColors.warning : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isTrial) ...[
                          Text(
                            'الإقرارات: $_declarationsCount / $maxTrialDeclarations',
                            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.warning),
                          ),
                          Text(
                            'الفواتير: $_invoicesCount / $maxTrialInvoices',
                            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.warning),
                          ),
                          if (_declarationsCount >= maxTrialDeclarations || _invoicesCount >= maxTrialInvoices)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                AppStrings.trialExpired,
                                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ] else
                          Text(
                            'ينتهي في: ${_activeSubscription?['end_date']?.toString().substring(0, 10) ?? ''}',
                            style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // باقات الاشتراك
                  Text('باقات الاشتراك', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  ..._plans.map((plan) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.workspace_premium, color: AppColors.accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan['name']!, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(plan['duration']!, style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(plan['price']!, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                onPressed: () => _activateSubscription(plan['type']!),
                                child: const Text('تفعيل', style: TextStyle(fontSize: 13)),
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
    );
  }
}
