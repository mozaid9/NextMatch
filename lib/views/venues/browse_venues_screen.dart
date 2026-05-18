import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/app_user.dart';
import '../../models/venue.dart';
import '../../viewmodels/venue_viewmodel.dart';
import 'venue_detail_screen.dart';

class BrowseVenuesScreen extends StatelessWidget {
  const BrowseVenuesScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final venueViewModel = context.watch<VenueViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Venues')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pitches near you', style: AppTextStyles.h1),
                  const SizedBox(height: 6),
                  Text(
                    'Pick a venue, pick a slot — done. No address typing.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Venue>>(
                stream: venueViewModel.venuesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonMatchList();
                  }

                  final venues = snapshot.data ?? [];
                  if (venues.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                      child: EmptyState(
                        icon: Icons.stadium_outlined,
                        title: 'No venues onboarded yet',
                        message:
                            'Seed a few partner venues to explore the booking flow.',
                        action: PrimaryButton(
                          label: 'Add demo venues',
                          icon: Icons.auto_awesome,
                          isLoading: venueViewModel.isLoading,
                          onPressed: () async {
                            final ok = await venueViewModel.seedDemoVenues();
                            if (!context.mounted || !ok) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Demo venues added.'),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                    itemCount: venues.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final venue = venues[index];
                      return _VenueCard(
                        venue: venue,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VenueDetailScreen(
                              venueId: venue.id,
                              currentUser: currentUser,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.onTap});

  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColours.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColours.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo / placeholder header
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: AppColours.cardAlt,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                gradient: LinearGradient(
                  colors: [
                    AppColours.accent.withValues(alpha: 0.18),
                    AppColours.accent.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.stadium,
                  color: AppColours.accent,
                  size: 36,
                ),
              ),
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
                        const Icon(Icons.star, color: AppColours.warning, size: 14),
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
                      const Icon(Icons.place_outlined,
                          size: 13, color: AppColours.mutedText),
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
                                horizontal: 8, vertical: 4),
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
                      const Icon(Icons.chevron_right,
                          color: AppColours.mutedText, size: 18),
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
