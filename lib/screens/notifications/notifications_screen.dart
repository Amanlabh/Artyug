import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _notifications = _demoNotifications;
      _loading = false;
    });
  }

  static final _demoNotifications = [
    {
      'id': '1',
      'eyebrow': 'NEW UPDATE',
      'title': 'download the new\nversion of the Artyug app',
      'actionLabel': 'Update now',
      'read': false,
      'icon': Icons.system_update_alt_rounded,
      'iconAccent': const Color(0xFF2A2A2A),
      'badgeColor': const Color(0xFFFF9A3C),
      'badgeIcon': Icons.campaign_rounded,
    },
    {
      'id': '2',
      'eyebrow': 'SECURITY',
      'title': 'activate fingerprint for\nfaster secure checkout',
      'actionLabel': 'Enable now',
      'read': false,
      'icon': Icons.fingerprint_rounded,
      'iconAccent': const Color(0xFF2EB67D),
      'badgeColor': const Color(0xFFFF9A3C),
      'badgeIcon': Icons.access_time_filled_rounded,
    },
  ];

  void _markAllRead() {
    setState(() {
      _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pop(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                _NotificationSheet(
                  notifications: _notifications,
                  loading: _loading,
                  onClose: () => context.pop(),
                  onMarkAllRead: _markAllRead,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final bool loading;
  final VoidCallback onClose;
  final VoidCallback onMarkAllRead;

  const _NotificationSheet({
    required this.notifications,
    required this.loading,
    required this.onClose,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleCount =
        notifications.where((item) => item['read'] == false).length;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.54,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F6F1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        child: loading
            ? const SizedBox(
                height: 360,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.2,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D2C8),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'notifications ($titleCount)',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFF1F1A17),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.9,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: notifications.isEmpty ? null : onMarkAllRead,
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Color(0xFF7A6F65),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF241F1C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 36, bottom: 72),
                      child: _EmptyState(),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Divider(
                          color: const Color(0xFFDDD6CB).withValues(alpha: 0.7),
                          thickness: 1,
                          height: 1,
                        ),
                      ),
                      itemBuilder: (_, index) => _NotificationCard(
                        item: notifications[index],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final iconAccent = item['iconAccent'] as Color? ?? AppColors.primary;
    final badgeColor = item['badgeColor'] as Color? ?? AppColors.primary;
    final badgeIcon = item['badgeIcon'] as IconData?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2DBD2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                item['icon'] as IconData,
                color: iconAccent,
                size: 28,
              ),
            ),
            if (badgeIcon != null)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFF9F6F1), width: 2),
                  ),
                  child: Icon(
                    badgeIcon,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['eyebrow'] as String? ?? '',
                style: const TextStyle(
                  color: Color(0xFFDD8D33),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['title'] as String,
                style: const TextStyle(
                  color: Color(0xFF221D19),
                  fontSize: 17,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              minimumSize: const Size(138, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(item['actionLabel'] as String),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(
          Icons.notifications_none_rounded,
          color: Color(0xFF8D847B),
          size: 34,
        ),
        SizedBox(height: 10),
        Text(
          'No notifications yet',
          style: TextStyle(
            color: Color(0xFF221D19),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Fresh updates from Artyug will show up here.',
          style: TextStyle(
            color: Color(0xFF7F7468),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
