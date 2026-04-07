import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

// Product tour (modal). Shown once per install unless replayed from Settings.
// Users who already completed profile onboarding (`profiles.onboarding_complete`)
// never see this — that flow is the real "first-time" setup.
class OnboardingGuide {
  static const _shownKey = 'artyug_guide_shown_v2';

  /// Call after profile onboarding saves successfully so the home tour does not appear later.
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
  }

  /// [force] bypasses prefs + DB checks — use only after [reset] (e.g. Settings → Replay App Guide).
  static Future<void> showIfNeeded(
    BuildContext context, {
    bool force = false,
    int authWaitAttempt = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(_shownKey) ?? false)) return;
    if (!context.mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Wait until auth finished loading so onboardingComplete reflects the DB.
    if (!force && auth.loading && authWaitAttempt < 15) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (context.mounted) {
        return showIfNeeded(context, force: force, authWaitAttempt: authWaitAttempt + 1);
      }
      return;
    }

    if (!force && auth.onboardingComplete) {
      await prefs.setBool(_shownKey, true);
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GuideDialog(),
    );
    if (context.mounted) {
      await prefs.setBool(_shownKey, true);
    }
  }

  /// Lets you re-trigger from settings for debugging / UX review
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shownKey);
  }
}

// ─── Guide data ──────────────────────────────────────────────────────────────

const _slides = [
  _Slide(
    emoji: '🎨',
    title: 'Welcome to Artyug',
    body: 'The SocialFi marketplace for India\'s creative economy. '
        'Buy, sell, and collect verified art — all in one place.',
    color: Color(0xFFE8470A),
  ),
  _Slide(
    emoji: '🔍',
    title: 'Discover & Collect',
    body: 'Browse thousands of artworks across every medium. '
        'Every sale comes with a blockchain-backed Certificate of Authenticity.',
    color: Color(0xFF7C3AED),
  ),
  _Slide(
    emoji: '🏛️',
    title: 'Join a Guild',
    body: 'Creator guilds are communities where artists share work, '
        'host events, and grow together. Find your tribe.',
    color: Color(0xFF0EA5E9),
  ),
  _Slide(
    emoji: '🤖',
    title: 'AI Art Assistant',
    body: 'Use our Gemini-powered AI to get critique, ideas, and insight '
        'about any artwork — just upload or describe it.',
    color: Color(0xFF16A34A),
  ),
  _Slide(
    emoji: '⚡',
    title: 'Demo vs Live Mode',
    body: 'You\'re in Demo Mode — explore freely with sample data. '
        'Switch to Live Mode from sidebar or Settings to transact for real.',
    color: Color(0xFFCA8A04),
  ),
];

class _Slide {
  final String emoji;
  final String title;
  final String body;
  final Color color;
  const _Slide({required this.emoji, required this.title, required this.body, required this.color});
}

// ─── Dialog ──────────────────────────────────────────────────────────────────

class _GuideDialog extends StatefulWidget {
  const _GuideDialog();
  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _slideIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _slides.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    final isLast = _index == _slides.length - 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideIn,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated hero ─────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [slide.color.withOpacity(0.08), slide.color.withOpacity(0.22)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Emoji
                      Positioned.fill(
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(_index),
                            tween: Tween(begin: 0.5, end: 1.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                            child: Text(slide.emoji, style: const TextStyle(fontSize: 64)),
                          ),
                        ),
                      ),
                      // Progress dots
                      Positioned(
                        bottom: 12,
                        left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_slides.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: i == _index ? 22 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _index ? slide.color : slide.color.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          )),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Text content ─────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: Padding(
                    key: ValueKey(_index),
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slide.title, style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.2,
                        )),
                        const SizedBox(height: 8),
                        Text(slide.body, style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary, height: 1.6,
                        )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── CTA row ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(children: [
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Skip', style: TextStyle(
                        color: AppColors.textTertiary, fontWeight: FontWeight.w600,
                      )),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: slide.color,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(width: 5),
                        Icon(isLast ? Icons.east_rounded : Icons.chevron_right_rounded, size: 18),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
