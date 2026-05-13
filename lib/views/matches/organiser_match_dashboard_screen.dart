import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../services/reliability_service.dart';
import '../../viewmodels/match_viewmodel.dart';

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
                          onPressed: null,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel match'),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Whole-match cancellation and refund automation will be added with real payments.',
                            style: AppTextStyles.small,
                          ),
                        ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColours.surface,
        title: const Text('Complete match?'),
        content: const Text(
          'Confirmed players not already marked as no-show or withdrawn will be marked as attended and receive +1 reliability.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
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
              _Badge(label: 'Min rel. ${match.minimumReliabilityRequired}'),
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
  const _ApprovalTile({required this.match, required this.participant});

  final FootballMatch match;
  final MatchParticipant participant;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MatchViewModel>();
    final approvedPendingPayment =
        participant.organiserApproved && match.isSplitPayment;

    return _PlayerPanel(
      participant: participant,
      threshold: match.minimumReliabilityRequired,
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
  const _PaymentPendingTile({required this.match, required this.participant});

  final FootballMatch match;
  final MatchParticipant participant;

  @override
  Widget build(BuildContext context) {
    return _PlayerPanel(
      participant: participant,
      threshold: match.minimumReliabilityRequired,
      trailing: const _Badge(label: 'Not secured', colour: AppColours.warning),
    );
  }
}

class _ConfirmedTile extends StatelessWidget {
  const _ConfirmedTile({required this.match, required this.participant});

  final FootballMatch match;
  final MatchParticipant participant;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MatchViewModel>();

    return _PlayerPanel(
      participant: participant,
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
  });

  final MatchParticipant participant;
  final int threshold;
  final Widget trailing;

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
          CircleAvatar(
            backgroundColor: AppColours.surface,
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
                    _Badge(label: participant.paymentStatus),
                    _Badge(label: _statusLabel(participant.attendanceStatus)),
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

  String _statusLabel(String status) {
    return switch (status) {
      'PendingPayment' => 'Pending payment',
      'PendingApproval' => 'Pending approval',
      'LateCancelled' => 'Late cancelled',
      'NoShow' => 'No-show',
      _ => status,
    };
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
