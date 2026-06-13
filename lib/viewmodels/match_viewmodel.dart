import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/football_match.dart';
import '../models/match_comment.dart';
import '../models/match_participant.dart';
import '../models/waitlist_entry.dart';
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

  Future<List<Map<String, dynamic>>> getFrequentCoPlayers(String uid) =>
      _matchService.getFrequentCoPlayers(uid);

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

  /// Returns the new match id, or null on failure.
  Future<String?> createMatch(FootballMatch match) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _matchService.createMatch(match);
    } catch (error) {
      errorMessage = 'Could not create this match. Please try again.';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
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

  Stream<WaitlistEntry?> myWaitlistEntryStream(String matchId, String uid) =>
      _matchService.myWaitlistEntryStream(matchId, uid);

  Stream<List<WaitlistEntry>> waitlistStream(String matchId) =>
      _matchService.waitlistStream(matchId);

  Future<bool> joinWaitlist({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    return _runAction(
      () => _matchService.joinWaitlist(
        match: match,
        user: user,
        position: position,
      ),
      failureMessage: 'Could not join the waitlist.',
    );
  }

  Future<bool> leaveWaitlist({
    required String matchId,
    required String uid,
  }) async {
    return _runAction(
      () => _matchService.leaveWaitlist(matchId: matchId, uid: uid),
      failureMessage: 'Could not leave the waitlist.',
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

  Future<bool> cancelMatch({
    required String matchId,
    required String reason,
  }) async {
    return _runAction(
      () => _matchService.cancelMatch(matchId: matchId, reason: reason),
      failureMessage: 'Could not cancel this match.',
    );
  }

  Stream<List<Map<String, dynamic>>> matchInvitesStream(String uid) =>
      _matchService.matchInvitesStream(uid);

  Stream<List<MatchComment>> commentsStream(String matchId) =>
      _matchService.commentsStream(matchId);

  Future<bool> addComment({
    required String matchId,
    required AppUser author,
    required String body,
  }) async {
    return _runAction(
      () => _matchService.addComment(
        matchId: matchId,
        author: author,
        body: body,
      ),
      failureMessage: 'Could not post comment.',
    );
  }

  Future<bool> deleteComment({
    required String matchId,
    required String commentId,
  }) async {
    return _runAction(
      () => _matchService.deleteComment(matchId: matchId, commentId: commentId),
      failureMessage: 'Could not delete comment.',
    );
  }

  Future<bool> inviteFriendsToMatch({
    required FootballMatch match,
    required String inviterUid,
    required String inviterName,
    required List<String> friendUids,
  }) async {
    return _runAction(
      () => _matchService.inviteFriendsToMatch(
        match: match,
        inviterUid: inviterUid,
        inviterName: inviterName,
        friendUids: friendUids,
      ),
      failureMessage: 'Could not send invites.',
    );
  }

  Future<bool> dismissMatchInvite({
    required String uid,
    required String matchId,
  }) async {
    return _runAction(
      () => _matchService.dismissMatchInvite(uid: uid, matchId: matchId),
      failureMessage: 'Could not dismiss invite.',
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
