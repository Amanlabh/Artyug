import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/main_tab_provider.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/main/main_tabs_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/public_profile_screen.dart';
import '../screens/communities/community_detail_screen.dart';
import '../screens/communities/community_channel_chat_screen.dart';
import '../screens/communities/create_community_screen.dart';
import '../screens/communities/edit_community_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/tickets/tickets_screen.dart';
import '../screens/nft/nft_screen.dart';

// ── Feature screens ──────────────────────────────────────────────────────────
import '../features/artworks/artwork_detail_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/checkout/order_confirm_screen.dart';
import '../features/authenticity/qr_verify_screen.dart';
import '../features/authenticity/qr_result_screen.dart';
import '../features/dashboard/creator/creator_dashboard_screen.dart';
import '../features/dashboard/collector/collector_dashboard_screen.dart';
import '../models/painting.dart';
import '../models/certificate.dart' as cert_schema;
import '../repositories/certificate_repository.dart';
import '../repositories/order_repository.dart' show OrderResult;
import '../models/order.dart' as app_order;

// ── New feature screens ──────────────────────────────────────────────────────
import '../features/onboarding/onboarding_screen.dart';
import '../features/authenticity/authenticity_center_screen.dart';
import '../features/authenticity/nfc_scan_screen.dart';
import '../features/certificates/certificate_screens.dart' as cert_ui;
import '../features/orders/order_screens.dart';
import '../features/events/event_screens.dart';
import '../features/communities/guild_home_screen.dart';
import '../features/communities/community_feed_screen.dart';
import '../features/upload/upload_artwork_screen.dart';
import '../features/ai/ai_art_assistant_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/legal/terms_acceptance_screen.dart';

class AppRouter {
  /// [auth] must be the same [AuthProvider] instance registered in [Provider];
  /// [refreshListenable] re-runs [redirect] after login, logout, and onboarding refresh.
  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: '/sign-in',
      refreshListenable: auth,
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAuthenticated = authProvider.isAuthenticated;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == '/sign-in' || loc == '/sign-up';
        final isPublicRoute = loc.startsWith('/qr-result') ||
            loc == '/verify' ||
            loc == '/nfc-scan' ||
            loc == '/onboarding';

        if (!authProvider.loading) {
          if (!isAuthenticated && !isAuthRoute && !isPublicRoute) {
            return '/sign-in';
          }

          // Logged in but onboarding not finished
          if (isAuthenticated && !authProvider.onboardingComplete) {
            if (loc == '/onboarding') return null;
            // Session restored on /sign-in → send straight to wizard
            if (isAuthRoute) return '/onboarding';
            if (isPublicRoute) return null;
            return '/onboarding';
          }

          // Onboarded but terms not accepted (per-device / per-user prefs)
          if (isAuthenticated &&
              authProvider.onboardingComplete &&
              !authProvider.termsAccepted) {
            if (loc == '/terms-acceptance') return null;
            return '/terms-acceptance';
          }

          // Logged in + onboarded: never stay on auth or onboarding
          if (isAuthenticated && isAuthRoute) return '/main';
          if (isAuthenticated &&
              loc == '/onboarding' &&
              authProvider.onboardingComplete) {
            return '/main';
          }
        }
        return null;
      },
      routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
          path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(
          path: '/sign-up', builder: (context, state) => const SignUpScreen()),

      // ── Onboarding ────────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/terms-acceptance',
        builder: (context, state) {
          final next = state.uri.queryParameters['next'];
          return TermsAcceptanceScreen(nextLocation: next);
        },
      ),

      // ── Main shell ────────────────────────────────────────────────────────
      GoRoute(
          path: '/main', builder: (context, state) => const MainTabsScreen()),
      GoRoute(
        path: '/explore',
        redirect: (context, state) {
          Provider.of<MainTabProvider>(context, listen: false).setIndex(1);
          return '/main';
        },
      ),

      // ── Core social ───────────────────────────────────────────────────────
      GoRoute(
          path: '/messages',
          builder: (context, state) => const MessagesScreen()),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen()),
      GoRoute(
          path: '/chat/:userId',
          builder: (context, state) {
            return ChatScreen(userId: state.pathParameters['userId']!);
          }),
      GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const EditProfileScreen()),
      GoRoute(
          path: '/public-profile/:userId',
          builder: (context, state) {
            return PublicProfileScreen(userId: state.pathParameters['userId']!);
          }),
      GoRoute(
          path: '/community-detail/:communityId',
          builder: (context, state) {
            return CommunityDetailScreen(
                communityId: state.pathParameters['communityId']!);
          }),
      GoRoute(
          path: '/community-chat/:communityId',
          builder: (context, state) {
            final name = state.uri.queryParameters['name'];
            return CommunityChannelChatScreen(
              communityId: state.pathParameters['communityId']!,
              communityName: name,
            );
          }),
      GoRoute(
          path: '/edit-community/:communityId',
          builder: (context, state) {
            return EditCommunityScreen(
              communityId: state.pathParameters['communityId']!,
            );
          }),
      GoRoute(
          path: '/create-community',
          builder: (context, state) => const CreateCommunityScreen()),
      GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen()),
      GoRoute(
          path: '/premium', builder: (context, state) => const PremiumScreen()),
      GoRoute(
          path: '/tickets', builder: (context, state) => const TicketsScreen()),
      GoRoute(path: '/nft', builder: (context, state) => const NFTScreen()),

      // ── Artworks & Checkout ───────────────────────────────────────────────
      GoRoute(
          path: '/artwork/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final extra = state.extra;
            return ArtworkDetailScreen(
              paintingId: id,
              initialPainting: extra is PaintingModel ? extra : null,
            );
          }),
      GoRoute(
          path: '/checkout/:paintingId',
          builder: (context, state) {
            final paintingId = state.pathParameters['paintingId']!;
            final extra = state.extra;
            return CheckoutScreen(
              paintingId: paintingId,
              initialPainting: extra is PaintingModel ? extra : null,
            );
          }),
      GoRoute(
          path: '/order-confirm',
          builder: (context, state) {
            final result = state.extra as OrderResult;
            return OrderConfirmScreen(result: result);
          }),

      // ── Orders ────────────────────────────────────────────────────────────
      GoRoute(
          path: '/orders',
          builder: (context, state) => const OrderListScreen()),
      GoRoute(
          path: '/order/:id',
          builder: (context, state) {
            final order = state.extra as app_order.OrderModel?;
            if (order != null) return OrderDetailScreen(order: order as app_order.OrderModel);
            // No extra → load asynchronously to avoid blank screen
            return OrderDetailLoadingScreen(
                orderId: state.pathParameters['id']!);
          }),

      // ── Certificates ──────────────────────────────────────────────────────
      GoRoute(
          path: '/certificates',
          builder: (context, state) => const cert_ui.CertificateListScreen()),
      GoRoute(
          path: '/certificate/:id',
          builder: (context, state) {
            final cert = state.extra as cert_ui.CertificateModel?;
            if (cert != null) {
              return cert_ui.CertificateDetailScreen(cert: cert);
            }
            // No extra → load asynchronously to avoid blank screen
            return cert_ui.CertificateLoadingScreen(
                certId: state.pathParameters['id']!);
          }),

      // ── Authenticity & QR / NFC ───────────────────────────────────────────
      GoRoute(
        path: '/authenticity-center',
        builder: (context, state) => const AuthenticityCenter(),
      ),
      GoRoute(
          path: '/verify', builder: (context, state) => const QrVerifyScreen()),
      GoRoute(
          path: '/qr-result',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Map<String, dynamic>) {
              // Manual verify already resolved the certificate
              return QrResultScreen(
                qrCode: extra['qrCode'] as String? ?? '',
                certificate:
                    extra['certificate'] as cert_schema.CertificateModel?,
              );
            }
            // Camera scan — raw QR string, need async DB lookup
            return _QrResultLoader(qrCode: extra as String? ?? '');
          }),

      GoRoute(
          path: '/nfc-scan',
          builder: (context, state) => const NfcScanScreen()),

      // ── Events & Guild ────────────────────────────────────────────────────
      GoRoute(
          path: '/events', builder: (context, state) => const EventsScreen()),
      GoRoute(
          path: '/event/:id',
          builder: (context, state) {
            final event = state.extra as EventModel?;
            if (event != null) return EventDetailScreen(event: event);
            // No extra → load asynchronously to avoid blank screen
            return EventDetailLoadingScreen(
                eventId: state.pathParameters['id']!);
          }),
      GoRoute(
          path: '/guild', builder: (context, state) => const GuildHomeScreen()),
      GoRoute(
          path: '/guild-feed/:communityId',
          builder: (context, state) {
            final name = state.uri.queryParameters['name'];
            return CommunityFeedScreen(
              communityId: state.pathParameters['communityId']!,
              communityName: name,
            );
          }),

      // ── Dashboards ────────────────────────────────────────────────────────
      GoRoute(
          path: '/creator-dashboard',
          builder: (context, state) => const CreatorDashboardScreen()),
      GoRoute(
          path: '/collector-dashboard',
          builder: (context, state) => const CollectorDashboardScreen()),

      // ── Upload ───────────────────────────────────────────────────────────
      GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadArtworkScreen()),

      // ── AI Art Assistant ────────────────────────────────────────────────
      GoRoute(
          path: '/ai-assistant',
          builder: (context, state) => const AiArtAssistantScreen()),

      // ── Global Search ───────────────────────────────────────────────────
      GoRoute(
          path: '/search',
          builder: (context, state) {
            final q = state.uri.queryParameters['q'];
            return SearchScreen(initialQuery: q);
          }),
    ],
    );
  }
}

// ── QR Result async loader ────────────────────────────────────────────────────
/// Runs the DB lookup asynchronously so [QrResultScreen] always receives a
/// resolved [cert_schema.CertificateModel] (or null for unrecognised codes).
class _QrResultLoader extends StatefulWidget {
  const _QrResultLoader({required this.qrCode});
  final String qrCode;
  @override
  State<_QrResultLoader> createState() => _QrResultLoaderState();
}

class _QrResultLoaderState extends State<_QrResultLoader> {
  static const _scheme = 'artyug://certificate/';

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  Future<void> _lookup() async {
    // Normalise: accept full deep-link OR bare UUID/cert-ID
    String code = widget.qrCode.trim();
    if (code.startsWith(_scheme)) {
      code = code.substring(_scheme.length);
    }
    final cert = await CertificateRepository.verifyByQrCode(code)
        .catchError((_) => null as cert_schema.CertificateModel?);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QrResultScreen(
          qrCode: widget.qrCode,
          certificate: cert,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
