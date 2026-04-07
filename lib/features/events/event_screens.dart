import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart' show AppColors;
import '../../providers/theme_provider.dart';
import 'event_calendar_helper.dart';

// ─── Event Model ─────────────────────────────────────────────────────────────
class EventModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String location;
  final String startDate;
  final String? endDate;
  final String hostName;
  final int capacity;
  final int participantCount;
  final bool isJoined;
  final String type; // 'exhibition' | 'workshop' | 'auction' | 'meetup'
  /// Organising community (events are hosted by one community).
  final String? communityId;
  final String? communityName;
  final String? communityImageUrl;
  final bool isCommunityMember;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.location,
    required this.startDate,
    this.endDate,
    required this.hostName,
    this.capacity = 100,
    this.participantCount = 0,
    this.isJoined = false,
    this.type = 'exhibition',
    this.communityId,
    this.communityName,
    this.communityImageUrl,
    this.isCommunityMember = false,
  });

  factory EventModel.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic>? comm;
    final raw = m['communities'];
    if (raw is Map<String, dynamic>) comm = raw;

    final communityName = comm?['name'] as String? ?? m['community_name'] as String?;
    final communityId = m['community_id']?.toString() ?? comm?['id']?.toString();
    final communityImageUrl =
        comm?['cover_image_url'] as String? ?? m['community_image_url'] as String?;

    return EventModel(
      id: m['id']?.toString() ?? '',
      title: m['title'] ?? 'Untitled Event',
      description: m['description'] ?? '',
      imageUrl: m['image_url'] as String?,
      location: m['location'] ?? 'Online',
      startDate: m['start_date']?.toString() ?? '',
      endDate: m['end_date']?.toString(),
      hostName: m['host_profiles']?['full_name'] ?? communityName ?? 'Artyug',
      capacity: (m['capacity'] as num?)?.toInt() ?? 100,
      participantCount: (m['participant_count'] as num?)?.toInt() ?? 0,
      isJoined: m['is_joined'] == true,
      type: m['type'] ?? 'exhibition',
      communityId: communityId,
      communityName: communityName,
      communityImageUrl: communityImageUrl,
      isCommunityMember: m['is_community_member'] == true,
    );
  }

  static List<EventModel> get demoEvents => const [
        EventModel(
          id: 'evt-001',
          title: 'Monsoon Art Showcase 2025',
          description:
              'A curated exhibition of works inspired by the Indian monsoon season. Meet artists, discover artworks, and witness live paintings.',
          imageUrl:
              'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=1200&q=85',
          location: 'Mumbai, Bandra West',
          startDate: '2025-07-15T18:00:00Z',
          endDate: '2025-07-15T21:00:00Z',
          hostName: 'Monsoon Art Collective',
          participantCount: 38,
          capacity: 100,
          type: 'exhibition',
          isJoined: true,
          communityName: 'Monsoon Art Collective',
          communityImageUrl:
              'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=400&q=85',
        ),
        EventModel(
          id: 'evt-002',
          title: 'Digital Art Masterclass',
          description:
              'Learn professional digital illustration techniques from award-winning digital artists. Limited seats.',
          imageUrl:
              'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1200&q=85',
          location: 'Online (Zoom)',
          startDate: '2025-06-20T10:00:00Z',
          endDate: '2025-06-20T13:00:00Z',
          hostName: 'Digital Artists Guild',
          participantCount: 12,
          capacity: 25,
          type: 'workshop',
          communityName: 'Digital Artists Guild',
          communityImageUrl:
              'https://images.unsplash.com/photo-1633356122544-f134324a6cee?w=400&q=85',
        ),
        EventModel(
          id: 'evt-003',
          title: 'Contemporary Sculptures Auction',
          description:
              'Bid on exclusive contemporary sculptures from 10 renowned artists. Starting prices from ₹5,000.',
          imageUrl:
              'https://images.unsplash.com/photo-1561214115-f2f134705491?w=1200&q=85',
          location: 'Delhi, Connaught Place',
          startDate: '2025-08-01T15:00:00Z',
          endDate: '2025-08-01T19:00:00Z',
          hostName: 'Sculptors Circle',
          participantCount: 5,
          capacity: 50,
          type: 'auction',
          communityName: 'Sculptors Circle',
          communityImageUrl:
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=85',
        ),
      ];
}

// ─── Events Screen ────────────────────────────────────────────────────────────
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<EventModel> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (AppConfig.isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() { _all = EventModel.demoEvents; _loading = false; });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('*, communities(id, name, cover_image_url)')
          .order('start_date');
      if (mounted) {
        setState(() {
          _all = (data as List)
              .map(
                  (m) => EventModel.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _all = EventModel.demoEvents; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: kBlack), onPressed: () => context.pop()),
      title: const Text('EVENTS & GUILD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack)),
      bottom: TabBar(
        controller: _tabs,
        labelColor: kOrange, unselectedLabelColor: kGrey,
        indicatorColor: kOrange,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        tabs: const [Tab(text: 'ALL'), Tab(text: 'JOINED'), Tab(text: 'GUILD')],
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: kOrange))
        : TabBarView(controller: _tabs, children: [
            _EventsList(events: _all, onRefresh: _load),
            _EventsList(events: _all.where((e) => e.isJoined).toList(), onRefresh: _load),
            const _GuildHomeTab(),
          ]),
  );
}

class _EventsList extends StatelessWidget {
  final List<EventModel> events;
  final Future<void> Function() onRefresh;
  const _EventsList({required this.events, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_outlined, size: 64, color: kGrey),
            SizedBox(height: 16),
            Text(
              'No events yet',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: kBlack),
            ),
            SizedBox(height: 8),
            Text(
              'Events and exhibitions will appear here.',
              style: TextStyle(color: kGrey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kOrange,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, i) => _EventCard(event: events[i]),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final EventModel event;
  const _EventCard({required this.event});
  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  late bool _participating;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _participating = widget.event.isJoined;
  }

  Color get _typeColor => switch (widget.event.type) {
        'exhibition' => kOrange,
        'workshop' => const Color(0xFF7C3AED),
        'auction' => const Color(0xFF0EA5E9),
        _ => kGrey,
      };

  String _formatDate(String s) {
    try {
      final d = DateTime.parse(s);
      return DateFormat('MMM d, yyyy').format(d);
    } catch (_) {
      return s.split('T').first;
    }
  }

  Widget _heroImage() {
    final url = widget.event.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        height: 168,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 168,
          color: _typeColor.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2, color: kOrange),
        ),
        errorWidget: (_, __, ___) => _heroPlaceholder(),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() => Container(
        height: 140,
        color: _typeColor.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: Icon(
          switch (widget.event.type) {
            'workshop' => Icons.school_outlined,
            'auction' => Icons.gavel_outlined,
            _ => Icons.palette_outlined,
          },
          size: 48,
          color: _typeColor.withValues(alpha: 0.55),
        ),
      );

  void _openCommunity(BuildContext context) {
    final id = widget.event.communityId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This demo event has no community id. In live mode, link events to a community in Supabase.',
          ),
        ),
      );
      return;
    }
    context.push('/community-detail/$id');
  }

  Future<void> _onParticipate() async {
    if (_participating) {
      setState(() => _participating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You’re no longer marked as participating.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    final start =
        DateTime.tryParse(widget.event.startDate) ?? DateTime.now();
    final end = widget.event.endDate != null
        ? DateTime.tryParse(widget.event.endDate!)
        : null;

    final ok = await addEventToDeviceOrGoogleCalendar(
      title: widget.event.title,
      description: widget.event.description,
      location: widget.event.location,
      start: start,
      end: end,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _participating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'You’re participating — open your calendar to confirm.'
              : 'Marked as participating. Could not open calendar — add the event manually.',
        ),
        backgroundColor: ok ? const Color(0xFF16A34A) : kOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              context.push('/event/${widget.event.id}', extra: widget.event),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroImage(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _typeColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                widget.event.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _typeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (_participating) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'PARTICIPATING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.event.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textOnLight,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: AppColors.textOnLightSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.event.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textOnLightSecondary,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_outlined,
                                size: 14, color: AppColors.textOnLightSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(widget.event.startDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textOnLightSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (widget.event.communityName != null &&
                            widget.event.communityName!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Organised by',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textOnLightSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: widget.event.communityImageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl:
                                            widget.event.communityImageUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 40,
                                          height: 40,
                                          color: kOrangeLight,
                                          child: const Icon(Icons.groups,
                                              color: kOrange, size: 22),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: kOrangeLight,
                                        child: const Icon(Icons.groups,
                                            color: kOrange, size: 22),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.event.communityName!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textOnLight,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openCommunity(context),
                                child: Text(
                                  widget.event.isCommunityMember
                                      ? 'View'
                                      : 'Join community',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.event.participantCount}/${widget.event.capacity} attending',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textOnLightSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: widget.event.capacity > 0
                                          ? widget.event.participantCount /
                                              widget.event.capacity
                                          : 0,
                                      backgroundColor: kBg,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          _typeColor),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : () => _onParticipate(),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _participating
                                            ? Icons.event_busy_outlined
                                            : Icons.event_available_outlined,
                                        size: 18,
                                      ),
                                label: Text(
                                  _participating ? 'Leave' : 'Participate',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _participating
                                      ? const Color(0xFF334155)
                                      : kOrange,
                                  foregroundColor: Colors.white,
                                  side: _participating
                                      ? BorderSide(
                                          color: Colors.white.withValues(
                                              alpha: 0.2))
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
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
          ),
        ),
      );
}

// ─── Event Detail Loading Screen — used when navigation has no `extra` ──────
class EventDetailLoadingScreen extends StatefulWidget {
  final String eventId;
  const EventDetailLoadingScreen({super.key, required this.eventId});
  @override
  State<EventDetailLoadingScreen> createState() => _EventDetailLoadingScreenState();
}

class _EventDetailLoadingScreenState extends State<EventDetailLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Try demo events first
    final demo = EventModel.demoEvents
        .where((e) => e.id == widget.eventId)
        .firstOrNull;
    if (demo != null) {
      if (!mounted) return;
      context.replace('/event/${widget.eventId}', extra: demo);
      return;
    }
    // 2. Try Supabase
    try {
      final data = await Supabase.instance.client
          .from('events')
          .select('*, communities(id, name, cover_image_url)')
          .eq('id', widget.eventId)
          .single();
      final event =
          EventModel.fromMap(Map<String, dynamic>.from(data as Map));
      if (!mounted) return;
      context.replace('/event/${widget.eventId}', extra: event);
    } catch (_) {
      // Fall back to list
      if (mounted) context.go('/events');
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: kBg,
        body: Center(
            child: CircularProgressIndicator(color: kOrange)),
      );
}

// ─── Event Detail Screen ──────────────────────────────────────────────────────
class EventDetailScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late bool _participating;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _participating = widget.event.isJoined;
  }

  Future<void> _onParticipate() async {
    if (_participating) {
      setState(() => _participating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You’re no longer marked as participating.')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    final start =
        DateTime.tryParse(widget.event.startDate) ?? DateTime.now();
    final end = widget.event.endDate != null
        ? DateTime.tryParse(widget.event.endDate!)
        : null;

    final ok = await addEventToDeviceOrGoogleCalendar(
      title: widget.event.title,
      description: widget.event.description,
      location: widget.event.location,
      start: start,
      end: end,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _participating = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'You’re participating — check your calendar.'
              : 'Marked as participating. Calendar could not be opened.',
        ),
        backgroundColor: ok ? const Color(0xFF16A34A) : kOrange,
      ),
    );
  }

  void _openCommunity() {
    final id = widget.event.communityId;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No community is linked to this event yet.',
          ),
        ),
      );
      return;
    }
    context.push('/community-detail/$id');
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: e.imageUrl != null ? 260 : 140,
            pinned: true,
            backgroundColor: kBg,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white70,
                child: Icon(Icons.arrow_back, color: kBlack, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: e.imageUrl != null && e.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: e.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: kOrangeLight),
                      errorWidget: (_, __, ___) =>
                          Container(color: kOrangeLight),
                    )
                  : Container(color: kOrangeLight),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.communityName != null
                        ? 'Organised by ${e.communityName}'
                        : 'Hosted by ${e.hostName}',
                    style: const TextStyle(fontSize: 14, color: kGrey),
                  ),
                  if (e.communityName != null &&
                      e.communityName!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openCommunity,
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: Text(
                        e.isCommunityMember
                            ? 'View community'
                            : 'Join community',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kBlack,
                        side: const BorderSide(color: kBorder),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(Icons.location_on_outlined, e.location),
                        const SizedBox(height: 10),
                        _InfoRow(Icons.calendar_today_outlined,
                            e.startDate.split('T').first),
                        const SizedBox(height: 10),
                        _InfoRow(Icons.people_outline,
                            '${e.participantCount}/${e.capacity} attending'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ABOUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kGrey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    e.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: kBlack,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _onParticipate,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _participating
                                  ? Icons.event_busy_outlined
                                  : Icons.event_available_outlined,
                            ),
                      label: Text(
                        _participating
                            ? 'Leave (stop participating)'
                            : 'Participate & add to calendar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _participating
                            ? const Color(0xFF334155)
                            : kOrange,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: kOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textOnLight,
            ),
          ),
        ),
      ]);
}

// ─── Guild Home Tab ───────────────────────────────────────────────────────────
class _GuildHomeTab extends StatelessWidget {
  const _GuildHomeTab();

  static const _guilds = [
    {'name': 'Painters Guild', 'members': 142, 'icon': Icons.brush_outlined},
    {'name': 'Digital Artists', 'members': 89, 'icon': Icons.computer_outlined},
    {'name': 'Photography Circle', 'members': 67, 'icon': Icons.camera_outlined},
    {'name': 'Mixed Media Collective', 'members': 43, 'icon': Icons.layers_outlined},
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kBlack, Color(0xFF1a1a1a)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.group_outlined, color: kOrange, size: 28),
              SizedBox(height: 12),
              Text('THE ARTYUG GUILD',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: kWhite,
                  )),
              SizedBox(height: 6),
              Text(
                  'Exclusive communities for creators and collectors. Join a guild to access curated events, peer feedback, and collaborations.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      height: 1.5)),
            ]),
      ),
      const SizedBox(height: 24),
      const Text('ACTIVE GUILDS', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800, color: kGrey, letterSpacing: 1.2,
      )),
      const SizedBox(height: 14),
      ...(_guilds as List<Map>).map((g) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(12)),
              child: Icon(g['icon'] as IconData, size: 22, color: kOrange),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kBlack)),
              Text('${g['members']} members', style: const TextStyle(fontSize: 12, color: kGrey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kOrange, borderRadius: BorderRadius.circular(100),
              ),
              child: const Text('Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kWhite)),
            ),
          ]),
        ),
      )),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('REQUEST AN EVENT', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800, color: kBlack, letterSpacing: 1,
          )),
          const SizedBox(height: 8),
          const Text('Are you a creator? Request a managed exhibition or workshop through the Artyug team.',
              style: TextStyle(fontSize: 13, color: kGrey, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event request feature coming soon!')));
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Request Event', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(foregroundColor: kBlack, side: const BorderSide(color: kBorder)),
          )),
        ]),
      ),
    ]),
  );
}
