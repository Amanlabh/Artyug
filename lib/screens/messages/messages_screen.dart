import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }

      // Fetch all conversations where user is a participant
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('participant1_id.eq.${user.id},participant2_id.eq.${user.id}')
          .order('updated_at', ascending: false);

      if (response.isEmpty) {
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }

      final conversationsData = List<Map<String, dynamic>>.from(response);

      // Get all participant IDs
      final participantIds = <String>{};
      for (var conv in conversationsData) {
        if (conv['participant1_id'] != null) {
          participantIds.add(conv['participant1_id'] as String);
        }
        if (conv['participant2_id'] != null) {
          participantIds.add(conv['participant2_id'] as String);
        }
      }
      participantIds.remove(user.id); // Remove current user

      // Fetch profiles for all participants
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .inFilter('id', participantIds.toList());

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (var p in profilesData) p['id']: p};

      // Get last message and unread count for each conversation
      final conversationsWithDetails = await Future.wait(
        conversationsData.map((conversation) async {
          final otherUserId = conversation['participant1_id'] == user.id
              ? conversation['participant2_id'] as String
              : conversation['participant1_id'] as String;

          final otherUser = profilesMap[otherUserId] ?? {};

          // Get last message
          final lastMessageResponse = await _supabase
              .from('messages')
              .select('*')
              .eq('conversation_id', conversation['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          // Get unread count
          final unreadResponse = await _supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', conversation['id'])
              .eq('is_read', false)
              .neq('sender_id', user.id);

          final unreadCount = (unreadResponse as List).length;

          return {
            ...conversation,
            'other_user': otherUser,
            'other_user_id': otherUserId,
            'last_message': lastMessageResponse,
            'unread_count': unreadCount,
          };
        }),
      );

      setState(() {
        _conversations = conversationsWithDetails;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _conversations = [];
        _loading = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    _subscription = _supabase
        .channel('conversations:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Refresh conversations when new messages arrive
            _fetchConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant1_id',
            value: user.id,
          ),
          callback: (payload) {
            // Refresh conversations when conversations are updated
            _fetchConversations();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
            value: user.id,
          ),
          callback: (payload) {
            // Refresh conversations when conversations are updated
            _fetchConversations();
          },
        )
        .subscribe();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) return 'Just now';
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      }
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _glassContainer({
    required Widget child,
    double radius = 18,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1.3,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final otherUser = conversation['other_user'] ?? {};
    final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final otherUserId = conversation['other_user_id'] as String?;

    final otherUserName =
        otherUser['display_name'] ?? otherUser['username'] ?? 'Unknown';
    final profilePictureUrl = otherUser['profile_picture_url'];

    final lastMessageContent = lastMessage?['content'] as String? ?? '';
    final lastMessageTime = lastMessage?['created_at'] as String?;

    return _glassContainer(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (otherUserId != null) {
              context.push('/chat/$otherUserId');
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Row(
            children: [
              // Profile Picture
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.purpleAccent,
                    backgroundImage: profilePictureUrl != null
                        ? CachedNetworkImageProvider(profilePictureUrl)
                        : null,
                    child: profilePictureUrl == null
                        ? Text(
                            otherUserName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF24243e),
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: const SizedBox(
                          width: 8,
                          height: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Message Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null)
                          Text(
                            _formatTime(lastMessageTime),
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageContent.isNotEmpty
                                ? lastMessageContent
                                : 'No messages yet',
                            style: TextStyle(
                              color: lastMessageContent.isNotEmpty
                                  ? (unreadCount > 0
                                      ? Colors.white
                                      : Colors.white70)
                                  : Colors.white54,
                              fontSize: 14,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.4),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent),
            )
          else if (_conversations.isEmpty)
            Center(
              child: _glassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No conversations yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start chatting with other artists!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _fetchConversations,
              color: Colors.purpleAccent,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildConversationCard(_conversations[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


