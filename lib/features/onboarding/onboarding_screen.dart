import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/onboarding_guide.dart';
import '../../providers/theme_provider.dart' show ThemeProvider;

/// Fixed white + orange onboarding canvas. Use [AppColors.textOnLight] on cards, not theme
/// shell text tokens, so copy stays readable regardless of global dark/light preference.
const _obCanvas = Color(0xFFFFFFFF);
const _obBorder = Color(0xFFFFE4D4);
const _obIconTint = Color(0xFFFFF4ED);

// ─── Data ─────────────────────────────────────────────────────────────────
const _kArtCategories = [
  'Painting', 'Photography', 'Sculpture', 'Digital Art', 'Illustration',
  'Printmaking', 'Mixed Media', 'Textile & Fiber', 'Ceramics',
  'Street Art', 'Video Art', 'Installation',
];

const _kCollectorInterests = [
  'Paintings', 'Photography', 'Digital Art', 'Sculpture', 'Prints',
  'Street Art', 'Emerging Artists', 'Abstract', 'Portraits', 'Landscapes',
];

const _kGuilds = [
  'Painters Guild', 'Digital Artists', 'Photography Circle',
  'Mixed Media Collective', 'None right now',
];

const _kSellTypes = [
  {'id': 'originals', 'label': 'Original works', 'icon': Icons.image_outlined},
  {'id': 'prints', 'label': 'Prints & editions', 'icon': Icons.print_outlined},
  {'id': 'digital', 'label': 'Digital downloads', 'icon': Icons.monitor_outlined},
  {'id': 'commissions', 'label': 'Commissions', 'icon': Icons.brush_outlined},
];

const _kPurchaseStyles = [
  {'id': 'buy', 'label': 'Direct purchase', 'sub': 'Browse and buy at the listed price'},
  {'id': 'bid', 'label': 'Auctions & bidding', 'sub': 'I love the thrill of live bidding'},
  {'id': 'both', 'label': 'Both styles', 'sub': 'Flexible — depends on the piece'},
];

// ─── Screen ───────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _role; // 'creator' | 'collector'
  int _step = 1;
  bool _saving = false;
  String? _error;

  // ── Username availability (Twitter-style) ────────────────────────────────
  static const _kUsernameCheckDebounce = Duration(milliseconds: 450);

  Timer? _creatorUsernameDebounce;
  Timer? _collectorUsernameDebounce;

  _UsernameStatus _creatorUsernameStatus = _UsernameStatus.idle;
  _UsernameStatus _collectorUsernameStatus = _UsernameStatus.idle;

  String? _creatorUsernameLastChecked;
  String? _collectorUsernameLastChecked;

  // Creator state
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final List<String> _categories = [];
  final List<String> _sellTypes = [];
  bool? _wantsEvents;
  String _guildPref = '';

  // Collector state
  final _cNameCtrl = TextEditingController();
  final _cUsernameCtrl = TextEditingController();
  final List<String> _interests = [];
  String _purchaseStyle = '';
  bool? _cWantsEvents;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _exitIfAlreadyOnboarded());
  }

  Future<void> _exitIfAlreadyOnboarded() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) return;
      final oc = row['onboarding_complete'];
      if (oc == true || oc == 'true' || oc == 't') {
        await context.read<AuthProvider>().refreshOnboardingStatus();
        if (mounted) context.go('/main');
      }
    } catch (_) {
      // Stay on onboarding if the check fails
    }
  }

  @override
  void dispose() {
    _creatorUsernameDebounce?.cancel();
    _collectorUsernameDebounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cNameCtrl.dispose();
    _cUsernameCtrl.dispose();
    super.dispose();
  }

  int get _totalSteps => _role == 'creator' ? 8 : (_role == 'collector' ? 6 : 1);
  double get _progress => _totalSteps > 1 ? (_step - 1) / (_totalSteps - 1) : 0;

  String _normalizeUsername(String raw) {
    var s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (s.length > 20) s = s.substring(0, 20);
    return s;
  }

  bool _isValidUsername(String v) => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v);

  /// True if [username] is free or already owned by the signed-in user (matches [edit_profile_screen]).
  Future<bool> _isUsernameAvailable(String username) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    try {
      final conflict = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .neq('id', user.id)
          .maybeSingle();
      return conflict == null;
    } catch (_) {
      // RLS/network: fall through to save; server still enforces uniqueness.
      return true;
    }
  }

  void _setUsernameStatus({
    required bool isCreator,
    required _UsernameStatus status,
    String? lastChecked,
  }) {
    if (!mounted) return;
    setState(() {
      if (isCreator) {
        _creatorUsernameStatus = status;
        if (lastChecked != null) _creatorUsernameLastChecked = lastChecked;
      } else {
        _collectorUsernameStatus = status;
        if (lastChecked != null) _collectorUsernameLastChecked = lastChecked;
      }
    });
  }

  void _scheduleUsernameAvailabilityCheck({
    required bool isCreator,
    required TextEditingController usernameCtrl,
  }) {
    final raw = usernameCtrl.text;
    final normalized = _normalizeUsername(raw);
    if (normalized != raw) {
      usernameCtrl.value = usernameCtrl.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }

    final timer = isCreator ? _creatorUsernameDebounce : _collectorUsernameDebounce;
    timer?.cancel();

    // Only check when it's actually a valid username. Otherwise stay idle.
    if (!_isValidUsername(normalized)) {
      _setUsernameStatus(isCreator: isCreator, status: _UsernameStatus.idle);
      return;
    }

    _setUsernameStatus(isCreator: isCreator, status: _UsernameStatus.checking);
    final t = Timer(_kUsernameCheckDebounce, () async {
      final current = _normalizeUsername(usernameCtrl.text);
      if (!_isValidUsername(current)) {
        _setUsernameStatus(isCreator: isCreator, status: _UsernameStatus.idle);
        return;
      }

      final ok = await _isUsernameAvailable(current);
      if (!mounted) return;

      // Ignore stale results if user already typed something else
      final now = _normalizeUsername(usernameCtrl.text);
      if (now != current) return;

      _setUsernameStatus(
        isCreator: isCreator,
        status: ok ? _UsernameStatus.available : _UsernameStatus.taken,
        lastChecked: current,
      );
    });

    if (isCreator) {
      _creatorUsernameDebounce = t;
    } else {
      _collectorUsernameDebounce = t;
    }
  }

  String _profileSaveErrorMessage(Object e) {
    final s = e.toString();
    if (s.contains('23505') &&
        (s.contains('profiles_username') || s.contains('username'))) {
      return 'That username is already taken. Tap Back and choose a different one.';
    }
    if (s.contains('23505')) {
      return 'This profile conflicts with existing data. Try a different username.';
    }
    return 'Could not save your profile. Please try again.';
  }

  bool get _canContinue {
    if (_step == 1) return _role != null;
    if (_role == 'creator') {
      if (_step == 2) return _nameCtrl.text.trim().isNotEmpty && _isValidUsername(_usernameCtrl.text);
      if (_step == 3) return _categories.isNotEmpty;
      if (_step == 6) return _wantsEvents != null;
      return true;
    }
    if (_role == 'collector') {
      if (_step == 2) return _cNameCtrl.text.trim().isNotEmpty && _isValidUsername(_cUsernameCtrl.text);
      if (_step == 4) return _purchaseStyle.isNotEmpty;
      if (_step == 5) return _cWantsEvents != null;
      return true;
    }
    return true;
  }

  Future<void> _complete() async {
    setState(() { _saving = true; _error = null; });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final username = _role == 'creator'
            ? _usernameCtrl.text.trim()
            : _cUsernameCtrl.text.trim();
        if (_isValidUsername(username)) {
          final available = await _isUsernameAvailable(username);
          if (!available) {
            throw Exception('USERNAME_TAKEN');
          }
        }
        // Use `display_name` (matches ProfileModel / Supabase schema). `full_name` breaks the upsert.
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'display_name': _role == 'creator'
              ? _nameCtrl.text.trim()
              : _cNameCtrl.text.trim(),
          'username': username,
          'bio': _role == 'creator' ? _bioCtrl.text.trim() : '',
          'role': _role,
          'onboarding_complete': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          await context.read<AuthProvider>().refreshOnboardingStatus();
          await OnboardingGuide.markAsShown();
        }
      }
      if (mounted) {
        // Post-onboarding landing.
        // - Creators: jump into studio dashboard
        // - Collectors: land on homepage (market feed), not dashboard
        final dashboard = _role == 'creator' ? '/creator-dashboard' : '/main';
        context.go(
          '/terms-acceptance?next=${Uri.encodeComponent(dashboard)}',
        );
      }
    } catch (e) {
      final msg = e.toString() == 'Exception: USERNAME_TAKEN'
          ? 'That username is already taken. Tap Back and choose a different one.'
          : _profileSaveErrorMessage(e);
      setState(() { _error = msg; });
      // Do not navigate away — otherwise onboarding_complete never saves and login loops forever.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _next() async {
    if (_step == _totalSteps) {
      await _complete();
      return;
    }
    if (_step == 2 && (_role == 'creator' || _role == 'collector')) {
      final username = _role == 'creator'
          ? _usernameCtrl.text.trim()
          : _cUsernameCtrl.text.trim();
      if (_isValidUsername(username)) {
        setState(() { _saving = true; _error = null; });
        final ok = await _isUsernameAvailable(username);
        if (!mounted) return;
        setState(() => _saving = false);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Username @$username is already taken. Pick another.',
                ),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() { _step++; _error = null; });
  }

  void _back() => setState(() => _step = (_step - 1).clamp(1, _totalSteps));

  // ── Step Renderers ──────────────────────────────────────────────────────
  Widget _stepRoleSelect() => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final creator = _RoleCard(
            title: "I'm a Creator",
            subtitle: 'Sell art. Run events.\nBuild your guild.',
            icon: Icons.palette_outlined,
            selected: _role == 'creator',
            onTap: () => setState(() => _role = 'creator'),
          );
          final collector = _RoleCard(
            title: "I'm a Collector",
            subtitle: 'Discover. Buy.\nOwn verified art.',
            icon: Icons.collections_outlined,
            selected: _role == 'collector',
            onTap: () => setState(() => _role = 'collector'),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHOOSE YOUR PATH.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textOnLight,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you here to create the culture or collect it?',
                style: TextStyle(
                  fontSize: narrow ? 13.5 : 14,
                  color: AppColors.primaryDark,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              if (narrow) ...[
                creator,
                const SizedBox(height: 12),
                collector,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: creator),
                    const SizedBox(width: 14),
                    Expanded(child: collector),
                  ],
                ),
            ],
          );
        },
      );

  Widget _stepNameUsername({
    required TextEditingController nameCtrl,
    required TextEditingController usernameCtrl,
    required bool isCreator,
    required String stepLabel,
    required String namePlaceholder,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel(stepLabel),
      const Text('NAME + USERNAME.', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      const Text('Set your public Artyug identity.', style: TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 28),
      _Label('Display Name'),
      const SizedBox(height: 8),
      TextField(
        controller: nameCtrl,
        textInputAction: TextInputAction.next,
        style: const TextStyle(color: AppColors.textOnLight, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: namePlaceholder,
          prefixIcon: const Icon(Icons.person_outline, size: 20),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: nameCtrl.text.trim().isEmpty && usernameCtrl.text.isNotEmpty
                  ? AppColors.primary.withOpacity(0.6)
                  : _obBorder,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (nameCtrl.text.trim().isEmpty && usernameCtrl.text.isNotEmpty) ...[        
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 13),
          const SizedBox(width: 5),
          const Text('Enter your name above to continue',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ],
      const SizedBox(height: 16),
      _Label('Username'),
      const SizedBox(height: 8),
      TextField(
        controller: usernameCtrl,
        textInputAction: TextInputAction.done,
        inputFormatters: [_UsernameFormatter()],
        style: const TextStyle(color: AppColors.textOnLight, fontSize: 15, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'e.g. priya_studio',
          prefixText: '@',
          prefixIcon: Icon(Icons.alternate_email, size: 20),
        ),
        onChanged: (v) {
          _scheduleUsernameAvailabilityCheck(
            isCreator: isCreator,
            usernameCtrl: usernameCtrl,
          );
        },
      ),
      const SizedBox(height: 6),
      Text('3–20 characters: letters, numbers, underscore.',
          style: TextStyle(fontSize: 12, color: _isValidUsername(usernameCtrl.text) ? AppColors.primary : AppColors.textOnLightSecondary)),

      // Live availability feedback (Twitter-style)
      if (_isValidUsername(_normalizeUsername(usernameCtrl.text))) ...[
        const SizedBox(height: 8),
        _UsernameAvailabilityRow(
          status: isCreator ? _creatorUsernameStatus : _collectorUsernameStatus,
          username: isCreator ? _creatorUsernameLastChecked : _collectorUsernameLastChecked,
        ),
      ],
    ],
  );

  Widget _stepChips({
    required String stepLabel,
    required String title,
    required String subtitle,
    required List<String> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel(stepLabel),
      Text(title, style: const TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: options.map((opt) => _Chip(
        label: opt,
        selected: selected.contains(opt),
        onTap: () { onToggle(opt); setState(() {}); },
      )).toList()),
    ],
  );

  Widget _stepBio() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel('Step 4 of 8'),
      const Text('YOUR BIO.', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      const Text('A short intro shown on your public profile.', style: TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      TextField(
        controller: _bioCtrl,
        minLines: 4,
        maxLines: 6,
        maxLength: 300,
        style: const TextStyle(color: AppColors.textOnLight, fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          hintText: 'e.g. I create abstract oil paintings exploring memory and landscape, based in Pune...',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    ],
  );

  Widget _stepSellTypes() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel('Step 5 of 8'),
      const Text('WHAT DO YOU SELL?', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      const Text('Select all types of work you offer.', style: TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      ...(_kSellTypes as List<Map>).map((t) {
        final selected = _sellTypes.contains(t['id'] as String);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SelectCard(
            title: t['label'] as String,
            icon: t['icon'] as IconData,
            selected: selected,
            onTap: () {
              setState(() {
                selected ? _sellTypes.remove(t['id']) : _sellTypes.add(t['id'] as String);
              });
            },
          ),
        );
      }),
    ],
  );

  Widget _stepYesNo({
    required String stepLabel,
    required String title,
    required String subtitle,
    required bool? value,
    required void Function(bool) onChanged,
    Widget? extra,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel(stepLabel),
      Text(title, style: const TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _YesNoCard(label: "Yes, I'm in", selected: value == true, onTap: () { onChanged(true); setState(() {}); })),
        const SizedBox(width: 12),
        Expanded(child: _YesNoCard(label: 'Not right now', selected: value == false, onTap: () { onChanged(false); setState(() {}); })),
      ]),
      if (extra != null) ...[const SizedBox(height: 16), extra],
    ],
  );

  Widget _stepGuild() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel('Step 7 of 8'),
      const Text('JOIN A GUILD?', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      const Text('Which creator community resonates with you? (Optional.)', style: TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      Wrap(spacing: 10, runSpacing: 10, children: _kGuilds.map((g) => _Chip(
        label: g,
        selected: _guildPref == g,
        onTap: () => setState(() => _guildPref = g),
      )).toList()),
      const SizedBox(height: 12),
      Text('You can browse and join guilds anytime from your dashboard.',
          style: TextStyle(fontSize: 12, color: AppColors.textOnLightSecondary)),
    ],
  );

  Widget _stepPurchaseStyle() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepLabel('Step 4 of 6'),
      const Text('HOW DO YOU BUY?', style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
      )),
      const SizedBox(height: 6),
      const Text('Tell us how you prefer to acquire art.', style: TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary)),
      const SizedBox(height: 24),
      ...(_kPurchaseStyles as List<Map>).map((opt) {
        final selected = _purchaseStyle == opt['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SelectCard(
            title: opt['label'] as String,
            subtitle: opt['sub'] as String,
            selected: selected,
            radio: true,
            onTap: () => setState(() => _purchaseStyle = opt['id'] as String),
          ),
        );
      }),
    ],
  );

  Widget _stepCompletion({required bool isCreator}) {
    final name = isCreator ? _nameCtrl.text : _cNameCtrl.text;
    final username = isCreator ? _usernameCtrl.text : _cUsernameCtrl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 24),
        Text(isCreator ? "YOU'RE READY." : 'YOUR VAULT AWAITS.', style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.6,
        )),
        const SizedBox(height: 8),
        Text(
          isCreator
              ? 'Your creator profile is configured. Launching your dashboard.'
              : 'Your collector profile is ready. Welcome to Artyug.',
          style: const TextStyle(fontSize: 14, color: AppColors.textOnLightSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _obBorder),
          ),
          child: Column(children: [
            _SummaryRow('Name', name.isEmpty ? '—' : name),
            _SummaryRow('Username', username.isEmpty ? '—' : '@$username'),
            _SummaryRow('Role', isCreator ? 'Creator' : 'Collector'),
            if (isCreator && _categories.isNotEmpty)
              _SummaryRow('Mediums', _categories.take(2).join(', ')),
            if (!isCreator && _interests.isNotEmpty)
              _SummaryRow('Interests', _interests.take(2).join(', ')),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildStep() {
    if (_step == 1) return _stepRoleSelect();

    if (_role == 'creator') {
      return switch (_step) {
        2 => _stepNameUsername(
          nameCtrl: _nameCtrl, usernameCtrl: _usernameCtrl,
          isCreator: true,
          stepLabel: 'Step 2 of 8', namePlaceholder: 'e.g. Priya Sharma Studio',
        ),
        3 => _stepChips(
          stepLabel: 'Step 3 of 8', title: 'YOUR MEDIUMS.',
          subtitle: 'Select all that apply. Collectors use this to find you.',
          options: _kArtCategories, selected: _categories,
          onToggle: (v) => _categories.contains(v) ? _categories.remove(v) : _categories.add(v),
        ),
        4 => _stepBio(),
        5 => _stepSellTypes(),
        6 => _stepYesNo(
          stepLabel: 'Step 6 of 8', title: 'EVENTS?',
          subtitle: 'Are you interested in hosting or joining art events on Artyug?',
          value: _wantsEvents, onChanged: (v) => _wantsEvents = v,
          extra: _wantsEvents == true ? Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Great! You\'ll get access to self-serve event creation in Creator Pro.',
                style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.9)),
              )),
            ]),
          ) : null,
        ),
        7 => _stepGuild(),
        _ => _stepCompletion(isCreator: true),
      };
    }

    if (_role == 'collector') {
      return switch (_step) {
        2 => _stepNameUsername(
          nameCtrl: _cNameCtrl, usernameCtrl: _cUsernameCtrl,
          isCreator: false,
          stepLabel: 'Step 2 of 6', namePlaceholder: 'e.g. Rahul M.',
        ),
        3 => _stepChips(
          stepLabel: 'Step 3 of 6', title: 'WHAT ART DO YOU LOVE?',
          subtitle: 'We\'ll personalize your Artyug feed based on your interests.',
          options: _kCollectorInterests, selected: _interests,
          onToggle: (v) => _interests.contains(v) ? _interests.remove(v) : _interests.add(v),
        ),
        4 => _stepPurchaseStyle(),
        5 => _stepYesNo(
          stepLabel: 'Step 5 of 6', title: 'EVENTS?',
          subtitle: 'Interested in attending art exhibitions and events?',
          value: _cWantsEvents, onChanged: (v) => _cWantsEvents = v,
        ),
        _ => _stepCompletion(isCreator: false),
      };
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = context.read<ThemeProvider>().lightTheme;
    return Theme(
      data: lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _obCanvas,
          body: SafeArea(
            child: Column(children: [
              // ── Progress bar ───────────────────────────────────────
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 3,
              ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ─────────────────────────────────────
                  RichText(text: const TextSpan(children: [
                    TextSpan(text: 'ARTYUG', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textOnLight, letterSpacing: -0.3,
                    )),
                    TextSpan(text: '.', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary,
                    )),
                  ])),

                  const SizedBox(height: 32),

                  // ── Step content ──────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),

          // ── Navigation bar ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _obBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_step > 1)
                  TextButton.icon(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textOnLightSecondary),
                  )
                else
                  const SizedBox(width: 80),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canContinue && !_saving
                        ? () async => _next()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              _step == _totalSteps ? 'Enter Artyug' : 'Continue',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            Icon(_step == _totalSteps ? Icons.east : Icons.chevron_right, size: 18),
                          ]),
                  ),
                ),
              ],
            ),
          ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final String text;
  const _StepLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1.5,
    )),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: const TextStyle(
    fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textOnLightSecondary, letterSpacing: 1.2,
  ));
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.primary : _obBorder, width: selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : _obIconTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: selected ? Colors.white : AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textOnLight,
          )),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textOnLightSecondary, height: 1.4)),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: selected ? AppColors.primary : _obBorder),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textOnLight,
      )),
    ),
  );
}

class _SelectCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;
  const _SelectCard({required this.title, this.subtitle, this.icon, required this.selected, this.radio = false, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : _obBorder, width: selected ? 2 : 1),
      ),
      child: Row(children: [
        if (radio)
          Container(
            width: 20, height: 20, margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? AppColors.primary : _obBorder, width: 2),
              color: selected ? AppColors.primary : Colors.white,
            ),
            child: selected ? const Icon(Icons.circle, size: 10, color: Colors.white) : null,
          )
        else if (icon != null)
          Container(
            width: 36, height: 36, margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : _obIconTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: selected ? Colors.white : AppColors.primary),
          ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textOnLight)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textOnLightSecondary, height: 1.4)),
          ],
        )),
        if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
      ]),
    ),
  );
}

class _YesNoCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YesNoCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.primary : _obBorder, width: selected ? 2 : 1),
      ),
      child: Center(child: Text(label, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: selected ? AppColors.primary : AppColors.textOnLight,
      ))),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textOnLightSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textOnLight)),
      ],
    ),
  );
}

class _UsernameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    var text = newVal.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (text.length > 20) text = text.substring(0, 20);
    return newVal.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

enum _UsernameStatus { idle, checking, available, taken }

class _UsernameAvailabilityRow extends StatelessWidget {
  final _UsernameStatus status;
  final String? username;
  const _UsernameAvailabilityRow({required this.status, required this.username});

  @override
  Widget build(BuildContext context) {
    final baseStyle = const TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    return Row(
      children: [
        if (status == _UsernameStatus.checking) ...[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Checking…', style: baseStyle.copyWith(color: AppColors.textOnLightSecondary)),
        ] else if (status == _UsernameStatus.available) ...[
          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Text('Username is available', style: baseStyle.copyWith(color: const Color(0xFF16A34A))),
        ] else if (status == _UsernameStatus.taken) ...[
          const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              username == null ? 'Username is already taken' : '@$username is already taken',
              style: baseStyle.copyWith(color: const Color(0xFFDC2626)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else ...[
          const Icon(Icons.info_outline, size: 16, color: AppColors.textOnLightSecondary),
          const SizedBox(width: 8),
          Text('Pick a unique username', style: baseStyle.copyWith(color: AppColors.textOnLightSecondary)),
        ],
      ],
    );
  }
}
