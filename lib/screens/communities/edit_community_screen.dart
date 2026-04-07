import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';

/// Lets the community creator update name, description, and cover image.
class EditCommunityScreen extends StatefulWidget {
  final String communityId;

  const EditCommunityScreen({super.key, required this.communityId});

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _selectedImage;
  String? _existingCoverUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _supabase
          .from('communities')
          .select('*')
          .eq('id', widget.communityId)
          .maybeSingle();

      if (row == null || row['creator_id'] != user.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can only edit communities you created')),
          );
          context.pop();
        }
        return;
      }

      setState(() {
        _nameController.text = (row['name'] as String?) ?? '';
        _descriptionController.text = (row['description'] as String?) ?? '';
        _existingCoverUrl = row['cover_image_url'] as String?;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load community')),
        );
        context.pop();
      }
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_selectedImage == null) return null;
    setState(() => _uploadingImage = true);
    try {
      final file = File(_selectedImage!.path);
      final fileExtension = _selectedImage!.path.split('.').last;
      final fileName =
          '$userId/community-covers/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _supabase.storage.from('community-covers').upload(
            fileName,
            file,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: false,
            ),
          );

      setState(() => _uploadingImage = false);
      return _supabase.storage.from('community-covers').getPublicUrl(fileName);
    } catch (e) {
      setState(() => _uploadingImage = false);
      rethrow;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      String? coverUrl = _existingCoverUrl;
      if (_selectedImage != null) {
        coverUrl = await _uploadImage(user.id);
      }

      await _supabase.from('communities').update({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        if (coverUrl != null) 'cover_image_url': coverUrl,
      }).eq('id', widget.communityId).eq('creator_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Community updated'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) setState(() => _selectedImage = image);
  }

  Widget _glassContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.3),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saving ? null : () => context.pop(),
        ),
        title: const Text(
          'Edit community',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          else
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _glassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cover', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _uploadingImage ? null : _pickImage,
                            child: Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: _uploadingImage
                                  ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                                  : _selectedImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                                        )
                                      : _existingCoverUrl != null && _existingCoverUrl!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.network(_existingCoverUrl!, fit: BoxFit.cover),
                                            )
                                          : const Center(
                                              child: Text('Tap to change cover',
                                                  style: TextStyle(color: Colors.white54)),
                                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _glassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDecoration('Community name'),
                            validator: (v) {
                              if (v == null || v.trim().length < 3) return 'Min 3 characters';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _glassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            style: const TextStyle(color: Colors.white),
                            decoration: _fieldDescription(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700)),
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

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  InputDecoration _fieldDescription() => InputDecoration(
        hintText: 'Description',
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
