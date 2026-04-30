import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/canonical_guilds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/onboarding_guide.dart';

const _kArtCategories = [
  'Painting',
  'Photography',
  'Sculpture',
  'Digital Art',
  'Illustration',
  'Printmaking',
  'Mixed Media',
  'Textile & Fiber',
  'Ceramics',
  'Street Art',
  'Video Art',
  'Installation',
];

const _kCollectorInterests = [
  'Paintings',
  'Photography',
  'Digital Art',
  'Sculpture',
  'Prints',
  'Street Art',
  'Emerging Artists',
  'Abstract',
  'Portraits',
  'Landscapes',
];

const List<Map<String, Object>> _kSellTypes = [
  {'id': 'originals', 'label': 'Original Works', 'icon': Icons.image_outlined},
  {'id': 'prints', 'label': 'Prints & Editions', 'icon': Icons.print_outlined},
  {
    'id': 'digital',
    'label': 'Digital Downloads',
    'icon': Icons.monitor_outlined
  },
  {'id': 'commissions', 'label': 'Commissions', 'icon': Icons.brush_outlined},
];

const List<Map<String, String>> _kPurchaseStyles = [
  {
    'id': 'buy',
    'label': 'Direct Purchase',
    'sub': 'Browse and buy at listed price',
  },
  {
    'id': 'bid',
    'label': 'Auctions & Bidding',
    'sub': 'I like the thrill of bidding',
  },
  {
    'id': 'both',
    'label': 'Both Styles',
    'sub': 'Depends on the artwork',
  },
];

final _fallbackGuilds = <_GuildData>[
  const _GuildData(
    id: 'guild-contemporary',
    name: 'Artyug Community',
    description: 'An iconic community curated thoughtfully for artists and collectors.',
    memberCount: 14,
    category: 'Community',
    imageUrl: 'assets/guilds/artyug.png',
  ),
  const _GuildData(
    id: 'guild-digital',
    name: 'Motojojo',
    description: 'Creators and collectors in the Motojojo circle sharing culture and collabs.',
    memberCount: 12,
    category: 'Culture',
    imageUrl: 'assets/guilds/motojojo.png',
  ),
  const _GuildData(
    id: 'guild-traditional',
    name: 'Webcoin Labs',
    description: 'Onchain creators exploring drops, experiments, and verified digital ownership.',
    memberCount: 10,
    category: 'Web3 Art',
    imageUrl: 'assets/guilds/webcoinlabs.jpg',
  ),
];

final _fallbackCreators = <_CreatorSuggestion>[
  const _CreatorSuggestion(
    id: 'creator-1',
    displayName: 'Aarav Canvas',
    username: 'aarav_canvas',
    medium: 'Oil Painting',
    followers: 8200,
  ),
  const _CreatorSuggestion(
    id: 'creator-2',
    displayName: 'Mira Pixels',
    username: 'mira_pixels',
    medium: 'Digital Art',
    followers: 6400,
  ),
  const _CreatorSuggestion(
    id: 'creator-3',
    displayName: 'Ishita Frames',
    username: 'ishita_frames',
    medium: 'Photography',
    followers: 5900,
  ),
  const _CreatorSuggestion(
    id: 'creator-4',
    displayName: 'Rohan Clay',
    username: 'rohan_clay',
    medium: 'Sculpture',
    followers: 3100,
  ),
  const _CreatorSuggestion(
    id: 'creator-5',
    displayName: 'Neel Street',
    username: 'neel_street',
    medium: 'Street Art',
    followers: 4700,
  ),
  const _CreatorSuggestion(
    id: 'creator-6',
    displayName: 'Tara Ink',
    username: 'tara_ink',
    medium: 'Illustration',
    followers: 5200,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  String? _role;
  int _step = 1;
  bool _saving = false;
  String? _error;

  static const _kUsernameCheckDebounce = Duration(milliseconds: 450);

  Timer? _creatorUsernameDebounce;
  Timer? _collectorUsernameDebounce;

  _UsernameStatus _creatorUsernameStatus = _UsernameStatus.idle;
  _UsernameStatus _collectorUsernameStatus = _UsernameStatus.idle;

  String? _creatorUsernameLastChecked;
  String? _collectorUsernameLastChecked;

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final List<String> _categories = [];
  final List<String> _sellTypes = [];
  bool? _wantsEvents;

  final _cNameCtrl = TextEditingController();
  final _cUsernameCtrl = TextEditingController();
  final List<String> _interests = [];
  String _purchaseStyle = '';
  bool? _cWantsEvents;

  final Set<String> _joinedGuildIds = <String>{};
  final Set<String> _followedCreatorIds = <String>{};
  List<_GuildData> _guildSuggestions = List<_GuildData>.from(_fallbackGuilds);
  List<_CreatorSuggestion> _creatorSuggestions =
      List<_CreatorSuggestion>.from(_fallbackCreators);
  bool _loadingGuilds = true;
  bool _loadingCreators = true;
  bool _socialLoaded = false;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _loadSocialData();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _exitIfAlreadyOnboarded());
  }

  @override
  void dispose() {
    _creatorUsernameDebounce?.cancel();
    _collectorUsernameDebounce?.cancel();
    _bgController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _cNameCtrl.dispose();
    _cUsernameCtrl.dispose();
    super.dispose();
  }

  int get _totalSteps =>
      _role == 'creator' ? 10 : (_role == 'collector' ? 9 : 1);

  double get _progress => _totalSteps > 1 ? (_step - 1) / (_totalSteps - 1) : 0;

  bool get _isCreator => _role == 'creator';

  bool get _isCollector => _role == 'collector';

  String get _activeName =>
      _isCreator ? _nameCtrl.text.trim() : _cNameCtrl.text.trim();

  String get _activeUsername =>
      _isCreator ? _usernameCtrl.text.trim() : _cUsernameCtrl.text.trim();

  Future<void> _exitIfAlreadyOnboarded() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || !mounted) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_complete')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      final oc = row['onboarding_complete'];
      if (oc == true || oc == 'true' || oc == 't') {
        await context.read<AuthProvider>().refreshOnboardingStatus();
        if (mounted) context.go('/main');
      }
    } catch (_) {
      // Keep onboarding screen if check fails.
    }
  }

  Future<void> _loadSocialData() async {
    if (_socialLoaded) return;
    _socialLoaded = true;

    if (mounted) {
      setState(() {
        _loadingGuilds = true;
        _loadingCreators = true;
      });
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;

    final guildsFuture = _fetchGuildSuggestions();
    final creatorsFuture = _fetchCreatorSuggestions(userId);

    final guilds = await guildsFuture;
    final creators = await creatorsFuture;

    if (!mounted) return;
    setState(() {
      _guildSuggestions =
          guilds.isEmpty ? List<_GuildData>.from(_fallbackGuilds) : guilds;
      _creatorSuggestions = creators.isEmpty
          ? List<_CreatorSuggestion>.from(_fallbackCreators)
          : creators;
      _loadingGuilds = false;
      _loadingCreators = false;
    });
  }

  Future<List<_GuildData>> _fetchGuildSuggestions() async {
    final client = Supabase.instance.client;

    try {
      final rows = await CanonicalGuilds.fetchOfficialCommunities(client);
      final parsed =
          rows.map(_GuildData.fromRow).whereType<_GuildData>().toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Fall through.
    }

    try {
      final response = await client.from('guilds').select('*').limit(10);
      final rows = List<Map<String, dynamic>>.from(response as List);
      final parsed =
          rows.map(_GuildData.fromRow).whereType<_GuildData>().toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Fall through.
    }

    return List<_GuildData>.from(_fallbackGuilds);
  }

  Future<List<_CreatorSuggestion>> _fetchCreatorSuggestions(
      String? userId) async {
    final client = Supabase.instance.client;
    if (userId == null) {
      return List<_CreatorSuggestion>.from(_fallbackCreators);
    }

    try {
      final response = await client
          .from('profiles')
          .select(
              'id, display_name, username, bio, role, artist_type, profile_picture_url, avatar_url, followers_count')
          .eq('role', 'creator')
          .neq('id', userId)
          .order('followers_count', ascending: false)
          .limit(10);

      final rows = List<Map<String, dynamic>>.from(response as List);
      final creators = rows
          .map(_CreatorSuggestion.fromProfileRow)
          .whereType<_CreatorSuggestion>()
          .toList();
      return creators;
    } catch (_) {
      return List<_CreatorSuggestion>.from(_fallbackCreators);
    }
  }

  String _normalizeUsername(String raw) {
    var s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (s.length > 20) s = s.substring(0, 20);
    return s;
  }

  bool _isValidUsername(String v) => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v);

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
      // Preserve existing behavior: do not block on transient check failures.
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

    final timer =
        isCreator ? _creatorUsernameDebounce : _collectorUsernameDebounce;
    timer?.cancel();

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

    if (_isCreator) {
      if (_step == 2) {
        return _nameCtrl.text.trim().isNotEmpty &&
            _isValidUsername(_usernameCtrl.text);
      }
      if (_step == 3) return _categories.isNotEmpty;
      if (_step == 6) return _wantsEvents != null;
      return true;
    }

    if (_isCollector) {
      if (_step == 2) {
        return _cNameCtrl.text.trim().isNotEmpty &&
            _isValidUsername(_cUsernameCtrl.text);
      }
      if (_step == 4) return _purchaseStyle.isNotEmpty;
      if (_step == 5) return _cWantsEvents != null;
      return true;
    }

    return true;
  }

  Future<void> _next() async {
    if (_step == _totalSteps) {
      await _complete();
      return;
    }

    if (_step == 2 && (_isCreator || _isCollector)) {
      final username = _activeUsername;
      if (_isValidUsername(username)) {
        setState(() {
          _saving = true;
          _error = null;
        });
        final ok = await _isUsernameAvailable(username);
        if (!mounted) return;
        setState(() => _saving = false);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Username @$username is already taken. Pick another.'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _step++;
      _error = null;
    });
  }

  void _back() => setState(() => _step = (_step - 1).clamp(1, _totalSteps));

  Future<void> _complete() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final username = _activeUsername;
        if (_isValidUsername(username)) {
          final available = await _isUsernameAvailable(username);
          if (!available) throw Exception('USERNAME_TAKEN');
        }

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'display_name': _activeName,
          'username': username,
          'bio': _isCreator ? _bioCtrl.text.trim() : '',
          'role': _role,
          'onboarding_complete': true,
          'updated_at': DateTime.now().toIso8601String(),
        });

        await _saveOptionalSocialData(user.id);

        if (mounted) {
          await context.read<AuthProvider>().refreshOnboardingStatus();
          await OnboardingGuide.markAsShown();
        }
      }

      if (mounted) {
        const dashboard = '/main';
        context.go('/terms-acceptance?next=${Uri.encodeComponent(dashboard)}');
      }
    } catch (e) {
      final msg = e.toString() == 'Exception: USERNAME_TAKEN'
          ? 'That username is already taken. Tap Back and choose a different one.'
          : _profileSaveErrorMessage(e);
      setState(() => _error = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOptionalSocialData(String userId) async {
    try {
      await _saveGuildMemberships(userId);
    } catch (e) {
      debugPrint('Optional guild save skipped: $e');
    }

    try {
      await _saveFollowSelections(userId);
    } catch (e) {
      debugPrint('Optional follow save skipped: $e');
    }
  }

  Future<void> _saveGuildMemberships(String userId) async {
    if (_joinedGuildIds.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final ids = _joinedGuildIds.toList();

    final attempts = <_OptionalWriteAttempt>[
      _OptionalWriteAttempt(
        table: 'guild_memberships',
        rows: ids
            .map((id) => {
                  'user_id': userId,
                  'guild_id': id,
                  'created_at': now,
                })
            .toList(),
        onConflict: 'user_id,guild_id',
      ),
      _OptionalWriteAttempt(
        table: 'profile_guilds',
        rows: ids
            .map((id) => {
                  'user_id': userId,
                  'guild_id': id,
                  'created_at': now,
                })
            .toList(),
        onConflict: 'user_id,guild_id',
      ),
      _OptionalWriteAttempt(
        table: 'community_members',
        rows: ids
            .map((id) => {
                  'user_id': userId,
                  'community_id': id,
                  'joined_at': now,
                })
            .toList(),
        onConflict: 'user_id,community_id',
      ),
    ];

    await _runOptionalUpsertAttempts(attempts);
  }

  Future<void> _saveFollowSelections(String userId) async {
    if (_followedCreatorIds.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final ids = _followedCreatorIds.toList();

    final attempts = <_OptionalWriteAttempt>[
      _OptionalWriteAttempt(
        table: 'follows',
        rows: ids
            .map((id) => {
                  'follower_id': userId,
                  'following_id': id,
                  'created_at': now,
                })
            .toList(),
        onConflict: 'follower_id,following_id',
      ),
      _OptionalWriteAttempt(
        table: 'user_follows',
        rows: ids
            .map((id) => {
                  'follower_id': userId,
                  'following_id': id,
                  'created_at': now,
                })
            .toList(),
        onConflict: 'follower_id,following_id',
      ),
      _OptionalWriteAttempt(
        table: 'profile_follows',
        rows: ids
            .map((id) => {
                  'user_id': userId,
                  'creator_id': id,
                  'created_at': now,
                })
            .toList(),
        onConflict: 'user_id,creator_id',
      ),
    ];

    await _runOptionalUpsertAttempts(attempts);
  }

  Future<void> _runOptionalUpsertAttempts(
      List<_OptionalWriteAttempt> attempts) async {
    if (attempts.isEmpty) return;
    final client = Supabase.instance.client;

    Object? lastError;
    for (final attempt in attempts) {
      try {
        await client
            .from(attempt.table)
            .upsert(attempt.rows, onConflict: attempt.onConflict);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      debugPrint('Optional save attempts failed: $lastError');
    }
  }

  void _onRoleSelected(String role) {
    setState(() => _role = role);
  }

  void _toggleGuild(String id) {
    setState(() {
      if (_joinedGuildIds.contains(id)) {
        _joinedGuildIds.remove(id);
      } else {
        _joinedGuildIds.add(id);
      }
    });
  }

  void _toggleFollow(String id) {
    setState(() {
      if (_followedCreatorIds.contains(id)) {
        _followedCreatorIds.remove(id);
      } else {
        _followedCreatorIds.add(id);
      }
    });
  }

  String _stepText(int value) => 'Step $value of $_totalSteps';

  Widget _buildStep() {
    if (_step == 1) return _stepRoleSelect();

    if (_isCreator) {
      return switch (_step) {
        2 => _stepNameUsername(
            nameCtrl: _nameCtrl,
            usernameCtrl: _usernameCtrl,
            isCreator: true,
            namePlaceholder: 'e.g. Priya Sharma Studio',
          ),
        3 => _stepChips(
            title: 'Your Mediums',
            subtitle: 'Pick the mediums that define your artistic signature.',
            options: _kArtCategories,
            selected: _categories,
            onToggle: (value) {
              setState(() {
                _categories.contains(value)
                    ? _categories.remove(value)
                    : _categories.add(value);
              });
            },
          ),
        4 => _stepBio(),
        5 => _stepSellTypes(),
        6 => _stepEvents(isCreator: true),
        7 => _stepGuilds(isCreator: true),
        8 => _stepFollowCreators(isCreator: true),
        9 => _stepFeedPreview(),
        _ => _stepCompletion(),
      };
    }

    if (_isCollector) {
      return switch (_step) {
        2 => _stepNameUsername(
            nameCtrl: _cNameCtrl,
            usernameCtrl: _cUsernameCtrl,
            isCreator: false,
            namePlaceholder: 'e.g. Rahul M.',
          ),
        3 => _stepChips(
            title: 'Your Interests',
            subtitle: 'Tell us what kind of art belongs in your feed.',
            options: _kCollectorInterests,
            selected: _interests,
            onToggle: (value) {
              setState(() {
                _interests.contains(value)
                    ? _interests.remove(value)
                    : _interests.add(value);
              });
            },
          ),
        4 => _stepPurchaseStyle(),
        5 => _stepEvents(isCreator: false),
        6 => _stepGuilds(isCreator: false),
        7 => _stepFollowCreators(isCreator: false),
        8 => _stepFeedPreview(),
        _ => _stepCompletion(),
      };
    }

    return const SizedBox.shrink();
  }

  Widget _stepRoleSelect() {
    return _StepShell(
      stepText: _stepText(1),
      title: 'Choose Your Path',
      subtitle: 'Create culture or collect it. Your flow adapts instantly.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;
          final creatorCard = SelectableCard(
            title: 'I am a Creator',
            subtitle: 'Sell art, run events, and grow your community.',
            icon: Icons.palette_outlined,
            selected: _role == 'creator',
            onTap: () => _onRoleSelected('creator'),
          );
          final collectorCard = SelectableCard(
            title: 'I am a Collector',
            subtitle: 'Discover, bid, and collect verified artwork.',
            icon: Icons.auto_awesome_mosaic_outlined,
            selected: _role == 'collector',
            onTap: () => _onRoleSelected('collector'),
          );

          if (stacked) {
            return Column(
              children: [
                creatorCard,
                const SizedBox(height: 12),
                collectorCard,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: creatorCard),
              const SizedBox(width: 12),
              Expanded(child: collectorCard),
            ],
          );
        },
      ),
    );
  }

  Widget _stepNameUsername({
    required TextEditingController nameCtrl,
    required TextEditingController usernameCtrl,
    required bool isCreator,
    required String namePlaceholder,
  }) {
    final normalizedUsername = _normalizeUsername(usernameCtrl.text);
    final validUsername = _isValidUsername(normalizedUsername);
    final status =
        isCreator ? _creatorUsernameStatus : _collectorUsernameStatus;

    return _StepShell(
      stepText: _stepText(2),
      title: 'Name + Username',
      subtitle:
          'Claim your identity. This is how the Artyug network finds you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePreviewCard(
            displayName: nameCtrl.text.trim().isEmpty
                ? (isCreator ? 'Creator Name' : 'Collector Name')
                : nameCtrl.text.trim(),
            username: normalizedUsername,
            role: isCreator ? 'Creator' : 'Collector',
            isVerified: status == _UsernameStatus.available,
          ),
          const SizedBox(height: 18),
          _FieldLabel(text: 'Display Name'),
          const SizedBox(height: 8),
          _GlassInput(
            controller: nameCtrl,
            hint: namePlaceholder,
            icon: Icons.person_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _FieldLabel(text: 'Username'),
          const SizedBox(height: 8),
          _GlassInput(
            controller: usernameCtrl,
            hint: 'e.g. priya_studio',
            icon: Icons.alternate_email,
            prefixText: '@',
            inputFormatters: const [_UsernameFormatter()],
            onChanged: (_) {
              _scheduleUsernameAvailabilityCheck(
                isCreator: isCreator,
                usernameCtrl: usernameCtrl,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '3-20 chars. Lowercase letters, numbers, underscore only.',
            style: TextStyle(
              fontSize: 12,
              color:
                  validUsername ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _UsernameAvailabilityRow(
            status: status,
            username: isCreator
                ? _creatorUsernameLastChecked
                : _collectorUsernameLastChecked,
          ),
          if (status == _UsernameStatus.available && validUsername) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x2216A34A),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFF16A34A).withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@$normalizedUsername is yours on Artyug',
                      style: const TextStyle(
                        color: Color(0xFF6EE7A5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepChips({
    required String title,
    required String subtitle,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return _StepShell(
      stepText: _stepText(_step),
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options
            .map(
              (option) => _SelectablePill(
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _stepBio() {
    return _StepShell(
      stepText: _stepText(4),
      title: 'Your Bio',
      subtitle: 'Give collectors a quick sense of your voice and style.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlassInput(
            controller: _bioCtrl,
            hint:
                'e.g. Abstract painter exploring memory and landscape from Pune...',
            maxLength: 300,
            minLines: 4,
            maxLines: 7,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _stepSellTypes() {
    return _StepShell(
      stepText: _stepText(5),
      title: 'What Do You Sell',
      subtitle: 'Select everything you currently offer on your profile.',
      child: Column(
        children: _kSellTypes.map((item) {
          final id = item['id']! as String;
          final selected = _sellTypes.contains(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableCard(
              title: item['label']! as String,
              icon: item['icon']! as IconData,
              selected: selected,
              onTap: () {
                setState(() {
                  selected ? _sellTypes.remove(id) : _sellTypes.add(id);
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stepEvents({required bool isCreator}) {
    final value = isCreator ? _wantsEvents : _cWantsEvents;
    return _StepShell(
      stepText: _stepText(isCreator ? 6 : 5),
      title: 'Events',
      subtitle: isCreator
          ? 'Interested in hosting or joining art events on Artyug?'
          : 'Interested in attending exhibitions and event drops?',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableCard(
                  title: 'Yes, I am in',
                  icon: Icons.check_circle_outline,
                  selected: value == true,
                  onTap: () => setState(() {
                    if (isCreator) {
                      _wantsEvents = true;
                    } else {
                      _cWantsEvents = true;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableCard(
                  title: 'Not right now',
                  icon: Icons.pause_circle_outline,
                  selected: value == false,
                  onTap: () => setState(() {
                    if (isCreator) {
                      _wantsEvents = false;
                    } else {
                      _cWantsEvents = false;
                    }
                  }),
                ),
              ),
            ],
          ),
          if (isCreator && _wantsEvents == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: const Text(
                'Great. You will see creator event tools once onboarding is complete.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepGuilds({required bool isCreator}) {
    return _StepShell(
      stepText: _stepText(isCreator ? 7 : 6),
      title: isCreator ? 'Join Guilds' : 'Join Guilds / Communities',
      subtitle:
          'Optional. Pick one or more communities to personalize your graph.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingGuilds)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.8, color: AppColors.primary),
              ),
            )
          else ...[
            ..._guildSuggestions.map(
              (guild) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GuildCard(
                  guild: guild,
                  joined: _joinedGuildIds.contains(guild.id),
                  onToggle: () => _toggleGuild(guild.id),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'You can skip now and join more communities later from Guild.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withOpacity(0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepFollowCreators({required bool isCreator}) {
    return _StepShell(
      stepText: _stepText(isCreator ? 8 : 7),
      title: isCreator ? 'Follow Creators' : 'Follow Artists',
      subtitle: 'Optional. Follow at least one account or skip for now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingCreators)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.8, color: AppColors.primary),
              ),
            )
          else ...[
            ..._creatorSuggestions.take(10).map(
                  (creator) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CreatorFollowCard(
                      creator: creator,
                      followed: _followedCreatorIds.contains(creator.id),
                      onToggle: () => _toggleFollow(creator.id),
                    ),
                  ),
                ),
            const SizedBox(height: 4),
            Text(
              _creatorSuggestions.isEmpty
                  ? 'No creators found right now. You can continue and follow later.'
                  : 'Following helps shape your first feed instantly.',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepFeedPreview() {
    final interests = _isCreator ? _categories : _interests;
    final joinedGuilds = _guildSuggestions
        .where((guild) => _joinedGuildIds.contains(guild.id))
        .map((guild) => guild.name)
        .toList();
    final followed = _creatorSuggestions
        .where((creator) => _followedCreatorIds.contains(creator.id))
        .toList();

    return _StepShell(
      stepText: _stepText(_isCreator ? 9 : 8),
      title: 'Your Artyug Is Ready',
      subtitle: 'Here is a personalized first-look based on your choices.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedPreviewCard(
            title: interests.isEmpty
                ? 'Recommended Discoveries'
                : '${interests.first} Spotlight',
            subtitle: joinedGuilds.isNotEmpty
                ? 'Because you joined ${joinedGuilds.take(2).join(' + ')}'
                : 'Curated from trending creators in your network',
            accentColor: const Color(0xFFFF7A3B),
          ),
          const SizedBox(height: 10),
          FeedPreviewCard(
            title: followed.isNotEmpty
                ? 'New from @${followed.first.username}'
                : 'Top creators to follow this week',
            subtitle: followed.isNotEmpty
                ? 'Fresh uploads and auction updates'
                : 'A mix of rising and established creators',
            accentColor: const Color(0xFF4F8BFF),
          ),
          const SizedBox(height: 10),
          FeedPreviewCard(
            title: _isCreator
                ? 'Collector activity near you'
                : 'Upcoming gallery events',
            subtitle: 'Personalized invites and drops based on your profile',
            accentColor: const Color(0xFF2BB673),
          ),
        ],
      ),
    );
  }

  Widget _stepCompletion() {
    final mediumOrInterest = _isCreator ? _categories : _interests;
    return _StepShell(
      stepText: _stepText(_totalSteps),
      title: _isCreator
          ? 'You Are Ready To Launch'
          : 'Your Collector Vault Is Ready',
      subtitle: 'One tap away from your personalized Artyug experience.',
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8D5A), Color(0xFFFF6A2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.45),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child:
                const Icon(Icons.check_rounded, size: 46, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.76),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.borderStrong.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Name',
                    value: _activeName.isEmpty ? '-' : _activeName),
                _SummaryRow(
                  label: 'Username',
                  value: _activeUsername.isEmpty ? '-' : '@${_activeUsername}',
                ),
                _SummaryRow(
                    label: 'Role', value: _isCreator ? 'Creator' : 'Collector'),
                _SummaryRow(
                  label: _isCreator ? 'Mediums' : 'Interests',
                  value: mediumOrInterest.isEmpty
                      ? 'Not selected'
                      : mediumOrInterest.take(2).join(', '),
                ),
                _SummaryRow(
                  label: 'Guilds Joined',
                  value: _joinedGuildIds.isEmpty
                      ? '0'
                      : _joinedGuildIds.length.toString(),
                ),
                _SummaryRow(
                  label: 'Creators Followed',
                  value: _followedCreatorIds.isEmpty
                      ? '0'
                      : _followedCreatorIds.length.toString(),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _stepPurchaseStyle() {
    return _StepShell(
      stepText: _stepText(4),
      title: 'Purchase Style',
      subtitle: 'Tell us how you usually acquire art pieces.',
      child: Column(
        children: _kPurchaseStyles.map((option) {
          final selected = _purchaseStyle == option['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SelectableCard(
              title: option['label']!,
              subtitle: option['sub'],
              selected: selected,
              icon: Icons.style_outlined,
              onTap: () => setState(() => _purchaseStyle = option['id']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF070B12),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            PremiumBackground(animation: _bgController),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _ProgressHeader(
                        step: _step,
                        totalSteps: _totalSteps,
                        progress: _progress),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth > 900
                            ? 860.0
                            : constraints.maxWidth;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: maxWidth,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 24),
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 280),
                                      transitionBuilder: (child, animation) {
                                        final curved = CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        );
                                        return FadeTransition(
                                          opacity: curved,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.06, 0),
                                              end: Offset.zero,
                                            ).animate(curved),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: KeyedSubtree(
                                        key: ValueKey('$_role-$_step'),
                                        child: _buildStep(),
                                      ),
                                    ),
                                  ),
                                ),
                                _BottomNavBar(
                                  showBack: _step > 1,
                                  isLoading: _saving,
                                  canContinue: _canContinue && !_saving,
                                  isLast: _step == _totalSteps,
                                  onBack: _back,
                                  onContinue: _next,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBackground extends StatelessWidget {
  final Animation<double> animation;
  const PremiumBackground({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          children: [
            Container(color: const Color(0xFF060A12)),
            Align(
              alignment: Alignment(-0.8 + (t * 0.3), -0.9 + (t * 0.2)),
              child: const _RadialGlow(
                size: 320,
                color: Color(0x66FF6A2B),
              ),
            ),
            Align(
              alignment: Alignment(0.9 - (t * 0.2), -0.4 + (t * 0.4)),
              child: const _RadialGlow(
                size: 300,
                color: Color(0x444F8BFF),
              ),
            ),
            Align(
              alignment: Alignment(-0.3 + (t * 0.4), 0.95 - (t * 0.2)),
              child: const _RadialGlow(
                size: 380,
                color: Color(0x332BB673),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RadialGlow extends StatelessWidget {
  final double size;
  final Color color;
  const _RadialGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.02)],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final double progress;

  const _ProgressHeader({
    required this.step,
    required this.totalSteps,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'ARTYUG',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$step / $totalSteps',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final String stepText;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepShell({
    required this.stepText,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepText.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  height: 1.05,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class SelectableCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const SelectableCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? AppColors.primary.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color:
                selected ? AppColors.primary : Colors.white.withOpacity(0.16),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.22)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 20),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: selected ? 1 : 0,
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class GuildCard extends StatelessWidget {
  final _GuildData guild;
  final bool joined;
  final VoidCallback onToggle;

  const GuildCard({
    super.key,
    required this.guild,
    required this.joined,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: joined ? AppColors.primary : Colors.white.withOpacity(0.14),
          width: joined ? 1.4 : 1,
        ),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: guild.imageUrl.trim().isEmpty
                      ? Center(
                          child: Text(
                            guild.name.isNotEmpty ? guild.name[0].toUpperCase() : 'G',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : guild.imageUrl.startsWith('assets/')
                          ? Image.asset(guild.imageUrl, fit: BoxFit.cover)
                          : Image.network(
                              guild.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  guild.name.isNotEmpty
                                      ? guild.name[0].toUpperCase()
                                      : 'G',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                ),
                Expanded(
                  child: Text(
                    guild.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              _TagLabel(text: guild.category),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            guild.description,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${guild.memberCount} members',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  foregroundColor:
                      joined ? AppColors.textPrimary : AppColors.primary,
                  backgroundColor: joined
                      ? AppColors.primary.withOpacity(0.22)
                      : AppColors.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(joined ? 'Joined' : 'Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CreatorFollowCard extends StatelessWidget {
  final _CreatorSuggestion creator;
  final bool followed;
  final VoidCallback onToggle;

  const CreatorFollowCard({
    super.key,
    required this.creator,
    required this.followed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final initials = creator.displayName.trim().isEmpty
        ? 'A'
        : creator.displayName
            .trim()
            .split(' ')
            .take(2)
            .map((word) => word.substring(0, 1).toUpperCase())
            .join();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: followed ? AppColors.primary : Colors.white.withOpacity(0.14),
          width: followed ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withOpacity(0.18),
            backgroundImage: creator.avatarUrl.isNotEmpty
                ? NetworkImage(creator.avatarUrl)
                : null,
            child: creator.avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creator.displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${creator.username}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TagLabel(text: creator.medium),
                    const SizedBox(width: 8),
                    Text(
                      '${creator.followers} followers',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor:
                  followed ? AppColors.textPrimary : AppColors.primary,
              backgroundColor: followed
                  ? AppColors.primary.withOpacity(0.22)
                  : AppColors.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(followed ? 'Following' : 'Follow'),
          ),
        ],
      ),
    );
  }
}

class ProfilePreviewCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String role;
  final bool isVerified;

  const ProfilePreviewCard({
    super.key,
    required this.displayName,
    required this.username,
    required this.role,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isEmpty
        ? 'A'
        : displayName
            .split(' ')
            .where((word) => word.trim().isNotEmpty)
            .take(2)
            .map((word) => word.trim().substring(0, 1).toUpperCase())
            .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primary.withOpacity(0.18),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      username.isEmpty ? '@username' : '@$username',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF16A34A), size: 16),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _TagLabel(text: role),
        ],
      ),
    );
  }
}

class FeedPreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const FeedPreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final bool showBack;
  final bool isLoading;
  final bool canContinue;
  final bool isLast;
  final VoidCallback onBack;
  final Future<void> Function() onContinue;

  const _BottomNavBar({
    required this.showBack,
    required this.isLoading,
    required this.canContinue,
    required this.isLast,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.13)),
            ),
            child: Row(
              children: [
                if (showBack)
                  TextButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary),
                  )
                else
                  const SizedBox(width: 80),
                const Spacer(),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: canContinue ? () => onContinue() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.surfaceHigh.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isLast ? 'Enter Artyug' : 'Continue',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                  isLast
                                      ? Icons.east_rounded
                                      : Icons.chevron_right_rounded,
                                  size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  final String text;
  const _TagLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 10.5,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _GlassInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final String? prefixText;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _GlassInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.prefixText,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixText: prefixText,
        prefixStyle: const TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 19, color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _SelectablePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectablePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.primary.withOpacity(0.16)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color:
                selected ? AppColors.primary : Colors.white.withOpacity(0.14),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsernameFormatter extends TextInputFormatter {
  const _UsernameFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text =
        newValue.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (text.length > 20) text = text.substring(0, 20);
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

enum _UsernameStatus { idle, checking, available, taken }

class _UsernameAvailabilityRow extends StatelessWidget {
  final _UsernameStatus status;
  final String? username;

  const _UsernameAvailabilityRow(
      {required this.status, required this.username});

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);

    if (status == _UsernameStatus.checking) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Checking availability...',
              style: style.copyWith(color: AppColors.textSecondary)),
        ],
      );
    }

    if (status == _UsernameStatus.available) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Text('Username is available',
              style: style.copyWith(color: const Color(0xFF6EE7A5))),
        ],
      );
    }

    if (status == _UsernameStatus.taken) {
      return Row(
        children: [
          const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              username == null
                  ? 'Username is already taken'
                  : '@$username is already taken',
              style: style.copyWith(color: const Color(0xFFF87171)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.info_outline,
            size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('Pick a unique username',
            style: style.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _OptionalWriteAttempt {
  final String table;
  final List<Map<String, dynamic>> rows;
  final String? onConflict;

  const _OptionalWriteAttempt({
    required this.table,
    required this.rows,
    this.onConflict,
  });
}

class _GuildData {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String category;
  final String imageUrl;

  const _GuildData({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.category,
    this.imageUrl = '',
  });

  static _GuildData? fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final name = (row['name'] ?? row['title'] ?? row['community_name'])
        ?.toString()
        .trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) return null;

    final description = (row['description'] ??
            row['about'] ??
            row['bio'] ??
            'Creative community')
        .toString();
    final category =
        (row['category'] ?? row['medium'] ?? row['type'] ?? 'Community')
            .toString();
    final memberCount = _toInt(
      row['member_count'] ??
          row['members_count'] ??
          row['members'] ??
          row['total_members'],
    );

    return _GuildData(
      id: id,
      name: name,
      description: description,
      memberCount: memberCount > 0 ? memberCount : 100,
      category: category,
      imageUrl: CanonicalGuilds.preferredImageForCommunityRow(row),
    );
  }
}

class _CreatorSuggestion {
  final String id;
  final String displayName;
  final String username;
  final String medium;
  final int followers;
  final String avatarUrl;

  const _CreatorSuggestion({
    required this.id,
    required this.displayName,
    required this.username,
    required this.medium,
    required this.followers,
    this.avatarUrl = '',
  });

  static _CreatorSuggestion? fromProfileRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final username = (row['username'] ?? '').toString().trim();
    if (username.isEmpty) return null;

    final displayName =
        (row['display_name'] ?? row['full_name'] ?? username).toString().trim();
    final avatarUrl = SupabaseMediaUrl.resolve(
      (row['profile_picture_url'] ?? row['avatar_url']) as String?,
    );

    final bio = (row['bio'] ?? '').toString().toLowerCase();
    var medium = (row['artist_type'] ?? '').toString().trim();
    if (medium.isEmpty) medium = 'Creator';
    if (bio.contains('photo')) medium = 'Photography';
    if (bio.contains('digital')) medium = 'Digital Art';
    if (bio.contains('paint')) medium = 'Painting';
    final followers = _toInt(
      row['followers_count'] ??
          row['follower_count'] ??
          row['total_followers'] ??
          row['followers'],
    );

    return _CreatorSuggestion(
      id: id,
      displayName: displayName,
      username: username,
      medium: medium,
      followers: followers,
      avatarUrl: avatarUrl,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return 0;
  return int.tryParse(value.toString()) ?? 0;
}
