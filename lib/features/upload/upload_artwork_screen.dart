import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import 'dart:typed_data';

class UploadArtworkScreen extends StatefulWidget {
  final String? shopId;
  final String? shopName;
  const UploadArtworkScreen({super.key, this.shopId, this.shopName});
  @override
  State<UploadArtworkScreen> createState() => _UploadArtworkScreenState();
}

class _UploadArtworkScreenState extends State<UploadArtworkScreen>
    with TickerProviderStateMixin {
  static const int _maxImages = 5;

  final _picker = ImagePicker();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _startingBidCtrl = TextEditingController();
  final _reservePriceCtrl = TextEditingController();
  final _mediumCtrl = TextEditingController();
  final _dimCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  List<XFile> _images = [];
  String _category = 'Painting';
  bool _forSale = true;
  String _listingType = 'fixed_price';
  DateTime? _auctionEndAt;
  List<Map<String, dynamic>> _shopCollections = [];
  String? _selectedCollectionId;
  bool _uploading = false;
  int _step = 0;

  late final AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  static const _categories = [
    'Painting',
    'Digital Art',
    'Photography',
    'Sculpture',
    'Drawing',
    'Print',
    'Other'
  ];
  static const _steps = [
    'Photos',
    'Title',
    'Story',
    'Details',
    'Price',
    'Review'
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
    _loadCollectionsForShop();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _startingBidCtrl.dispose();
    _reservePriceCtrl.dispose();
    _mediumCtrl.dispose();
    _dimCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionsForShop() async {
    if (widget.shopId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('collections')
          .select('id, name')
          .eq('shop_id', widget.shopId!)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _shopCollections = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (_) {
      // Optional enhancement only; keep upload flow stable if table is missing.
    }
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
      case 0:
        return _images.isNotEmpty;
      case 1:
        return _titleCtrl.text.trim().isNotEmpty;
      case 4:
        if (!_forSale) return true;
        if (_listingType == 'auction') {
          final start = double.tryParse(_startingBidCtrl.text.trim());
          return start != null && start > 0 && _auctionEndAt != null;
        }
        if (_listingType == 'fixed_price') {
          final price = double.tryParse(_priceCtrl.text.trim());
          return price != null && price > 0;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    final remainingSlots = _maxImages - _images.length;
    if (remainingSlots <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can upload up to 5 photos only.')),
      );
      return;
    }
    setState(() {
      _images.addAll(picked.take(remainingSlots));
    });
    if (picked.length > remainingSlots && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the first 5 photos were added.')),
      );
    }
  }

  Future<void> _pickAuctionEndDate() async {
    final now = DateTime.now();
    final initial = _auctionEndAt ?? now.add(const Duration(days: 2));
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: initial,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _auctionEndAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
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
        final path =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
        await db.storage.from('paintings').uploadBinary(path, bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
        final url = db.storage.from('paintings').getPublicUrl(path);
        if (i == 0)
          imageUrl = url;
        else
          extras.add(url);
      }
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final listingType = _forSale ? _listingType : 'open_offer';
      final fixedPrice = double.tryParse(_priceCtrl.text.trim());
      final startingBid = double.tryParse(_startingBidCtrl.text.trim());
      final reserve = double.tryParse(_reservePriceCtrl.text.trim());
      final basePrice = listingType == 'auction' ? startingBid : fixedPrice;

      final paintingInsert = <String, dynamic>{
        'artist_id': user.id,
        'title': _titleCtrl.text.trim(),
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'image_url': imageUrl,
        'additional_images': extras.isEmpty ? null : extras,
        'category': _category,
        'medium':
            _mediumCtrl.text.trim().isEmpty ? null : _mediumCtrl.text.trim(),
        'dimensions':
            _dimCtrl.text.trim().isEmpty ? null : _dimCtrl.text.trim(),
        'price': _forSale ? basePrice : null,
        'is_for_sale': _forSale,
        'listing_type': listingType,
        'status': _forSale ? 'available' : 'draft',
        'currency': 'INR',
        'style_tags': tags,
        if (widget.shopId != null) 'shop_id': widget.shopId,
        if (_selectedCollectionId != null)
          'collection_id': _selectedCollectionId,
        'nfc_status': 'not_attached',
        'created_at': DateTime.now().toIso8601String(),
      };

      String? paintingId;
      try {
        final inserted = await db
            .from('paintings')
            .insert(paintingInsert)
            .select('id')
            .single();
        paintingId = inserted['id']?.toString();
      } catch (_) {
        await db.from('paintings').insert({
          ...paintingInsert,
          'status': _forSale ? 'available' : 'draft',
          'listing_type': null,
          'currency': null,
          'nfc_status': null,
          'collection_id': null,
        });
      }

      if (listingType == 'auction' &&
          paintingId != null &&
          startingBid != null &&
          _auctionEndAt != null) {
        try {
          await db.from('auctions').insert({
            'painting_id': paintingId,
            'seller_id': user.id,
            'starting_price': startingBid,
            'reserve_price': reserve,
            'current_highest_bid': null,
            'start_time': DateTime.now().toIso8601String(),
            'end_time': _auctionEndAt!.toIso8601String(),
            'status': 'active',
            'bid_increment': 500,
          });
        } catch (_) {
          // Auction table may not exist on older DBs; artwork listing should still succeed.
        }
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Artwork published!')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    _step == 0 ? Icons.close : Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_steps[_step],
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  Text('Step ${_step + 1} of ${_steps.length}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (widget.shopName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.storefront_outlined,
                      color: AppColors.primary, size: 12),
                  const SizedBox(width: 4),
                  Text(widget.shopName!,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      );

  Widget _buildProgress() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: List.generate(
              _steps.length,
              (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin:
                          EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
                      decoration: BoxDecoration(
                        color:
                            i <= _step ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
        ),
      );

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _stepPhotos();
      case 1:
        return _stepTitle();
      case 2:
        return _stepStory();
      case 3:
        return _stepDetails();
      case 4:
        return _stepPrice();
      case 5:
        return _stepReview();
      default:
        return const SizedBox();
    }
  }

  Widget _stepPhotos() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Show your artwork',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            if (_images.isEmpty)
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.add_photo_alternate_outlined,
                              color: AppColors.primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('Tap to add photos',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Up to 8 images · JPEG, PNG, WEBP',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
                  itemCount:
                      _images.length < _maxImages ? _images.length + 1 : _images.length,
                  itemBuilder: (ctx, i) {
                    if (i == _images.length)
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border)),
                          child: const Icon(Icons.add,
                              color: AppColors.primary, size: 32),
                        ),
                      );
                    return Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _pickedImage(_images[i], fit: BoxFit.cover),
                      ),
                      if (i == 0)
                        Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Cover',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            )),
                      Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => _images.removeAt(i)),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
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
            const Text('Give it a name',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: AppColors.textOnLight,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: AppColors.textOnLight,
              decoration: const InputDecoration(
                hintText: 'Artwork title...',
                hintStyle: TextStyle(
                  color: AppColors.textOnLightSecondary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 40),
            const Text('CATEGORY',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final sel = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13)),
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
            const Text('Tell collectors the story',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            Expanded(
              child: TextField(
                controller: _descCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 17, height: 1.6),
                decoration: const InputDecoration(
                  hintText:
                      'What inspired this piece? What techniques did you use?',
                  hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 17,
                      height: 1.6),
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const Text('Optional — but great stories sell art',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _stepDetails() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Technical details',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            _inputField('Medium', _mediumCtrl, hint: 'e.g. Oil on canvas'),
            const SizedBox(height: 20),
            _inputField('Dimensions', _dimCtrl, hint: 'e.g. 24 × 36 in'),
            const SizedBox(height: 20),
            _inputField('Style tags', _tagsCtrl,
                hint: 'abstract, modern, dark (comma separated)'),
          ],
        ),
      );

  Widget _stepPrice() => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set your listing',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => setState(() => _forSale = !_forSale),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _forSale
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _forSale ? AppColors.primary : AppColors.border,
                        width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(
                        _forSale
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _forSale
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('List this artwork in marketplace',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                          Text('Choose fixed price, auction, or open offers',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ])),
                  ]),
                ),
              ),
              if (_forSale) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _listingPill('fixed_price', 'Fixed Price'),
                    _listingPill('auction', 'Auction'),
                    _listingPill('open_offer', 'Open Offer'),
                  ],
                ),
                const SizedBox(height: 16),
                if (_listingType == 'fixed_price') ...[
                  const Text('PRICE (INR)',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text('INR',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                  color: AppColors.border,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800),
                              border: InputBorder.none),
                        )),
                      ]),
                ] else if (_listingType == 'auction') ...[
                  _inputField('Starting bid (INR)', _startingBidCtrl,
                      hint: 'e.g. 5000'),
                  const SizedBox(height: 12),
                  _inputField('Reserve price (optional)', _reservePriceCtrl,
                      hint: 'e.g. 12000'),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickAuctionEndDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _auctionEndAt == null
                                  ? 'Pick auction end date & time'
                                  : 'Ends: ${_auctionEndAt!.toLocal()}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Collectors can send purchase offers. You can accept manually.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
                if (_shopCollections.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('COLLECTION',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCollectionId,
                    dropdownColor: AppColors.surfaceVariant,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: '', child: Text('No collection')),
                      ..._shopCollections.map((c) => DropdownMenuItem<String>(
                            value: c['id']?.toString() ?? '',
                            child: Text(c['name']?.toString() ?? 'Collection'),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedCollectionId =
                        (value == null || value.isEmpty) ? null : value),
                  ),
                ],
              ],
            ],
          ),
        ),
      );

  Widget _listingPill(String type, String label) {
    final selected = _listingType == type;
    return InkWell(
      onTap: () => setState(() => _listingType = type),
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _stepReview() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Everything looks good?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            if (_images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _pickedImage(_images[0], fit: BoxFit.cover)),
              ),
            const SizedBox(height: 20),
            Text(_titleCtrl.text,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_category,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            if (_descCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_descCtrl.text,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis)
            ],
            const SizedBox(height: 16),
            _reviewRow(
                'Medium', _mediumCtrl.text.isEmpty ? '—' : _mediumCtrl.text),
            _reviewRow(
                'Dimensions', _dimCtrl.text.isEmpty ? '—' : _dimCtrl.text),
            _reviewRow('Images',
                '${_images.length} photo${_images.length == 1 ? "" : "s"}'),
            _reviewRow('Listing',
                _forSale ? _listingType.replaceAll('_', ' ') : 'Not for sale'),
            _reviewRow(
              'Price',
              !_forSale
                  ? 'Not for sale'
                  : _listingType == 'auction'
                      ? (_startingBidCtrl.text.isEmpty
                          ? 'Auction (no start bid)'
                          : 'Starts at INR ${_startingBidCtrl.text}')
                      : _listingType == 'fixed_price'
                          ? (_priceCtrl.text.isEmpty
                              ? 'No price set'
                              : 'INR ${_priceCtrl.text}')
                          : 'Open offer',
            ),
            if (widget.shopName != null) _reviewRow('Studio', widget.shopName!),
          ],
        ),
      );

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _inputField(String label, TextEditingController ctrl,
          {String hint = ''}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      );

  Widget _pickedImage(XFile file, {BoxFit fit = BoxFit.cover}) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.memory(snap.data!,
            fit: fit, width: double.infinity, height: double.infinity);
      },
    );
  }

  Widget _buildFooter() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: _step == _steps.length - 1
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _uploading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text('Publish Artwork',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                )
              : ElevatedButton(
                  onPressed: _canAdvance() ? () => _goTo(_step + 1) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _canAdvance() ? AppColors.primary : AppColors.border,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continue',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _canAdvance()
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: _canAdvance()
                                ? Colors.white
                                : AppColors.textSecondary),
                      ]),
                ),
        ),
      );
}
