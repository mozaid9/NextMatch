import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/app_user.dart';
import '../../models/venue.dart';
import '../../viewmodels/venue_viewmodel.dart';
import 'venue_detail_screen.dart';

class BrowseVenuesScreen extends StatefulWidget {
  const BrowseVenuesScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<BrowseVenuesScreen> createState() => _BrowseVenuesScreenState();
}

class _BrowseVenuesScreenState extends State<BrowseVenuesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _city = 'Any city';
  String _format = 'Any format';
  String _maxPrice = 'Any price';

  void _clearFilters() => setState(() {
    _city = 'Any city';
    _format = 'Any format';
    _maxPrice = 'Any price';
    _query = '';
    _searchController.clear();
  });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Venue> _applyFilters(List<Venue> venues) {
    return venues.where((venue) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches =
            venue.name.toLowerCase().contains(q) ||
            venue.city.toLowerCase().contains(q) ||
            venue.address.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_city != 'Any city' && venue.city != _city) return false;
      if (_format != 'Any format' && !venue.pitchTypes.contains(_format)) {
        return false;
      }
      if (_maxPrice != 'Any price') {
        final cap = _maxPriceValue(_maxPrice);
        if (venue.fromPrice > cap) return false;
      }
      return true;
    }).toList();
  }

  double _maxPriceValue(String label) => switch (label) {
    'Under £50/hr' => 50,
    'Under £75/hr' => 75,
    'Under £100/hr' => 100,
    _ => double.infinity,
  };

  @override
  Widget build(BuildContext context) {
    final venueViewModel = context.watch<VenueViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Venues')),
      body: SafeArea(
        child: StreamBuilder<List<Venue>>(
          stream: venueViewModel.venuesStream(),
          builder: (context, snapshot) {
            final allVenues = snapshot.data ?? [];
            // Build a dynamic city list from current venues.
            final cities = <String>{for (final v in allVenues) v.city}.toList()
              ..sort();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                      ),
                      const SizedBox(height: 12),
                      _FilterRow(
                        city: _city,
                        format: _format,
                        maxPrice: _maxPrice,
                        cities: cities,
                        onCityChanged: (v) => setState(() => _city = v),
                        onFormatChanged: (v) => setState(() => _format = v),
                        onMaxPriceChanged: (v) => setState(() => _maxPrice = v),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SkeletonMatchList();
                      }

                      if (allVenues.isEmpty) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                          child: EmptyState(
                            icon: Icons.stadium_outlined,
                            title: 'No venues onboarded yet',
                            message:
                                'Partner venues are coming soon. You can still create a match anywhere in the meantime.',
                          ),
                        );
                      }

                      final filtered = _applyFilters(allVenues);
                      if (filtered.isEmpty) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                          child: EmptyState(
                            icon: Icons.filter_alt_off,
                            title: 'No venues match these filters',
                            message:
                                'Try broadening your search, or clear the filters.',
                            action: PrimaryButton(
                              label: 'Clear filters',
                              icon: Icons.filter_alt_off,
                              isSecondary: true,
                              onPressed: _clearFilters,
                            ),
                          ),
                        );
                      }

                      return StreamBuilder<Set<String>>(
                        stream: venueViewModel.favouriteVenueIdsStream(
                          widget.currentUser.uid,
                        ),
                        builder: (context, favSnap) {
                          final favs = favSnap.data ?? const <String>{};
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final venue = filtered[index];
                              return _VenueCard(
                                venue: venue,
                                isFavourite: favs.contains(venue.id),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => VenueDetailScreen(
                                      venueId: venue.id,
                                      currentUser: widget.currentUser,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search by name, city or address',
          hintStyle: AppTextStyles.bodyMuted,
          prefixIcon: Icon(Icons.search, color: AppColours.mutedText),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.city,
    required this.format,
    required this.maxPrice,
    required this.cities,
    required this.onCityChanged,
    required this.onFormatChanged,
    required this.onMaxPriceChanged,
  });

  final String city;
  final String format;
  final String maxPrice;
  final List<String> cities;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onMaxPriceChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _PopupFilter(
            icon: Icons.location_city,
            title: 'City',
            label: city,
            options: ['Any city', ...cities],
            onSelected: onCityChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.groups_2,
            title: 'Format',
            label: format,
            options: const [
              'Any format',
              '5-a-side',
              '6-a-side',
              '7-a-side',
              '9-a-side',
              '11-a-side',
            ],
            onSelected: onFormatChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.payments_outlined,
            title: 'Max price',
            label: maxPrice,
            options: const [
              'Any price',
              'Under £50/hr',
              'Under £75/hr',
              'Under £100/hr',
            ],
            onSelected: onMaxPriceChanged,
          ),
        ],
      ),
    );
  }
}

class _PopupFilter extends StatelessWidget {
  const _PopupFilter({
    required this.icon,
    required this.title,
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = !label.startsWith('Any');

    return InkWell(
      onTap: () => _openOptions(context),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? AppColours.accent.withValues(alpha: 0.08)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColours.accent.withValues(alpha: 0.6)
                : AppColours.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColours.accent),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: isActive ? AppColours.accent : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: isActive ? AppColours.accent : AppColours.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOptions(BuildContext context) async {
    final selected = await showSelectionSheet(
      context: context,
      title: title,
      selectedValue: label,
      options: options,
    );

    if (selected != null) onSelected(selected);
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.onTap,
    this.isFavourite = false,
  });

  final Venue venue;
  final VoidCallback onTap;
  final bool isFavourite;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColours.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColours.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColours.cardAlt,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        AppColours.accent.withValues(alpha: 0.18),
                        AppColours.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.stadium,
                      color: AppColours.accent,
                      size: 36,
                    ),
                  ),
                ),
                if (isFavourite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColours.surface.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: AppColours.accent,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(venue.name, style: AppTextStyles.h3),
                      ),
                      if (venue.reviewCount > 0) ...[
                        const Icon(
                          Icons.star,
                          color: AppColours.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          venue.rating.toStringAsFixed(1),
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: AppColours.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.address,
                          style: AppTextStyles.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: venue.pitchTypes
                        .map(
                          (type) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColours.cardAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(type, style: AppTextStyles.small),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'From ${CurrencyHelpers.formatGBP(venue.fromPrice)}/hr',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColours.accent,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: AppColours.mutedText,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
