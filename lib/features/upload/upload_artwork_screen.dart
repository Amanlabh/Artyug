import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Upload Artwork Screen — Gallery Management
//
// Web-safe: uses image_picker (works on web & native).
// No dart:io File references at top level — XFile is platform-agnostic.
// Uploads to Supabase Storage `paintings` bucket.
// Creates row in `paintings` table.
// ─────────────────────────────────────────────────────────────────────────────

class UploadArtworkScreen extends StatefulWidget {
  const UploadArtworkScreen({super.key});

  @override
  State<UploadArtworkScreen> createState() => _UploadArtworkScreenState();
}

class _UploadArtworkScreenState extends State<UploadArtworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Form controllers
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mediumCtrl = TextEditingController();
  final _dimensionsCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  // State
  List<XFile> _pickedImages = [];
  String _category = 'Painting';
  bool _isForSale = true;
  bool _uploading = false;
  double _progress = 0;
  int _currentStep = 0; // 0=image, 1=details, 2=price & publish

  static const _categories = [
    'Painting',
    'Digital Art',
    'Photography',
    'Sculpture',
    'Drawing',
    'Print',
    'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _mediumCtrl.dispose();
    _dimensionsCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  // ─── Image picking ────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final imgs = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (imgs.isNotEmpty) {
        setState(() {
          // Merge new picks, cap at 8 images
          final combined = [..._pickedImages, ...imgs];
          _pickedImages = combined.take(8).toList();
        });
      }
    } catch (e) {
      _showSnack('Could not pick image: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  // ─── Upload & publish ─────────────────────────────────────────────────────

  Future<void> _publish() async {
    if (_pickedImages.isEmpty) {
      _showSnack('Please select at least one image', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) {
      context.push('/sign-in');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 0.1;
    });

    try {
      // ── 1. Upload primary image (first in list) ───────────────────────────
      final primary = _pickedImages.first;
      final bytes = await primary.readAsBytes();
      final ext = primary.name.split('.').last.toLowerCase().replaceAll('blob', 'jpg');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '${user.id}/$ts.$ext';

      setState(() => _progress = 0.2);

      await Supabase.instance.client.storage
          .from('paintings')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
              upsert: false,
            ),
          );

      final imageUrl = Supabase.instance.client.storage
          .from('paintings')
          .getPublicUrl(storagePath);

      setState(() => _progress = 0.5);

      // ── 2. Upload additional images ───────────────────────────────────────
      final additionalUrls = <String>[];
      for (int i = 1; i < _pickedImages.length; i++) {
        final img = _pickedImages[i];
        final b = await img.readAsBytes();
        final e = img.name.split('.').last.toLowerCase().replaceAll('blob', 'jpg');
        final p = '${user.id}/${ts}_$i.$e';
        await Supabase.instance.client.storage
            .from('paintings')
            .uploadBinary(p, b,
                fileOptions: FileOptions(
                    contentType: 'image/${e == 'jpg' ? 'jpeg' : e}',
                    upsert: false));
        additionalUrls.add(
            Supabase.instance.client.storage.from('paintings').getPublicUrl(p));
        setState(() => _progress = 0.5 + i.toDouble() / _pickedImages.length.toDouble() * 0.2);
      }

      setState(() => _progress = 0.7);

      // ── 2. Parse tags ─────────────────────────────────────────────────────
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();

      // ── 3. Insert painting row ────────────────────────────────────────────
      final price = double.tryParse(
          _priceCtrl.text.trim().replaceAll('₹', '').trim());

      await Supabase.instance.client.from('paintings').insert({
        'artist_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'image_url': imageUrl,
        'additional_images': additionalUrls.isEmpty ? null : additionalUrls,
        'category': _category,
        'medium': _mediumCtrl.text.trim().isEmpty
            ? null
            : _mediumCtrl.text.trim(),
        'dimensions': _dimensionsCtrl.text.trim().isEmpty
            ? null
            : _dimensionsCtrl.text.trim(),
        'price': _isForSale ? price : null,
        'is_for_sale': _isForSale,
        'status': 'available',
        'style_tags': tags,
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() => _progress = 1.0);

      if (mounted) {
        _showSnack('Artwork published! 🎨');
        await Future.delayed(const Duration(milliseconds: 400));
        context.pop();
      }
    } catch (e) {
      _showSnack('Failed to publish: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _uploading ? _buildUploading() : _buildForm(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'PUBLISH ARTWORK',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      actions: [
        if (!_uploading)
          TextButton(
            onPressed: _publish,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Publish',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildUploading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 5,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _progress < 0.5
                ? 'Uploading image...'
                : _progress < 0.8
                    ? 'Processing...'
                    : 'Publishing artwork...',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(_progress * 100).round()}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Image picker ────────────────────────────────────────────────
          _SectionLabel('ARTWORK IMAGES (up to 8)'),
          const SizedBox(height: 8),
          _ImageGridPicker(
            images: _pickedImages,
            onPickMore: _pickImage,
            onRemove: _removeImage,
          ),

          const SizedBox(height: 28),

          // ── Title ───────────────────────────────────────────────────────
          _SectionLabel('TITLE *'),
          const SizedBox(height: 8),
          _Field(
            controller: _titleCtrl,
            hint: 'e.g. Sunset Over Old Delhi',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),

          const SizedBox(height: 20),

          // ── Category ────────────────────────────────────────────────────
          _SectionLabel('CATEGORY'),
          const SizedBox(height: 8),
          _CategoryPicker(
            categories: _categories,
            selected: _category,
            onSelect: (c) => setState(() => _category = c),
          ),

          const SizedBox(height: 20),

          // ── Description ─────────────────────────────────────────────────
          _SectionLabel('DESCRIPTION'),
          const SizedBox(height: 8),
          _Field(
            controller: _descCtrl,
            hint: 'Tell collectors the story behind this piece...',
            maxLines: 4,
          ),

          const SizedBox(height: 20),

          // ── Medium + Dimensions row ─────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('MEDIUM'),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _mediumCtrl,
                      hint: 'Oil on canvas',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('DIMENSIONS'),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _dimensionsCtrl,
                      hint: '24 × 36 in',
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Tags ────────────────────────────────────────────────────────
          _SectionLabel('STYLE TAGS'),
          const SizedBox(height: 4),
          const Text(
            'Comma-separated: impressionism, blue, abstract',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          _Field(
            controller: _tagsCtrl,
            hint: 'impressionism, landscape, oil',
          ),

          const SizedBox(height: 28),

          // ── Pricing ─────────────────────────────────────────────────────
          _PricingCard(
            isForSale: _isForSale,
            priceController: _priceCtrl,
            onToggleSale: (v) => setState(() => _isForSale = v),
          ),

          const SizedBox(height: 28),

          // ── Web notice ──────────────────────────────────────────────────
          if (kIsWeb)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'On mobile, image quality is optimized automatically. '
                      'Web uploads may be slightly larger.',
                      style: TextStyle(
                        color: AppColors.primary.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          // ── Publish button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Publish Artwork',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
          color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textTertiary, fontSize: 14),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── Image grid picker (Amazon-style square thumbnails) ──────────────────────

class _ImageGridPicker extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onPickMore;
  final void Function(int) onRemove;

  const _ImageGridPicker({
    required this.images,
    required this.onPickMore,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return GestureDetector(
        onTap: onPickMore,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.primary, size: 30),
              ),
              const SizedBox(height: 12),
              const Text('Tap to add artwork images',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
              const SizedBox(height: 4),
              const Text('Up to 8 images · JPEG, PNG, WEBP',
                  style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // Amazon-style: first image is large hero (left), rest are small squares (right column)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 280,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero / primary image ───────────────────────────────────
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                      child: _SquareImage(
                        path: images[0].path,
                        size: double.infinity,
                        isHero: true,
                      ),
                    ),
                    // PRIMARY badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PRIMARY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            )),
                      ),
                    ),
                    // Remove hero
                    Positioned(
                      top: 8, right: 8,
                      child: _RemoveBtn(onTap: () => onRemove(0)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // ── Thumbnail strip ────────────────────────────────────────
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Existing thumbnails (indices 1–5)
                    for (int i = 1; i <= 5; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: i < images.length
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topRight: i == 1 ? const Radius.circular(14) : Radius.zero,
                                        bottomRight: i == 5 || i == images.length - 1
                                            ? const Radius.circular(14)
                                            : Radius.zero,
                                      ),
                                      child: _SquareImage(
                                          path: images[i].path,
                                          size: double.infinity),
                                    ),
                                    Positioned(
                                      top: 3, right: 3,
                                      child: _RemoveBtn(
                                          size: 18, onTap: () => onRemove(i)),
                                    ),
                                  ],
                                )
                              // Add more slot
                              : i == images.length && images.length < 8
                                  ? GestureDetector(
                                      onTap: onPickMore,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: const Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppColors.primary, size: 22),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Bottom action row ────────────────────────────────────────────
        Row(
          children: [
            Text(
              '${images.length}/8 image${images.length == 1 ? '' : 's'} selected',
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 12),
            ),
            const Spacer(),
            if (images.length < 8)
              TextButton.icon(
                onPressed: onPickMore,
                icon: const Icon(Icons.add, size: 16,
                    color: AppColors.primary),
                label: const Text('Add more',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ],
        ),
      ],
    );
  }
}

class _SquareImage extends StatelessWidget {
  final String path;
  final double size;
  final bool isHero;
  const _SquareImage({required this.path, required this.size, this.isHero = false});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      path,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surface,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textTertiary, size: 28),
      ),
    );
  }
}

class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  const _RemoveBtn({required this.onTap, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close, color: Colors.white, size: size * 0.6),
      ),
    );
  }
}

// ─── Category picker ──────────────────────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;

  const _CategoryPicker({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final active = cat == selected;
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              cat,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textSecondary,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Pricing card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  final bool isForSale;
  final TextEditingController priceController;
  final void Function(bool) onToggleSale;

  const _PricingCard({
    required this.isForSale,
    required this.priceController,
    required this.onToggleSale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Pricing & Availability',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Switch(
                value: isForSale,
                onChanged: onToggleSale,
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Toggle off to list as "Not for Sale"',
            style: TextStyle(
                color: AppColors.textTertiary, fontSize: 12),
          ),
          if (isForSale) ...[
            const SizedBox(height: 16),
            const Text(
              'PRICE (₹)',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: priceController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                hintText: '0',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 22),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
              validator: (v) {
                if (isForSale) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) return 'Enter a valid price';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}
