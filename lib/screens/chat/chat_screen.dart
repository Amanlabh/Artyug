import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String userId;

  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _otherUser;
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  bool _processingDealAction = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    await _fetchOtherUser();
    await _createOrGetConversation();
    await _fetchMessages();
    _setupRealtimeSubscription();
  }

  Future<void> _fetchOtherUser() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .eq('id', widget.userId)
          .single();

      setState(() {
        _otherUser = response as Map<String, dynamic>;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _createOrGetConversation() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      // Check if conversation exists
      final existingResponse = await _supabase
          .from('conversations')
          .select('id')
          .or('and(participant1_id.eq.${user.id},participant2_id.eq.${widget.userId}),and(participant1_id.eq.${widget.userId},participant2_id.eq.${user.id})')
          .maybeSingle();

      if (existingResponse != null) {
        setState(() {
          _conversationId = existingResponse['id'] as String;
        });
      } else {
        // Create new conversation
        final newResponse = await _supabase
            .from('conversations')
            .insert({
              'participant1_id': user.id,
              'participant2_id': widget.userId,
            })
            .select()
            .single();

        setState(() {
          _conversationId = newResponse['id'] as String;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchMessages() async {
    if (_conversationId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });

      // Mark messages as read
      _markMessagesAsRead();

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _messages = [];
        _loading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null || _conversationId == null) return;

    final unreadMessages = _messages
        .where((msg) => msg['sender_id'] != user.id && msg['is_read'] != true)
        .map((msg) => msg['id'] as String)
        .toList();

    if (unreadMessages.isEmpty) return;

    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .inFilter('id', unreadMessages);
    } catch (e) {
      // Ignore errors
    }
  }

  void _setupRealtimeSubscription() {
    if (_conversationId == null) return;

    _subscription = _supabase
        .channel('messages:$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId,
          ),
          callback: (payload) {
            setState(() {
              _messages = [..._messages, payload.newRecord];
            });
            _markMessagesAsRead();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || 
        _conversationId == null || 
        _sending) {
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    final conversationId = _conversationId!; // Store in local variable for null safety
    final messageContent = _messageController.text.trim();
    _messageController.clear();
    setState(() => _sending = true);

    try {
      await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': user.id,
            'content': messageContent,
          });

      // Update conversation timestamp
      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      _messageController.text = messageContent;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendTemplateMessage(String content) async {
    if (_conversationId == null) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      await _supabase.from('messages').insert({
        'conversation_id': _conversationId!,
        'sender_id': user.id,
        'content': content,
      });
      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', _conversationId!);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update deal status')),
      );
    }
  }

  Future<void> _confirmDealCompletion() async {
    if (_processingDealAction) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Deal as Done?'),
        content: const Text(
          'This will send a confirmation in the chat so both parties have a record of the completed purchase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Done'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingDealAction = true);
    await _sendTemplateMessage('✅ Deal completed! Thank you for the purchase.');
    setState(() => _processingDealAction = false);
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send Payment Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick an option to automatically share payment information in chat.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _paymentOptionTile(
                  icon: Icons.qr_code_2,
                  title: 'Share UPI / QR',
                  subtitle: 'Send a note to pay via UPI apps',
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendTemplateMessage(
                      '💸 Pay via UPI: Please use my UPI ID / QR to complete the payment.',
                    );
                  },
                ),
                _paymentOptionTile(
                  icon: Icons.account_balance,
                  title: 'Share Bank Transfer',
                  subtitle: 'Send a reminder to transfer via bank',
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendTemplateMessage(
                      '🏦 Bank transfer preferred. I will share account details privately.',
                    );
                  },
                ),
                _paymentOptionTile(
                  icon: Icons.payments,
                  title: 'Custom Payment Link',
                  subtitle: 'Paste a Razorpay/Stripe link',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final link = await _askForPaymentLink();
                    if (link != null && link.trim().isNotEmpty) {
                      _sendTemplateMessage('🔗 Pay here: $link');
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askForPaymentLink() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Payment Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _paymentOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF8b5cf6).withOpacity(0.1),
        child: Icon(icon, color: const Color(0xFF8b5cf6)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDealActions() {
    if (_conversationId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.verified),
              label: _processingDealAction
                  ? const Text('Saving...')
                  : const Text('Deal Done'),
              onPressed: _processingDealAction ? null : _confirmDealCompletion,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Pay Now'),
              onPressed: _showPaymentOptions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final user = Provider.of<AuthProvider>(context).user;
    final isOwnMessage = message['sender_id'] == user?.id;

    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isOwnMessage ? const Color(0xFF8b5cf6) : Colors.grey[200],
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isOwnMessage ? const Radius.circular(4) : null,
            bottomLeft: !isOwnMessage ? const Radius.circular(4) : null,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] as String? ?? '',
              style: TextStyle(
                color: isOwnMessage ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['created_at'] as String? ?? ''),
                  style: TextStyle(
                    color: isOwnMessage ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (isOwnMessage) ...[
                  const SizedBox(width: 4),
                  Text(
                    message['is_read'] == true ? '✓✓' : '✓',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF8b5cf6),
              backgroundImage: _otherUser?['profile_picture_url'] != null
                  ? NetworkImage(_otherUser!['profile_picture_url'] as String)
                  : null,
              child: _otherUser?['profile_picture_url'] == null
                  ? Text(
                      (_otherUser?['display_name'] as String? ??
                              _otherUser?['username'] as String? ??
                              '?')[0]
                          .toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser?['display_name'] as String? ??
                        _otherUser?['username'] as String? ??
                        'User',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8b5cf6),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8b5cf6)),
            )
          : Column(
              children: [
                // Messages List
                _buildDealActions(),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('💬', style: TextStyle(fontSize: 60)),
                              SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Start a conversation!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) =>
                              _buildMessageBubble(_messages[index]),
                        ),
                ),
                // Input Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
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
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
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
                            onPressed: _sending ? null : _sendMessage,
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
