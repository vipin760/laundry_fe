import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';

const _kPrimary = Color(0xFF2453FF);
const _kBg = Color(0xFFF5F6FA);

class MyInformationScreen extends ConsumerStatefulWidget {
  const MyInformationScreen({super.key});

  @override
  ConsumerState<MyInformationScreen> createState() => _MyInformationScreenState();
}

class _MyInformationScreenState extends ConsumerState<MyInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;

  // Tracks newly picked image (before save)
  File? _pickedImage;
  String? _uploadedPhotoUrl;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  String? _photoError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _uploadedPhotoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Pick image from gallery ──────────────────────────────────────────────

  Future<void> _pickAndUploadPhoto() async {
    setState(() { _photoError = null; });

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return; // user cancelled

    setState(() {
      _pickedImage = File(picked.path);
      _isUploadingPhoto = true;
      _photoError = null;
    });

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
      });

      final response = await ApiClient.instance.post(
        '/upload/image',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final url = response.data?['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('Upload succeeded but no URL returned.');
      }

      setState(() {
        _uploadedPhotoUrl = url;
        _isUploadingPhoto = false;
      });
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? e.response?.data['message']?.toString()
          : null;
      setState(() {
        _isUploadingPhoto = false;
        _photoError = msg ?? 'Photo upload failed. Please try again.';
        _pickedImage = null; // revert preview on failure
      });
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
        _photoError = 'Photo upload failed. Please try again.';
        _pickedImage = null;
      });
    }
  }

  // ── Save profile ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final nameValue = _nameCtrl.text.trim();
    final currentUser = ref.read(authProvider).user;

    final nameChanged = nameValue.isNotEmpty && nameValue != (currentUser?.name ?? '');
    final photoChanged = _uploadedPhotoUrl != null &&
        _uploadedPhotoUrl != currentUser?.photoUrl;

    if (!nameChanged && !photoChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isUploadingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait — photo is still uploading.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    await ref.read(authProvider.notifier).updateProfile(
      name: nameChanged ? nameValue : null,
      photoUrl: photoChanged ? _uploadedPhotoUrl : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final error = ref.read(authProvider).error;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Color(0xFF12B76A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0A1645)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Information',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A1645),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar picker ─────────────────────────────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _AvatarWidget(
                      pickedImage: _pickedImage,
                      photoUrl: _uploadedPhotoUrl,
                      initials: _initials(user?.name),
                      isUploading: _isUploadingPhoto,
                    ),
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimary.withAlpha(60),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_photoError != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _photoError!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // ── Read-only fields ──────────────────────────────────────────
              _SectionLabel('Contact'),
              const SizedBox(height: 10),
              _ReadOnlyField(
                icon: Icons.phone_outlined,
                label: 'Mobile Number',
                value: user?.mobileNumber ?? '—',
              ),
              if (user?.email != null && user!.email!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _ReadOnlyField(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email!,
                ),
              ],

              const SizedBox(height: 28),

              // ── Editable fields ───────────────────────────────────────────
              _SectionLabel('Edit Profile'),
              const SizedBox(height: 10),
              _FieldCard(
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0A1645),
                  ),
                  decoration: _inputDecoration(
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  // Name is optional — leave blank to keep existing
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return null; // optional
                    if (val.length < 2) return 'Name must be at least 2 characters';
                    if (val.length > 60) return 'Name is too long';
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 10),
              Text(
                'Leave name blank to keep your current name.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 36),

              // ── Save button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingPhoto) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    disabledBackgroundColor: _kPrimary.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: (_isSaving || _isUploadingPhoto)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
    );
  }
}

// ── Avatar widget ─────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({
    required this.pickedImage,
    required this.photoUrl,
    required this.initials,
    required this.isUploading,
  });

  final File? pickedImage;
  final String? photoUrl;
  final String initials;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isUploading) {
      content = const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5);
    } else if (pickedImage != null) {
      content = ClipOval(
        child: Image.file(pickedImage!, width: 96, height: 96, fit: BoxFit.cover),
      );
    } else if (photoUrl != null && photoUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          photoUrl!,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _InitialsWidget(initials: initials),
        ),
      );
    } else {
      content = _InitialsWidget(initials: initials);
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2453FF), Color(0xFF6B8EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2453FF).withAlpha(50),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(child: content),
    );
  }
}

class _InitialsWidget extends StatelessWidget {
  const _InitialsWidget({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      );
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.8,
        ),
      );
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}
