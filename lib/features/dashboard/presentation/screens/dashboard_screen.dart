import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../declarations/presentation/screens/declarations_list_screen.dart';
import '../../../clients/presentation/screens/clients_list_screen.dart';
import '../../../banks/presentation/screens/banks_screen.dart';
import '../../../fund/presentation/screens/fund_dashboard_screen.dart';
import '../../../invoices/presentation/screens/invoices_list_screen.dart';
import '../../../revenues/presentation/screens/revenues_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../users/presentation/screens/users_screen.dart';
import '../../../subscriptions/presentation/screens/subscription_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../about/presentation/screens/about_screen.dart';
import '../../../office/presentation/screens/office_settings_screen.dart';
import '../../../fee_settings/presentation/screens/fee_settings_screen.dart';
import '../../../customs_centers/presentation/screens/customs_centers_screen.dart';
import '../../../representatives/presentation/screens/representatives_screen.dart';
import '../../../importers/presentation/screens/importers_screen.dart';
import '../../../subscriptions/presentation/screens/office_license_screen.dart';
import '../../../hs_code_fees/presentation/screens/hs_code_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _DashboardHomeTab(),
    DeclarationsListScreen(),
    ClientsListScreen(),
    _FinanceHubTab(),
    _MoreHubTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.cairo(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'الإقرارات'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'العملاء'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'المالية'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy/MM/dd');
    final today = dateFormatter.format(DateTime.now());
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لوحة التحكم',
                      style: GoogleFonts.cairo(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 25),
            
            // بطاقات الإحصائيات
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  context,
                  title: 'الإقرارات',
                  value: '24',
                  icon: Icons.description_outlined,
                  color: AppColors.info,
                  subtitle: '+3 هذا الأسبوع',
                ),
                _buildStatCard(
                  context,
                  title: 'العملاء',
                  value: '45',
                  icon: Icons.people_outline,
                  color: AppColors.success,
                  subtitle: '+5 هذا الشهر',
                ),
                _buildStatCard(
                  context,
                  title: 'الإيرادات',
                  value: '2.5M ر.ي',
                  icon: Icons.trending_up,
                  color: AppColors.accent,
                  subtitle: 'هذا الشهر',
                ),
                _buildStatCard(
                  context,
                  title: 'الرصيد',
                  value: '850K ر.ي',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                  subtitle: 'الصندوق والبنوك',
                ),
              ],
            ),
            const SizedBox(height: 25),
            
            // الإقرارات الجارية
            Text(
              'الإقرارات الجارية',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            
            // قائمة الإقرارات
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description, color: AppColors.primary, size: 22),
                    ),
                    title: Text(
                      'إقرار جمركي #${2024001 + index}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'العميل: شركة النجاح للتجارة',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: index < 3 ? AppColors.warning.withOpacity(0.2) : AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        index < 3 ? 'قيد المعالجة' : 'مكتمل',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: index < 3 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceHubTab extends StatelessWidget {
  const _FinanceHubTab();

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem('الصندوق والبنوك', Icons.account_balance_wallet_rounded, (ctx) => const FundDashboardScreen()),
      _HubItem('الفواتير', Icons.receipt_long_rounded, (ctx) => const InvoicesListScreen()),
      _HubItem('الإيرادات', Icons.trending_up_rounded, (ctx) => const RevenuesScreen()),
      _HubItem('المصروفات', Icons.trending_down_rounded, (ctx) => const ExpensesScreen()),
      _HubItem('البنوك', Icons.account_balance_rounded, (ctx) => const BanksScreen()),
    ];
    return _HubList(title: 'المالية', items: items);
  }
}

class _MoreHubTab extends StatelessWidget {
  const _MoreHubTab();

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem('إعدادات مكتب التخليص', Icons.business_rounded, (ctx) => const OfficeSettingsScreen()),
      _HubItem('إعدادات الرسوم', Icons.tune_rounded, (ctx) => const FeeSettingsScreen()),
      _HubItem('رسوم HS Code', Icons.qr_code_rounded, (ctx) => const HsCodeManagementScreen()),
      _HubItem('المراكز الجمركية', Icons.location_on_rounded, (ctx) => const CustomsCentersScreen()),
      _HubItem('المندوبون', Icons.badge_rounded, (ctx) => const RepresentativesScreen()),
      _HubItem('المستوردون', Icons.local_shipping_rounded, (ctx) => const ImportersScreen()),
      _HubItem('التراخيص والاشتراكات', Icons.verified_user_rounded, (ctx) => const OfficeLicenseScreen()),
      _HubItem('المستخدمون', Icons.people_alt_rounded, (ctx) => const UsersScreen()),
      _HubItem('التقارير', Icons.bar_chart_rounded, (ctx) => const ReportsScreen()),
      _HubItem('الإشعارات', Icons.notifications_rounded, (ctx) => const NotificationsScreen()),
      _HubItem('الاشتراك', Icons.workspace_premium_rounded, (ctx) => const SubscriptionScreen()),
      _HubItem('عن التطبيق', Icons.info_rounded, (ctx) => const AboutScreen()),
    ];
    return _HubList(title: 'المزيد', items: items);
  }
}

class _HubItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  _HubItem(this.label, this.icon, this.builder);
}

class _HubList extends StatelessWidget {
  final String title;
  final List<_HubItem> items;
  const _HubList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              title,
              style: GoogleFonts.cairo(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(item.icon, color: AppColors.primary),
                    title: Text(item.label, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: item.builder));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
