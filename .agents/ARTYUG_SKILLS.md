# Artyug — Installed Skills & Development Reference

> Flutter cross-platform app (Web + Android) — ArtYug creative platform  
> Stack: Flutter 3.x · Dart 3 · Supabase · Provider · GoRouter · Gemini AI · Material Design 3

---

## ✅ Stack Detection Results

| Layer | Technology | Detected |
|---|---|---|
| **Framework** | Flutter 3.x (Dart SDK ≥3.0) | ✅ `pubspec.yaml` |
| **Platforms** | Android + Web + iOS/Desktop dirs | ✅ `/android`, `/web`, `/ios`, `/windows` |
| **Backend** | Supabase (Auth + DB + Storage) | ✅ `supabase_flutter ^2.0.0` |
| **State Management** | Provider (ChangeNotifier) | ✅ `provider ^6.1.1` |
| **Navigation** | GoRouter (declarative, auth-guarded) | ✅ `go_router ^13.0.0` |
| **HTTP / API** | Dio + http | ✅ `dio ^5.4.0`, `http ^1.1.0` |
| **AI Integration** | Google Gemini AI | ✅ `google_generative_ai ^0.4.0` |
| **NFT / Blockchain** | NFT Screen exists, Solana TBD | ✅ `/screens/nft/` |
| **QR / NFC** | Not yet in pubspec (to be added) | 🔶 Needs packages |
| **UI** | Material 3, Shimmer, Staggered Grid | ✅ |
| **Deployment** | Vercel (web), Android native | ✅ `vercel.json` |

---

## 🎯 Installed Skills — Mapped to Artyug Goals

### 1. `@flutter-expert` — Core Flutter Development
**Use for:**
- Widget architecture & composition strategies
- Dart 3 patterns (sealed classes, records, patterns)
- Performance optimization (const widgets, Slivers, lazy lists)
- Platform-channel bridges for QR/NFC native calls
- Responsive layout for web + mobile from a single codebase
- GoRouter auth guards and deep-link configuration
- Material Design 3 theming and dark mode

---

### 2. `@mobile-design` — UI/UX Revamp & Responsive Design
**Use for:**
- Touch-first, platform-respectful UI design
- Adaptive layouts: phone → tablet → web breakpoints
- Navigation patterns (BottomNav, Drawer, TabBar)
- Modal sheets, cards, empty-state illustrations
- Platform-specific interaction cues (Android vs. web)

---

### 3. `@design-spells` — Micro-animations & Polish
**Use for:**
- Skeleton loaders, shimmer effects
- Smooth page transitions with GoRouter's transition builders
- Hero animations for artwork/NFT cards
- Haptic feedback patterns for button taps
- Scroll-based fade-ins for Explore & Home feeds

---

### 4. `@animejs-animation` — Complex Animation Sequences
**Use for:**
- Staggered entrance animations for artwork grids
- Wallet connection / Solana transaction animations
- QR code reveal/scan UI animations
- NFT minting progress animations

> ⚠️ This is a JS animation skill — for Flutter web, combine with `@flutter-expert` to use `flutter_animate` or custom `AnimationController` patterns instead.

---

### 5. `@debugger` — Build & Runtime Error Resolution
**Use for:**
- Supabase auth state errors (`AuthException`, session expiry)
- GoRouter redirect loops (auth guard bugs)
- Widget tree overflow errors on web breakpoints
- PlatformException from plugins on web
- Provider `ChangeNotifier` disposed after widget unmount

---

### 6. `@systematic-debugging` — Deep Diagnostic Workflow
**Use for:**
- Supabase RLS (Row-Level Security) policy failures
- Android build failures (Gradle, manifest, minSdk conflicts)
- Flutter web CORS issues with Supabase endpoints
- Multi-platform state inconsistencies
- Provider not notifying listeners in subtree

---

### 7. `@nft-standards` — NFT & Solana Integration Reference
**Use for:**
- NFT metadata schema (ERC-721 reference for context, Solana equivalents)
- Token validation and display logic
- Artwork → NFT minting flow design
- Wallet connection UX patterns
- Solana demo vs. live flow architecture decisions

> ℹ️ This skill is EVM-focused by default. For Solana: combine with `@api-patterns` for REST-based Solana RPC calls from Flutter.

---

### 8. `@web3-testing` — Blockchain Integration Testing
**Use for:**
- Mocking Solana wallet responses in Flutter tests
- Simulating NFT transaction flows without real SOL
- Testing QR-encoded wallet address display
- Validating Supabase ↔ Solana data sync

---

### 9. `@api-patterns` — Supabase & External API Integration
**Use for:**
- Supabase REST vs. Realtime vs. RPC decisions
- Auth header injection with Dio interceptors
- Pagination patterns for artwork/community feeds
- Gemini AI API request/response handling
- Solana RPC endpoint integration from Flutter

---

### 10. `@supabase-automation` — Supabase Workflow Cleanup
**Use for:**
- Schema migration scripting
- RLS policy generation and testing
- Realtime subscription setup for messages/notifications
- Storage bucket rules for artwork uploads
- Auth provider configuration (Google, GitHub OAuth)

---

### 11. `@frontend-design` — Design System Setup
**Use for:**
- Defining the Artyug color palette and typography system
- Dark/light theme token architecture
- Typography scale for artist platform (display, headline, body)
- Component-level design consistency rules

---

### 12. `@iconsax-library` — Icon System
**Use for:**
- Selecting premium icons for nav bar, action buttons
- QR code, NFC, wallet, and NFT-specific icon choices
- AI-driven icon generation for custom Artyug UI elements

---

### 13. `@ui-skills` — UI Constraint Guardrails
**Use for:**
- Enforcing consistent spacing, sizing, and component patterns
- Preventing ad-hoc style overrides
- Code review checklist for Flutter widget quality

---

### 14. `@mobile-developer` — Android-Specific Patterns
**Use for:**
- Android manifest permissions (NFC, camera for QR)
- Gradle build configuration for Flutter
- ProGuard/R8 rules for release builds
- Play Store compliance checklist

---

### 15. `@lint-and-validate` — Code Quality Gates
**Use for:**
- Running `flutter analyze` after every change
- Catching null safety violations before runtime
- analysis_options.yaml rule enforcement
- Pre-commit validation workflow

---

## 🔶 Packages to Add for QR + NFC

Add these to `pubspec.yaml` when implementing QR/NFC:

```yaml
# QR Code
qr_flutter: ^4.1.0          # QR display
mobile_scanner: ^3.5.0       # QR scanner (camera)

# NFC
nfc_manager: ^3.3.0          # NFC read/write (Android + iOS)

# Solana (REST-based, no native deps conflict)
solana: ^0.30.4              # Solana Dart SDK
```

> ℹ️ `mobile_scanner` and `nfc_manager` require Android manifest updates — use `@mobile-developer` skill.

---

## ❌ Skipped Skills (Not Relevant)

| Skill | Reason Skipped |
|---|---|
| `nextjs-best-practices` | React/Node — not Flutter |
| `react-patterns` | Not applicable |
| `sveltekit` | Not applicable |
| `python-pro` | No Python backend |
| `kubernetes-architect` | No K8s infrastructure |
| `ios-debugger-agent` | Requires Mac + Xcode — Windows dev env |
| `django-pro` | No Django backend |
| `nodejs-backend-patterns` | Not applicable |

---

## 🗂️ Project Quick Reference

```
E:\artyug\Artyug-main\
├── lib/
│   ├── main.dart              # Supabase init, Provider setup
│   ├── config/
│   │   ├── supabase_config.dart   # ⚠️ Hardcoded keys (move to --dart-define)
│   │   └── api_config.dart
│   ├── providers/
│   │   ├── auth_provider.dart    # AuthProvider (ChangeNotifier)
│   │   └── theme_provider.dart   # Dark/light toggle
│   ├── router/
│   │   └── app_router.dart       # GoRouter with auth redirect
│   ├── screens/
│   │   ├── auth/                 # sign-in, sign-up
│   │   ├── home/                 # Feed
│   │   ├── explore/              # Discovery
│   │   ├── communities/          # Groups + detail + create
│   │   ├── nft/                  # NFT screen (Solana entry point)
│   │   ├── premium/              # Subscription
│   │   ├── tickets/              # Events
│   │   ├── profile/              # Public + edit profile
│   │   ├── messages/ + chat/     # DMs
│   │   ├── notifications/
│   │   ├── upload/               # Artwork upload
│   │   └── settings/
│   ├── services/
│   │   └── gemini_ai_service.dart
│   └── components/               # Shared widgets
├── android/                      # Android platform
├── web/                          # Flutter web (Vercel deployed)
└── assets/images/
```

---

## ⚠️ Priority Issues to Fix First

1. **Hardcoded Supabase keys** in `supabase_config.dart` — move to `--dart-define` build args
2. **No env injection** — needed for safe web + Android CI builds
3. **QR + NFC packages missing** from pubspec — add before building those features
4. **Solana SDK not installed** — decide REST vs. native Dart SDK approach
5. **Provider-only state** — consider migrating high-frequency paths to Riverpod

---

*Generated by Antigravity for Artyug revamp session — 2026-04-06*
