import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../core/widgets/venue_autocomplete_field.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/venue.dart';
import '../../core/widgets/app_sheet.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../viewmodels/venue_viewmodel.dart';
import '../payment/payment_screen.dart';
import 'organiser_match_dashboard_screen.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({
    super.key,
    required this.currentUser,
    this.venueDraft,
    this.template,
  });

  final AppUser currentUser;

  /// When provided, the form is pre-filled from this venue + slot booking.
  final VenueBookingDraft? venueDraft;

  /// When provided, the form is pre-filled from a past match the user is
  /// "running it back" from. Date defaults to one week from the template's
  /// start time, same hour.
  final FootballMatch? template;

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _durationController;
  late final TextEditingController _totalPlayersController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _goalkeepersController;
  late final TextEditingController _defendersController;
  late final TextEditingController _midfieldersController;
  late final TextEditingController _forwardsController;
  late final TextEditingController _minimumReliabilityController;
  late final TextEditingController _cancellationPolicyController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _format;
  String _skillLevel = 'Casual';
  late String _pitchType;
  String _visibility = 'Public';
  String _paymentMode = AppStrings.paymentModeSplit;
  bool _requiresApprovalForLowReliability = true;

  List<Venue> _venues = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe once to the venues stream so autocomplete has data.
    context.read<VenueViewModel>().venuesStream().first.then((venues) {
      if (!mounted) return;
      setState(() => _venues = venues);
    });
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.venueDraft;
    final template = widget.template;

    _titleController = TextEditingController(text: template?.title ?? '');
    _locationNameController = TextEditingController(
      text: draft?.venue.name ?? template?.locationName ?? '',
    );
    _addressController = TextEditingController(
      text: draft?.venue.address ?? template?.address ?? '',
    );
    _durationController = TextEditingController(
      text: '${draft?.durationMinutes ?? template?.durationMinutes ?? 60}',
    );
    _totalPlayersController = TextEditingController(
      text:
          '${draft?.slot.pitch.capacity ?? template?.totalPlayersNeeded ?? 10}',
    );
    _priceController = TextEditingController(
      text: (draft?.suggestedPricePerPlayer ?? template?.pricePerPlayer ?? 5.00)
          .toStringAsFixed(2),
    );
    _priceController.addListener(_rebuildPaymentNotice);
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _goalkeepersController = TextEditingController(
      text: '${template?.neededPositions['Goalkeepers'] ?? 2}',
    );
    _defendersController = TextEditingController(
      text: '${template?.neededPositions['Defenders'] ?? 2}',
    );
    _midfieldersController = TextEditingController(
      text: '${template?.neededPositions['Midfielders'] ?? 4}',
    );
    _forwardsController = TextEditingController(
      text: '${template?.neededPositions['Forwards'] ?? 2}',
    );
    _minimumReliabilityController = TextEditingController(
      text: '${template?.minimumReliabilityRequired ?? 60}',
    );
    _cancellationPolicyController = TextEditingController(
      text: template?.cancellationPolicy.isNotEmpty == true
          ? template!.cancellationPolicy
          : 'Withdraw at least 24 hours before kick-off for a full refund.',
    );
    _skillLevel = template?.skillLevel ?? 'Casual';
    _visibility = template?.visibility ?? 'Public';
    _paymentMode = template?.paymentMode ?? AppStrings.paymentModeSplit;
    _requiresApprovalForLowReliability =
        template?.requiresApprovalForLowReliability ?? true;

    if (draft != null) {
      final slotStart = draft.slot.startTime;
      _selectedDate = DateTime(slotStart.year, slotStart.month, slotStart.day);
      _selectedTime = TimeOfDay(hour: slotStart.hour, minute: slotStart.minute);
      _format = AppStrings.matchFormats.contains(draft.slot.pitch.format)
          ? draft.slot.pitch.format
          : '5-a-side';
      _pitchType = draft.matchPitchType;
    } else if (template != null) {
      // Default to next week, same kick-off time.
      final nextWeek = template.startDateTime.add(const Duration(days: 7));
      _selectedDate = DateTime(nextWeek.year, nextWeek.month, nextWeek.day);
      _selectedTime = TimeOfDay(
        hour: template.startDateTime.hour,
        minute: template.startDateTime.minute,
      );
      _format = AppStrings.matchFormats.contains(template.format)
          ? template.format
          : '5-a-side';
      _pitchType = AppStrings.pitchTypes.contains(template.pitchType)
          ? template.pitchType
          : 'Astro';
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 19, minute: 0);
      _format = '5-a-side';
      _pitchType = 'Astro';
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_rebuildPaymentNotice);
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

  void _rebuildPaymentNotice() {
    if (mounted) setState(() {});
  }

  void _applyVenuePick(Venue venue) {
    setState(() {
      _locationNameController.text = venue.name;
      _addressController.text = venue.address;

      // Pre-fill format + pitch type from the first available pitch, but
      // only when the user hasn't already picked something non-default.
      if (venue.pitches.isNotEmpty) {
        final pitch = venue.pitches.first;
        if (AppStrings.matchFormats.contains(pitch.format)) {
          _format = pitch.format;
        }
        _pitchType = _surfaceToPitchType(pitch.surface);

        // Suggest a per-player price based on the pitch hire / capacity.
        if (pitch.capacity > 0) {
          final per = (pitch.pricePerHour / pitch.capacity);
          _priceController.text = per.toStringAsFixed(2);
        }
      }
    });
    // Show a brief confirmation so the user knows it worked.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filled in details from ${venue.name}.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _surfaceToPitchType(String surface) {
    final lower = surface.toLowerCase();
    if (lower.contains('indoor')) return 'Indoor';
    if (lower.contains('3g') || lower.contains('4g')) return '3G/4G';
    if (lower.contains('astro')) return 'Astro';
    if (lower.contains('grass')) return 'Grass';
    return 'Outdoor';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final pricePerPlayer = double.parse(_priceController.text);
    final confirmed = await _confirmPaymentSetup(pricePerPlayer);
    if (!confirmed || !mounted) return;

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
      pricePerPlayer: pricePerPlayer,
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

    final matchId = await context.read<MatchViewModel>().createMatch(match);
    if (!mounted) return;

    if (matchId != null) {
      final createdMatch = match.copyWith(id: matchId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Match created.')));
      // Organisers playing a split match secure their own spot first so
      // the liability picture starts clean.
      if (createdMatch.isSplitPayment) {
        final payNow = await _askToPayOwnSpot(createdMatch);
        if (!mounted) return;
        if (payNow) {
          final position =
              AppStrings.positions.contains(
                widget.currentUser.preferredPosition,
              )
              ? widget.currentUser.preferredPosition
              : 'Any';
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => PaymentScreen(
                match: createdMatch,
                currentUser: widget.currentUser,
                position: position,
              ),
            ),
          );
          if (!mounted) return;
        }
      }
      // Straight into inviting players — the game fills faster when the
      // squad hears about it immediately.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrganiserMatchDashboardScreen(
            matchId: matchId,
            currentUser: widget.currentUser,
            openInviteSheetOnLoad: true,
          ),
        ),
      );
    }
  }

  Future<bool> _confirmPaymentSetup(double pricePerPlayer) async {
    final isSplit = _paymentMode == AppStrings.paymentModeSplit;
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: isSplit ? 'Split payment setup' : 'Organiser pays setup',
      message: isSplit
          ? 'Each player pays their own share before their spot is secured — '
                'including you: ${CurrencyHelpers.formatGBP(pricePerPlayer)} '
                'for your own place after creating the match. If a player '
                'misses their payment deadline, their share shows as your '
                'liability on the dashboard.'
          : 'You are covering the pitch upfront. Players join without paying '
                'in the app and their share is recorded as owed to you '
                'directly.',
      confirmLabel: 'Create match',
      confirmIcon: Icons.check,
      cancelLabel: 'Review',
    );
    return confirmed == true;
  }

  Future<bool> _askToPayOwnSpot(FootballMatch match) async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Pay your place now?',
      message:
          'Your match is live. Pay your own spot now so nothing is owed '
          'against you when players start joining.',
      confirmLabel: 'Pay now',
      confirmIcon: Icons.lock_outline,
      cancelLabel: 'Later',
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create a match')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.venueDraft != null || widget.template != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.venueDraft != null
                          ? "We've pre-filled the location, date and format from your booking."
                          : "Running it back — we've copied everything from \"${widget.template!.title}\" and set the date a week later. Tweak anything you like.",
                      style: AppTextStyles.bodyMuted,
                    ),
                  ),
                if (widget.venueDraft != null) ...[
                  const SizedBox(height: 14),
                  _VenueDraftBanner(draft: widget.venueDraft!),
                ],

                _SectionHeader(title: 'Basic info'),
                CustomTextField(
                  controller: _titleController,
                  label: 'Match title',
                  icon: Icons.sports_soccer,
                  validator: (value) =>
                      Validators.required(value, label: 'Match title'),
                ),
                const SizedBox(height: 14),
                VenueAutocompleteField(
                  controller: _locationNameController,
                  venues: _venues,
                  onVenuePicked: _applyVenuePick,
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
                const SizedBox(height: 12),
                _PaymentResponsibilityNotice(
                  paymentMode: _paymentMode,
                  priceText: _priceController.text,
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
                  label: 'Create match',
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
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MatchDateSheet(selectedDate: _selectedDate),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MatchTimeSheet(selectedTime: _selectedTime),
    );

    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MatchDateSheet extends StatefulWidget {
  const _MatchDateSheet({required this.selectedDate});

  final DateTime selectedDate;

  @override
  State<_MatchDateSheet> createState() => _MatchDateSheetState();
}

class _MatchDateSheetState extends State<_MatchDateSheet> {
  late DateTime _selectedDate;
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = _dateOnly(widget.selectedDate);
    _dates = [
      for (var index = 0; index < 56; index++) today.add(Duration(days: index)),
    ];
    if (_dates.every((date) => !_sameDate(date, _selectedDate))) {
      _dates.add(_selectedDate);
      _dates.sort();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SelectionSheetHandle(),
              Text('Match date', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Choose when players should meet.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              Text('Popular', style: AppTextStyles.small),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DateShortcut(
                    label: 'Today',
                    date: _dateOnly(DateTime.now()),
                    selectedDate: _selectedDate,
                    onSelected: _setSelectedDate,
                  ),
                  _DateShortcut(
                    label: 'Tomorrow',
                    date: _dateOnly(
                      DateTime.now().add(const Duration(days: 1)),
                    ),
                    selectedDate: _selectedDate,
                    onSelected: _setSelectedDate,
                  ),
                  _DateShortcut(
                    label: 'Weekend',
                    date: _nextWeekend(),
                    selectedDate: _selectedDate,
                    onSelected: _setSelectedDate,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SheetSummaryTile(
                icon: Icons.event_available,
                label: 'Selected date',
                value: DateTimeHelpers.formatDate(_selectedDate),
              ),
              const SizedBox(height: 14),
              Text('Next 8 weeks', style: AppTextStyles.small),
              const SizedBox(height: 8),
              const _WeekdayHeader(),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.builder(
                  itemCount: _dates.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 54,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final date = _dates[index];
                    return _DateTile(
                      date: date,
                      selected: _sameDate(date, _selectedDate),
                      onTap: () => _setSelectedDate(date),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Use date',
                icon: Icons.check,
                onPressed: () => Navigator.of(context).pop(_selectedDate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setSelectedDate(DateTime date) {
    setState(() => _selectedDate = _dateOnly(date));
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static DateTime _nextWeekend() {
    final today = _dateOnly(DateTime.now());
    final daysUntilSaturday = (DateTime.saturday - today.weekday) % 7;
    return today.add(Duration(days: daysUntilSaturday));
  }
}

class _DateShortcut extends StatelessWidget {
  const _DateShortcut({
    required this.label,
    required this.date,
    required this.selectedDate,
    required this.onSelected,
  });

  final String label;
  final DateTime date;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = _MatchDateSheetState._sameDate(date, selectedDate);
    return SelectionPill(
      label: label,
      selected: selected,
      onTap: () => onSelected(date),
    );
  }
}

class _SheetSummaryTile extends StatelessWidget {
  const _SheetSummaryTile({
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: AppColours.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColours.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.small),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _weekdays
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: AppTextStyles.small.copyWith(
                    color: AppColours.mutedText.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: selected
              ? AppColours.accent.withValues(alpha: 0.16)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColours.accent : AppColours.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdays[date.weekday - 1],
              style: AppTextStyles.small.copyWith(
                color: selected ? AppColours.accent : AppColours.mutedText,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              date.day.toString(),
              style: AppTextStyles.body.copyWith(
                color: selected ? AppColours.accent : AppColours.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchTimeSheet extends StatefulWidget {
  const _MatchTimeSheet({required this.selectedTime});

  final TimeOfDay selectedTime;

  @override
  State<_MatchTimeSheet> createState() => _MatchTimeSheetState();
}

class _MatchTimeSheetState extends State<_MatchTimeSheet> {
  late TimeOfDay _selectedTime;
  late final List<TimeOfDay> _times;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.selectedTime;
    _times = [
      for (var hour = 6; hour <= 23; hour++) ...[
        TimeOfDay(hour: hour, minute: 0),
        TimeOfDay(hour: hour, minute: 30),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SelectionSheetHandle(),
              Text('Kick-off time', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Pick the first whistle. Times use a 24-hour clock.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              Text('Popular kick-offs', style: AppTextStyles.small),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    const [
                          _TimeShortcut(hour: 18, minute: 0),
                          _TimeShortcut(hour: 19, minute: 0),
                          _TimeShortcut(hour: 20, minute: 0),
                          _TimeShortcut(hour: 21, minute: 0),
                        ]
                        .map(
                          (shortcut) => SelectionPill(
                            label: shortcut.label,
                            selected: _sameTime(shortcut.time, _selectedTime),
                            onTap: () =>
                                setState(() => _selectedTime = shortcut.time),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 14),
              _SheetSummaryTile(
                icon: Icons.schedule,
                label: 'Selected kick-off',
                value: _formatSheetTime(_selectedTime),
              ),
              const SizedBox(height: 14),
              Text('All times', style: AppTextStyles.small),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: _times.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisExtent: 44,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final time = _times[index];
                    return _TimeTile(
                      time: time,
                      selected: _sameTime(time, _selectedTime),
                      onTap: () => setState(() => _selectedTime = time),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Use time',
                icon: Icons.check,
                onPressed: () => Navigator.of(context).pop(_selectedTime),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameTime(TimeOfDay first, TimeOfDay second) {
    return first.hour == second.hour && first.minute == second.minute;
  }
}

class _TimeShortcut {
  const _TimeShortcut({required this.hour, required this.minute});

  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);
  String get label => _formatSheetTime(time);
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final TimeOfDay time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelectionPill(
      label: _formatSheetTime(time),
      selected: selected,
      onTap: onTap,
      compact: true,
    );
  }
}

String _formatSheetTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
              "You cover the pitch cost and collect each player's share directly.",
          icon: Icons.payments_outlined,
          selected: selected == AppStrings.paymentModeOrganiserPays,
          onTap: () => onChanged(AppStrings.paymentModeOrganiserPays),
        ),
      ],
    );
  }
}

class _PaymentResponsibilityNotice extends StatelessWidget {
  const _PaymentResponsibilityNotice({
    required this.paymentMode,
    required this.priceText,
  });

  final String paymentMode;
  final String priceText;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(priceText) ?? 0;
    final isSplit = paymentMode == AppStrings.paymentModeSplit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColours.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSplit ? Icons.shield_outlined : Icons.account_balance_wallet,
            color: AppColours.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSplit
                  ? 'Players pay before their spot is secured. You will pay £${price.toStringAsFixed(2)} for your own place after creating the match. If someone misses the payment deadline, their share appears as organiser liability.'
                  : 'You cover the pitch upfront. Players can join without paying in app and their share is tracked as owed to you.',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
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
    return SelectionSheetField(
      label: label,
      value: value,
      options: items,
      onChanged: onChanged,
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

class _VenueDraftBanner extends StatelessWidget {
  const _VenueDraftBanner({required this.draft});

  final VenueBookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final start = draft.slot.startTime;
    final end = draft.endTime;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [
            AppColours.accent.withValues(alpha: 0.14),
            AppColours.accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColours.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.stadium,
              color: AppColours.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  draft.venue.name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.slot.pitch.format} · ${_dayLabel(start)} · '
                  '${_hourLabel(start)}–${_hourLabel(end)}',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${time.day} ${months[time.month - 1]}';
  }

  static String _hourLabel(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
