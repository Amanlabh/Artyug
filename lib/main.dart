import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/web_oauth_session.dart';
import 'core/config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/app_mode_provider.dart';
import 'providers/main_tab_provider.dart';
import 'router/app_router.dart';
import 'services/gemini_ai_service.dart';
import 'services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env asset
  await dotenv.load(fileName: '.env');

  // Initialize Supabase from env (PKCE + detect OAuth callback in the URL on web)
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUri: true,
    ),
  );

  // Second pass: ensure ?code= is exchanged when app_links / init order misses the callback
  await finalizeWebOAuthSessionIfNeeded();

  // Initialize Gemini AI Service
  YugAIService().initialize();

  // Initialize push notification service (no-op on web)
  await NotificationService.instance.initialize();

  // If a session was already active (app restart), subscribe immediately
  final existingUser = Supabase.instance.client.auth.currentUser;
  if (existingUser != null) {
    NotificationService.instance.subscribeForUser(existingUser.id);
  }

  // Allow landscape on wide screens (web / desktop)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ArtyugApp());
}

class ArtyugApp extends StatefulWidget {
  const ArtyugApp({super.key});

  @override
  State<ArtyugApp> createState() => _ArtyugAppState();
}

class _ArtyugAppState extends State<ArtyugApp> {
  late final AuthProvider _auth = AuthProvider();
  late final GoRouter _router = AppRouter.create(_auth);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => MainTabProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'ArtYug',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _router,
            builder: (context, child) => child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

class _DemoModeBanner extends StatelessWidget {
  const _DemoModeBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.15),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.4), width: 0.5),
            ),
            child: const Text(
              '✦ DEMO MODE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD4AF37),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

