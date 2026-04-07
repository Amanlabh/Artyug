import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ArtyugNotificationService
///
/// Responsibility: initialise [FlutterLocalNotificationsPlugin] for mobile /
/// desktop, then subscribe to Supabase Realtime channels that matter for a
/// logged-in user:
///
///   • `orders` table  → notify when an order status moves to "completed"
///   • `messages` table → notify when a new DM arrives
///
/// On web, local-notification calls are skipped (the package has no web
/// implementation) but the Realtime subscriptions still function normally,
/// so in-app notification badges / lists remain accurate.
///
/// Usage:
///   final ns = NotificationService.instance;
///   await ns.initialize();   // called once in main() after Supabase.initialize
///   ns.subscribeForUser(userId);  // called after sign-in
///   ns.unsubscribe();             // called on sign-out
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Realtime channels kept so we can remove them on sign-out
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _messagesChannel;

  bool _initialized = false;

  // ─── Initialise ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) return; // flutter_local_notifications has no web backend

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    // Request permission on Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  // ─── Subscribe for a specific user ──────────────────────────────────────────

  void subscribeForUser(String userId) {
    unsubscribe(); // clear any previous subscriptions

    final client = Supabase.instance.client;

    // ── Orders channel ────────────────────────────────────────────────
    // Fires when the authenticated user's order flips to "completed".
    _ordersChannel = client
        .channel('user-orders-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'buyer_id',
            value: userId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            if (newRow['status'] == 'completed') {
              final title = newRow['painting_title'] as String? ??
                  'Your order is confirmed!';
              _show(
                id: _stableId('order', newRow['id'] as String? ?? ''),
                title: '🎨 Order Confirmed — $title',
                body: 'Your certificate of authenticity is being prepared.',
                channelId: 'orders',
                channelName: 'Order Updates',
              );
            }
          },
        )
        .subscribe();

    // ── Messages channel ──────────────────────────────────────────────
    // Fires when a DM arrives for this user.
    _messagesChannel = client
        .channel('user-messages-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;
            final sender = newRow['sender_name'] as String? ?? 'Someone';
            final preview = _truncate(newRow['content'] as String? ?? '…');
            _show(
              id: _stableId('msg', newRow['id'] as String? ?? ''),
              title: '💬 New message from $sender',
              body: preview,
              channelId: 'messages',
              channelName: 'Direct Messages',
            );
          },
        )
        .subscribe();
  }

  // ─── Unsubscribe ─────────────────────────────────────────────────────────────

  void unsubscribe() {
    final client = Supabase.instance.client;
    if (_ordersChannel != null) {
      client.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
    if (_messagesChannel != null) {
      client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
  }

  // ─── Manual trigger (demo / test) ───────────────────────────────────────────

  /// Send a one-off notification. Useful for demo mode to prove the flow works.
  Future<void> sendDemo() async {
    await _show(
      id: 999,
      title: '🖼️ Artyug — Demo Notification',
      body: "Push notifications are working! You'll receive order & DM alerts here.",
      channelId: 'demo',
      channelName: 'Demo',
    );
  }

  // ─── Internal helpers ────────────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    if (kIsWeb) return; // no-op on web
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void _onTap(NotificationResponse response) {
    // Deep-link routing can be added here once flutter_app_links is wired.
    // For now, the tap just dismisses the notification.
  }

  /// Converts a string ID to a stable int notification ID (avoids collisions).
  int _stableId(String prefix, String id) =>
      (prefix + id).hashCode.abs() % 100000;

  String _truncate(String s, {int maxLen = 80}) =>
      s.length > maxLen ? '${s.substring(0, maxLen)}…' : s;
}
