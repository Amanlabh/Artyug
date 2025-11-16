import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_config.dart';

class YugAIService {
  static final YugAIService _instance = YugAIService._internal();
  factory YugAIService() => _instance;
  YugAIService._internal();

  GenerativeModel? _model;
  final List<Content> _conversationHistory = [];
  bool _isAvailable = false;

  static const String _systemPrompt = '''
You are YugAI, the AI assistant for Artयुग (ArtYug), a creative platform for artists, creators, and art lovers.
ArtYug was founded by Aman Labh (Founder & CEO) and built in one week in React Native.

Your rules:
- Always respond in 40 words or less.
- If the user asks to navigate (e.g., "Go to chat", "Open explore", "Show my profile"), return a navigation action for the correct screen: Home, Chat, Explore, Profile.
- You know all about ArtYug, its features, and its founder.
- Always introduce yourself as YugAI, here to help.

Be concise, helpful, and friendly.
''';

  void initialize() {
    if (ApiConfig.validateApiKeys()) {
      try {
        _model = GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: ApiConfig.geminiApiKey,
        );
        _isAvailable = true;
      } catch (e) {
        _isAvailable = false;
      }
    } else {
      _isAvailable = false;
    }
  }

  String _trimToWordLimit(String text, {int limit = 40}) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length > limit) {
      return '${words.take(limit).join(' ')}...';
    }
    return text;
  }

  Future<String> initializeConversation() async {
    if (!_isAvailable) {
      return 'Hello! I\'m YugAI, your creative assistant. Please configure your Gemini API key to enable AI features.';
    }

    try {
      if (_model != null) {
        final response = await _model!.generateContent([Content.text(_systemPrompt)]);
        _conversationHistory.clear();
        _conversationHistory.add(Content.text(_systemPrompt));
        _conversationHistory.add(Content.text('Hello! I\'m YugAI, your creative assistant. How can I help you with your art journey today?'));
        return _trimToWordLimit(response.text ?? 'Hello! I\'m YugAI, your creative assistant. How can I help you today?');
      }
    } catch (e) {
      return 'Hello! I\'m YugAI, your creative assistant. How can I help you today?';
    }
    return 'Hello! I\'m YugAI, your creative assistant. How can I help you today?';
  }

  Future<Map<String, dynamic>> processUserInput(
    String userInput, {
    Map<String, dynamic>? userContext,
  }) async {
    if (!_isAvailable) {
      final fallbackResponses = {
        'upload': 'I can help you upload artwork! Navigate to the upload section to share your creativity.',
        'explore': 'Let\'s explore amazing artwork from our community!',
        'communities': 'Join creative communities and connect with fellow artists.',
        'messages': 'Check your messages and stay connected with the art community.',
        'profile': 'I\'ll take you to your profile where you can manage your artwork and settings.',
        'help': 'I\'m here to help! You can ask me to upload artwork, find events, explore galleries, or navigate to any section of the app.',
        'hello': 'Hello! I\'m YugAI, your creative assistant. Please configure your Gemini API key for enhanced AI features.',
      };

      final lowerInput = userInput.toLowerCase();
      final fallbackKey = fallbackResponses.keys.firstWhere(
        (key) => lowerInput.contains(key),
        orElse: () => '',
      );

      return {
        'response': fallbackResponses[fallbackKey] ??
            'I\'m here to help with your creative journey! Please configure your Gemini API key for enhanced AI features.',
        'navigationAction': _extractNavigationIntent(userInput, ''),
        'confidence': 0.5,
      };
    }

    try {
      final contextPrompt = '''
User Context:
- Current section: ${userContext?['currentSection'] ?? 'Home'}
- User type: ${userContext?['userType'] ?? 'Artist'}
- Recent activity: ${userContext?['recentActivity'] ?? 'None'}

User Input: "$userInput"

Please provide a helpful response and suggest relevant actions. If the user wants to navigate somewhere, include the navigation action in your response.
''';

      _conversationHistory.add(Content.text(userInput));

      if (_model != null) {
        final response = await _model!.generateContent(_conversationHistory);
        final responseText = response.text ?? '';
        final trimmedResponse = _trimToWordLimit(responseText, limit: 40);

        _conversationHistory.add(Content.text(trimmedResponse));

        return {
          'response': trimmedResponse,
          'navigationAction': _extractNavigationIntent(userInput, trimmedResponse),
          'confidence': _calculateConfidence(userInput, trimmedResponse),
        };
      }
    } catch (e) {
      return {
        'response':
            'I apologize, but I\'m having trouble processing your request right now. Please try again or use the menu to navigate manually.',
        'navigationAction': null,
        'confidence': 0.0,
      };
    }

    return {
      'response': 'I apologize, but I\'m having trouble processing your request right now.',
      'navigationAction': null,
      'confidence': 0.0,
    };
  }

  Map<String, dynamic>? _extractNavigationIntent(String userInput, String response) {
    final input = userInput.toLowerCase();
    final responseText = response.toLowerCase();

    if (input.contains('upload') || input.contains('share') || input.contains('post')) {
      return {
        'action': 'navigate',
        'destination': 'Upload',
        'reason': 'User wants to upload or share content',
      };
    }
    if (input.contains('explore') || input.contains('discover') || input.contains('find')) {
      return {
        'action': 'navigate',
        'destination': 'Explore',
        'reason': 'User wants to explore or discover content',
      };
    }
    if (input.contains('community') || input.contains('communities') || input.contains('join')) {
      return {
        'action': 'navigate',
        'destination': 'Communities',
        'reason': 'User wants to access communities',
      };
    }
    if (input.contains('message') || input.contains('chat') || input.contains('talk')) {
      return {
        'action': 'navigate',
        'destination': 'Chat',
        'reason': 'User wants to access chat/messages',
      };
    }
    if (input.contains('profile') ||
        input.contains('account') ||
        input.contains('settings') ||
        input.contains('me')) {
      return {
        'action': 'navigate',
        'destination': 'Profile',
        'reason': 'User wants to access profile or settings',
      };
    }
    if (input.contains('premium') ||
        input.contains('upgrade') ||
        input.contains('subscription')) {
      return {
        'action': 'navigate',
        'destination': 'Premium',
        'reason': 'User wants to access premium features',
      };
    }
    if (input.contains('home') || input.contains('main feed')) {
      return {
        'action': 'navigate',
        'destination': 'Home',
        'reason': 'User wants to go to the home screen',
      };
    }
    if (input.contains('artwork') ||
        input.contains('painting') ||
        input.contains('drawing') ||
        input.contains('gallery')) {
      return {
        'action': 'navigate',
        'destination': 'Explore',
        'reason': 'User is looking for artwork',
      };
    }
    if (input.contains('event') ||
        input.contains('workshop') ||
        input.contains('exhibition') ||
        input.contains('meetup')) {
      return {
        'action': 'navigate',
        'destination': 'Explore',
        'reason': 'User is looking for events',
      };
    }
    return null;
  }

  double _calculateConfidence(String userInput, String response) {
    double confidence = 0.5;

    final navigationKeywords = [
      'upload',
      'explore',
      'community',
      'message',
      'profile',
      'premium',
      'home'
    ];
    final hasNavigationKeyword = navigationKeywords.any(
      (keyword) => userInput.toLowerCase().contains(keyword),
    );

    if (hasNavigationKeyword) {
      confidence += 0.3;
    }

    final artKeywords = [
      'art',
      'painting',
      'drawing',
      'gallery',
      'artist',
      'creative'
    ];
    final hasArtKeyword = artKeywords.any(
      (keyword) => userInput.toLowerCase().contains(keyword),
    );

    if (hasArtKeyword) {
      confidence += 0.2;
    }

    final offTopicKeywords = ['weather', 'news', 'sports', 'politics'];
    final hasOffTopicKeyword = offTopicKeywords.any(
      (keyword) => userInput.toLowerCase().contains(keyword),
    );

    if (hasOffTopicKeyword) {
      confidence -= 0.3;
    }

    return confidence.clamp(0.0, 1.0);
  }

  Future<String> getCreativeInspiration({Map<String, dynamic>? userPreferences}) async {
    if (!_isAvailable || _model == null) {
      return 'Try exploring different art styles or techniques. Sometimes the best inspiration comes from stepping outside your comfort zone!';
    }

    try {
      final prompt = '''
Generate creative inspiration for an artist. Consider these preferences:
- Art style: ${userPreferences?['artStyle'] ?? 'Any'}
- Medium: ${userPreferences?['medium'] ?? 'Any'}
- Mood: ${userPreferences?['mood'] ?? 'Creative'}

Provide:
1. A creative prompt or idea
2. Suggested techniques or approaches
3. Inspiration sources
4. Encouraging message

Keep it concise and inspiring.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? 'Try exploring different art styles or techniques.';
    } catch (e) {
      return 'Try exploring different art styles or techniques. Sometimes the best inspiration comes from stepping outside your comfort zone!';
    }
  }

  Future<String> getArtTips(String topic) async {
    if (!_isAvailable || _model == null) {
      return 'Practice regularly, experiment with different techniques, and don\'t be afraid to make mistakes. Every artist grows through practice!';
    }

    try {
      final prompt = '''
Provide helpful art tips and advice for: $topic

Include:
1. Practical tips
2. Common mistakes to avoid
3. Recommended resources
4. Encouraging advice

Keep it concise and actionable.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ??
          'Practice regularly, experiment with different techniques, and don\'t be afraid to make mistakes. Every artist grows through practice!';
    } catch (e) {
      return 'Practice regularly, experiment with different techniques, and don\'t be afraid to make mistakes. Every artist grows through practice!';
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  List<Content> getConversationSummary() {
    final length = _conversationHistory.length;
    return length > 5 ? _conversationHistory.sublist(length - 5) : _conversationHistory;
  }
}



