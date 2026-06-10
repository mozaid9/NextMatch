import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';

import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_comment.dart';
import '../../models/match_participant.dart';
import '../../services/friends_service.dart';
import '../../services/reliability_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import 'organiser_match_dashboard_screen.dart';
import 'post_match_rating_screen.dart';
import '../payment/mock_payment_screen.dart';

String _shareTextFor(FootballMatch match) {
  final start = match.startDateTime;
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h = start.hour.toString().padLeft(2, '0');
  final m = start.minute.toString().padLeft(2, '0');
  final dateLabel = '${start.day} ${months[start.month - 1]} at $h:$m';
  final priceLabel = match.isOrganiserPays
      ? '${CurrencyHelpers.formatGBP(match.pricePerPlayer)} paid to the organiser directly'
      : '${CurrencyHelpers.formatGBP(match.pricePerPlayer)} per player';
  return [
    '⚽ ${match.title}',
    '📅 $dateLabel',
    '📍 ${match.locationName}, ${match.address}',
    '👥 ${match.format} · ${match.skillLevel} · ${match.spacesLabel} filled',
    '💷 $priceLabel',
    'Open NextMatch to grab a spot.',
  ].join('\n');
}

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
      appBar: AppBar(
        title: const Text('Match details'),
        actions: [
          IconButton(
            tooltip: 'Share match',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final match = await matchViewModel.getMatch(matchId);
              if (match == null || !context.mounted) return;
              await _openShareSheet(context, match);
            },
          ),
        ],
      ),
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
                          if (match.isCancelled) ...[
                            _CancelledBanner(match: match),
                            const SizedBox(height: 14),
                          ],
                          _Header(match: match),
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
                          StreamBuilder<List<Friend>>(
                            stream: context
                                .read<FriendsViewModel>()
                                .friendsStream(currentUser.uid),
                            builder: (context, friendsSnapshot) {
                              final friendUids = (friendsSnapshot.data ?? [])
                                  .map((f) => f.uid)
                                  .toSet();
                              final friendCount = participants
                                  .where((p) => friendUids.contains(p.userId))
                                  .length;
                              return Column(
                                children: [
                                  if (friendCount > 0) ...[
                                    _FriendsInMatchBanner(count: friendCount),
                                    const SizedBox(height: 12),
                                  ],
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
                                                    isSplitPayment:
                                                        match.isSplitPayment,
                                                    viewer: currentUser,
                                                    isFriend: friendUids
                                                        .contains(participant.userId),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _CommentsSection(
                            matchId: match.id,
                            currentUser: currentUser,
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
                          : 'No payment in the app — you pay the organiser '
                                '${CurrencyHelpers.formatGBP(match.pricePerPlayer)} '
                                'for your share directly.',
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
                      label: 'Join match',
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

  Future<void> _openShareSheet(
    BuildContext context,
    FootballMatch match,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MatchShareSheet(
        match: match,
        currentUser: currentUser,
      ),
    );
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
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Withdraw from match?',
      message: [
        warning,
        if (match.isSplitPayment && participant.amountPaid > 0)
          'Refund handling will be added when real payments are enabled.',
      ].join('\n\n'),
      confirmLabel: 'Withdraw',
      confirmIcon: Icons.logout,
      cancelLabel: 'Stay in',
      isDestructive: true,
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
    required this.isSplitPayment,
    required this.viewer,
    this.isFriend = false,
  });

  final MatchParticipant participant;
  final int lowReliabilityThreshold;
  final bool isSplitPayment;
  final AppUser viewer;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final isPaid = participant.hasConfirmedSlot &&
        (participant.amountPaid > 0 || isSplitPayment);
    final isPending = participant.isPendingPayment && isSplitPayment;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtherUserProfileScreen(
            uid: participant.userId,
            viewer: viewer,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          UserAvatar(
            fullName: participant.fullName,
            photoUrl: participant.photoUrl,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.fullName, style: AppTextStyles.body),
                Text(
                  '${participant.position} · ${participant.skillLevel}',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isFriend)
                      const _MiniBadge(
                        label: 'Friend',
                        colour: AppColours.accent,
                      ),
                    if (isSplitPayment && participant.hasConfirmedSlot)
                      _MiniBadge(
                        label: participant.amountPaid > 0 ? 'Paid' : 'Paid',
                        colour: AppColours.accent,
                      ),
                    if (isPending)
                      _MiniBadge(
                        label: participant.isPaymentOverdue
                            ? 'Overdue'
                            : 'Not paid',
                        colour: participant.isPaymentOverdue
                            ? AppColours.error
                            : AppColours.warning,
                      ),
                    if (participant.isPendingApproval)
                      const _MiniBadge(
                        label: 'Pending approval',
                        colour: AppColours.mutedText,
                      ),
                    if (!isSplitPayment && participant.hasConfirmedSlot)
                      const _MiniBadge(label: 'Confirmed'),
                    if (participant.reliabilityScoreAtJoin <
                        lowReliabilityThreshold)
                      const _MiniBadge(
                        label: 'Low rel.',
                        colour: AppColours.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isPaid
                ? Icons.check_circle
                : isPending
                ? Icons.radio_button_unchecked
                : Icons.hourglass_top_rounded,
            color: isPaid
                ? AppColours.accent
                : isPending
                ? AppColours.warning
                : AppColours.mutedText,
            size: 18,
          ),
        ],
      ),
    ),  // close Padding
    );  // close InkWell
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
        ? 'Manage'
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

    final totalWithFee = CurrencyHelpers.roundMoney(
      match.pricePerPlayer + CurrencyHelpers.mockPlatformFee(match.pricePerPlayer),
    );
    final priceLabel = isOrganiser
        ? 'Your match'
        : CurrencyHelpers.formatGBP(
            match.isOrganiserPays ? match.pricePerPlayer : totalWithFee,
          );

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPendingPayment && (participant?.isPaymentOverdue ?? false))
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColours.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColours.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColours.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your payment deadline has passed. The organiser has been charged.',
                          style: AppTextStyles.small.copyWith(color: AppColours.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
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
        return 'Spot confirmed. Pay the organiser directly.';
      }
      return 'Paid to the organiser directly — nothing due in the app.';
    }

    final fee = CurrencyHelpers.mockPlatformFee(match.pricePerPlayer);
    if (participant?.hasConfirmedSlot == true) return 'Payment confirmed';
    if (isPendingPayment) {
      final deadline = participant?.paymentDeadline;
      final isOverdue = participant?.isPaymentOverdue ?? false;
      if (isOverdue) {
        return 'Deadline passed — organiser covering your share.';
      }
      if (deadline != null) {
        final timeLeft = deadline.difference(DateTime.now());
        final hours = timeLeft.inHours;
        final mins = timeLeft.inMinutes.remainder(60);
        return 'Pay within ${hours}h ${mins}m to secure your spot.';
      }
      return 'Pay within 24h to lock in your spot.';
    }
    if (participant?.isPendingApproval == true) {
      return 'Organiser approval needed before payment.';
    }
    return 'Includes ${CurrencyHelpers.formatGBP(fee)} service fee. '
        'Pay within 24h of joining.';
  }
}

class _CommentsSection extends StatefulWidget {
  const _CommentsSection({
    required this.matchId,
    required this.currentUser,
  });

  final String matchId;
  final AppUser currentUser;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    final viewModel = context.read<MatchViewModel>();
    final ok = await viewModel.addComment(
      matchId: widget.matchId,
      author: widget.currentUser,
      body: body,
    );
    if (!mounted) return;
    if (ok) {
      _bodyController.clear();
      FocusScope.of(context).unfocus();
    } else if (viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MatchViewModel>();

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
          Text('Match chat', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          StreamBuilder<List<MatchComment>>(
            stream: viewModel.commentsStream(widget.matchId),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No comments yet. Be the first to chime in.',
                    style: AppTextStyles.bodyMuted,
                  ),
                );
              }
              return Column(
                children: comments
                    .map(
                      (c) => _CommentTile(
                        comment: c,
                        canDelete: c.authorUid == widget.currentUser.uid,
                        onDelete: () => viewModel.deleteComment(
                          matchId: widget.matchId,
                          commentId: c.id,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment…',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: viewModel.isLoading ? null : _post,
                style: IconButton.styleFrom(
                  backgroundColor: AppColours.accent,
                  foregroundColor: const Color(0xFF071014),
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final MatchComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            fullName: comment.authorName,
            photoUrl: comment.authorPhotoUrl,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _ago(comment.createdAt),
                      style: AppTextStyles.small.copyWith(fontSize: 11),
                    ),
                    if (canDelete) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(99),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: AppColours.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}

class _FriendsInMatchBanner extends StatelessWidget {
  const _FriendsInMatchBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColours.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: AppColours.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 of your friends is in this match'
                  : '$count of your friends are in this match',
              style: AppTextStyles.small.copyWith(
                color: AppColours.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColours.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined, color: AppColours.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match cancelled',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColours.error,
                  ),
                ),
                if ((match.cancelReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    match.cancelReason!,
                    style: AppTextStyles.small,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchShareSheet extends StatelessWidget {
  const _MatchShareSheet({required this.match, required this.currentUser});

  final FootballMatch match;
  final AppUser currentUser;

  String get _shareText => _shareTextFor(match);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColours.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Text('Share this match', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Send to a friend in a chat, or copy the details to paste anywhere.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _shareText),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Match details copied to clipboard.'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Copy details'),
              ),
              const SizedBox(height: 14),
              Text(
                'Send to a friend',
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColours.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: StreamBuilder<List<Friend>>(
                  stream: context
                      .read<FriendsViewModel>()
                      .friendsStream(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColours.accent,
                          ),
                        ),
                      );
                    }
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Add friends to share matches with them in a chat.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return InkWell(
                          onTap: () async {
                            await _sendToFriend(context, friend);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColours.card,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColours.line),
                            ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  fullName: friend.fullName,
                                  photoUrl: friend.photoUrl,
                                  radius: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    friend.fullName,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.send_outlined,
                                  color: AppColours.accent,
                                  size: 18,
                                ),
                              ],
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
      ),
    );
  }

  Future<void> _sendToFriend(BuildContext context, Friend friend) async {
    final chatViewModel = context.read<ChatViewModel>();
    final friendsViewModel = context.read<FriendsViewModel>();

    final friendUser = await friendsViewModel.getUserById(friend.uid);
    if (friendUser == null || !context.mounted) return;
    final chatId = await chatViewModel.openChatWith(
      me: currentUser,
      other: friendUser,
    );
    if (chatId == null || !context.mounted) return;
    await chatViewModel.sendMessage(
      chatId: chatId,
      sender: currentUser,
      body: _shareText,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sent to ${friend.fullName}.')),
    );
  }
}
