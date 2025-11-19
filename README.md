# ArtYug Flutter App

This is the Flutter version of the ArtYug mobile application - a creative platform for artists, creators, and art lovers.

## Features

- **Authentication**: Sign in/Sign up with email and password
- **Communities**: Create, join, and discover art communities
- **Home Feed**: View and interact with art threads
- **Explore**: Discover new artwork and artists
- **Upload**: Share your creative work
- **Messages**: Connect with other artists
- **Profile**: Manage your profile and artwork
- **AI Assistant**: YugAI powered by Google Gemini AI

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Supabase account (for backend)

## Setup Instructions

1. **Install Flutter**
   ```bash
   # Check Flutter installation
   flutter doctor
   ```

2. **Get Dependencies**
   ```bash
   cd flutter_app
   flutter pub get
   ```

3. **Configure Supabase**
   - The Supabase configuration is already set in `lib/config/supabase_config.dart`
   - Update if needed with your Supabase URL and anon key

4. **Configure API Keys**
   - Update `lib/config/api_config.dart` with your Gemini AI API key if needed

5. **Run the App**
   ```bash
   # For iOS
   flutter run -d ios

   # For Android
   flutter run -d android
   ```

## Project Structure

```
lib/
├── config/           # Configuration files (Supabase, API)
├── components/        # Reusable UI components
├── providers/        # State management (Auth, etc.)
├── router/           # Navigation setup
├── screens/          # Screen widgets
│   ├── auth/         # Authentication screens
│   ├── communities/  # Community-related screens
│   ├── home/         # Home screen
│   ├── explore/      # Explore screen
│   ├── upload/       # Upload screen
│   ├── messages/     # Messages screen
│   ├── profile/      # Profile screens
│   └── ...
├── services/         # Business logic services
└── main.dart         # App entry point
```

## Dependencies

Key dependencies used:
- `supabase_flutter`: Backend integration
- `go_router`: Navigation
- `provider`: State management
- `google_generative_ai`: AI assistant
- `cached_network_image`: Image caching
- `image_picker`: Image selection
- And more...

## Notes

- Some screens are placeholder implementations and need to be fully developed
- The Communities screen is fully implemented as an example
- Authentication flow is complete
- Navigation structure is set up

## Converting from React Native

This Flutter app maintains the same structure and functionality as the original React Native app:
- Same Supabase backend
- Same navigation flow
- Same UI/UX patterns
- Same features and screens

## Development

To contribute or extend:
1. Follow Flutter best practices
2. Use the existing code structure as a template
3. Implement remaining screens following the Communities screen pattern
4. Test on both iOS and Android

## License

Same as the original React Native app.






