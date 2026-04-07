import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../config/api_config.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Art Assistant Screen — Powered by Gemini
// Capabilities:
//   1. Chat: ask art-related questions (style advice, pricing, mediums)
//   2. Image analysis: upload an artwork → get AI critique / description
//   3. Preset prompts for common artist needs
// Design: cream/orange/black editorial-brutalist
// ─────────────────────────────────────────────────────────────────────────────

class AiArtAssistantScreen extends StatefulWidget {
  const AiArtAssistantScreen({super.key});

  @override
  State<AiArtAssistantScreen> createState() => _AiArtAssistantScreenState();
}

class _AiArtAssistantScreenState extends State<AiArtAssistantScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl  = TextEditingController();
  final List<_ChatMessage> _messages = [];

  bool _thinking = false;
  Uint8List? _pendingImageBytes;
  String? _geminiApiKey;
  GenerativeModel? _model;
  ChatSession? _chat;

  static const _systemPrompt = '''
You are the Artyug Art Assistant — a knowledgeable, friendly AI for artists 
and art collectors on the Artyug platform. You help with:
• Art critique and style analysis
• Pricing advice for artworks (INR-aware for Indian market)
• Mediums, techniques, and best practices
• Art history and movement context
• Writing artist statements and descriptions
• Blockchain certificates and authenticity for collectors
Keep replies concise, practical, and encouraging. 
Use some emojis to make responses friendly.
''';

  @override
  void initState() {
    super.initState();
    _initGemini();
    _addWelcome();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _initGemini() {
    _geminiApiKey = ApiConfig.geminiApiKey.isNotEmpty
        ? ApiConfig.geminiApiKey
        : null;

    if (_geminiApiKey != null && _geminiApiKey!.isNotEmpty) {
      _model = GenerativeModel(
        model: ApiConfig.geminiModel,
        apiKey: _geminiApiKey!,
        systemInstruction: Content.system(_systemPrompt),
      );
      _chat = _model!.startChat();
    }
  }

  void _addWelcome() {
    _messages.add(const _ChatMessage(
      role: _Role.assistant,
      text: '🎨 Hi! I\'m your Artyug Art Assistant, powered by Gemini.\n\n'
          'I can help you with:\n'
          '• **Art critique** — upload a photo for feedback\n'
          '• **Pricing advice** — for the Indian art market\n'
          '• **Techniques** — mediums, styles, and methods\n'
          '• **Artist statements** — writing compelling descriptions\n\n'
          'What can I help you create today?',
    ));
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _pendingImageBytes == null) return;

    final imageBytes = _pendingImageBytes;
    _inputCtrl.clear();
    setState(() {
      _pendingImageBytes = null;
      _messages.add(_ChatMessage(
        role: _Role.user,
        text: text,
        imageBytes: imageBytes,
      ));
      _thinking = true;
    });
    _scrollToBottom();

    // No API key — use smart demo responses
    if (_chat == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      final demoReply = _getDemoResponse(text, imageBytes != null);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: _Role.assistant, text: demoReply));
          _thinking = false;
        });
        _scrollToBottom();
      }
      return;
    }

    try {
      List<Part> parts = [];
      if (text.isNotEmpty) parts.add(TextPart(text));
      if (imageBytes != null) {
        parts.add(DataPart('image/jpeg', imageBytes));
        if (text.isEmpty) {
          parts.add(TextPart('Please analyse this artwork and provide critique, '
              'style notes, and any observations about technique.'));
        }
      }

      final response = await _chat!.sendMessage(Content.multi(parts));
      final reply = response.text ?? 'I couldn\'t generate a response. Try again.';

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(role: _Role.assistant, text: reply));
          _thinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: _Role.assistant,
            text: '⚠️ Couldn\'t reach Gemini right now. '
                'Check your GEMINI_API_KEY in .env or try again later.',
          ));
          _thinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _getDemoResponse(String input, bool hasImage) {
    if (hasImage) {
      return '🎨 **Artwork Analysis**\n\n'
          'This piece shows strong compositional instincts — '
          'the use of negative space creates visual breathing room.\n\n'
          '**Style Notes:**\n'
          '• The colour palette leans warm, suggesting emotional depth\n'
          '• Brushwork is expressive and gestural\n'
          '• The focal point draws the eye naturally\n\n'
          '**Suggestions:**\n'
          '• Consider adding a mid-tone to bridge darks and lights\n'
          '• A title that references the emotional undertone would strengthen collector appeal\n\n'
          '_Connect a Gemini API key in .env for full AI analysis._';
    }

    final lower = input.toLowerCase();
    if (lower.contains('price') || lower.contains('sell') || lower.contains('₹')) {
      return '💰 **Pricing Your Art (India)**\n\n'
          'A good starting formula for emerging artists:\n\n'
          'Price = (Material cost × 3) + (Hours × ₹300–500/hr)\n\n'
          'For a 24×36" canvas with 20 hours of work:\n'
          '• Materials: ₹2,000 × 3 = ₹6,000\n'
          '• Labour: 20 × ₹400 = ₹8,000\n'
          '• **Suggested: ₹14,000–18,000**\n\n'
          'Factor in your following, exhibition history, and medium. '
          'Watercolours typically fetch less than oils for the same size.';
    }
    if (lower.contains('statement') || lower.contains('description')) {
      return '✍️ **Artist Statement Tips**\n\n'
          'Great artist statements answer 3 questions:\n\n'
          '1. **What** — What do you make and with what materials?\n'
          '2. **Why** — What drives or inspires your work?\n'
          '3. **Impact** — What do you want viewers to feel or think?\n\n'
          'Keep it 100–200 words. Avoid jargon.\n\n'
          'Template: *"I create [medium] works that explore [theme]. '
          'Inspired by [source], my practice examines [idea]. '
          'I want viewers to [emotion/reflection]."*';
    }
    if (lower.contains('medium') || lower.contains('technique') ||
        lower.contains('paint') || lower.contains('oil') ||
        lower.contains('watercolour') || lower.contains('acrylic')) {
      return '🖌️ **Medium Comparison**\n\n'
          '**Oil paint** — Rich depth, slow drying, highly valued. '
          'Best for large canvases and layered techniques.\n\n'
          '**Watercolour** — Delicate, luminous, portable. '
          'Demands confidence — mistakes are hard to fix.\n\n'
          '**Acrylics** — Versatile, fast-drying, water-clean. '
          'Can mimic both oil and watercolour effects.\n\n'
          '**Mixed media** — Combines materials for texture and depth. '
          'Very popular with contemporary collectors.';
    }
    return '🎨 Great question! I\'m currently running in demo mode without a live Gemini API key.\n\n'
        'To enable full AI responses:\n'
        '1. Get a free key at **ai.google.dev**\n'
        '2. Add `GEMINI_API_KEY=your_key` to your `.env` file\n'
        '3. Restart the app\n\n'
        'In the meantime, try the preset prompts below for demo responses on '
        'pricing, artist statements, and technique advice!';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() => _pendingImageBytes = bytes);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _usePreset(String prompt) {
    _inputCtrl.text = prompt;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

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
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Art Assistant',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  hasKey ? ApiConfig.geminiModel : 'Demo mode',
                  style: TextStyle(
                    color: hasKey ? AppColors.success : AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textTertiary),
            tooltip: 'New conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                if (_model != null) _chat = _model!.startChat();
                _addWelcome();
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      body: Column(
        children: [
          // ── Preset chips ─────────────────────────────────────────────
          _PresetBar(onSelect: _usePreset),

          // ── Messages ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  return const _ThinkingBubble();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),

          // ── Image preview ─────────────────────────────────────────────
          if (_pendingImageBytes != null) ...[
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _pendingImageBytes!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image ready — add a question or send for analysis',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _pendingImageBytes = null),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
          ],

          // ── Input bar ────────────────────────────────────────────────
          _InputBar(
            controller: _inputCtrl,
            thinking: _thinking,
            onSend: _sendMessage,
            onPickImage: _pickImage,
          ),
        ],
      ),
    );
  }
}

// ─── Preset Bar ──────────────────────────────────────────────────────────────

class _PresetBar extends StatelessWidget {
  final void Function(String) onSelect;

  const _PresetBar({required this.onSelect});

  static const _presets = [
    ('💰 Price my art', 'How should I price a medium-sized oil painting that took 3 weeks to create?'),
    ('✍️ Artist statement', 'Help me write a compelling artist statement for a contemporary abstract series'),
    ('🖌️ Compare mediums', 'What are the pros and cons of oils vs acrylics for a beginner?'),
    ('🏛️ Collector tips', 'What should a first-time art collector look for when verifying authenticity?'),
    ('📸 Describe art', 'Describe this artwork as it would appear in a gallery catalogue'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (label, prompt) = _presets[i];
          return GestureDetector(
            onTap: () => onSelect(prompt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == _Role.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (msg.imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      msg.imageBytes!,
                      width: 200,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (msg.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isUser ? 14 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 14),
                      ),
                      border: isUser
                          ? null
                          : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Thinking Bubble ──────────────────────────────────────────────────────────

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('✦', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay),
        () => _ctrl.repeat(reverse: true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.textTertiary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool thinking;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.thinking,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Image button
          IconButton(
            icon: const Icon(Icons.image_outlined,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'Attach artwork image',
            onPressed: thinking ? null : onPickImage,
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask about art, technique, pricing...',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                filled: true,
                fillColor: AppColors.surfaceVariant,
              ),
              onSubmitted: (_) => thinking ? null : onSend(),
            ),
          ),

          const SizedBox(width: 4),

          // Send button
          GestureDetector(
            onTap: thinking ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: thinking
                    ? AppColors.surfaceVariant
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

enum _Role { user, assistant }

class _ChatMessage {
  final _Role role;
  final String text;
  final Uint8List? imageBytes;

  const _ChatMessage({
    required this.role,
    required this.text,
    this.imageBytes,
  });
}
