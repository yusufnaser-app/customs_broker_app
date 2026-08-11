import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/declarations/presentation/screens/declarations_list_screen.dart';
import 'features/clients/presentation/screens/clients_list_screen.dart';
import 'features/invoices/presentation/screens/invoices_list_screen.dart';
import 'features/fund/presentation/screens/fund_dashboard_screen.dart';
import 'features/expenses/presentation/screens/expenses_screen.dart';
import 'features/revenues/presentation/screens/revenues_screen.dart';
import 'features/banks/presentation/screens/banks_screen.dart';
import 'features/reports/presentation/screens/reports_screen.dart';
import 'features/users/presentation/screens/users_screen.dart';
import 'features/subscriptions/presentation/screens/subscription_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/about/presentation/screens/about_screen.dart';
import 'features/hs_code_fees/presentation/screens/hs_code_management_screen.dart';

class CustomsBrokerApp extends StatelessWidget {
  const CustomsBrokerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دليل المخلص الجمركي اليمني',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      routes: {
        '/dashboard': (context) => const DashboardScreen(),
        '/declarations': (context) => const DeclarationsListScreen(),
        '/clients': (context) => const ClientsListScreen(),
        '/invoices': (context) => const InvoicesListScreen(),
        '/fund': (context) => const FundDashboardScreen(),
        '/expenses': (context) => const ExpensesScreen(),
        '/revenues': (context) => const RevenuesScreen(),
        '/banks': (context) => const BanksScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/users': (context) => const UsersScreen(),
        '/subscriptions': (context) => const SubscriptionScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/about': (context) => const AboutScreen(),
        '/hs-code-fees': (context) => const HsCodeManagementScreen(),
      },
    );
  }
}
