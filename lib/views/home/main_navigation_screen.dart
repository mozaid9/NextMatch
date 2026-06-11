import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/app_user.dart';
import '../../services/notification_service.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../models/chat.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../matches/browse_matches_screen.dart';
import '../matches/create_match_screen.dart';
import '../matches/match_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../social/community_screen.dart';
import 'home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  StreamSubscription<dynamic>? _foregroundMessages;

  /// Stripe Checkout redirects back to the app with ?checkout=... in the
  /// URL. Static so a hot restart in the same page load doesn't replay it.
  static bool _checkoutReturnHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleCheckoutReturn();
      final notifications = context.read<NotificationService>();
      notifications.initialise(widget.currentUser.uid);
      // Pushes arriving while the app is open surface as a snackbar
      // instead of a system notification.
      _foregroundMessages = notifications.foregroundMessages.listen((message) {
        final title = message.notification?.title;
        final body = message.notification?.body;
        final text = [
          if (title != null && title.isNotEmpty) title,
          if (body != null && body.isNotEmpty) body,
        ].join(' — ');
        if (text.isEmpty || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(text)),
        );
      });
    });
  }

  @override
  void dispose() {
    _foregroundMessages?.cancel();
    super.dispose();
  }

  void _handleCheckoutReturn() {
    if (!kIsWeb || _checkoutReturnHandled) return;
    final params = Uri.base.queryParameters;
    final result = params['checkout'];
    if (result == null) return;
    _checkoutReturnHandled = true;

    final matchId = params['matchId'] ?? '';
    if (result == 'success' && matchId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment received — confirming your spot now.'),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MatchDetailScreen(
            matchId: matchId,
            currentUser: widget.currentUser,
          ),
        ),
      );
    } else if (result == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout cancelled — your spot is not reserved.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        currentUser: widget.currentUser,
        // Create now opens as a pushed route so the bottom nav can
        // stay dedicated to ongoing destinations.
        onCreateMatch: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CreateMatchScreen(currentUser: widget.currentUser),
          ),
        ),
        onBrowseMatches: () => setState(() => _currentIndex = 1),
        onOpenCommunity: () => setState(() => _currentIndex = 2),
        onOpenProfile: () => setState(() => _currentIndex = 3),
      ),
      BrowseMatchesScreen(currentUser: widget.currentUser),
      CommunityScreen(currentUser: widget.currentUser),
      ProfileScreen(currentUser: widget.currentUser),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context
            .read<MatchViewModel>()
            .matchInvitesStream(widget.currentUser.uid),
        builder: (context, inviteSnap) {
          final inviteCount = inviteSnap.data?.length ?? 0;
          return StreamBuilder<List<Chat>>(
            stream: context
                .read<ChatViewModel>()
                .myChatsStream(widget.currentUser.uid),
            builder: (context, chatsSnap) {
              final unread = (chatsSnap.data ?? [])
                  .where((c) => c.hasUnreadFor(widget.currentUser.uid))
                  .length;
              return _NextMatchTabBar(
                currentIndex: _currentIndex,
                badgeCounts: {
                  0: inviteCount, // Home: pending match invites
                  2: unread, // Community: unread chats
                },
                onSelected: (index) =>
                    setState(() => _currentIndex = index),
              );
            },
          );
        },
      ),
    );
  }
}

class _NextMatchTabBar extends StatelessWidget {
  const _NextMatchTabBar({
    required this.currentIndex,
    required this.onSelected,
    this.badgeCounts = const <int, int>{},
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  /// Map of tab index → badge count. A count > 0 renders a small red
  /// notification dot with the number on top-right of the tab icon.
  final Map<int, int> badgeCounts;

  static const _items = [
    _TabItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _TabItemData(
      label: 'Matches',
      icon: Icons.sports_soccer_outlined,
      selectedIcon: Icons.sports_soccer,
    ),
    _TabItemData(
      label: 'Community',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _TabItemData(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _TabButton(
                    item: _items[index],
                    selected: currentIndex == index,
                    badgeCount: badgeCounts[index] ?? 0,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _TabItemData item;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final colour = selected ? AppColours.accent : AppColours.mutedText;

    return Semantics(
      selected: selected,
      button: true,
      label: badgeCount > 0
          ? '${item.label}, $badgeCount new'
          : item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 34,
                    width: 58,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColours.accent.withValues(alpha: 0.13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: colour,
                      size: 23,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: 8,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppColours.error,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColours.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: AppTextStyles.small.copyWith(
                  color: colour,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItemData {
  const _TabItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
