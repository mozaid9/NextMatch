import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../services/friends_service.dart';
import '../../services/reliability_service.dart';
import '../../models/team.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../viewmodels/team_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';
import 'create_match_screen.dart';

class OrganiserMatchDashboardScreen extends StatelessWidget {
  const OrganiserMatchDashboardScreen({
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
      appBar: AppBar(title: const Text('Organiser dashboard')),
      body: StreamBuilder<FootballMatch?>(
        stream: matchViewModel.matchStream(matchId),
        builder: (context, matchSnapshot) {
          final match = matchSnapshot.data;
          if (match == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.assignment_late_outlined,
                title: 'Match not found',
                message: 'This organiser dashboard is no longer available.',
              ),
            );
          }

          final isOrganiser = match.organiserId == currentUser.uid;
          if (!isOrganiser) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Organiser only',
                message: 'Only the match organiser can manage this game.',
              ),
            );
          }

          return StreamBuilder<List<MatchParticipant>>(
            stream: matchViewModel.participantsStream(match.id),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              final pending = participants
                  .where((participant) => participant.isPendingApproval)
                  .toList();
              final pendingPayment = participants
                  .where((participant) => participant.isPendingPayment)
                  .toList();
              final confirmed = participants
                  .where((participant) => participant.hasConfirmedSlot)
                  .toList();
              final canComplete =
                  match.hasStarted &&
                  confirmed.isNotEmpty &&
                  !match.isCompleted &&
                  !match.isCancelled;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                children: [
                  _SummaryCard(match: match),
                  const SizedBox(height: 16),
                  _GuaranteeBanner(match: match, pendingPayment: pendingPayment),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Pending approvals',
                    child: pending.isEmpty
                        ? Text(
                            'No approval requests right now.',
                            style: AppTextStyles.bodyMuted,
                          )
                        : Column(
                            children: pending
                                .map(
                                  (participant) => _ApprovalTile(
                                    match: match,
                                    participant: participant,
                                    viewer: currentUser,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Pending payment',
                    child: pendingPayment.isEmpty
                        ? Text(
                            'No players waiting to pay.',
                            style: AppTextStyles.bodyMuted,
                          )
                        : Column(
                            children: pendingPayment
                                .map(
                                  (participant) => _PaymentPendingTile(
                                    match: match,
                                    participant: participant,
                                    viewer: currentUser,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Confirmed players',
                    child: confirmed.isEmpty
                        ? Text(
                            'No confirmed players yet.',
                            style: AppTextStyles.bodyMuted,
                          )
                        : Column(
                            children: confirmed
                                .map(
                                  (participant) => _ConfirmedTile(
                                    match: match,
                                    participant: participant,
                                    viewer: currentUser,
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Match controls',
                    child: Column(
                      children: [
                        if (!match.isCompleted && !match.isCancelled) ...[
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openInviteFriendsSheet(context, match),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Invite friends'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (match.isCompleted) ...[
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CreateMatchScreen(
                                  currentUser: currentUser,
                                  template: match,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.replay_outlined),
                            label: const Text('Run it back'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        PrimaryButton(
                          label: _completeButtonLabel(match, confirmed.length),
                          icon: Icons.flag_circle_outlined,
                          isLoading: matchViewModel.isLoading,
                          onPressed: canComplete
                              ? () => _confirmComplete(context, match)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: (match.isCompleted || match.isCancelled)
                              ? null
                              : () => _confirmCancel(context, match),
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            match.isCancelled
                                ? 'Match cancelled'
                                : 'Cancel match',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColours.error,
                            side: const BorderSide(color: AppColours.error),
                          ),
                        ),
                        if (match.isCancelled &&
                            (match.cancelReason ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Reason: ${match.cancelReason}',
                              style: AppTextStyles.small,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Cancelling notifies joined players. Anyone who has already paid will need to be refunded.',
                              style: AppTextStyles.small,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _completeButtonLabel(FootballMatch match, int confirmedCount) {
    if (match.isCompleted) return 'Match completed';
    if (match.isCancelled) return 'Match cancelled';
    if (!match.hasStarted) return 'Complete after kick-off';
    if (confirmedCount == 0) return 'Add players first';
    return 'Complete match';
  }

  Future<void> _confirmComplete(
    BuildContext context,
    FootballMatch match,
  ) async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Complete match?',
      message:
          'Confirmed players not already marked as no-show or withdrawn will be marked as attended and receive +1 reliability.',
      confirmLabel: 'Complete',
      confirmIcon: Icons.flag_circle_outlined,
      cancelLabel: 'Not yet',
    );

    if (!context.mounted || confirmed != true) return;
    final viewModel = context.read<MatchViewModel>();
    final success = await viewModel.completeMatch(match.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Match completed. Attended players can now rate each other.'
              : viewModel.errorMessage ?? 'Could not complete match.',
        ),
      ),
    );
  }

  Future<void> _openInviteFriendsSheet(
    BuildContext context,
    FootballMatch match,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _InviteFriendsSheet(
        match: match,
        currentUser: currentUser,
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    FootballMatch match,
  ) async {
    final reason = await showAppInputSheet(
      context: context,
      title: 'Cancel match?',
      message:
          'Joined players will see this match as cancelled. Anyone who has already paid will need to be refunded.',
      label: 'Reason (shown to players)',
      hint: 'e.g. Pitch unavailable, not enough players',
      confirmLabel: 'Cancel match',
      confirmIcon: Icons.cancel_outlined,
      isDestructive: true,
      validator: (value) =>
          value.isEmpty ? 'Add a short reason.' : null,
    );

    if (!context.mounted || reason == null || reason.isEmpty) return;
    final viewModel = context.read<MatchViewModel>();
    final success = await viewModel.cancelMatch(
      matchId: match.id,
      reason: reason,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Match cancelled. Joined players will see the reason.'
              : viewModel.errorMessage ?? 'Could not cancel match.',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(match.title, style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(match.locationName, style: AppTextStyles.bodyMuted),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                label: DateTimeHelpers.formatMatchDateTime(match.startDateTime),
              ),
              _Badge(label: match.status),
              _Badge(label: '${match.spacesLabel} filled'),
              _Badge(label: 'Min ${match.minimumReliabilityRequired} rel.'),
            ],
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
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.match,
    required this.participant,
    required this.viewer,
  });

  final FootballMatch match;
  final MatchParticipant participant;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MatchViewModel>();
    final approvedPendingPayment =
        participant.organiserApproved && match.isSplitPayment;

    return _PlayerPanel(
      participant: participant,
      threshold: match.minimumReliabilityRequired,
      viewer: viewer,
      trailing: approvedPendingPayment
          ? const _Badge(label: 'Payment needed', colour: AppColours.warning)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Approve',
                  onPressed: viewModel.isLoading
                      ? null
                      : () => viewModel.approveParticipant(
                          matchId: match.id,
                          userId: participant.userId,
                        ),
                  icon: const Icon(Icons.check_circle_outline),
                ),
                IconButton(
                  tooltip: 'Reject',
                  onPressed: viewModel.isLoading
                      ? null
                      : () => viewModel.rejectParticipant(
                          matchId: match.id,
                          userId: participant.userId,
                        ),
                  icon: const Icon(Icons.cancel_outlined),
                ),
              ],
            ),
    );
  }
}

class _PaymentPendingTile extends StatelessWidget {
  const _PaymentPendingTile({
    required this.match,
    required this.participant,
    required this.viewer,
  });

  final FootballMatch match;
  final MatchParticipant participant;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final deadline = participant.paymentDeadline;
    final isOverdue = participant.isPaymentOverdue;
    final timeLeft = participant.timeUntilDeadline;

    String deadlineLabel;
    Color deadlineColor;
    if (deadline == null) {
      deadlineLabel = 'Pay by: —';
      deadlineColor = AppColours.mutedText;
    } else if (isOverdue) {
      deadlineLabel = 'Overdue — organiser liable';
      deadlineColor = AppColours.error;
    } else if (timeLeft != null && timeLeft.inHours < 6) {
      deadlineLabel = 'Pay in ${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}m';
      deadlineColor = AppColours.warning;
    } else {
      final h = timeLeft?.inHours ?? 24;
      deadlineLabel = 'Pay within ${h}h';
      deadlineColor = AppColours.mutedText;
    }

    return _PlayerPanel(
      participant: participant,
      threshold: match.minimumReliabilityRequired,
      viewer: viewer,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Badge(
            label: isOverdue ? 'Overdue' : 'Not secured',
            colour: isOverdue ? AppColours.error : AppColours.warning,
          ),
          const SizedBox(height: 4),
          Text(
            deadlineLabel,
            style: TextStyle(fontSize: 10, color: deadlineColor),
          ),
        ],
      ),
    );
  }
}

class _GuaranteeBanner extends StatelessWidget {
  const _GuaranteeBanner({
    required this.match,
    required this.pendingPayment,
  });

  final FootballMatch match;
  final List<MatchParticipant> pendingPayment;

  @override
  Widget build(BuildContext context) {
    if (!match.isSplitPayment || pendingPayment.isEmpty) {
      return const SizedBox.shrink();
    }

    final overdueCount = pendingPayment.where((p) => p.isPaymentOverdue).length;
    final pendingCount = pendingPayment.length - overdueCount;
    final liabilityAmount = match.pricePerPlayer * pendingPayment.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: overdueCount > 0
            ? AppColours.error.withValues(alpha: 0.08)
            : AppColours.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: overdueCount > 0
              ? AppColours.error.withValues(alpha: 0.4)
              : AppColours.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            overdueCount > 0 ? Icons.warning_amber_rounded : Icons.shield_outlined,
            color: overdueCount > 0 ? AppColours.error : AppColours.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overdueCount > 0
                      ? 'You are liable for £${liabilityAmount.toStringAsFixed(2)}'
                      : 'Payment guarantee active',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: overdueCount > 0 ? AppColours.error : AppColours.warning,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  overdueCount > 0
                      ? '$overdueCount player${overdueCount > 1 ? "s" : ""} overdue — their share is on you.'
                      : '$pendingCount player${pendingCount > 1 ? "s" : ""} have 24h to pay. If they don\'t, you cover their share.',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedTile extends StatelessWidget {
  const _ConfirmedTile({
    required this.match,
    required this.participant,
    required this.viewer,
  });

  final FootballMatch match;
  final MatchParticipant participant;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MatchViewModel>();

    return _PlayerPanel(
      participant: participant,
      viewer: viewer,
      threshold: match.minimumReliabilityRequired,
      trailing: IconButton(
        tooltip: 'Attendance',
        onPressed: () => _openAttendanceSheet(context, viewModel),
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  Future<void> _openAttendanceSheet(
    BuildContext context,
    MatchViewModel viewModel,
  ) async {
    final value = await showSelectionSheet(
      context: context,
      title: 'Attendance',
      selectedValue: participant.attendanceStatus,
      options: const ['Attended', 'NoShow'],
    );

    if (value == 'Attended') {
      await viewModel.markParticipantAttended(
        matchId: match.id,
        userId: participant.userId,
      );
    }
    if (value == 'NoShow') {
      await viewModel.markParticipantNoShow(
        matchId: match.id,
        userId: participant.userId,
      );
    }
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.participant,
    required this.threshold,
    required this.trailing,
    required this.viewer,
  });

  final MatchParticipant participant;
  final int threshold;
  final Widget trailing;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final lowReliability = participant.reliabilityScoreAtJoin < threshold;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColours.cardAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: lowReliability ? AppColours.warning : AppColours.line,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OtherUserProfileScreen(
                      uid: participant.userId,
                      viewer: viewer,
                    ),
              ),
            ),
            child: UserAvatar(
              fullName: participant.fullName,
              photoUrl: participant.photoUrl,
              radius: 20,
              backgroundColor: AppColours.surface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.fullName, style: AppTextStyles.body),
                const SizedBox(height: 3),
                Text(
                  '${participant.position} · ${participant.skillLevel}',
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Badge(
                      label:
                          'Rel ${participant.reliabilityScoreAtJoin} ${ReliabilityService.getReliabilityLabel(participant.reliabilityScoreAtJoin)}',
                      colour: lowReliability
                          ? AppColours.warning
                          : AppColours.accent,
                    ),
                    _Badge(
                      label:
                          'Ability ${participant.abilityRatingAtJoin.toStringAsFixed(1)}',
                    ),
                    _Badge(
                      label: _paymentLabel(participant),
                      colour: _paymentColour(participant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  String _paymentLabel(MatchParticipant p) {
    if (p.hasConfirmedSlot) return 'Paid';
    if (p.isPaymentOverdue) return 'Overdue';
    if (p.isPendingPayment) return 'Not paid';
    if (p.isPendingApproval) return 'Pending approval';
    return p.attendanceStatus;
  }

  Color _paymentColour(MatchParticipant p) {
    if (p.hasConfirmedSlot) return AppColours.accent;
    if (p.isPaymentOverdue) return AppColours.error;
    if (p.isPendingPayment) return AppColours.warning;
    return AppColours.mutedText;
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.colour = AppColours.accent});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppColours.card,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColours.line),
  );
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({required this.match, required this.currentUser});

  final FootballMatch match;
  final AppUser currentUser;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();
    final matchViewModel = context.watch<MatchViewModel>();
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
              Text('Invite to match', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Tap a team to invite the whole squad, or pick friends individually.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Team>>(
                stream: context
                    .read<TeamViewModel>()
                    .myTeamsStream(widget.currentUser.uid),
                builder: (context, snapshot) {
                  final teams = snapshot.data ?? [];
                  if (teams.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your teams',
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColours.mutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: teams.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final team = teams[index];
                            final teamMemberIds = team.memberIds
                                .where((id) => id != widget.currentUser.uid)
                                .toSet();
                            final allSelected = teamMemberIds.isNotEmpty &&
                                teamMemberIds.every(_selected.contains);
                            return _TeamInviteChip(
                              team: team,
                              allSelected: allSelected,
                              onTap: () {
                                setState(() {
                                  if (allSelected) {
                                    _selected.removeAll(teamMemberIds);
                                  } else {
                                    _selected.addAll(teamMemberIds);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Friends',
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColours.mutedText,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              Flexible(
                child: StreamBuilder<List<Friend>>(
                  stream:
                      friendsViewModel.friendsStream(widget.currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
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
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "You haven't added any friends yet. Add some on the Profile screen.",
                          style: AppTextStyles.bodyMuted,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selected.contains(friend.uid);
                        return InkWell(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(friend.uid);
                            } else {
                              _selected.add(friend.uid);
                            }
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColours.accent.withValues(alpha: 0.08)
                                  : AppColours.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColours.accent
                                    : AppColours.line,
                                width: isSelected ? 1.5 : 1,
                              ),
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.fullName,
                                        style: AppTextStyles.body.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${friend.position} · ${friend.skillLevel}',
                                        style: AppTextStyles.small,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: isSelected
                                      ? AppColours.accent
                                      : AppColours.mutedText,
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
              const SizedBox(height: 14),
              PrimaryButton(
                label: _selected.isEmpty
                    ? 'Pick someone'
                    : 'Send ${_selected.length} invite${_selected.length == 1 ? "" : "s"}',
                icon: Icons.send_outlined,
                isLoading: matchViewModel.isLoading,
                onPressed: _selected.isEmpty
                    ? null
                    : () async {
                        final viewModel = context.read<MatchViewModel>();
                        final ok = await viewModel.inviteFriendsToMatch(
                          match: widget.match,
                          inviterUid: widget.currentUser.uid,
                          inviterName: widget.currentUser.fullName,
                          friendUids: _selected.toList(),
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Invites sent.'
                                  : viewModel.errorMessage ??
                                      'Could not send invites.',
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamInviteChip extends StatelessWidget {
  const _TeamInviteChip({
    required this.team,
    required this.allSelected,
    required this.onTap,
  });

  final Team team;
  final bool allSelected;
  final VoidCallback onTap;

  Color _teamColour() {
    final hex = team.colour.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final colour = _teamColour();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: allSelected
              ? colour.withValues(alpha: 0.18)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: allSelected ? colour : AppColours.line,
            width: allSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allSelected ? Icons.shield : Icons.shield_outlined,
              size: 14,
              color: colour,
            ),
            const SizedBox(width: 6),
            Text(
              team.name,
              style: AppTextStyles.small.copyWith(
                color: allSelected ? colour : AppColours.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '· ${team.memberIds.length - 1}',
              style: AppTextStyles.small.copyWith(
                color: AppColours.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
