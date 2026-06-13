import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/dob_picker_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../viewmodels/profile_viewmodel.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  DateTime? _dateOfBirth;
  late String _preferredPosition;
  late String _secondaryPosition;
  late String _skillLevel;
  late String _favouriteFoot;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _locationController = TextEditingController(text: widget.user.location);
    _bioController = TextEditingController(text: widget.user.bio);
    _dateOfBirth = widget.user.dateOfBirth;
    _preferredPosition = widget.user.preferredPosition;
    _secondaryPosition = widget.user.secondaryPosition;
    _skillLevel = widget.user.skillLevel;
    _favouriteFoot = widget.user.favouriteFoot;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final dob = _dateOfBirth;
    final updated = widget.user.copyWith(
      fullName: _nameController.text.trim(),
      dateOfBirth: dob,
      age: dob != null ? AppUser.ageFromDate(dob) : widget.user.age,
      location: _locationController.text.trim(),
      preferredPosition: _preferredPosition,
      secondaryPosition: _secondaryPosition,
      skillLevel: _skillLevel,
      favouriteFoot: _favouriteFoot,
      bio: _bioController.text.trim(),
      updatedAt: DateTime.now(),
    );

    final success = await context.read<ProfileViewModel>().saveProfile(updated);
    if (!mounted || !success) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Player profile', style: AppTextStyles.h1),
                const SizedBox(height: 18),
                _PhotoRow(user: widget.user),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Full name'),
                ),
                const SizedBox(height: 14),
                DobPickerField(
                  value: _dateOfBirth,
                  fallbackAge: widget.user.age,
                  onChanged: (date) => setState(() => _dateOfBirth = date),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _locationController,
                  label: 'Location / town',
                  icon: Icons.location_city_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Location'),
                ),
                const SizedBox(height: 14),
                _DropdownField(
                  label: 'Preferred position',
                  value: _preferredPosition,
                  items: AppStrings.positions,
                  onChanged: (value) =>
                      setState(() => _preferredPosition = value),
                ),
                const SizedBox(height: 14),
                _DropdownField(
                  label: 'Secondary position',
                  value: _secondaryPosition,
                  items: AppStrings.positions,
                  onChanged: (value) =>
                      setState(() => _secondaryPosition = value),
                ),
                const SizedBox(height: 14),
                _DropdownField(
                  label: 'Skill level',
                  value: _skillLevel,
                  items: AppStrings.skillLevels,
                  onChanged: (value) => setState(() => _skillLevel = value),
                ),
                const SizedBox(height: 14),
                _DropdownField(
                  label: 'Favourite foot',
                  value: _favouriteFoot,
                  items: AppStrings.favouriteFeet,
                  onChanged: (value) => setState(() => _favouriteFoot = value),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _bioController,
                  label: 'Bio (optional)',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
                if (profile.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    profile.errorMessage!,
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: AppColours.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save changes',
                  icon: Icons.check,
                  isLoading: profile.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SelectionSheetField(
      label: label,
      value: value,
      options: items,
      onChanged: onChanged,
    );
  }
}

class _PhotoRow extends StatefulWidget {
  const _PhotoRow({required this.user});

  final AppUser user;

  @override
  State<_PhotoRow> createState() => _PhotoRowState();
}

class _PhotoRowState extends State<_PhotoRow> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    XFile? file;
    try {
      final picker = ImagePicker();
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open photo picker: $error')),
      );
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final profileViewModel = context.read<ProfileViewModel>();
      final url = await profileViewModel
          .uploadProfilePhoto(
            uid: widget.user.uid,
            bytes: bytes,
            contentType: file.mimeType ?? 'image/jpeg',
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            url == null
                ? profileViewModel.errorMessage ?? 'Upload failed.'
                : 'Profile photo updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(
                fullName: widget.user.fullName,
                photoUrl: widget.user.photoUrl,
                radius: 28,
              ),
              if (_uploading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColours.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile photo',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.photoUrl == null
                      ? 'Add a photo so teammates recognise you.'
                      : 'Tap change to update your photo.',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: Text(widget.user.photoUrl == null ? 'Add' : 'Change'),
          ),
        ],
      ),
    );
  }
}
