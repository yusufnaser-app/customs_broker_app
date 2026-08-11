import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _generateDefaultNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final notifications = await db.query('notifications', orderBy: 'created_at DESC');
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _generateDefaultNotifications() async {
    final db = await _dbHelper.database;
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM notifications');
    
    if ((count.first['count'] as int?) == 0) {
      final now = DateTime.now().toIso8601String();
      final defaultNotifications = [
        {
          'id': 'notif-1', 'title': 'مرحباً بك', 'message': 'أهلاً بك في دليل المخلص الجمركي اليمني. ابدأ بإضافة أول إقرار.',
          'type': 'info', 'reference_type': '', 'reference_id': '', 'created_at': now, 'is_read': 0,
        },
        {
          'id': 'notif-2', 'title': 'النسخة التجريبية', 'message': 'أنت تستخدم النسخة التجريبية. يمكنك إنشاء 5 إقرارات و5 فواتير.',
          'type': 'warning', 'reference_type': 'subscription', 'reference_id': '', 'created_at': now, 'is_read': 0,
        },
      ];
      
      for (final notif in defaultNotifications) {
        await db.insert('notifications', notif);
      }
      
      _loadNotifications();
    }
  }

  Future<void> _markAsRead(String id) async {
    final db = await _dbHelper.database;
    await db.update('notifications', {'is_read': 1}, where: 'id = ?', whereArgs: [id]);
    _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    final db = await _dbHelper.database;
    await db.update('notifications', {'is_read': 1});
    _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديد الكل كمقروء')));
    }
  }

  Future<void> _clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('notifications');
    _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح جميع الإشعارات')));
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'warning': return Icons.warning_amber;
      case 'error': return Icons.error;
      case 'success': return Icons.check_circle;
      default: return Icons.info;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'warning': return AppColors.warning;
      case 'error': return AppColors.error;
      case 'success': return AppColors.success;
      default: return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => (n['is_read'] as int?) == 0).length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(value: 'read_all', child: Row(children: const [Icon(Icons.done_all, size: 18), SizedBox(width: 8), Text('تحديد الكل كمقروء')])),
                PopupMenuItem(value: 'clear', child: Row(children: const [Icon(Icons.delete, size: 18), SizedBox(width: 8), Text('مسح الكل')])),
              ],
              onSelected: (v) {
                if (v == 'read_all') _markAllAsRead();
                if (v == 'clear') _clearAll();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('لا توجد إشعارات', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    final isRead = (notif['is_read'] as int?) == 1;
                    final typeColor = _getTypeColor(notif['type'] as String? ?? 'info');
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isRead ? null : typeColor.withOpacity(0.05),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_getTypeIcon(notif['type'] as String? ?? 'info'), color: typeColor, size: 20),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif['title'] as String? ?? '',
                                style: GoogleFonts.cairo(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                              ),
                            ),
                            if (!isRead)
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          ],
                        ),
                        subtitle: Text(notif['message'] as String? ?? '', style: GoogleFonts.cairo(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _markAsRead(notif['id'] as String),
                        ),
                        onTap: () => _markAsRead(notif['id'] as String),
                      ),
                    );
                  },
                ),
    );
  }
}
