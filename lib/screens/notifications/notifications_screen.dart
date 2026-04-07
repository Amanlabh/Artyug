import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // Demo notifications if table doesn't exist yet
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _notifications = _demoNotifications;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _notifications = _demoNotifications;
        _loading = false;
      });
    }
  }

  static final _demoNotifications = [
    {
      'id': '1',
      'type': 'like',
      'title': 'Someone liked your artwork',
      'body': '"Morning Raga" received a new like',
      'time': '2m ago',
      'read': false,
      'icon': Icons.favorite_outlined,
    },
    {
      'id': '2',
      'type': 'sale',
      'title': '🎉 You made a sale!',
      'body': '"Urban Chaos" was purchased for ₹4,500',
      'time': '1h ago',
      'read': false,
      'icon': Icons.sell_outlined,
    },
    {
      'id': '3',
      'type': 'follow',
      'title': 'New follower',
      'body': '@priya_studio started following you',
      'time': '3h ago',
      'read': true,
      'icon': Icons.person_add_outlined,
    },
    {
      'id': '4',
      'type': 'verify',
      'title': 'Artwork verified',
      'body': '"Monsoon III" has been authenticated',
      'time': '1d ago',
      'read': true,
      'icon': Icons.verified_outlined,
    },
    {
      'id': '5',
      'type': 'guild',
      'title': 'Guild event invite',
      'body': 'You\'re invited to "Delhi Art Collective" meetup',
      'time': '2d ago',
      'read': true,
      'icon': Icons.group_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _notifications = _notifications
                  .map((n) => {...n, 'read': true})
                  .toList();
            }),
            child: const Text('Mark all read',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _notifications.isEmpty
              ? _empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.border),
                    itemBuilder: (_, i) =>
                        _NotificationTile(item: _notifications[i]),
                  ),
                ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.surfaceVariant, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_outlined,
                size: 32, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Activity from your\nartwork and profile will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationTile({required this.item});

  Color _iconColor() {
    switch (item['type']) {
      case 'like':
        return const Color(0xFFE8470A);
      case 'sale':
        return AppColors.success;
      case 'follow':
        return AppColors.info;
      case 'verify':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = item['read'] == false;
    return Container(
      color: isUnread
          ? AppColors.primary.withOpacity(0.04)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _iconColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item['icon'] as IconData,
                size: 20, color: _iconColor()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(item['title'] as String,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(item['body'] as String,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.3)),
                const SizedBox(height: 4),
                Text(item['time'] as String,
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
