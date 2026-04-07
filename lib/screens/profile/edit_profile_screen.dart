import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile — Twitter/X–style layout: banner + overlapping avatar,
// underline fields, centered readable column. Saves to Supabase `profiles`.
// ─────────────────────────────────────────────────────────────────────────────

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();

  String _artistType = '';
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  String? _coverUrl;
  Uint8List? _coverBytes;
  String? _errorMsg;

  static const _artistTypes = [
    'Painter',
    'Sculptor',
    'Photographer',
    'Digital Artist',
    'Illustrator',
    'Printmaker',
    'Mixed Media',
    'Other',
  ];

  static const double _bannerHeight = 148;
  static const double _avatarSize = 82;
  static const double _avatarOverlap = 42;

  /// Usernames are stored without a leading @; users often paste "@handle".
  static String _normalizeUsername(String? raw) {
    var s = (raw ?? '').trim().toLowerCase();
    if (s.startsWith('@')) s = s.substring(1);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _twitterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();
      final p = Map<String, dynamic>.from(res);
      _displayNameCtrl.text = p['display_name'] as String? ?? '';
      _usernameCtrl.text = p['username'] as String? ?? '';
      _bioCtrl.text = p['bio'] as String? ?? '';
      _locationCtrl.text = p['location'] as String? ?? '';
      _websiteCtrl.text =
          (p['website'] ?? p['website_url']) as String? ?? '';
      _instagramCtrl.text = p['instagram'] as String? ?? '';
      _twitterCtrl.text = p['twitter'] as String? ?? '';
      _artistType = p['artist_type'] as String? ?? '';
      _avatarUrl = p['profile_picture_url'] as String?;
      _coverUrl = (p['cover_image_url'] ?? p['cover_photo_url']) as String?;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 88,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 88,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() => _coverBytes = bytes);
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_avatarBytes == null) return null;
    final path = 'avatars/$userId.jpg';
    await _supabase.storage.from('profiles').uploadBinary(
          path,
          _avatarBytes!,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from('profiles').getPublicUrl(path);
  }

  Future<String?> _uploadCover(String userId) async {
    if (_coverBytes == null) return null;
    final path = 'banners/$userId.jpg';
    await _supabase.storage.from('profiles').uploadBinary(
          path,
          _coverBytes!,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from('profiles').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    final userId =
        Provider.of<AuthProvider>(context, listen: false).user?.id;
    if (userId == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      String? newAvatarUrl = _avatarUrl;
      if (_avatarBytes != null) {
        newAvatarUrl = await _uploadAvatar(userId);
      }

      String? newCoverUrl = _coverUrl;
      if (_coverBytes != null) {
        newCoverUrl = await _uploadCover(userId);
      }

      final username = _normalizeUsername(_usernameCtrl.text);

      if (username.isNotEmpty) {
        final conflict = await _supabase
            .from('profiles')
            .select('id')
            .eq('username', username)
            .neq('id', userId)
            .maybeSingle();
        if (conflict != null) {
          setState(() {
            _errorMsg = 'Username @$username is already taken.';
            _saving = false;
          });
          return;
        }
      }

      final web = _websiteCtrl.text.trim();
      final bio = _bioCtrl.text.trim();
      final loc = _locationCtrl.text.trim();
      final ig = _instagramCtrl.text.trim();
      final tw = _twitterCtrl.text.trim();

      final updates = <String, dynamic>{
        'display_name': _displayNameCtrl.text.trim(),
        'bio': bio.isEmpty ? null : bio,
        'location': loc.isEmpty ? null : loc,
        'website': web.isEmpty ? null : web,
        'website_url': web.isEmpty ? null : web,
        'instagram': ig.isEmpty ? null : ig,
        'twitter': tw.isEmpty ? null : tw,
        'artist_type': _artistType.isEmpty ? null : _artistType,
        'profile_picture_url': newAvatarUrl,
        'cover_image_url': newCoverUrl,
        'cover_photo_url': newCoverUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (username.isNotEmpty) {
        updates['username'] = username;
      }

      await _supabase.from('profiles').update(updates).eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        final m = e.message.trim();
        _errorMsg =
            m.isNotEmpty ? m : 'Save failed. Please try again.';
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Save failed. Please try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    const maxContent = 520.0;
    const horizontalPad = 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.border.withValues(alpha: 0.45),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final innerW = w > maxContent + horizontalPad * 2
                ? maxContent
                : w - horizontalPad * 2;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContent + horizontalPad * 2),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPad,
                      0,
                      horizontalPad,
                      48,
                    ),
                    child: SizedBox(
                      width: innerW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBannerAndAvatar(),
                          if (_errorMsg != null) ...[
                            const SizedBox(height: 16),
                            _InlineError(_errorMsg!),
                          ],
                          const SizedBox(height: 22),
                          _TwitterUnderlineField(
                            controller: _displayNameCtrl,
                            label: 'Name',
                            hint: 'Your name',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          _TwitterUnderlineField(
                            controller: _usernameCtrl,
                            label: 'Username',
                            hint: 'username',
                            prefix: '@',
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final clean = _normalizeUsername(v);
                              if (!RegExp(r'^[a-z0-9_.]{3,30}$')
                                  .hasMatch(clean)) {
                                return '3–30 characters: letters, numbers, . or _';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 4),
                          _BioField(
                            controller: _bioCtrl,
                            label: 'Bio',
                            maxLength: 280,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Discipline',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _artistTypes.map((t) {
                              final selected = _artistType == t;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _artistType = t),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: selected ? 1.5 : 1,
                                      ),
                                      color: selected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.14)
                                          : Colors.transparent,
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Location & links',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _TwitterUnderlineField(
                            controller: _locationCtrl,
                            label: 'Location',
                            hint: 'City, Country',
                          ),
                          _TwitterUnderlineField(
                            controller: _websiteCtrl,
                            label: 'Website',
                            hint: 'https://…',
                            keyboardType: TextInputType.url,
                          ),
                          _TwitterUnderlineField(
                            controller: _instagramCtrl,
                            label: 'Instagram',
                            hint: 'handle',
                            prefix: '@',
                          ),
                          _TwitterUnderlineField(
                            controller: _twitterCtrl,
                            label: 'X (Twitter)',
                            hint: 'handle',
                            prefix: '@',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBannerAndAvatar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          child: SizedBox(
            height: _bannerHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _pickCover,
                  child: _coverBytes != null
                      ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                      : _coverUrl != null
                          ? Image.network(
                              _coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _bannerPlaceholder(),
                            )
                          : _bannerPlaceholder(),
                ),
                // Bottom gradient for camera chip contrast
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _pickCover,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -_avatarOverlap),
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: _avatarSize,
                      height: _avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceVariant,
                        border: Border.all(
                          color: AppColors.background,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _avatarBytes != null
                            ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                            : _avatarUrl != null
                                ? Image.network(
                                    _avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarPlaceholder(),
                                  )
                                : _avatarPlaceholder(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -_avatarOverlap + 8),
          child: Padding(
            padding: const EdgeInsets.only(left: 6, top: 4),
            child: Text(
              'Tap banner or photo to change',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 40,
        color: AppColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    final initial = _displayNameCtrl.text.isNotEmpty
        ? _displayNameCtrl.text[0].toUpperCase()
        : '?';
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─── Inline error ─────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

// ─── Twitter-style underline fields ───────────────────────────────────────────

class _TwitterUnderlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefix;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _TwitterUnderlineField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  static const _borderColor = AppColors.border;
  static const _focusColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textTertiary.withValues(alpha: 0.85),
            fontSize: 16,
          ),
          prefixText: prefix,
          prefixStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 10),
          border: const UnderlineInputBorder(
            borderSide: BorderSide(color: _borderColor, width: 1),
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _borderColor, width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _focusColor, width: 1.5),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.9)),
          ),
          focusedErrorBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _BioField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLength;

  const _BioField({
    required this.controller,
    required this.label,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 4,
          maxLength: maxLength,
          buildCounter: (context,
                  {required currentLength,
                  required isFocused,
                  maxLength}) =>
              Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$currentLength / $maxLength',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: 'Tell people about your work…',
            hintStyle: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.85),
              fontSize: 16,
            ),
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.55),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
