import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // الشعار
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            // اسم التطبيق
            Text(
              AppStrings.appName,
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // الإصدار
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الإصدار ${AppStrings.appVersion}',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // الوصف
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                AppStrings.appDescription,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 50),
            
            // المميزات
            _buildFeatureItem(Icons.check_circle, 'إدارة الإقرارات الجمركية'),
            _buildFeatureItem(Icons.check_circle, 'محرك احتساب الرسوم'),
            _buildFeatureItem(Icons.check_circle, 'إدارة العملاء والتجار'),
            _buildFeatureItem(Icons.check_circle, 'فواتير الأتعاب وكشوف الحساب'),
            _buildFeatureItem(Icons.check_circle, 'إدارة الصندوق والمصروفات'),
            _buildFeatureItem(Icons.check_circle, 'تقارير PDF و Excel'),
            _buildFeatureItem(Icons.check_circle, 'لوحة تحكم احترافية'),
            
            const SizedBox(height: 50),
            
            // حقوق النشر
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.copyright, color: AppColors.accent, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.copyright,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.supportContact,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
