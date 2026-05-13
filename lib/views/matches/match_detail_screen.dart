import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../services/reliability_service.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import 'organiser_match_dashboard_screen.dart';
import 'post_match_rating_screen.dart';
import '../payment/mock_payment_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.currentUser,
  });

  final String matchId;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Match details')),
      body: StreamBuilder<FootballMatch?>(
        stream: matchViewModel.matchStream(matchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }

          final match = snapshot.data;
          if (match == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Match not found',
                message: 'This game may have been removed by the organiser.',
              ),
            );
          }

          return StreamBuilder<List<MatchParticipant>>(
            stream: matchViewModel.participantsStream(match.id),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              final currentParticipant = _currentParticipant(participants);
              final isOrganiser = match.organiserId == currentUser.uid;
              final canRate =
                  match.isCompleted &&
                  currentParticipant?.attendanceStatus == 'Attended';

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _Header(match: match),
                          if (isOrganiser) ...[
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: 'Organiser dashboard',
                              icon: Icons.admin_panel_settings_outlined,
                              onPressed: () =>
                                  _openOrganiserDashboard(context, match),
                            ),
                          ],
                          if (canRate) ...[
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: 'Rate players',
                              icon: Icons.star_rate,
                              isSecondary: true,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PostMatchRatingScreen(
                                      match: match,
                                      currentUser: currentUser,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 18),
                          _InfoGrid(match: match),
                          const SizedBox(height: 18),
                          _Section(
                            title: 'Description',
                            child: Text(
                              match.description.isEmpty
                                  ? 'No description added yet.'
                                  : match.description,
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Needed positions',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: match.neededPositions.entries
                                  .map(
                                    (entry) => _PositionNeed(
                                      label: entry.key,
                                      count: entry.value,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Rules / notes',
                            child: Text(
                              match.cancellationPolicy.isEmpty
                                  ? 'Respect the organiser, arrive on time and bring suitable footwear.'
                                  : match.cancellationPolicy,
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Players & requests',
                            child: participants.isEmpty
                                ? Text(
                                    'No confirmed players yet.',
                                    style: AppTextStyles.bodyMuted,
                                  )
                                : Column(
                                    children: participants
                                        .map(
                                          (participant) => _PlayerTile(
                                            participant: participant,
                                            lowReliabilityThreshold: match
                                                .minimumReliabilityRequired,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                    _BottomJoinBar(
                      match: match,
                      participant: currentParticipant,
                      isOrganiser: isOrganiser,
                      onManage: () => _openOrganiserDashboard(context, match),
                      onJoin: () => _choosePosition(context, match),
                      onPayApproved: currentParticipant == null
                          ? null
                          : () => _openPayment(
                              context,
                              match,
                              currentParticipant.position,
                            ),
                      onWithdraw: currentParticipant == null
                          ? null
                          : () => _confirmWithdraw(
                              context,
                              match,
                              currentParticipant,
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openOrganiserDashboard(BuildContext context, FootballMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrganiserMatchDashboardScreen(
          matchId: match.id,
          currentUser: currentUser,
        ),
      ),
    );
  }

  Future<void> _choosePosition(
    BuildContext context,
    FootballMatch match,
  ) async {
    String selectedPosition =
        AppStrings.positions.contains(currentUser.preferredPosition)
        ? currentUser.preferredPosition
        : 'Any';

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose your position', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      match.isSplitPayment
                          ? 'Join the match first so you can review the player list. Payment secures your slot afterwards.'
                          : 'This helps the organiser balance the teams.',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppStrings.positions
                          .map(
                            (position) => _PositionOption(
                              label: position,
                              selected: selectedPosition == position,
                              onTap: () => setModalState(
                                () => selectedPosition = position,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: match.isSplitPayment
                          ? 'Join match'
                          : 'Join and owe organiser',
                      icon: match.isSplitPayment
                          ? Icons.how_to_reg
                          : Icons.payments_outlined,
                      onPressed: () =>
                          Navigator.of(context).pop(selectedPosition),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;

    if (match.isOrganiserPays) {
      final paymentViewModel = context.read<PaymentViewModel>();
      final success = await paymentViewModel.freeJoin(
        match: match,
        user: currentUser,
        position: result,
      );
      if (!context.mounted || !success) {
        if (context.mounted && paymentViewModel.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(paymentViewModel.errorMessage!)),
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You're in. You owe ${CurrencyHelpers.formatGBP(match.pricePerPlayer)} to the organiser.",
          ),
        ),
      );
      return;
    }

    final matchViewModel = context.read<MatchViewModel>();
    final request = await matchViewModel.requestToJoinMatch(
      match: match,
      user: currentUser,
      position: result,
    );
    if (!context.mounted) return;
    if (request == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(matchViewModel.errorMessage ?? 'Could not join match.'),
        ),
      );
      return;
    }
    if (request.requiresApproval) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(request.message)));
      return;
    }

    if (request.canContinueToPayment) {
      await _openPayment(context, match, result);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(request.message)));
  }

  Future<void> _openPayment(
    BuildContext context,
    FootballMatch match,
    String position,
  ) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MockPaymentScreen(
          match: match,
          currentUser: currentUser,
          position: position,
        ),
      ),
    );

    if (!context.mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You're in. Payment confirmed.")),
    );
  }

  MatchParticipant? _currentParticipant(List<MatchParticipant> participants) {
    for (final participant in participants) {
      if (participant.userId == currentUser.uid) return participant;
    }
    return null;
  }

  Future<void> _confirmWithdraw(
    BuildContext context,
    FootballMatch match,
    MatchParticipant participant,
  ) async {
    final warning = ReliabilityService.withdrawalWarning(
      match.startDateTime,
      DateTime.now(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColours.surface,
        title: const Text('Withdraw from match?'),
        content: Text(
          [
            warning,
            if (match.isSplitPayment && participant.amountPaid > 0)
              'Refund handling will be added when real payments are enabled.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay in'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) return;
    final viewModel = context.read<MatchViewModel>();
    final success = await viewModel.withdrawFromMatch(
      matchId: match.id,
      userId: currentUser.uid,
      reason: 'Player withdrew from match detail.',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'You have withdrawn from this match.'
              : viewModel.errorMessage ?? 'Could not withdraw.',
        ),
      ),
    );
  }
}

class _PositionOption extends StatelessWidget {
  const _PositionOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColours.accent.withValues(alpha: 0.14)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColours.accent : AppColours.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? AppColours.accent : AppColours.mutedText,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: selected ? AppColours.accent : AppColours.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColours.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: AppColours.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.title, style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    Text(match.locationName, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (match.joinedPlayerCount / match.totalPlayersNeeded).clamp(
                0,
                1,
              ),
              backgroundColor: AppColours.line,
              color: match.isFull ? AppColours.error : AppColours.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${match.spacesLabel} spaces filled - ${match.displayStatus}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoItem(
        icon: Icons.event,
        label: 'Date and time',
        value: DateTimeHelpers.formatMatchDateTime(match.startDateTime),
      ),
      _InfoItem(
        icon: Icons.schedule,
        label: 'Duration',
        value: DateTimeHelpers.formatDuration(match.durationMinutes),
      ),
      _InfoItem(icon: Icons.groups_2, label: 'Format', value: match.format),
      _InfoItem(
        icon: Icons.payments_outlined,
        label: 'Price',
        value: CurrencyHelpers.formatGBP(match.pricePerPlayer),
      ),
      _InfoItem(icon: Icons.bolt, label: 'Skill', value: match.skillLevel),
      _InfoItem(
        icon: Icons.verified_user_outlined,
        label: 'Reliability',
        value: match.requiresApprovalForLowReliability
            ? 'Min ${match.minimumReliabilityRequired}'
            : 'Open',
      ),
      _InfoItem(icon: Icons.grass, label: 'Pitch', value: match.pitchType),
      _InfoItem(
        icon: Icons.person,
        label: 'Organiser',
        value: match.organiserName,
      ),
      _InfoItem(icon: Icons.place, label: 'Address', value: match.address),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColours.accent, size: 18),
          const Spacer(),
          Text(label, style: AppTextStyles.small),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PositionNeed extends StatelessWidget {
  const _PositionNeed({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColours.cardAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $count', style: AppTextStyles.small),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.participant,
    required this.lowReliabilityThreshold,
  });

  final MatchParticipant participant;
  final int lowReliabilityThreshold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColours.cardAlt,
            child: Text(
              participant.fullName.isEmpty
                  ? '?'
                  : participant.fullName[0].toUpperCase(),
              style: const TextStyle(color: AppColours.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.fullName, style: AppTextStyles.body),
                Text(
                  '${participant.position} - ${participant.skillLevel} · Rel ${participant.reliabilityScoreAtJoin} · Ability ${participant.abilityRatingAtJoin.toStringAsFixed(1)}',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniBadge(label: _statusLabel(participant)),
                    if (participant.reliabilityScoreAtJoin <
                        lowReliabilityThreshold)
                      const _MiniBadge(
                        label: 'Low reliability',
                        colour: AppColours.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            participant.hasConfirmedSlot
                ? Icons.verified
                : participant.isPendingPayment
                ? Icons.lock_clock
                : Icons.hourglass_top,
            color: participant.hasConfirmedSlot
                ? AppColours.accent
                : AppColours.warning,
            size: 18,
          ),
        ],
      ),
    );
  }

  String _statusLabel(MatchParticipant participant) {
    return switch (participant.attendanceStatus) {
      'PendingPayment' => 'Pending payment',
      'PendingApproval' => 'Pending approval',
      'LateCancelled' => 'Late cancelled',
      'NoShow' => 'No-show',
      _ => participant.attendanceStatus,
    };
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, this.colour = AppColours.accent});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.small.copyWith(color: colour, fontSize: 11),
      ),
    );
  }
}

class _BottomJoinBar extends StatelessWidget {
  const _BottomJoinBar({
    required this.match,
    required this.participant,
    required this.isOrganiser,
    required this.onManage,
    required this.onJoin,
    required this.onPayApproved,
    required this.onWithdraw,
  });

  final FootballMatch match;
  final MatchParticipant? participant;
  final bool isOrganiser;
  final VoidCallback onManage;
  final VoidCallback onJoin;
  final VoidCallback? onPayApproved;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final isApprovedPendingPayment =
        participant?.isPendingApproval == true &&
        participant?.organiserApproved == true &&
        match.isSplitPayment;
    final isPendingPayment =
        participant?.isPendingPayment == true || isApprovedPendingPayment;
    final label = isOrganiser
        ? 'Manage match'
        : switch (participant?.attendanceStatus) {
            'Joined' => "You're in",
            'Attended' => 'Attended',
            'NoShow' => 'No-show',
            'Cancelled' || 'LateCancelled' => 'Withdrawn',
            'Rejected' => 'Rejected',
            'PendingPayment' => 'Pay to secure',
            'PendingApproval' when isApprovedPendingPayment => 'Pay to secure',
            'PendingApproval' => 'Pending approval',
            _ => match.isFull ? 'Match Full' : 'Join match',
          };

    final priceLabel = isOrganiser
        ? 'Manage game'
        : match.isOrganiserPays
        ? 'Free to join'
        : CurrencyHelpers.formatGBP(match.pricePerPlayer);

    final subLabel = isOrganiser
        ? '${match.spacesLabel} secured spots'
        : _subLabel(match, participant, isPendingPayment);

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
                  Text(priceLabel, style: AppTextStyles.h3),
                  Text(subLabel, style: AppTextStyles.small),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: label,
                    icon: isOrganiser
                        ? Icons.admin_panel_settings_outlined
                        : participant?.hasConfirmedSlot == true
                        ? Icons.check
                        : isPendingPayment
                        ? Icons.lock
                        : match.isOrganiserPays
                        ? Icons.how_to_reg
                        : Icons.how_to_reg,
                    onPressed: isOrganiser
                        ? onManage
                        : match.isFull ||
                              match.isCompleted ||
                              match.isCancelled ||
                              participant?.isRejected == true ||
                              participant?.isWithdrawn == true ||
                              (participant?.isPendingApproval == true &&
                                  !isApprovedPendingPayment)
                        ? null
                        : isPendingPayment
                        ? onPayApproved
                        : participant?.hasConfirmedSlot == true
                        ? null
                        : onJoin,
                  ),
                  if (participant?.canWithdraw == true &&
                      !match.hasStarted &&
                      !match.isCompleted &&
                      !match.isCancelled) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onWithdraw,
                      child: const Text('Withdraw'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subLabel(
    FootballMatch match,
    MatchParticipant? participant,
    bool isPendingPayment,
  ) {
    if (match.isOrganiserPays) {
      if (participant?.hasConfirmedSlot == true) {
        return 'Spot confirmed. Settle with the organiser.';
      }
      return 'Join free, then settle your share with the organiser.';
    }

    if (participant?.hasConfirmedSlot == true) return 'Payment confirmed';
    if (isPendingPayment) {
      return 'You can view players now. Pay to lock in your place.';
    }
    if (participant?.isPendingApproval == true) {
      return 'Organiser approval needed before payment.';
    }
    return 'Join first, then pay when you are ready.';
  }
}
