import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../viewmodels/team_viewmodel.dart';
import 'team_detail_screen.dart';

class TeamsTab extends StatelessWidget {
  const TeamsTab({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeamViewModel>();

    return StreamBuilder<List<Team>>(
      stream: viewModel.myTeamsStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColours.accent),
          );
        }
        final teams = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            if (teams.isEmpty)
              EmptyState(
                icon: Icons.shield_outlined,
                title: 'No teams yet',
                message:
                    'Create a team with your regular crew, manage your roster and chat with them all in one place.',
                action: PrimaryButton(
                  label: 'Create your first team',
                  icon: Icons.add_circle_outline,
                  onPressed: () => _openCreateTeamSheet(context),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    'Your teams · ${teams.length}',
                    style: AppTextStyles.h2,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openCreateTeamSheet(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...teams.map(
                (team) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TeamCard(
                    team: team,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TeamDetailScreen(
                          teamId: team.id,
                          currentUser: currentUser,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openCreateTeamSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CreateTeamSheet(currentUser: currentUser),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onTap});

  final Team team;
  final VoidCallback onTap;

  Color _colour() {
    final hex = team.colour.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final colour = _colour();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColours.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colour.withValues(alpha: 0.6)),
              ),
              child: Icon(Icons.shield, color: colour, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.members.length} member${team.members.length == 1 ? "" : "s"}',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColours.mutedText, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CreateTeamSheet extends StatefulWidget {
  const _CreateTeamSheet({required this.currentUser});

  final AppUser currentUser;

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final viewModel = context.read<TeamViewModel>();
    final team = await viewModel.createTeam(
      creator: widget.currentUser,
      name: _nameController.text,
      description: _descController.text,
    );
    if (!mounted) return;
    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Could not create team.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeamDetailScreen(
          teamId: team.id,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeamViewModel>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Form(
            key: _formKey,
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
                Text('Create a team', style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(
                  'Group your regular crew so you can chat and organise without retyping names every time.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _nameController,
                  label: 'Team name',
                  hint: 'e.g. Sunday Strollers',
                  icon: Icons.shield_outlined,
                  autofocus: true,
                  validator: (value) =>
                      Validators.required(value, label: 'Team name'),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _descController,
                  label: 'Description (optional)',
                  hint: 'A short tagline — vibe, level, where you play',
                  icon: Icons.notes_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Create team',
                  icon: Icons.add_circle_outline,
                  isLoading: viewModel.isLoading,
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
