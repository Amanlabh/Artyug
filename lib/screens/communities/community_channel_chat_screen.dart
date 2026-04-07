import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

/// Guild-wide "main" channel chat for a community (e.g. Artyug-main).
class CommunityChannelChatScreen extends StatefulWidget {
  final String communityId;
  final String? communityName;

  const CommunityChannelChatScreen({
    super.key,
    required this.communityId,
    this.communityName,
  });

  @override
  State<CommunityChannelChatScreen> createState() =>
      _CommunityChannelChatScreenState();
}

class _CommunityChannelChatScreenState extends State<CommunityChannelChatScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, dynamic>> _profiles = {};
  bool _loading = true;
  bool _sending = false;
  bool _isMember = false;
  bool _membershipChecked = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _checkMembership();
    if (_isMember) {
      await _fetchMessages();
      _subscribe();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkMembership() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() {
        _isMember = false;
        _membershipChecked = true;
      });
      return;
    }
    try {
      final row = await _supabase
          .from('community_members')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('user_id', user.id)
          .maybeSingle();
      setState(() {
        _isMember = row != null;
        _membershipChecked = true;
      });
    } catch (_) {
      setState(() {
        _isMember = false;
        _membershipChecked = true;
      });
    }
  }

  Future<void> _fetchMessages() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('community_chat_messages')
          .select('*')
          .eq('community_id', widget.communityId)
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(res as List);
      final senderIds = list.map((m) => m['sender_id'] as String).toSet().toList();
      if (senderIds.isNotEmpty) {
        final profs = await _supabase
            .from('profiles')
            .select('id, username, display_name, profile_picture_url')
            .inFilter('id', senderIds);
        final pmap = {
          for (final p in List<Map<String, dynamic>>.from(profs as List))
            p['id'] as String: p
        };
        setState(() {
          _messages = list;
          _profiles = pmap;
          _loading = false;
        });
      } else {
        setState(() {
          _messages = list;
          _loading = false;
        });
      }
      _scrollToEnd();
    } catch (_) {
      setState(() {
        _messages = [];
        _loading = false;
      });
    }
  }

  void _subscribe() {
    _subscription = _supabase
        .channel('community_chat:${widget.communityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: widget.communityId,
          ),
          callback: (payload) async {
            final row = Map<String, dynamic>.from(payload.newRecord);
            final sid = row['sender_id'] as String;
            if (!_profiles.containsKey(sid)) {
              try {
                final p = await _supabase
                    .from('profiles')
                    .select('id, username, display_name, profile_picture_url')
                    .eq('id', sid)
                    .maybeSingle();
                if (p != null) {
                  setState(() => _profiles[sid] = Map<String, dynamic>.from(p));
                }
              } catch (_) {}
            }
            setState(() => _messages = [..._messages, row]);
            _scrollToEnd();
          },
        )
        .subscribe();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || !_isMember) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await _supabase.from('community_chat_messages').insert({
        'community_id': widget.communityId,
        'sender_id': user.id,
        'content': text,
      });
      _scrollToEnd();
    } catch (_) {
      _messageController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _displayName(Map<String, dynamic>? p) {
    if (p == null) return 'Member';
    return (p['display_name'] as String?)?.trim().isNotEmpty == true
        ? p['display_name'] as String
        : (p['username'] as String?) ?? 'Member';
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

  @override
  Widget build(BuildContext context) {
    final title = widget.communityName ?? 'Guild';
    final channelLabel = '$title — main';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8b5cf6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              channelLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Guild channel · chat history',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: !_membershipChecked
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8b5cf6)))
          : !_isMember
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Join this guild to read and send messages.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              context.push('/community-detail/${widget.communityId}'),
                          child: const Text('Open community'),
                        ),
                      ],
                    ),
                  ),
                )
              : _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8b5cf6)),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet.\nSay hello to the guild!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 12),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final msg = _messages[index];
                                    final uid = msg['sender_id'] as String;
                                    final prof = _profiles[uid];
                                    final user = Provider.of<AuthProvider>(context).user;
                                    final mine = msg['sender_id'] == user?.id;
                                    return _MessageRow(
                                      mine: mine,
                                      name: _displayName(prof),
                                      avatarUrl: prof?['profile_picture_url'] as String?,
                                      content: msg['content'] as String? ?? '',
                                      time: _formatTime(msg['created_at'] as String?),
                                    );
                                  },
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Message $title main channel…',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                    ),
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF8b5cf6),
                                  child: IconButton(
                                    icon: _sending
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.send, color: Colors.white),
                                    onPressed: _sending ? null : _send,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final bool mine;
  final String name;
  final String? avatarUrl;
  final String content;
  final String time;

  const _MessageRow({
    required this.mine,
    required this.name,
    this.avatarUrl,
    required this.content,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purple.shade200,
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl!)
                  : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF8b5cf6) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  if (!mine) const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: mine ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: mine ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
