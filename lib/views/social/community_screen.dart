import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import 'chats_tab.dart';
import 'friends_screen.dart';
import 'teams_tab.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Friends'),
              Tab(text: 'Chats'),
              Tab(text: 'Teams'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FriendsTab(currentUser: currentUser),
            ChatsTab(currentUser: currentUser),
            TeamsTab(currentUser: currentUser),
          ],
        ),
      ),
    );
  }
}
