class ApiConfig {
  // Gemini AI API Key
  static const String geminiApiKey = 'AIzaSyBoEpP_5Cs6qIT4e8GKH5lnTzasY3tKSa0';
  
  // Validate API keys
  static bool validateApiKeys() {
    if (geminiApiKey.isEmpty || geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return false;
    }
    return true;
  }
}



