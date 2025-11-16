import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../components/clickable_name.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFf3f4f6), width: 1),
      ),
      elevation: 3,
      child: InkWell(
        onTap: () {
          context.push('/community-detail/${community['id']}');
        },
        borderRadius: BorderRadius.circular(16),
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
                                  color: const Color(0xFF8b5cf6),
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 50,
                                  height: 50,
                                  color: const Color(0xFF8b5cf6),
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
                                  color: const Color(0xFF8b5cf6),
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
                            color: Color(0xFF1f2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        ClickableName(
                          name: name,
                          userId: profile?['id'],
                          showPrefix: true,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.people, size: 14, color: Color(0xFF8b5cf6)),
                            const SizedBox(width: 4),
                            Text(
                              '$memberCount member${memberCount != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6b7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMember) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.check_circle, size: 14, color: Color(0xFF10b981)),
                              const SizedBox(width: 4),
                              const Text(
                                'Joined',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6b7280),
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
                    color: Color(0xFF6b7280),
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
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isMember) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Leave Community'),
                                content: Text('Are you sure you want to leave "${community['name']}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _handleLeaveCommunity(community['id']);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Leave'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            _handleJoinCommunity(community['id']);
                          }
                        },
                        icon: Icon(
                          isMember ? Icons.exit_to_app : Icons.add,
                          size: 16,
                          color: isMember ? Colors.white : const Color(0xFF8b5cf6),
                        ),
                        label: Text(isMember ? 'Leave' : 'Join'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMember
                              ? const Color(0xFFef4444)
                              : const Color(0xFFf3f4f6),
                          foregroundColor: isMember
                              ? Colors.white
                              : const Color(0xFF8b5cf6),
                          side: BorderSide(
                            color: isMember
                                ? Colors.transparent
                                : const Color(0xFF8b5cf6),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (!isMyCommunity) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/community-detail/${community['id']}');
                      },
                      icon: const Icon(Icons.visibility, size: 16, color: Colors.white),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10b981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        emptyAction = ElevatedButton.icon(
          onPressed: () => context.push('/create-community'),
          icon: const Icon(Icons.add_circle, color: Colors.white),
          label: const Text('Create Community'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8b5cf6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        break;
      case 'joined':
        communities = _getJoinedCommunities();
        emptyIcon = Icons.people_outline;
        emptyTitle = 'No Joined Communities';
        emptyText = 'Join communities to connect with other artists';
        emptyAction = ElevatedButton.icon(
          onPressed: () => setState(() => _activeTab = 'discover'),
          icon: const Icon(Icons.search, color: Colors.white),
          label: const Text('Discover Communities'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8b5cf6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
              Icon(emptyIcon, size: 64, color: const Color(0xFFd1d5db)),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1f2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6b7280),
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
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF8b5cf6)),
              SizedBox(height: 10),
              Text(
                'Loading communities...',
                style: TextStyle(fontSize: 16, color: Color(0xFF6b7280)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Communities',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Connect with fellow artists',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6b7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/create-community'),
                    icon: const Icon(Icons.add, color: Color(0xFF8b5cf6)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFf3f4f6),
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(22)),
                        side: BorderSide(color: Color(0xFFe5e7eb)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab Navigation
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFf3f4f6), width: 1),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                padding: const EdgeInsets.all(20),
                child: _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String tab, String label, IconData icon) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8b5cf6) : const Color(0xFFf9fafb),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF6b7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF6b7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

