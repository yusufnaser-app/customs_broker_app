import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class SubscriptionStatus {
  final bool isActive;
  final String? message;
  final String? endDate;

  const SubscriptionStatus({required this.isActive, this.message, this.endDate});
}

/// يتحقق من صلاحية اشتراك المكتب قبل عمليات الإنشاء/التعديل الحساسة.
class SubscriptionGuard {
  static const contactNumber = '775477377';

  static Future<SubscriptionStatus> check() async {
    final db = await DatabaseHelper().database;
    final subs = await db.query('office_subscriptions', limit: 1);

    if (subs.isEmpty) {
      // لا يوجد اشتراك مسجل بعد (حالة نادرة) - نسمح بالاستمرار حتى لا نقفل التطبيق بالخطأ
      return const SubscriptionStatus(isActive: true);
    }

    final sub = subs.first;
    final status = sub['status'] as String? ?? 'active';
    final endDateStr = sub['end_date'] as String?;

    if (status == 'stopped') {
      return const SubscriptionStatus(
        isActive: false,
        message: 'تم إيقاف اشتراك هذا المكتب. يرجى التواصل مع الإدارة. رقم التواصل: $contactNumber',
      );
    }

    if (endDateStr != null) {
      final endDate = DateTime.tryParse(endDateStr);
      if (endDate != null && DateTime.now().isAfter(endDate)) {
        return SubscriptionStatus(
          isActive: false,
          message: 'انتهت صلاحية اشتراك هذا المكتب. يرجى التواصل مع الإدارة لتجديد الاشتراك. رقم التواصل: $contactNumber',
          endDate: endDateStr,
        );
      }
    }

    return SubscriptionStatus(isActive: true, endDate: endDateStr);
  }

  /// يعرض رسالة تنبيه إن كان الاشتراك منتهيًا/موقوفًا، ويرجع true إن كان بإمكان المتابعة.
  static Future<bool> ensureActiveOrWarn(BuildContext context) async {
    final result = await check();
    if (result.isActive) return true;

    if (!context.mounted) return false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انتهت صلاحية الاشتراك'),
        content: Text(result.message ?? 'اشتراك المكتب غير نشط حاليًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );

    return false;
  }
}
