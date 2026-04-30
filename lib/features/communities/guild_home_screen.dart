import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/canonical_guilds.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Guild Home Screen — Phase G (Communities)
// Lists all communities/guilds the user can browse or join.
// Connects to Supabase `communities` table (6 rows live in DB).
// ─────────────────────────────────────────────────────────────────────────────

class GuildHomeScreen extends StatefulWidget {
  const GuildHomeScreen({super.key});

  @override
  State<GuildHomeScreen> createState() => _GuildHomeScreenState();
}

class _GuildHomeScreenState extends State<GuildHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<GuildModel> _allGuilds = [];
  List<GuildModel> _myGuilds = [];
  bool _loading = true;
  bool _membershipBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadGuilds();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadGuilds() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // Fetch all communities
      final allRes = await Supabase.instance.client
          .from('communities')
          .select('*')
          .order('member_count', ascending: false)
          .limit(30);

      var all = (allRes as List)
          .map((j) => GuildModel.fromJson(j as Map<String, dynamic>))
          .toList();

      // Only the three official guilds: Artyug, Motojojo, Webcoin Labs.
      all = CanonicalGuilds.filterAndSort(all, (g) => g.name);

      List<GuildModel> mine = [];
      if (userId != null) {
        final myRes = await Supabase.instance.client
            .from('community_members')
            .select('community_id')
            .eq('user_id', userId);

        final myIds =
            (myRes as List).map((j) => j['community_id'] as String).toSet();

        mine = all.where((g) => myIds.contains(g.id)).toList();
      }

      if (mounted) {
        setState(() {
          _allGuilds = all;
          _myGuilds = mine;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Demo data fallback — three canonical guilds only
          _allGuilds = GuildModel.demoData();
          _myGuilds = [GuildModel.demoData().first];
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleJoin(GuildModel guild) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    if (_membershipBusy) return;

    final isJoined = _myGuilds.any((g) => g.id == guild.id);
    try {
      setState(() => _membershipBusy = true);
      if (isJoined) {
        await _leaveGuildEverywhere(userId, guild.id);
      } else {
        await _joinGuildEverywhere(userId, guild.id);
      }
      if (!mounted) return;
      setState(() {
        _allGuilds = _allGuilds
            .map((g) => g.id == guild.id
                ? g.copyWith(
                    memberCount: (g.memberCount + (isJoined ? -1 : 1)).clamp(0, 999999),
                  )
                : g)
            .toList();
        if (isJoined) {
          _myGuilds.removeWhere((g) => g.id == guild.id);
        } else if (!_myGuilds.any((g) => g.id == guild.id)) {
          _myGuilds.add(
            guild.copyWith(memberCount: guild.memberCount + 1),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('23505')
                  ? 'You are already a member of this guild'
                  : 'Could not update membership',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _membershipBusy = false);
    }
  }

  Future<void> _joinGuildEverywhere(String userId, String guildId) async {
    // Only write to community_members — the canonical membership table.
    // guild_memberships / profile_guilds are optional aliases that may not exist.
    await Supabase.instance.client.from('community_members').upsert(
      {
        'user_id': userId,
        'community_id': guildId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,community_id',
    );
  }

  Future<void> _leaveGuildEverywhere(String userId, String guildId) async {
    await Supabase.instance.client
        .from('community_members')
        .delete()
        .eq('user_id', userId)
        .eq('community_id', guildId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GUILDS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Artyug · Motojojo · Webcoin Labs',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'ALL (${_allGuilds.length})'),
            Tab(text: 'MINE (${_myGuilds.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error)))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _GuildList(
                      guilds: _allGuilds,
                      myGuilds: _myGuilds,
                      onToggle: _toggleJoin,
                    ),
                    _GuildList(
                      guilds: _myGuilds,
                      myGuilds: _myGuilds,
                      onToggle: _toggleJoin,
                      emptyMessage: 'No guilds joined yet',
                      emptySub: 'Browse guilds and join communities',
                    ),
                  ],
                ),
    );
  }
}

// ─── Guild List ───────────────────────────────────────────────────────────────

class _GuildList extends StatelessWidget {
  final List<GuildModel> guilds;
  final List<GuildModel> myGuilds;
  final Future<void> Function(GuildModel) onToggle;
  final String emptyMessage;
  final String emptySub;

  const _GuildList({
    required this.guilds,
    required this.myGuilds,
    required this.onToggle,
    this.emptyMessage = 'No guilds found',
    this.emptySub = 'Check back later',
  });

  @override
  Widget build(BuildContext context) {
    if (guilds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏛️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 4),
            Text(emptySub,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final state = context.findAncestorStateOfType<_GuildHomeScreenState>();
        await state?._loadGuilds();
      },
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: guilds.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final guild = guilds[i];
          final isJoined = myGuilds.any((g) => g.id == guild.id);
          return _GuildCard(
            guild: guild,
            isJoined: isJoined,
            onJoin: () => onToggle(guild),
            onTap: () => context.push('/community-detail/${guild.id}'),
          );
        },
      ),
    );
  }
}

// ─── Guild Card ───────────────────────────────────────────────────────────────

class _GuildCard extends StatelessWidget {
  final GuildModel guild;
  final bool isJoined;
  final VoidCallback onJoin;
  final VoidCallback onTap;

  const _GuildCard({
    required this.guild,
    required this.isJoined,
    required this.onJoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isJoined
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guild avatar — circular, with asset/network/fallback
            ClipOval(
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.primary,
                child: guild.imageUrl.trim().isEmpty
                    ? Center(
                        child: Text(
                          guild.name.isNotEmpty ? guild.name[0].toUpperCase() : 'G',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      )
                    : guild.imageUrl.startsWith('assets/')
                        ? Image.asset(
                            guild.imageUrl,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                          )
                        : Image.network(
                            guild.imageUrl,
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                guild.name.isNotEmpty
                                    ? guild.name[0].toUpperCase()
                                    : 'G',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guild.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isJoined)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'JOINED',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guild.description ?? 'An Artyug creative guild',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        '${guild.memberCount} members',
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 11),
                      ),
                      if (guild.postCount > 0) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.forum_outlined,
                            size: 12, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          '${guild.postCount} posts',
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (guild.topics.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          label: guild.topics.first,
                          color: AppColors.primary.withOpacity(0.14),
                          textColor: AppColors.primary,
                        ),
                        if (guild.topics.length > 1)
                          _MetaChip(
                            label: guild.topics[1],
                            color: AppColors.surfaceHigh,
                            textColor: AppColors.textSecondary,
                          ),
                        _MetaChip(
                          label: '${guild.channelCount} channels',
                          color: AppColors.surfaceHigh,
                          textColor: AppColors.textSecondary,
                          icon: Icons.tag_rounded,
                        ),
                        _MetaChip(
                          label: '${guild.ruleCount} rules',
                          color: AppColors.surfaceHigh,
                          textColor: AppColors.textSecondary,
                          icon: Icons.gavel_rounded,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 104,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: onJoin,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        isJoined ? AppColors.surfaceHigh : AppColors.primary,
                    foregroundColor:
                        isJoined ? AppColors.textSecondary : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size.fromHeight(40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isJoined ? 'Leave' : 'Join',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => context.push(
                        '/guild-feed/${guild.id}?name=${Uri.encodeComponent(guild.name)}',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 10, color: AppColors.textSecondary),
                            SizedBox(width: 3),
                            Text(
                              'Feed',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => context.push(
                        '/community-chat/${guild.id}?name=${Uri.encodeComponent(guild.name)}',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 10, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text(
                              'Main chat',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

// ─── Model ────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _MetaChip({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class GuildModel {
  final String id;
  final String name;
  final String? description;
  final String imageUrl;
  final int memberCount;
  final int postCount;
  final int channelCount;
  final int ruleCount;
  final List<String> topics;

  const GuildModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl = '',
    required this.memberCount,
    this.postCount = 0,
    this.channelCount = 3,
    this.ruleCount = 4,
    this.topics = const [],
  });

  factory GuildModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Guild';
    final presets = _GuildPresets.byName(name);
    final metadata = (json['metadata'] is Map<String, dynamic>)
        ? json['metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final topics = _toStringList(metadata['topics']);

    return GuildModel(
      id: json['id'] as String,
      name: name,
      description: json['description'] as String? ?? presets.description,
      imageUrl: CanonicalGuilds.preferredImageForCommunityRow(json),
      memberCount: json['member_count'] as int? ?? 0,
      postCount: json['post_count'] as int? ??
          (metadata['post_count'] as int? ?? presets.postCount),
      channelCount: json['channel_count'] as int? ??
          (metadata['channel_count'] as int? ?? presets.channelCount),
      ruleCount: json['rule_count'] as int? ??
          (metadata['rule_count'] as int? ?? presets.ruleCount),
      topics: topics.isNotEmpty ? topics : presets.topics,
    );
  }

  GuildModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    int? memberCount,
    int? postCount,
    int? channelCount,
    int? ruleCount,
    List<String>? topics,
  }) {
    return GuildModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      channelCount: channelCount ?? this.channelCount,
      ruleCount: ruleCount ?? this.ruleCount,
      topics: topics ?? this.topics,
    );
  }

  static List<String> _toStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<GuildModel> demoData() => const [
        GuildModel(
          id: 'guild-contemporary',
          name: 'Artyug Community',
          description: 'An iconic community curated thoughtfully just for you.',
          imageUrl: 'assets/guilds/artyug.png',
          memberCount: 14,
          postCount: 74,
          channelCount: 6,
          ruleCount: 5,
          topics: ['Exhibitions', 'Artist Growth'],
        ),
        GuildModel(
          id: 'guild-digital',
          name: 'Motojojo',
          description: 'Creators and collectors in the Motojojo circle.',
          imageUrl: 'assets/guilds/motojojo.png',
          memberCount: 12,
          postCount: 52,
          channelCount: 5,
          ruleCount: 4,
          topics: ['Street Culture', 'Collabs'],
        ),
        GuildModel(
          id: 'guild-traditional',
          name: 'Webcoin Labs',
          description: 'Webcoin Labs guild - experiments, drops, and dialogue.',
          imageUrl: 'assets/guilds/webcoinlabs.jpg',
          memberCount: 10,
          postCount: 31,
          channelCount: 7,
          ruleCount: 6,
          topics: ['Onchain Drops', 'Web3 Art'],
        ),
      ];
}

class _GuildPresets {
  final String description;
  final int postCount;
  final int channelCount;
  final int ruleCount;
  final List<String> topics;

  const _GuildPresets({
    required this.description,
    required this.postCount,
    required this.channelCount,
    required this.ruleCount,
    required this.topics,
  });

  static _GuildPresets byName(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('artyug')) {
      return const _GuildPresets(
        description: 'An iconic community curated thoughtfully just for you.',
        postCount: 74,
        channelCount: 6,
        ruleCount: 5,
        topics: ['Exhibitions', 'Artist Growth'],
      );
    }
    if (n.contains('motojojo')) {
      return const _GuildPresets(
        description: 'Creators and collectors in the Motojojo circle.',
        postCount: 52,
        channelCount: 5,
        ruleCount: 4,
        topics: ['Street Culture', 'Collabs'],
      );
    }
    if (n.contains('webcoin')) {
      return const _GuildPresets(
        description: 'Webcoin Labs guild - experiments, drops, and dialogue.',
        postCount: 31,
        channelCount: 7,
        ruleCount: 6,
        topics: ['Onchain Drops', 'Web3 Art'],
      );
    }

    return const _GuildPresets(
      description: 'An Artyug creative guild.',
      postCount: 0,
      channelCount: 3,
      ruleCount: 4,
      topics: ['Community'],
    );
  }
}
