import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/venue.dart';
import '../../viewmodels/venue_viewmodel.dart';

class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({
    super.key,
    required this.venueId,
    required this.currentUser,
  });

  final String venueId;
  final AppUser currentUser;

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  late DateTime _selectedDay;
  VenueSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final venueViewModel = context.watch<VenueViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Venue')),
      body: FutureBuilder<Venue?>(
        future: venueViewModel.getVenue(widget.venueId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }

          final venue = snapshot.data;
          if (venue == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Venue not found',
                message: 'This venue may have been removed.',
              ),
            );
          }

          final slots = venueViewModel.generateSlotsForDay(venue, _selectedDay);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    _Header(venue: venue),
                    const SizedBox(height: 16),
                    _AmenitiesRow(venue: venue),
                    const SizedBox(height: 18),
                    Text('Pitches', style: AppTextStyles.h3),
                    const SizedBox(height: 10),
                    Column(
                      children: venue.pitches
                          .map((pitch) => _PitchTile(pitch: pitch))
                          .toList(),
                    ),
                    const SizedBox(height: 22),
                    Text('Book a slot', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    _DayPicker(
                      selected: _selectedDay,
                      onSelect: (day) => setState(() {
                        _selectedDay = day;
                        _selectedSlot = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _SlotGrid(
                      slots: slots,
                      selected: _selectedSlot,
                      onSelect: (slot) =>
                          setState(() => _selectedSlot = slot),
                    ),
                    const SizedBox(height: 96),
                  ],
                ),
              ),
              if (_selectedSlot != null)
                _BookingBar(
                  venue: venue,
                  slot: _selectedSlot!,
                  onContinue: () => _continueToCreateMatch(venue, _selectedSlot!),
                ),
            ],
          );
        },
      ),
    );
  }

  void _continueToCreateMatch(Venue venue, VenueSlot slot) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking ${slot.pitch.format} on ${DateTimeHelpers.formatMatchDateTime(slot.startTime)} '
          '(${CurrencyHelpers.formatGBP(slot.pitch.pricePerHour)}). '
          'Match creation hook-up coming next.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                colors: [
                  AppColours.accent.withValues(alpha: 0.25),
                  AppColours.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.stadium, color: AppColours.accent, size: 56),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(venue.name, style: AppTextStyles.h2),
                    ),
                    if (venue.reviewCount > 0) ...[
                      const Icon(Icons.star, color: AppColours.warning, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${venue.rating.toStringAsFixed(1)} (${venue.reviewCount})',
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColours.mutedText),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(venue.address,
                          style: AppTextStyles.bodyMuted),
                    ),
                  ],
                ),
                if (venue.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(venue.description, style: AppTextStyles.bodyMuted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenitiesRow extends StatelessWidget {
  const _AmenitiesRow({required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    if (venue.amenities.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: venue.amenities.map((amenity) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColours.cardAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColours.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_amenityIcon(amenity),
                  size: 13, color: AppColours.mutedText),
              const SizedBox(width: 6),
              Text(amenity, style: AppTextStyles.small),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _amenityIcon(String amenity) {
    final lower = amenity.toLowerCase();
    if (lower.contains('parking')) return Icons.local_parking;
    if (lower.contains('floodlight')) return Icons.wb_sunny_outlined;
    if (lower.contains('changing')) return Icons.checkroom_outlined;
    if (lower.contains('shower')) return Icons.shower;
    if (lower.contains('café') || lower.contains('cafe')) return Icons.coffee;
    if (lower.contains('bar')) return Icons.sports_bar_outlined;
    if (lower.contains('wifi')) return Icons.wifi;
    if (lower.contains('indoor')) return Icons.home_outlined;
    if (lower.contains('vending')) return Icons.local_drink_outlined;
    return Icons.check_circle_outline;
  }
}

class _PitchTile extends StatelessWidget {
  const _PitchTile({required this.pitch});
  final VenuePitch pitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColours.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.groups_2, color: AppColours.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pitch.format, style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                )),
                Text(
                  '${pitch.surface} · ${pitch.capacity} players',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          Text(
            '${CurrencyHelpers.formatGBP(pitch.pricePerHour)}/hr',
            style: AppTextStyles.body.copyWith(
              color: AppColours.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final days = List.generate(14, (i) => start.add(Duration(days: i)));

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.year == selected.year &&
              day.month == selected.month &&
              day.day == selected.day;
          return InkWell(
            onTap: () => onSelect(day),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColours.accent.withValues(alpha: 0.12)
                    : AppColours.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColours.accent : AppColours.line,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekday(day),
                    style: AppTextStyles.small.copyWith(
                      color: isSelected ? AppColours.accent : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day.day.toString(),
                    style: AppTextStyles.h3.copyWith(
                      color: isSelected ? AppColours.accent : AppColours.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _weekday(DateTime day) {
    return const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][day.weekday - 1];
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final List<VenueSlot> slots;
  final VenueSlot? selected;
  final ValueChanged<VenueSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Text('No slots configured for this venue.',
          style: AppTextStyles.bodyMuted);
    }

    // Group by pitch
    final byPitch = <VenuePitch, List<VenueSlot>>{};
    for (final slot in slots) {
      byPitch.putIfAbsent(slot.pitch, () => []).add(slot);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byPitch.entries.map((entry) {
        final pitch = entry.key;
        final pitchSlots = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pitch.format} · ${pitch.surface}',
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColours.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pitchSlots.map((slot) {
                  final isSelected = slot == selected;
                  final isPast = !slot.isAvailable;
                  return InkWell(
                    onTap: isPast ? null : () => onSelect(slot),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: isPast
                            ? AppColours.surface
                            : isSelected
                                ? AppColours.accent.withValues(alpha: 0.16)
                                : AppColours.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColours.accent
                              : AppColours.line,
                        ),
                      ),
                      child: Text(
                        _formatHour(slot.startTime),
                        style: AppTextStyles.small.copyWith(
                          color: isPast
                              ? AppColours.mutedText
                              : isSelected
                                  ? AppColours.accent
                                  : AppColours.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatHour(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    return '$h:00';
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({
    required this.venue,
    required this.slot,
    required this.onContinue,
  });

  final Venue venue;
  final VenueSlot slot;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${slot.pitch.format} · ${_dayLabel(slot.startTime)}',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_hourLabel(slot.startTime)} – ${_hourLabel(slot.endTime)} · ${CurrencyHelpers.formatGBP(slot.pitch.pricePerHour)}',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: PrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${time.day} ${months[time.month - 1]}';
  }

  String _hourLabel(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    return '$h:00';
  }
}
