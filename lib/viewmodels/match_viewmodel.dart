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

  Future<JoinRequestResult?> requestToJoinMatch({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _matchService.requestToJoinMatch(
        match: match,
        user: user,
        position: position,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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
    return _runAction(
      () => _matchService.seedDemoMatches(organiser),
      failureMessage: 'Could not add demo matches.',
    );
  }

  Future<bool> withdrawFromMatch({
    required String matchId,
    required String userId,
    String? reason,
  }) async {
    return _runAction(
      () => _matchService.withdrawFromMatch(
        matchId: matchId,
        userId: userId,
        reason: reason,
      ),
      failureMessage: 'Could not withdraw from this match.',
    );
  }

  Future<bool> approveParticipant({
    required String matchId,
    required String userId,
  }) async {
    return _runAction(
      () => _matchService.approveParticipant(matchId: matchId, userId: userId),
      failureMessage: 'Could not approve this player.',
    );
  }

  Future<bool> rejectParticipant({
    required String matchId,
    required String userId,
  }) async {
    return _runAction(
      () => _matchService.rejectParticipant(matchId: matchId, userId: userId),
      failureMessage: 'Could not reject this player.',
    );
  }

  Future<bool> markParticipantAttended({
    required String matchId,
    required String userId,
  }) async {
    return _runAction(
      () => _matchService.markParticipantAttended(
        matchId: matchId,
        userId: userId,
      ),
      failureMessage: 'Could not mark this player as attended.',
    );
  }

  Future<bool> markParticipantNoShow({
    required String matchId,
    required String userId,
  }) async {
    return _runAction(
      () =>
          _matchService.markParticipantNoShow(matchId: matchId, userId: userId),
      failureMessage: 'Could not mark this player as no-show.',
    );
  }

  Future<bool> completeMatch(String matchId) async {
    return _runAction(
      () => _matchService.completeMatch(matchId),
      failureMessage: 'Could not complete this match.',
    );
  }

  Future<bool> _runAction(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (error) {
      final raw = error.toString().replaceFirst('Exception: ', '');
      errorMessage = raw == error.toString() ? failureMessage : raw;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
