import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';

class UploadArtworkScreen extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  const UploadArtworkScreen({super.key, this.shopId, this.shopName});
  @override
  State<UploadArtworkScreen> createState() => _UploadArtworkScreenState();
}

class _UploadArtworkScreenState extends State<UploadArtworkScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mediumCtrl = TextEditingController();
  final _dimCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  List<XFile> _images = [];
  String _category = 'Painting';
  bool _forSale = true;
  bool _uploading = false;
  int _step = 0;

  late final AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  static const _categories = ['Painting','Digital Art','Photography','Sculpture','Drawing','Print','Other'];
  static const _steps = ['Photos','Title','Story','Details','Price','Review'];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(1,0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _titleCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose();
    _mediumCtrl.dispose(); _dimCtrl.dispose(); _tagsCtrl.dispose();
    super.dispose();
  }

  void _goTo(int next) {
    _slideCtrl.reset();
    _slideAnim = Tween<Offset>(
      begin: Offset(next > _step ? 1 : -1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    setState(() => _step = next);
    _slideCtrl.forward();
  }

  bool _canAdvance() {
    switch (_step) {
      case 0: return _images.isNotEmpty;
      case 1: return _titleCtrl.text.trim().isNotEmpty;
      default: return true;
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) setState(() => _images = picked.take(8).toList());
  }

  Future<void> _publish() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _uploading = true);
    try {
      final db = Supabase.instance.client;
      String imageUrl = '';
      final List<String> extras = [];
      for (int i = 0; i < _images.length; i++) {
        final bytes = await _images[i].readAsBytes();
        final ext = _images[i].name.split('.').last;
        final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await db.storage.from('paintings').uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
        final url = db.storage.from('paintings').getPublicUrl(path);
        if (i == 0) imageUrl = url; else extras.add(url);
      }
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      await db.from('paintings').insert({
        'artist_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'image_url': imageUrl,
        'additional_images': extras.isEmpty ? null : extras,
        'category': _category,
        'medium': _mediumCtrl.text.trim().isEmpty ? null : _mediumCtrl.text.trim(),
        'dimensions': _dimCtrl.text.trim().isEmpty ? null : _dimCtrl.text.trim(),
        'price': _forSale && _priceCtrl.text.isNotEmpty ? double.tryParse(_priceCtrl.text) : null,
        'is_for_sale': _forSale,
        'status': 'available',
        'style_tags': tags,
        if (widget.shopId != null) 'shop_id': widget.shopId,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artwork published!'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgress(),
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: _buildStep(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => _step == 0 ? context.pop() : _goTo(_step - 1),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Icon(_step == 0 ? Icons.close : Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_steps[_step], style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text('Step ${_step + 1} of ${_steps.length}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        if (widget.shopName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_outlined, color: AppColors.primary, size: 12),
              const SizedBox(width: 4),
              Text(widget.shopName!, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
      ],
    ),
  );

  Widget _buildProgress() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(
      children: List.generate(_steps.length, (i) => Expanded(
        child: Container(
          height: 3,
          margin: EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
          decoration: BoxDecoration(
            color: i <= _step ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
    ),
  );

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepPhotos();
      case 1: return _stepTitle();
      case 2: return _stepStory();
      case 3: return _stepDetails();
      case 4: return _stepPrice();
      case 5: return _stepReview();
      default: return const SizedBox();
    }
  }

  Widget _stepPhotos() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Show your artwork', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        if (_images.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: double.infinity, height: 280,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Tap to add photos', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Up to 8 images · JPEG, PNG, WEBP', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _images.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _images.length) return GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 32),
                  ),
                );
                return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(_images[i].path, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                      errorBuilder: (_, __, ___) => FutureBuilder<List<int>>(
                        future: _images[i].readAsBytes().then((b) => b.toList()),
                        builder: (_, snap) => snap.hasData
                          ? Image.memory(Uint8List.fromList(snap.data!), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                          : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  if (i == 0) Positioned(top: 8, left: 8, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  )),
                  Positioned(top: 6, right: 6, child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(i)),
                    child: Container(
                      width: 24, height: 24,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  )),
                ]);
              },
            ),
          ),
      ],
    ),
  );

  Widget _stepTitle() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Give it a name', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        TextField(
          controller: _titleCtrl,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'Artwork title...',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 28, fontWeight: FontWeight.w700),
            border: InputBorder.none,
          ),
          maxLines: 3,
          minLines: 1,
        ),
        const SizedBox(height: 40),
        const Text('CATEGORY', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((cat) {
            final sel = cat == _category;
            return GestureDetector(
              onTap: () => setState(() => _category = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                ),
                child: Text(cat, style: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  Widget _stepStory() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tell collectors the story', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        Expanded(
          child: TextField(
            controller: _descCtrl,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, height: 1.6),
            decoration: const InputDecoration(
              hintText: 'What inspired this piece? What techniques did you use?',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 17, height: 1.6),
              border: InputBorder.none,
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
        const Text('Optional — but great stories sell art', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    ),
  );

  Widget _stepDetails() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Technical details', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        _inputField('Medium', _mediumCtrl, hint: 'e.g. Oil on canvas'),
        const SizedBox(height: 20),
        _inputField('Dimensions', _dimCtrl, hint: 'e.g. 24 × 36 in'),
        const SizedBox(height: 20),
        _inputField('Style tags', _tagsCtrl, hint: 'abstract, modern, dark (comma separated)'),
      ],
    ),
  );

  Widget _stepPrice() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set your price', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => setState(() => _forSale = !_forSale),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _forSale ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _forSale ? AppColors.primary : AppColors.border, width: 1.5),
            ),
            child: Row(children: [
              Icon(_forSale ? Icons.check_circle : Icons.radio_button_unchecked, color: _forSale ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Make this available to buy', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Collectors can purchase this artwork', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ])),
            ]),
          ),
        ),
        if (_forSale) ...[
          const SizedBox(height: 24),
          const Text('PRICE (₹)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            const Text('₹', style: TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: AppColors.border, fontSize: 36, fontWeight: FontWeight.w800), border: InputBorder.none),
            )),
          ]),
        ],
      ],
    ),
  );

  Widget _stepReview() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Everything looks good?', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        if (_images.isNotEmpty) ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(aspectRatio: 4/3, child: Image.network(_images[0].path, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => FutureBuilder<List<int>>(
              future: _images[0].readAsBytes().then((b) => b.toList()),
              builder: (_, snap) => snap.hasData ? Image.memory(Uint8List.fromList(snap.data!), fit: BoxFit.cover) : Container(color: AppColors.surface),
            ),
          )),
        ),
        const SizedBox(height: 20),
        Text(_titleCtrl.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_category, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
        if (_descCtrl.text.isNotEmpty) ...[const SizedBox(height: 12), Text(_descCtrl.text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis)],
        const SizedBox(height: 16),
        _reviewRow('Medium', _mediumCtrl.text.isEmpty ? '—' : _mediumCtrl.text),
        _reviewRow('Dimensions', _dimCtrl.text.isEmpty ? '—' : _dimCtrl.text),
        _reviewRow('Images', '${_images.length} photo${_images.length == 1 ? "" : "s"}'),
        _reviewRow('Price', _forSale && _priceCtrl.text.isNotEmpty ? '₹${_priceCtrl.text}' : 'Not for sale'),
        if (widget.shopName != null) _reviewRow('Gallery', widget.shopName!),
      ],
    ),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const Spacer(),
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _inputField(String label, TextEditingController ctrl, {String hint = ''}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      const SizedBox(height: 10),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ],
  );

  Widget _buildFooter() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    child: SizedBox(
      width: double.infinity, height: 56,
      child: _step == _steps.length - 1
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              onPressed: _uploading ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _uploading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('Publish Artwork', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          )
        : ElevatedButton(
            onPressed: _canAdvance() ? () => _goTo(_step + 1) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canAdvance() ? AppColors.primary : AppColors.border,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _canAdvance() ? Colors.white : AppColors.textSecondary)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: _canAdvance() ? Colors.white : AppColors.textSecondary),
            ]),
          ),
    ),
  );
}



