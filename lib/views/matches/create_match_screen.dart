import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/match_viewmodel.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _totalPlayersController = TextEditingController(text: '10');
  final _priceController = TextEditingController(text: '5.00');
  final _descriptionController = TextEditingController();
  final _goalkeepersController = TextEditingController(text: '2');
  final _defendersController = TextEditingController(text: '2');
  final _midfieldersController = TextEditingController(text: '4');
  final _forwardsController = TextEditingController(text: '2');
  final _minimumReliabilityController = TextEditingController(text: '60');
  final _cancellationPolicyController = TextEditingController(
    text: 'Refunds are handled manually in the MVP. Please give notice early.',
  );

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  String _format = '5-a-side';
  String _skillLevel = 'Casual';
  String _pitchType = 'Astro';
  String _visibility = 'Public';
  String _paymentMode = AppStrings.paymentModeSplit;
  bool _requiresApprovalForLowReliability = true;

  @override
  void dispose() {
    _titleController.dispose();
    _locationNameController.dispose();
    _addressController.dispose();
    _durationController.dispose();
    _totalPlayersController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _goalkeepersController.dispose();
    _defendersController.dispose();
    _midfieldersController.dispose();
    _forwardsController.dispose();
    _minimumReliabilityController.dispose();
    _cancellationPolicyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startDateTime = DateTimeHelpers.combineDateAndTime(
      _selectedDate,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final now = DateTime.now();
    final match = FootballMatch(
      id: '',
      title: _titleController.text.trim(),
      organiserId: widget.currentUser.uid,
      organiserName: widget.currentUser.fullName,
      locationName: _locationNameController.text.trim(),
      address: _addressController.text.trim(),
      date: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      startTime: _formatTime(_selectedTime),
      startDateTime: startDateTime,
      durationMinutes: int.parse(_durationController.text),
      format: _format,
      totalPlayersNeeded: int.parse(_totalPlayersController.text),
      joinedPlayerCount: 0,
      pricePerPlayer: double.parse(_priceController.text),
      skillLevel: _skillLevel,
      pitchType: _pitchType,
      description: _descriptionController.text.trim(),
      neededPositions: {
        'Goalkeepers': int.parse(_goalkeepersController.text),
        'Defenders': int.parse(_defendersController.text),
        'Midfielders': int.parse(_midfieldersController.text),
        'Forwards': int.parse(_forwardsController.text),
      },
      visibility: _visibility,
      status: 'Open',
      cancellationPolicy: _cancellationPolicyController.text.trim(),
      paymentMode: _paymentMode,
      minimumReliabilityRequired: int.parse(_minimumReliabilityController.text),
      requiresApprovalForLowReliability: _requiresApprovalForLowReliability,
      organiserCanApproveLowReliability: true,
      createdAt: now,
      updatedAt: now,
    );

    final success = await context.read<MatchViewModel>().createMatch(match);
    if (!mounted) return;

    if (success) {
      _formKey.currentState!.reset();
      _titleController.clear();
      _locationNameController.clear();
      _addressController.clear();
      _descriptionController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Match created.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create a match', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Set the terms, collect payments and fill the game.',
                  style: AppTextStyles.bodyMuted,
                ),

                _SectionHeader(title: 'Basic info'),
                CustomTextField(
                  controller: _titleController,
                  label: 'Match title',
                  icon: Icons.sports_soccer,
                  validator: (value) =>
                      Validators.required(value, label: 'Match title'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _locationNameController,
                  label: 'Location name',
                  icon: Icons.place_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Location name'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _addressController,
                  label: 'Address',
                  icon: Icons.map_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Address'),
                ),

                _SectionHeader(title: 'Date & time'),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.event,
                        label: 'Date',
                        value: DateTimeHelpers.formatDate(_selectedDate),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.schedule,
                        label: 'Start time',
                        value: _formatTime(_selectedTime),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _durationController,
                        label: 'Duration (mins)',
                        icon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            Validators.positiveInt(value, label: 'Duration'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _totalPlayersController,
                        label: 'Players needed',
                        icon: Icons.groups_2_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.positiveInt(
                          value,
                          label: 'Players needed',
                        ),
                      ),
                    ),
                  ],
                ),

                _SectionHeader(title: 'Match settings'),
                _DropdownField(
                  label: 'Format',
                  value: _format,
                  items: AppStrings.matchFormats,
                  onChanged: (value) => setState(() => _format = value),
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
                  label: 'Pitch type',
                  value: _pitchType,
                  items: AppStrings.pitchTypes,
                  onChanged: (value) => setState(() => _pitchType = value),
                ),
                const SizedBox(height: 14),
                _DropdownField(
                  label: 'Visibility',
                  value: _visibility,
                  items: AppStrings.visibilityOptions,
                  onChanged: (value) => setState(() => _visibility = value),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _minimumReliabilityController,
                  label: 'Minimum reliability',
                  icon: Icons.verified_user_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) => Validators.positiveInt(
                    value,
                    label: 'Minimum reliability',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Approve low reliability players',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Players below the minimum score request approval before joining.',
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                  ),
                  value: _requiresApprovalForLowReliability,
                  activeThumbColor: AppColours.accent,
                  onChanged: (value) => setState(
                    () => _requiresApprovalForLowReliability = value,
                  ),
                ),

                _SectionHeader(title: 'Payment'),
                CustomTextField(
                  controller: _priceController,
                  label: 'Price per player (£)',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => Validators.positiveMoney(
                    value,
                    label: 'Price per player',
                  ),
                ),
                const SizedBox(height: 14),
                _PaymentModePicker(
                  selected: _paymentMode,
                  onChanged: (value) => setState(() => _paymentMode = value),
                ),

                _SectionHeader(title: 'Positions needed'),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _goalkeepersController,
                        label: 'Goalkeepers',
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.nonNegativeInt(
                          value,
                          label: 'Goalkeepers',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _defendersController,
                        label: 'Defenders',
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.nonNegativeInt(
                          value,
                          label: 'Defenders',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _midfieldersController,
                        label: 'Midfielders',
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.nonNegativeInt(
                          value,
                          label: 'Midfielders',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomTextField(
                        controller: _forwardsController,
                        label: 'Forwards',
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            Validators.nonNegativeInt(value, label: 'Forwards'),
                      ),
                    ),
                  ],
                ),

                _SectionHeader(title: 'Details'),
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                  validator: (value) =>
                      Validators.required(value, label: 'Description'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _cancellationPolicyController,
                  label: 'Cancellation policy',
                  icon: Icons.policy_outlined,
                  maxLines: 3,
                  validator: (value) =>
                      Validators.required(value, label: 'Cancellation policy'),
                ),
                if (matchViewModel.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    matchViewModel.errorMessage!,
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: AppColours.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create Match',
                  icon: Icons.add,
                  isLoading: matchViewModel.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _PaymentModePicker extends StatelessWidget {
  const _PaymentModePicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaymentModeOption(
          mode: AppStrings.paymentModeSplit,
          title: 'Split the cost',
          subtitle: 'Each player pays their share when they join.',
          icon: Icons.group,
          selected: selected == AppStrings.paymentModeSplit,
          onTap: () => onChanged(AppStrings.paymentModeSplit),
        ),
        const SizedBox(height: 10),
        _PaymentModeOption(
          mode: AppStrings.paymentModeOrganiserPays,
          title: 'Organiser pays',
          subtitle:
              "You cover the pitch cost. Players owe you their share through the app.",
          icon: Icons.payments_outlined,
          selected: selected == AppStrings.paymentModeOrganiserPays,
          onTap: () => onChanged(AppStrings.paymentModeOrganiserPays),
        ),
      ],
    );
  }
}

class _PaymentModeOption extends StatelessWidget {
  const _PaymentModeOption({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColours.accent.withValues(alpha: 0.08)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColours.accent : AppColours.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColours.accent.withValues(alpha: 0.15)
                    : AppColours.cardAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColours.accent : AppColours.mutedText,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColours.accent : AppColours.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColours.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColours.accent),
            const SizedBox(height: 10),
            Text(label, style: AppTextStyles.small),
            const SizedBox(height: 3),
            Text(
              value,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(title, style: AppTextStyles.h3),
    );
  }
}
