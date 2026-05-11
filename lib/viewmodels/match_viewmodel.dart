import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/football_match.dart';
import '../models/match_participant.dart';
import '../services/match_service.dart';

class MatchViewModel extends ChangeNotifier {
  MatchViewModel(this._matchService);

  final MatchService _matchService;

  bool isLoading = false;
  String? errorMessage;

  Stream<List<FootballMatch>> openMatchesStream() =>
      _matchService.openMatchesStream();

  Stream<FootballMatch?> matchStream(String matchId) =>
      _matchService.matchStream(matchId);

  Stream<List<MatchParticipant>> participantsStream(String matchId) =>
      _matchService.participantsStream(matchId);

  Stream<List<Map<String, dynamic>>> joinedMatchSummariesStream(String uid) =>
      _matchService.joinedMatchSummariesStream(uid);

  Stream<List<FootballMatch>> organisedMatchesStream(String uid) =>
      _matchService.organisedMatchesStream(uid);

  Future<FootballMatch?> getMatch(String matchId) =>
      _matchService.getMatch(matchId);

  Future<bool> createMatch(FootballMatch match) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _matchService.createMatch(match);
      return true;
    } catch (error) {
      errorMessage = 'Could not create this match. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> seedDemoMatches(AppUser organiser) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _matchService.seedDemoMatches(organiser);
      return true;
    } catch (error) {
      errorMessage = 'Could not add demo matches.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
