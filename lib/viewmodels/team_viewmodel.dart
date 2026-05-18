import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/team.dart';
import '../services/team_service.dart';

class TeamViewModel extends ChangeNotifier {
  TeamViewModel(this._teamService);

  final TeamService _teamService;

  bool isLoading = false;
  String? errorMessage;

  Stream<List<Team>> myTeamsStream(String uid) =>
      _teamService.myTeamsStream(uid);

  Stream<Team?> teamStream(String teamId) =>
      _teamService.teamStream(teamId);

  Stream<List<ChatMessage>> messagesStream(String teamId) =>
      _teamService.messagesStream(teamId);

  Future<Team?> createTeam({
    required AppUser creator,
    required String name,
    required String description,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _teamService.createTeam(
        creator: creator,
        name: name,
        description: description,
      );
    } catch (error) {
      errorMessage = 'Could not create team.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMembers({
    required String teamId,
    required List<AppUser> users,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _teamService.addMembers(teamId: teamId, users: users);
      return true;
    } catch (error) {
      errorMessage = 'Could not add members.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> leaveTeam({
    required String teamId,
    required String uid,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _teamService.leaveTeam(teamId: teamId, uid: uid);
      return true;
    } catch (error) {
      errorMessage = 'Could not leave team.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String teamId,
    required AppUser sender,
    required String body,
  }) async {
    try {
      await _teamService.sendMessage(
        teamId: teamId,
        sender: sender,
        body: body,
      );
    } catch (error) {
      errorMessage = 'Could not send message.';
      notifyListeners();
    }
  }
}
