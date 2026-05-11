import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
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
  late final TextEditingController _ageController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  late String _preferredPosition;
  late String _secondaryPosition;
  late String _skillLevel;
  late String _favouriteFoot;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _ageController = TextEditingController(text: widget.user.age.toString());
    _locationController = TextEditingController(text: widget.user.location);
    _bioController = TextEditingController(text: widget.user.bio);
    _preferredPosition = widget.user.preferredPosition;
    _secondaryPosition = widget.user.secondaryPosition;
    _skillLevel = widget.user.skillLevel;
    _favouriteFoot = widget.user.favouriteFoot;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.user.copyWith(
      fullName: _nameController.text.trim(),
      age: int.parse(_ageController.text),
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
                CustomTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Full name'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _ageController,
                  label: 'Age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      Validators.positiveInt(value, label: 'Age'),
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
                  label: 'Bio',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                  validator: (value) =>
                      Validators.required(value, label: 'Bio'),
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppColours.card,
      items: items
          .map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
