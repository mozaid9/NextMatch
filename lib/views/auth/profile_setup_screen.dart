import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../models/app_user.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.firebaseUser});

  final User firebaseUser;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  String _preferredPosition = 'Any';
  String _secondaryPosition = 'Any';
  String _skillLevel = 'Casual';
  String _favouriteFoot = 'Right';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.firebaseUser.displayName ?? '',
    );
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

    final now = DateTime.now();
    final user = AppUser(
      uid: widget.firebaseUser.uid,
      fullName: _nameController.text.trim(),
      email: widget.firebaseUser.email ?? '',
      age: int.parse(_ageController.text),
      location: _locationController.text.trim(),
      preferredPosition: _preferredPosition,
      secondaryPosition: _secondaryPosition,
      skillLevel: _skillLevel,
      favouriteFoot: _favouriteFoot,
      bio: _bioController.text.trim(),
      photoUrl: null,
      reliabilityScore: 100,
      abilityRating: 3.0,
      abilityRatingCount: 0,
      completedMatches: 0,
      cancelledMatches: 0,
      lateCancellations: 0,
      noShows: 0,
      attendedMatches: 0,
      matchesPlayed: 0,
      rating: 3.0,
      createdAt: now,
      updatedAt: now,
    );

    final success = await context.read<ProfileViewModel>().saveProfile(user);
    if (!mounted || !success) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved. Welcome to NextMatch.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up your profile', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'This helps organisers fill the right spaces and balance games.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 22),
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColours.cardAlt,
                    child: Icon(
                      Icons.person,
                      size: 42,
                      color: AppColours.accent.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                      Validators.required(value, label: 'A short bio'),
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
                  label: 'Save profile',
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
