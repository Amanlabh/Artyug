# Artyug — Full Project Context for GPT

> **Last Updated:** April 7, 2026  
> **Build Status:** ✅ `flutter build web` → Exit 0  
> **Dev Server:** `npx serve build/web -p 5556`  
> **Platform:** Flutter (Web ✅ | Android ✅ | iOS ready)

---

## 🎨 What is Artyug?

Artyug is a **SocialFi art marketplace** for India's creative economy. Think OpenSea meets Instagram meets Artsy — built in Flutter. Artists upload and sell verified artwork, collectors buy with blockchain-backed authenticity certificates, and both groups engage in social communities (Guilds).

### Design System
- **Style:** Editorial-Brutalist
- **Colors:** Cream `#F5F1EC` (bg), Black `#0A0A0A` (text), Orange `#E8470A` (primary/accent)
- **Font:** Google Fonts — Outfit (headings) + Inter (body)
- **Theme file:** `lib/core/theme/app_colors.dart`

---

## 🗂️ Project Structure

```
artyug-main/
├── lib/
│   ├── main.dart                         # App entry, MultiProvider setup
│   ├── core/
│   │   ├── config/app_config.dart        # Env vars, AppMode, ChainMode
│   │   ├── theme/app_colors.dart         # Design tokens (cream/black/orange)
│   │   ├── constants/                    # Shared constants
│   │   ├── utils/                        # Helpers
│   │   └── errors/                       # Error types
│   ├── router/
│   │   └── app_router.dart              # GoRouter — all 30+ routes
│   ├── providers/
│   │   ├── auth_provider.dart           # Supabase auth state
│   │   ├── app_mode_provider.dart       # Demo/Live runtime toggle (NEW)
│   │   ├── theme_provider.dart          # Light/Dark + AppTheme
│   │   ├── feed_provider.dart           # Feed state
│   │   └── dashboard_provider.dart      # Dashboard state
│   ├── screens/
│   │   ├── main/main_tabs_screen.dart   # Sidebar (desktop) + Bottom nav (mobile) — NEW
│   │   ├── auth/
│   │   │   ├── sign_in_screen.dart
│   │   │   └── sign_up_screen.dart
│   │   ├── explore/explore_screen.dart
│   │   ├── profile/
│   │   │   ├── profile_screen.dart
│   │   │   ├── edit_profile_screen.dart
│   │   │   └── public_profile_screen.dart
│   │   ├── settings/settings_screen.dart  # UPDATED: Demo/Live toggle + Guide replay
│   │   ├── messages/messages_screen.dart
│   │   ├── chat/chat_screen.dart
│   │   ├── notifications/notifications_screen.dart
│   │   ├── communities/
│   │   │   ├── community_detail_screen.dart
│   │   │   └── create_community_screen.dart
│   │   ├── nft/nft_screen.dart
│   │   ├── premium/premium_screen.dart
│   │   ├── tickets/tickets_screen.dart
│   │   └── upload/                       # (duplicate path — see features/upload)
│   ├── features/                         # 21 feature modules
│   │   ├── ai/ai_art_assistant_screen.dart         # Gemini AI chat
│   │   ├── artists/                                # Artist profiles
│   │   ├── artworks/artwork_detail_screen.dart     # Buy Art screen
│   │   ├── auth/                                   # Auth helpers
│   │   ├── authenticity/
│   │   │   ├── authenticity_center_screen.dart     # Hub for QR/NFC
│   │   │   ├── qr_verify_screen.dart               # Camera QR scan
│   │   │   ├── qr_result_screen.dart               # Scan result
│   │   │   └── nfc_scan_screen.dart                # NFC tap
│   │   ├── certificates/
│   │   │   └── certificate_screens.dart            # CertificateListScreen, CertificateDetailScreen
│   │   ├── checkout/
│   │   │   ├── checkout_screen.dart                # Payment flow
│   │   │   └── order_confirm_screen.dart           # Success screen
│   │   ├── collections/                            # Collector collections
│   │   ├── communities/
│   │   │   ├── guild_home_screen.dart              # Guild listing
│   │   │   └── community_feed_screen.dart          # Guild posts feed
│   │   ├── dashboard/
│   │   │   ├── creator/creator_dashboard_screen.dart   # Revenue/earnings
│   │   │   └── collector/collector_dashboard_screen.dart # Spend/portfolio
│   │   ├── events/event_screens.dart               # EventsScreen + EventDetailScreen
│   │   ├── feed/feed_screen.dart                   # Main social feed
│   │   ├── home/                                   # Home widgets
│   │   ├── messages/                               # DM list
│   │   ├── nft/                                    # NFT minting
│   │   ├── notifications/                          # Push notifications
│   │   ├── onboarding/onboarding_screen.dart       # Brand splash (pre-auth)
│   │   ├── orders/order_screens.dart               # OrderListScreen, OrderDetailScreen, OrderDetailLoadingScreen (NEW)
│   │   ├── profile/                                # Profile feature widgets
│   │   ├── settings/                               # Settings feature
│   │   └── upload/upload_artwork_screen.dart       # Artist artwork upload
│   ├── models/
│   │   └── painting.dart                           # PaintingModel
│   ├── repositories/
│   │   └── order_repository.dart                   # OrderResult type
│   ├── services/
│   │   ├── gemini_ai_service.dart                  # YugAIService (Gemini 1.5)
│   │   ├── blockchain/                             # Solana integration (demo)
│   │   ├── nfc/                                    # NFC service (mobile)
│   │   ├── payments/                               # Payment gateway stubs
│   │   ├── qr/                                     # QR generation
│   │   └── supabase/                               # (empty — Supabase used directly)
│   └── widgets/
│       ├── onboarding_guide.dart                   # In-app 5-slide guide — NEW
│       ├── cards/                                  # ArtCard, CollectorCard, etc.
│       ├── common/                                 # SharedWidgets
│       ├── dashboard/                              # Chart widgets
│       └── feed/                                   # Feed item widgets
├── assets/
│   └── images/                                     # Static art images
├── .env                                            # Secrets (gitignored)
├── .env.example                                    # Template with all required keys
└── pubspec.yaml
```

---

## 📦 Dependencies (pubspec.yaml)

| Package | Purpose |
|---|---|
| `flutter_dotenv ^5.1.0` | `.env` support |
| `go_router ^13.0.0` | Navigation / deep links |
| `provider ^6.1.1` | State management |
| `supabase_flutter ^2.0.0` | Auth + DB + Storage |
| `google_generative_ai ^0.4.0` | Gemini AI (YugAIService) |
| `shared_preferences ^2.2.2` | Persist mode, onboarding seen flag |
| `google_fonts ^6.1.0` | Outfit typeface |
| `cached_network_image ^3.3.0` | Artwork images |
| `flutter_svg ^2.0.9` | SVG icons |
| `image_picker ^1.0.5` | Upload artwork |
| `file_picker ^11.0.1` | File selection |
| `qr_flutter ^4.1.0` | QR code on certificates |
| `mobile_scanner ^3.5.7` | Camera QR scanning (mobile only) |
| `fl_chart ^0.68.0` | Revenue/spend charts |
| `shimmer ^3.0.0` | Loading skeletons |
| `flutter_staggered_grid_view ^0.7.0` | Artwork masonry grid |
| `intl ^0.19.0` | INR currency formatting |
| `uuid ^4.3.3` | Order/certificate IDs |
| `url_launcher ^6.2.2` | External links |
| `share_plus ^7.2.1` | Share artwork |
| `animations ^2.0.8` | Page transitions |
| `flutter_local_notifications ^19.5.0` | Push notifications |
| `http ^1.1.0` + `dio ^5.4.0` | HTTP requests |

---

## 🌐 All Routes (GoRouter)

| Path | Screen | Auth Required |
|---|---|---|
| `/sign-in` | SignInScreen | ❌ |
| `/sign-up` | SignUpScreen | ❌ |
| `/onboarding` | OnboardingScreen (brand splash) | ❌ |
| `/main` | MainTabsScreen (sidebar shell) | ✅ |
| `/explore` | (handled inside MainTabsScreen) | ✅ |
| `/messages` | MessagesScreen | ✅ |
| `/profile` | ProfileScreen | ✅ |
| `/settings` | SettingsScreen | ✅ |
| `/edit-profile` | EditProfileScreen | ✅ |
| `/public-profile/:userId` | PublicProfileScreen | ✅ |
| `/chat/:userId` | ChatScreen | ✅ |
| `/notifications` | NotificationsScreen | ✅ |
| `/premium` | PremiumScreen | ✅ |
| `/tickets` | TicketsScreen | ✅ |
| `/nft` | NFTScreen | ✅ |
| `/community-detail/:communityId` | CommunityDetailScreen | ✅ |
| `/create-community` | CreateCommunityScreen | ✅ |
| `/artwork/:id` | ArtworkDetailScreen | ✅ |
| `/checkout/:paintingId` | CheckoutScreen | ✅ |
| `/order-confirm` | OrderConfirmScreen | ✅ |
| `/orders` | OrderListScreen | ✅ |
| `/order/:id` | OrderDetailScreen (+ async loader) | ✅ |
| `/certificates` | CertificateListScreen | ✅ |
| `/certificate/:id` | CertificateDetailScreen | ✅ |
| `/authenticity-center` | AuthenticityCenter | ✅ |
| `/verify` | QrVerifyScreen | ❌ public |
| `/qr-result` | QrResultScreen | ❌ public |
| `/nfc-scan` | NfcScanScreen | ✅ |
| `/events` | EventsScreen | ✅ |
| `/event/:id` | EventDetailScreen | ✅ |
| `/guild` | GuildHomeScreen | ✅ |
| `/guild-feed/:communityId` | CommunityFeedScreen | ✅ |
| `/creator-dashboard` | CreatorDashboardScreen | ✅ |
| `/collector-dashboard` | CollectorDashboardScreen | ✅ |
| `/upload` | UploadArtworkScreen | ✅ |
| `/ai-assistant` | AiArtAssistantScreen | ✅ |

---

## ✅ COMPLETED — What's Done

### Foundation
- [x] `AppConfig` — reads `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY` from `.env`
- [x] `AppMode` enum (`demo` / `live`) + `ChainMode` enum (`testnet` / `mainnet`)
- [x] `AppColors` design tokens (cream/black/orange system)
- [x] `ThemeProvider` — light/dark mode + full `AppTheme` (MaterialTheme)
- [x] `AppRouter` — 35+ routes with auth redirect guard
- [x] Bottom navigation (mobile) + **OpenSea-style sidebar** (desktop ≥800px) — **NEW**
- [x] Adaptive layout: sidebar on wide, bottom nav on narrow

### Auth
- [x] Sign In screen (email/password + Supabase)
- [x] Sign Up screen
- [x] Auth guard in GoRouter
- [x] `AuthProvider` (ChangeNotifier wrapping Supabase auth stream)
- [x] Auto-create profile row on first sign-up

### Demo/Live Mode Toggle — **NEW**
- [x] `AppModeProvider` — runtime ChangeNotifier (persists via SharedPreferences)
- [x] Demo/Live badge in sidebar (tap = bottom sheet toggle)
- [x] "DEMO MODE" banner in top bar updates live
- [x] Settings screen "DEVELOPER" section with Live Mode switch
- [x] "Replay App Guide" in settings

### In-App Onboarding Guide — **NEW**
- [x] `OnboardingGuide.showIfNeeded()` — shown once post-login
- [x] 5-slide animated dialog (elastic emoji hero, animated progress dots, slide transitions)
- [x] Per-slide accent color theming
- [x] `OnboardingGuide.reset()` for re-triggering
- [x] Stored via SharedPreferences key `artyug_guide_shown_v2`

### Orders (Blank Page Fix) — **NEW**
- [x] `OrderDetailLoadingScreen` — fallback when `/order/:id` navigated without `extra`
- [x] Fetches demo order by ID first, then Supabase, then falls back to list
- [x] Router updated: `extra == null` → use loader, not list screen

### Social Feed
- [x] `FeedScreen` — artwork cards with like, comment, share
- [x] `FeedProvider` — Supabase `paintings` table with demo fallback
- [x] Like/unlike toggle (Supabase + demo)
- [x] Stories bar at top

### Explore
- [x] `ExploreScreen` — masonry grid, category filter chips
- [x] "Buy Art" button navigates to ArtworkDetailScreen

### Artwork
- [x] `ArtworkDetailScreen` — full artwork info, artist bio, price, "Buy Now" CTA
- [x] Reads from `paintings` table, fallback demo data

### Checkout & Orders
- [x] `CheckoutScreen` — payment options (UPI, Card, Solana demo), order summary
- [x] `OrderConfirmScreen` — success with certificate CTA
- [x] `OrderListScreen` — past orders, filterable by status, demo + live data
- [x] `OrderDetailScreen` — full order info + tracking
- [x] `OrderDetailLoadingScreen` — async load wrapper (prevents blank screen)

### Certificates — Async Loader (NEW)
- [x] `CertificateLoadingScreen` — fallback for `/certificate/:id` without `extra`
- [x] Checks demo certs → Supabase query → falls back to `/certificates` list
- [x] Router updated: `extra == null` → use loader, not list screen

### Events — Async Loader (NEW)
- [x] `EventDetailLoadingScreen` — fallback for `/event/:id` without `extra`
- [x] Checks demo events → Supabase query → falls back to `/events` list
- [x] Router updated: `extra == null` → use loader, not events screen

### Push Notifications (NEW)
- [x] `NotificationService` singleton — `lib/services/notifications/notification_service.dart`
- [x] Initialised in `main()` after `Supabase.initialize`; no-op on web
- [x] Supabase Realtime subscription: `orders` table — fires local push when `status` → `completed`
- [x] Supabase Realtime subscription: `messages` table — fires local push on new DM
- [x] Subscribe on `signedIn`, unsubscribe on `signedOut` (in `AuthProvider`)
- [x] Resume-session handled: subscribes at startup if session already active
- [x] `sendDemo()` method for testing without real data

### Authenticity System
- [x] `AuthenticityCenter` — hub with QR scan, NFC scan, manual verify
- [x] `QrVerifyScreen` — camera scanner (mobile), manual code entry
- [x] `QrResultScreen` — shows verified artwork info
- [x] `NfcScanScreen` — NFC tap UI (web fallback for desktop)
- [x] `CertificateListScreen` + `CertificateDetailScreen` — shows ownership QR code

### Dashboards
- [x] `CreatorDashboardScreen` — revenue chart, top artworks, total sales
- [x] `CollectorDashboardScreen` — portfolio value, spend chart, collection overview
- [x] `fl_chart` revenue & spend charts

### Communities / Guilds
- [x] `GuildHomeScreen` — list of guilds with join/leave
- [x] `CommunityFeedScreen` — guild post feed
- [x] `CommunityDetailScreen` — detail + members

### Events
- [x] `EventsScreen` — list of art events (demo + Supabase)
- [x] `EventDetailScreen` — event info, register CTA

### Upload
- [x] `UploadArtworkScreen` — image picker, artwork metadata form, Supabase Storage upload

### AI Assistant
- [x] `AiArtAssistantScreen` — Gemini 1.5 Flash chat
- [x] `YugAIService` — singleton Generative AI service
- [x] Image attach + analysis

### Profile
- [x] `ProfileScreen` — avatar, bio, artworks grid, stats
- [x] `EditProfileScreen` — update name, bio, avatar
- [x] `PublicProfileScreen` — other users' profiles

### Notifications, Messages, Chat
- [x] `NotificationsScreen` — notification list (demo data)
- [x] `MessagesScreen` — DM conversation list
- [x] `ChatScreen` — 1-on-1 chat with Supabase Realtime

### Settings
- [x] `SettingsScreen` — profile, authenticity, notifications, **demo/live toggle**, **guide replay**, account, sign out

### Onboarding (Brand Splash)
- [x] `OnboardingScreen` — pre-auth splash/walkthrough (brand intro, not the in-app guide)

---

## ❌ NOT DONE / TODO

### High Priority (all done ✅)
- [x] **Real payment integration** — Razorpay via Supabase Edge Function `create-razorpay-order`.
  - Web: Edge fn creates Razorpay Order → `url_launcher` opens Hosted Checkout URL
  - Falls back to demo mode if `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` not set
  - `CheckoutScreen` shows pending state while awaiting webhook confirmation
- [x] **Solana blockchain real signing** — `SolanaService.sendMemoAttestation`:
  - Fetches latest blockhash from Solana RPC
  - Builds legacy Memo program transaction with compact-u16 wire encoding
  - Signs using `cryptography` package (Ed25519, pure Dart, web-safe)
  - Decodes base58 keypair via `bs58` package
  - Returns Explorer URL; falls back to synthetic hash if keys absent

### Medium Priority
- [x] **Search** — `SearchScreen` at `/search` with debounced parallel queries across `paintings`, `profiles`, and `community_posts`. Tabbed results (Artworks / Artists / Posts). Top-bar search box and sidebar entry both route here.
- [x] **Social follow/unfollow** — fully implemented in `PublicProfileScreen`: optimistic toggle, `follows` table insert/delete, follower/following counts.
- [x] **Comments** — `_CommentDialog` in `HomeScreen` with full Supabase `post_comments` read/write, author enrichment, and error handling.
- [x] **Artwork likes persistence** — `painting_likes` table with real insert/delete via `PaintingRepository.toggleLike`. Optimistic UI with revert-on-failure in `FeedProvider`. Per-user `isLikedByMe` loaded at feed fetch time.
- [ ] **NFC for mobile** — `nfc_manager` is commented out because it breaks web build. Mobile-only NFC write (during upload, to embed chip signature) not implemented.
- [ ] **Messages / DMs real-time** — `ChatScreen` uses Supabase Realtime — already wired. `MessagesScreen` conversation list also uses Realtime channel. ✅ Both are done.
- [ ] **Premium / Subscriptions** — `PremiumScreen` is a placeholder paywall.
- [ ] **Tickets** — `TicketsScreen` is a stub (event ticketing).
- [ ] **NFT screen** — `NFTScreen` is a stub.

### Low Priority / Polish (noted, not yet started)
- [ ] **Deep link support** — GoRouter routes set up; `flutter_app_links` / custom URL scheme for Android/iOS not configured in native code.
- [ ] **Offline support** — no caching layer; all non-demo data requires network.
- [ ] **Analytics** — no event tracking (Amplitude/Mixpanel/PostHog).
- [ ] **Error boundaries** — some screens surface raw exception strings instead of user-friendly error states.
- [ ] **Web SEO** — no custom `index.html` title/meta tags, no OG tags.
- [ ] **Accessibility** — no semantic labels on artwork images or icons.




---

## 🔐 Environment Variables Required

File: `.env` (copy from `.env.example`)

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

GEMINI_API_KEY=your-gemini-key

APP_MODE=demo              # or "live"
CHAIN_MODE=testnet         # or "mainnet"

# Optional — only needed for live payment mode:
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
SOLANA_RPC_URL=
SOLANA_PROGRAM_ID=
```

---

## 🗄️ Supabase Schema (tables used by the app)

| Table | Used For |
|---|---|
| `profiles` | User profile (id, username, display_name, avatar_url, bio, is_verified) |
| `paintings` | Artworks (id, title, artist_id, image_url, price, medium, is_sold) |
| `painting_likes` | Like/unlike junction (user_id, painting_id) |
| `orders` | Purchase orders (id, buyer_id, painting_id, amount, status, created_at) |
| `certificates` | Authenticity certs (id, order_id, painting_id, qr_code, blockchain_tx) |
| `guilds` / `communities` | Creator guilds |
| `guild_posts` | Posts inside guilds |
| `events` | Art events |
| `messages` | 1-on-1 DMs |
| `notifications` | User notification log |

---

## 🏃 How to Run

```bash
# 1. Install Flutter deps
flutter pub get

# 2. Add your .env file (copy from .env.example)
cp .env.example .env
# → fill in SUPABASE_URL, SUPABASE_ANON_KEY, GEMINI_API_KEY

# 3. Build web
flutter build web --no-tree-shake-icons

# 4. Serve locally
npx serve build/web -p 5556
# → open http://localhost:5556

# 5. Run on device (Android/iOS)
flutter run
```

---

## 🧩 Key Architecture Patterns

1. **Feature-first structure** — each domain (orders, certificates, authenticity…) lives in `lib/features/<name>/` with its own screens and models collocated.
2. **Provider state** — `MultiProvider` at root. Each provider is a `ChangeNotifier`. No Riverpod/BLoC used (by choice).
3. **GoRouter + redirect guard** — all navigation goes through `AppRouter.router`. Auth state drives redirect. Public routes explicitly whitelisted.
4. **Demo/Live duality** — every data-fetching operation checks `AppModeProvider.isDemoMode`. Demo mode returns hardcoded `DemoXxx` lists so the app is fully functional with no backend.
5. **Supabase directly** — no repository abstraction for most features. `Supabase.instance.client` is called from screens. `lib/repositories/` has `OrderRepository` as the only repo class.
6. **Design tokens** — all colors come from `AppColors.*` constants. No hardcoded hex strings in widgets.
7. **Adaptive layout** — `MediaQuery.of(context).size.width >= 800` flips between sidebar and bottom nav layout in `MainTabsScreen`.
