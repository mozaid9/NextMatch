import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../services/notification_service.dart';
import '../../services/user_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

enum _HandleStatus { idle, current, checking, available, taken, invalid }

/// Account management: unique @username, display name, notification
/// preference, sign out and delete account. Reached from Settings.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;

  late bool _notificationsEnabled;
  bool _savingProfile = false;
  bool _deleting = false;

  _HandleStatus _handleStatus = _HandleStatus.current;
  String _handleMessage = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _displayNameController = TextEditingController(text: widget.user.fullName);
    _notificationsEnabled = widget.user.notificationsEnabled;
    _handleStatus = widget.user.hasUsername
        ? _HandleStatus.current
        : _HandleStatus.idle;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // ---- Username availability ------------------------------------------------

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();
    final handle = UserService.canonicalUsername(raw);

    if (handle == widget.user.username && handle.isNotEmpty) {
      setState(() {
        _handleStatus = _HandleStatus.current;
        _handleMessage = 'Your current username';
      });
      return;
    }
    if (handle.isEmpty) {
      setState(() => _handleStatus = _HandleStatus.idle);
      return;
    }
    final invalid = UserService.validateUsername(handle);
    if (invalid != null) {
      setState(() {
        _handleStatus = _HandleStatus.invalid;
        _handleMessage = invalid;
      });
      return;
    }
    setState(() {
      _handleStatus = _HandleStatus.checking;
      _handleMessage = 'Checking availability…';
    });
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      bool? available;
      try {
        available = await context
            .read<ProfileViewModel>()
            .isUsernameAvailable(handle, uid: widget.user.uid);
      } catch (_) {
        available = null; // Lookup failed — let the save attempt surface why.
      }
      // Ignore stale results if the field moved on while we were waiting.
      if (!mounted ||
          UserService.canonicalUsername(_usernameController.text) != handle) {
        return;
      }
      setState(() {
        if (available == null) {
          _handleStatus = _HandleStatus.idle;
          _handleMessage = '';
        } else if (available) {
          _handleStatus = _HandleStatus.available;
          _handleMessage = '@$handle is available';
        } else {
          _handleStatus = _HandleStatus.taken;
          _handleMessage = '@$handle is taken';
        }
      });
    });
  }

  Color get _handleColour => switch (_handleStatus) {
    _HandleStatus.available => AppColours.success,
    _HandleStatus.taken || _HandleStatus.invalid => AppColours.error,
    _ => AppColours.mutedText,
  };

  // ---- Save -----------------------------------------------------------------

  Future<void> _save() async {
    final profile = context.read<ProfileViewModel>();
    final uid = widget.user.uid;
    final newName = _displayNameController.text.trim();
    final newHandle = UserService.canonicalUsername(_usernameController.text);
    final usernameChanged =
        newHandle.isNotEmpty && newHandle != widget.user.username;
    final nameChanged = newName != widget.user.fullName;

    if (newName.isEmpty) {
      _snack('Display name is required.');
      return;
    }
    if (_handleStatus == _HandleStatus.taken ||
        _handleStatus == _HandleStatus.invalid) {
      _snack(_handleMessage);
      return;
    }
    if (!usernameChanged && !nameChanged) {
      _snack('Nothing to save.');
      return;
    }

    setState(() => _savingProfile = true);
    var ok = true;
    if (usernameChanged) {
      ok = await profile.claimUsername(uid: uid, raw: newHandle);
    }
    if (ok && nameChanged) {
      ok = await profile.saveProfile(
        widget.user.copyWith(fullName: newName, updatedAt: DateTime.now()),
      );
    }
    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (ok) {
      _snack('Account updated.');
      Navigator.of(context).pop();
    } else {
      _snack(profile.errorMessage ?? 'Could not save. Please try again.');
    }
  }

  // ---- Notifications --------------------------------------------------------

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final profile = context.read<ProfileViewModel>();
    final notifications = context.read<NotificationService>();

    final ok = await profile.setNotificationsEnabled(widget.user.uid, value);
    if (value) {
      await notifications.initialise(widget.user.uid);
    } else {
      await notifications.unregister();
    }
    if (!ok && mounted) {
      setState(() => _notificationsEnabled = !value);
      _snack(profile.errorMessage ?? 'Could not update notifications.');
    }
  }

  // ---- Sign out -------------------------------------------------------------

  Future<void> _signOut() async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Sign out?',
      message: 'You can log back in with the same account any time.',
      confirmLabel: 'Sign out',
      confirmIcon: Icons.logout,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    await context.read<NotificationService>().unregister();
    if (!mounted) return;
    await context.read<AuthViewModel>().signOut();
  }

  // ---- Delete account -------------------------------------------------------

  Future<void> _deleteAccount() async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Delete account?',
      message:
          'This permanently deletes your sign-in and personal details, and '
          'frees your @username. Matches you organised stay live with the '
          'organiser shown as "Deleted user". This cannot be undone.',
      confirmLabel: 'Delete account',
      confirmIcon: Icons.delete_forever,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthViewModel>();
    final profile = context.read<ProfileViewModel>();
    final notifications = context.read<NotificationService>();
    final providerId = auth.primaryProviderId;

    // 1. Re-authenticate (Firebase requires a fresh credential to delete).
    bool reauthed;
    if (providerId == 'password') {
      final password = await _promptPassword();
      if (password == null || !mounted) return; // cancelled
      reauthed = await auth.reauthenticateWithPassword(password);
    } else {
      reauthed = await auth.reauthenticateWithProvider(providerId);
    }
    if (!reauthed) {
      if (mounted) _snack(auth.errorMessage ?? 'Re-authentication failed.');
      return;
    }

    setState(() => _deleting = true);

    // 2. Free the handle, scrub the profile, relabel organised matches, and
    //    drop this device's push tokens — all while still authenticated.
    await notifications.unregister();
    final cleaned = await profile.anonymiseAndReleaseAccount(widget.user.uid);
    if (!cleaned) {
      if (mounted) {
        setState(() => _deleting = false);
        _snack(profile.errorMessage ?? 'Could not delete your data.');
      }
      return;
    }

    // 3. Delete the auth user. authStateChanges then routes to WelcomeScreen.
    final deleted = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (!deleted) {
      _snack(auth.errorMessage ?? 'Could not delete your account.');
    }
  }

  Future<String?> _promptPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColours.card,
          title: const Text('Confirm your password'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              style: TextButton.styleFrom(foregroundColor: AppColours.error),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _savingProfile || _deleting;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader('Identity'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'e.g. zaid_10',
                  icon: Icons.alternate_email,
                  onChanged: _onUsernameChanged,
                ),
                if (_handleStatus != _HandleStatus.idle) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (_handleStatus == _HandleStatus.checking)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_handleStatus == _HandleStatus.available)
                        Icon(Icons.check_circle,
                            size: 14, color: AppColours.success),
                      if (_handleStatus == _HandleStatus.taken ||
                          _handleStatus == _HandleStatus.invalid)
                        Icon(Icons.error_outline,
                            size: 14, color: AppColours.error),
                      if (_handleStatus != _HandleStatus.idle)
                        const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _handleMessage,
                          style: AppTextStyles.small.copyWith(
                            color: _handleColour,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _displayNameController,
                  label: 'Display name',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                _ReadOnlyRow(label: 'Email', value: widget.user.email),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Save changes',
                  icon: Icons.check,
                  isLoading: _savingProfile,
                  onPressed: busy ? null : _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Notifications'),
          _Card(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: _notificationsEnabled,
              onChanged: busy ? null : _toggleNotifications,
              title: const Text('Push notifications'),
              subtitle: Text(
                'Match invites, chat messages and updates.',
                style: AppTextStyles.bodyMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Account'),
          OutlinedButton.icon(
            onPressed: busy ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : _deleteAccount,
            icon: _deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            label: const Text('Delete account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColours.error,
              side: const BorderSide(color: AppColours.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
        Flexible(
          child: Text(
            value.isEmpty ? '—' : value,
            style: AppTextStyles.body,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.small.copyWith(
          color: AppColours.mutedText,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: child,
    );
  }
}
