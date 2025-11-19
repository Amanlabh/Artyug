import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../components/clickable_name.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;
  String _activeTab = 'my-communities';

  @override
  void initState() {
    super.initState();
    _fetchCommunities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen comes into focus
    _fetchCommunities();
  }

  Future<void> _fetchCommunities() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final response = await _supabase
          .from('communities')
          .select('*')
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        setState(() {
          _communities = [];
          _loading = false;
        });
        return;
      }

      final communitiesData = List<Map<String, dynamic>>.from(response);
      final creatorIds = communitiesData
          .map((c) => c['creator_id'] as String)
          .toSet()
          .toList();

      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .inFilter('id', creatorIds);

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);

      final communitiesWithStats = await Future.wait(
        communitiesData.map((community) async {
          // Get member count by fetching all members and counting
          final memberCountResponse = await _supabase
              .from('community_members')
              .select('id')
              .eq('community_id', community['id']);

          final memberCount = (memberCountResponse as List).length;

          final membershipResponse = await _supabase
              .from('community_members')
              .select('id')
              .eq('community_id', community['id'])
              .eq('user_id', user.id)
              .maybeSingle();

          final isMember = membershipResponse != null;

          final profile = profilesData.firstWhere(
            (p) => p['id'] == community['creator_id'],
            orElse: () => <String, dynamic>{},
          );

          return {
            ...community,
            'profiles': profile,
            'member_count': memberCount,
            'is_member': isMember,
          };
        }),
      );

      setState(() {
        _communities = communitiesWithStats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _communities = [];
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getMyCommunities() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return _communities
        .where((c) => c['creator_id'] == user?.id)
        .toList();
  }

  List<Map<String, dynamic>> _getJoinedCommunities() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return _communities
        .where((c) => c['is_member'] == true && c['creator_id'] != user?.id)
        .toList();
  }

  List<Map<String, dynamic>> _getDiscoverCommunities() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    return _communities
        .where((c) => c['is_member'] == false && c['creator_id'] != user?.id)
        .toList();
  }

  List<Map<String, dynamic>> _getPopularCommunities() {
    final sorted = List<Map<String, dynamic>>.from(_communities)
      ..sort((a, b) => (b['member_count'] as int).compareTo(a['member_count'] as int));
    return sorted.where((c) => c['is_member'] == false).take(5).toList();
  }

  Future<void> _handleJoinCommunity(String communityId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      _showError('Please sign in to join communities');
      return;
    }

    try {
      await _supabase.from('community_members').insert({
        'community_id': communityId,
        'user_id': user.id,
        'role': 'member',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have joined the community!')),
        );
        _fetchCommunities();
      }
    } catch (e) {
      if (e.toString().contains('23505')) {
        _showError('You are already a member of this community');
      } else {
        _showError('Failed to join community');
      }
    }
  }

  Future<void> _handleLeaveCommunity(String communityId) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      _showError('Please sign in to leave communities');
      return;
    }

    try {
      await _supabase
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('user_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the community')),
        );
        _fetchCommunities();
      }
    } catch (e) {
      _showError('Failed to leave community');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildCommunityCard(Map<String, dynamic> community, {bool isMyCommunity = false}) {
    final isMember = community['is_member'] as bool? ?? false;
    final memberCount = community['member_count'] as int? ?? 0;
    final profile = community['profiles'] as Map<String, dynamic>?;
    final name = profile?['display_name'] ?? profile?['username'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.4),
          width: 1.5,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.push('/community-detail/${community['id']}');
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: community['cover_image_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: community['cover_image_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.purpleAccent,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.purpleAccent,
                                        child: Center(
                                          child: Text(
                                            (community['name'] as String? ?? 'C')[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.purpleAccent,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (community['name'] as String? ?? 'C')[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (isMyCommunity)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                community['name'] ?? 'Community',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClickableName(
                                name: name,
                                userId: profile?['id'],
                                showPrefix: true,
                                textStyle: const TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 14, color: Colors.purpleAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$memberCount member${memberCount != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isMember) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Joined',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (community['description'] != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        community['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!isMyCommunity)
                          Expanded(
                            child: _buildRetroButton(
                              onPressed: () {
                                if (isMember) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF24243e),
                                      title: const Text(
                                        'Leave Community',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: Text(
                                        'Are you sure you want to leave "${community['name']}"?',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _handleLeaveCommunity(community['id']);
                                          },
                                          child: const Text('Leave', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  _handleJoinCommunity(community['id']);
                                }
                              },
                              text: isMember ? 'Leave' : 'Join',
                              icon: isMember ? Icons.exit_to_app : Icons.add,
                              isDanger: isMember,
                            ),
                          ),
                        if (!isMyCommunity) const SizedBox(width: 12),
                        Expanded(
                          child: _buildRetroButton(
                            onPressed: () {
                              context.push('/community-detail/${community['id']}');
                            },
                            text: 'View',
                            icon: Icons.visibility,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetroButton({
    required VoidCallback? onPressed,
    required String text,
    IconData? icon,
    bool isPrimary = false,
    bool isDanger = false,
  }) {
    Color buttonColor;
    if (isDanger) {
      buttonColor = Colors.red;
    } else if (isPrimary) {
      buttonColor = Colors.greenAccent;
    } else {
      buttonColor = Colors.purpleAccent;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: buttonColor.withOpacity(0.4),
          width: 1.5,
        ),
        gradient: LinearGradient(
          colors: [
            buttonColor,
            buttonColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    List<Map<String, dynamic>> communities;
    IconData emptyIcon;
    String emptyTitle;
    String emptyText;
    Widget? emptyAction;

    switch (_activeTab) {
      case 'my-communities':
        communities = _getMyCommunities();
        emptyIcon = Icons.people_outline;
        emptyTitle = 'No Communities Created';
        emptyText = "You haven't created any communities yet";
        emptyAction = _buildRetroButton(
          onPressed: () => context.push('/create-community'),
          text: 'Create Community',
          icon: Icons.add_circle,
        );
        break;
      case 'joined':
        communities = _getJoinedCommunities();
        emptyIcon = Icons.people_outline;
        emptyTitle = 'No Joined Communities';
        emptyText = 'Join communities to connect with other artists';
        emptyAction = _buildRetroButton(
          onPressed: () => setState(() => _activeTab = 'discover'),
          text: 'Discover Communities',
          icon: Icons.search,
        );
        break;
      case 'discover':
        communities = _getDiscoverCommunities();
        emptyIcon = Icons.public_outlined;
        emptyTitle = 'No Communities Available';
        emptyText = 'Be the first to create a community';
        emptyAction = null;
        break;
      case 'popular':
        communities = _getPopularCommunities();
        emptyIcon = Icons.trending_up_outlined;
        emptyTitle = 'No Popular Communities';
        emptyText = 'Communities will appear here as they grow';
        emptyAction = null;
        break;
      default:
        return const SizedBox();
    }

    if (communities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 64, color: Colors.white.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              if (emptyAction != null) ...[
                const SizedBox(height: 24),
                emptyAction,
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: communities.length,
      itemBuilder: (context, index) {
        final isMyCommunity = _activeTab == 'my-communities';
        return _buildCommunityCard(communities[index], isMyCommunity: isMyCommunity);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildRetroAppBar(),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          if (_loading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.purpleAccent),
                  SizedBox(height: 10),
                  Text(
                    'Loading communities...',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Tab Navigation
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab('my-communities', 'My Communities', Icons.star),
                        const SizedBox(width: 8),
                        _buildTab('joined', 'Joined', Icons.people),
                        const SizedBox(width: 8),
                        _buildTab('discover', 'Discover', Icons.public),
                        const SizedBox(width: 8),
                        _buildTab('popular', 'Popular', Icons.trending_up),
                      ],
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildTabContent(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildRetroAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black.withOpacity(0.4),
      centerTitle: true,
      title: const Text(
        'Communities',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/create-community'),
          icon: const Icon(Icons.add, color: Colors.white),
          tooltip: 'Create Community',
        ),
      ],
    );
  }

  Widget _buildTab(String tab, String label, IconData icon) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.purpleAccent
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Colors.purpleAccent
                : Colors.purpleAccent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

