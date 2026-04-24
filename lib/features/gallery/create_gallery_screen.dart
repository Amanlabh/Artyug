import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

/// Full-screen wizard for creating an artist gallery.
/// Asks: gallery name, description, cover photo — all one by one (CRED-style).
class CreateGalleryScreen extends StatefulWidget {
  const CreateGalleryScreen({super.key});

  @override
  State<CreateGalleryScreen> createState() => _CreateGalleryScreenState();
}

class _CreateGalleryScreenState extends State<CreateGalleryScreen>
    with SingleTickerProviderStateMixin {

  static const _bg      = Color(0xFF0A0C12);
  static const _surface = Color(0xFF181C24);
  static const _border  = Color(0xFF2B3040);
  static const _accent  = Color(0xFFFF5A1F);
  static const _text    = Color(0xFFE9EAF0);
  static const _muted   = Color(0xFF9DA3B2);

  final PageController _page = PageController();
  int _step = 0;
  bool _saving = false;

  // Form values
  XFile? _coverPhoto;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool get _canContinue {
    switch (_step) {
      case 0: return _coverPhoto != null;
      case 1: return _nameCtrl.text.trim().length >= 3;
      case 2: return true; // description optional
      default: return true;
    }
  }

  Future<void> _pickPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img != null) setState(() => _coverPhoto = img);
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _page.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _page.animateToPage(_step, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final db = Supabase.instance.client;
      final user = db.auth.currentUser;
      if (user == null) { setState(() => _saving = false); return; }

      String? avatarUrl;
      if (_coverPhoto != null) {
        final bytes = await File(_coverPhoto!.path).readAsBytes();
        final ext = _coverPhoto!.path.split('.').last;
        final path = 'gallery-covers/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await db.storage.from('shop-assets').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
        avatarUrl = db.storage.from('shop-assets').getPublicUrl(path);
      }

      await db.from('shops').insert({
        'owner_id': user.id,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'is_active': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gallery created! ✨'),
          backgroundColor: _accent,
        ));
        context.pop(); // go back to selector
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Cover', 'Name', 'About'];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        // ── Top bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            GestureDetector(
              onTap: _back,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 16),
              ),
            ),
            const Spacer(),
            Text('${_step + 1} / ${steps.length}', style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),

        // ── Progress bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: List.generate(steps.length, (i) => Expanded(child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            margin: EdgeInsets.only(right: i < steps.length - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: i <= _step ? _accent : _border,
              borderRadius: BorderRadius.circular(2),
            ),
          )))),
        ),
        const SizedBox(height: 8),

        // ── Pages ────────────────────────────────────────────────────
        Expanded(
          child: PageView(
            controller: _page,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _PhotoStep(photo: _coverPhoto, onPick: _pickPhoto),
              _TextStep(
                icon: Icons.storefront_outlined,
                label: 'GALLERY NAME',
                hint: "e.g. Ravi's Abstract Studio",
                ctrl: _nameCtrl,
                maxLength: 48,
                onChanged: (_) => setState(() {}),
              ),
              _TextStep(
                icon: Icons.edit_note_rounded,
                label: 'SHORT BIO',
                hint: 'Tell collectors what makes your gallery special…',
                ctrl: _descCtrl,
                maxLength: 280,
                maxLines: 5,
                onChanged: (_) => setState(() {}),
                optional: true,
              ),
            ],
          ),
        ),

        // ── Bottom CTA ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: (_canContinue && !_saving) ? _next : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withOpacity(0.25),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == 2 ? 'CREATE GALLERY' : 'CONTINUE',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8)),
            ),
          ),
        ),
      ])),
    );
  }
}

// ─── Photo Step ───────────────────────────────────────────────────────────────
class _PhotoStep extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onPick;
  const _PhotoStep({required this.photo, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        const Text('Add a cover photo', style: TextStyle(color: Color(0xFFE9EAF0), fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('This is the first thing collectors see when they visit your gallery.', style: TextStyle(color: Color(0xFF9DA3B2), fontSize: 15, height: 1.5)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onPick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity, height: 220,
            decoration: BoxDecoration(
              color: photo != null ? null : const Color(0xFF181C24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: photo != null ? const Color(0xFFFF5A1F) : const Color(0xFF2B3040), width: 1.5),
              image: photo != null
                ? DecorationImage(image: FileImage(File(photo!.path)), fit: BoxFit.cover)
                : null,
            ),
            child: photo == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_photo_alternate_outlined, color: Color(0xFFFF5A1F), size: 40),
              SizedBox(height: 12),
              Text('Tap to choose a photo', style: TextStyle(color: Color(0xFF9DA3B2), fontSize: 14)),
            ]) : null,
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 16),
          Center(child: TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.swap_horiz, color: Color(0xFFFF5A1F), size: 16),
            label: const Text('Change photo', style: TextStyle(color: Color(0xFFFF5A1F))),
          )),
        ],
      ]),
    );
  }
}

// ─── Text Step ────────────────────────────────────────────────────────────────
class _TextStep extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final TextEditingController ctrl;
  final int maxLength;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final bool optional;
  const _TextStep({required this.icon, required this.label, required this.hint, required this.ctrl, required this.maxLength, this.maxLines = 1, required this.onChanged, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 40),
        Row(children: [
          Icon(icon, color: const Color(0xFFFF5A1F), size: 28),
          const SizedBox(width: 10),
          Text(optional ? '$label (optional)' : label,
            style: const TextStyle(color: Color(0xFF9DA3B2), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          maxLength: maxLength,
          maxLines: maxLines,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE9EAF0), fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF3A3F50), fontSize: 20, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: const Color(0xFF181C24),
            counterStyle: const TextStyle(color: Color(0xFF9DA3B2), fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2B3040))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF2B3040))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5A1F), width: 1.5)),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ]),
    );
  }
}
