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
          .select('id, name, description, member_count, created_at')
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

        final myIds = (myRes as List)
            .map((j) => j['community_id'] as String)
            .toSet();

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

    final isJoined = _myGuilds.any((g) => g.id == guild.id);
    try {
      if (isJoined) {
        await Supabase.instance.client
            .from('community_members')
            .delete()
            .eq('user_id', userId)
            .eq('community_id', guild.id);
        setState(() => _myGuilds.removeWhere((g) => g.id == guild.id));
      } else {
        await Supabase.instance.client
            .from('community_members')
            .insert({'user_id': userId, 'community_id': guild.id});
        setState(() => _myGuilds.add(guild));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update membership')),
        );
      }
    }
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
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
      onRefresh: () => Future.value(),
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
          children: [
            // Guild avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.7),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  guild.name.isNotEmpty
                      ? guild.name[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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
                  const SizedBox(height: 2),
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
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                TextButton(
                  onPressed: onJoin,
                  style: TextButton.styleFrom(
                    backgroundColor: isJoined
                        ? AppColors.surfaceHigh
                        : AppColors.primary,
                    foregroundColor: isJoined
                        ? AppColors.textSecondary
                        : Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
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
          ],
        ),
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class GuildModel {
  final String id;
  final String name;
  final String? description;
  final int memberCount;

  const GuildModel({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
  });

  factory GuildModel.fromJson(Map<String, dynamic> json) => GuildModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Guild',
        description: json['description'] as String?,
        memberCount: json['member_count'] as int? ?? 0,
      );

  static List<GuildModel> demoData() => const [
        GuildModel(
          id: 'guild-contemporary',
          name: 'Artyug Community',
          description:
              'An iconic community curated thoughtfully just for you.',
          memberCount: 14,
        ),
        GuildModel(
          id: 'guild-digital',
          name: 'Motojojo',
          description:
              'Creators and collectors in the Motojojo circle.',
          memberCount: 12,
        ),
        GuildModel(
          id: 'guild-traditional',
          name: 'Webcoin Labs',
          description:
              'Webcoin Labs guild — experiments, drops, and dialogue.',
          memberCount: 10,
        ),
      ];
}
