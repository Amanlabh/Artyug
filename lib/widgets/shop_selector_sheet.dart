import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GallerySelectorSheet — replaces the old "ShopSelectorSheet"
// Terminology: "Shop" → "Gallery" throughout the app.
// ─────────────────────────────────────────────────────────────────────────────

// Keep old class name as alias so existing code compiles unchanged
typedef ShopSelectorSheet = GallerySelectorSheet;

class GallerySelectorSheet extends StatefulWidget {
  const GallerySelectorSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GallerySelectorSheet(),
    );
  }

  @override
  State<GallerySelectorSheet> createState() => _GallerySelectorSheetState();
}

class _GallerySelectorSheetState extends State<GallerySelectorSheet> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _galleries = [];
  bool _loading = true;
  String? _selectedId;

  static const _bg     = Color(0xFF0F1117);
  static const _surface = Color(0xFF181C24);
  static const _border  = Color(0xFF2B3040);
  static const _accent  = Color(0xFFFF5A1F);
  static const _text    = Color(0xFFE9EAF0);
  static const _muted   = Color(0xFF9DA3B2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _db.auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }
    try {
      final data = await _db
          .from('shops')
          .select('id, name, description, avatar_url, tags')
          .eq('owner_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      setState(() { _galleries = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _openCreate() {
    Navigator.pop(context);
    context.push('/create-gallery');
  }

  @override
  Widget build(BuildContext context) {
    final hasGalleries = _galleries.isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: _loading ? 0.4 : (hasGalleries ? 0.65 : 0.55),
      minChildSize: 0.3,
      maxChildSize: 0.88,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.collections_outlined, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WHERE TO LIST?', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                SizedBox(height: 2),
                Text('Choose where to publish this artwork', style: TextStyle(color: _muted, fontSize: 12)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _border),

          // Body
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
                if (hasGalleries) ...[
                  _label('YOUR GALLERIES'),
                  const SizedBox(height: 8),
                  ..._galleries.map((g) => _GalleryTile(
                    gallery: g,
                    selected: _selectedId == g['id'],
                    onTap: () => setState(() => _selectedId = g['id']),
                  )),
                  const SizedBox(height: 16),
                ],

                // No-gallery state
                if (!hasGalleries) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.collections_outlined, color: _accent, size: 32),
                      const SizedBox(height: 12),
                      const Text("You don't have a gallery yet", style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text("Create a gallery to sell your artwork and reach collectors. It's free.", style: TextStyle(color: _muted, fontSize: 13, height: 1.5)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openCreate,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Your Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // Profile only option
                _OptionTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: _muted,
                  title: 'My Profile',
                  subtitle: 'List under your public profile only',
                  selected: _selectedId == '__none__',
                  onTap: () => setState(() => _selectedId = '__none__'),
                ),
                const SizedBox(height: 10),

                // Create gallery option
                _OptionTile(
                  icon: Icons.add_photo_alternate_outlined,
                  iconColor: _accent,
                  title: 'Create New Gallery',
                  subtitle: 'Set up a new gallery storefront',
                  selected: false,
                  onTap: _openCreate,
                ),

                if (_selectedId != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedId == '__none__') {
                          Navigator.pop(context, null);
                        } else {
                          final g = _galleries.firstWhere((g) => g['id'] == _selectedId);
                          Navigator.pop(context, g);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.upload_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('CONTINUE TO UPLOAD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13)),
                      ]),
                    ),
                  ),
                ],
              ]),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4));
}

// ─── Gallery tile ─────────────────────────────────────────────────────────────
class _GalleryTile extends StatelessWidget {
  final Map<String, dynamic> gallery;
  final bool selected;
  final VoidCallback onTap;
  const _GalleryTile({required this.gallery, required this.selected, required this.onTap});

  static const _accent   = Color(0xFFFF5A1F);
  static const _surface  = Color(0xFF181C24);
  static const _border   = Color(0xFF2B3040);
  static const _text     = Color(0xFFE9EAF0);
  static const _muted    = Color(0xFF9DA3B2);

  @override
  Widget build(BuildContext context) {
    final avatar = gallery['avatar_url'] as String?;
    final tags = (gallery['tags'] as List?)?.cast<String>() ?? [];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _accent.withOpacity(0.08) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _accent : _border, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(12),
              image: avatar != null ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null,
            ),
            child: avatar == null ? const Icon(Icons.collections_outlined, color: _muted, size: 22) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(gallery['name'] ?? 'Untitled Gallery', style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 14)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 4, children: tags.take(3).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(4)),
                child: Text(t, style: const TextStyle(color: _muted, fontSize: 10)),
              )).toList()),
            ],
          ])),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: selected
              ? const Icon(Icons.check_circle_rounded, color: _accent, size: 22, key: ValueKey('c'))
              : const Icon(Icons.radio_button_unchecked, color: _border, size: 22, key: ValueKey('r')),
          ),
        ]),
      ),
    );
  }
}

// ─── Option tile ──────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.selected, required this.onTap});

  static const _accent  = Color(0xFFFF5A1F);
  static const _surface = Color(0xFF181C24);
  static const _border  = Color(0xFF2B3040);
  static const _text    = Color(0xFFE9EAF0);
  static const _muted   = Color(0xFF9DA3B2);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accent.withOpacity(0.06) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _accent : _border, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: selected
              ? const Icon(Icons.check_circle_rounded, color: _accent, size: 22, key: ValueKey('c'))
              : const Icon(Icons.radio_button_unchecked, color: _border, size: 22, key: ValueKey('r')),
          ),
        ]),
      ),
    );
  }
}