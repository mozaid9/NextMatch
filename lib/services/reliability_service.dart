/// Pure helpers for reliability scoring. The penalty/reward *constants* and
/// timing tiers are mirrored authoritatively in functions/index.js, which is
/// the only thing that actually writes scores — keep the two in sync. This
/// class now exists purely for client-side display and the withdrawal warning.
class ReliabilityService {
  const ReliabilityService();

  static const int attendMatchScoreChange = 1;
  static const int earlyCancellationPenalty = -1;
  static const int mediumCancellationPenalty = -3;
  static const int lateCancellationPenalty = -8;
  static const int noShowPenalty = -15;

  static int calculateWithdrawalPenalty(
    DateTime startDateTime,
    DateTime withdrawalTime,
  ) {
    final hoursUntilKickOff =
        startDateTime.difference(withdrawalTime).inMinutes / 60;
    if (hoursUntilKickOff > 24) return earlyCancellationPenalty;
    if (hoursUntilKickOff >= 6) return mediumCancellationPenalty;
    return lateCancellationPenalty;
  }

  static String withdrawalWarning(DateTime startDateTime, DateTime now) {
    final hoursUntilKickOff = startDateTime.difference(now).inHours;
    if (hoursUntilKickOff > 24) {
      return 'This should not affect your reliability much.';
    }
    if (hoursUntilKickOff >= 6) {
      return 'This may reduce your reliability.';
    }
    return 'This is a late withdrawal and will reduce your reliability.';
  }

  static String getReliabilityLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Risky';
    return 'Low';
  }

  static bool isLowReliability(int score, int threshold) => score < threshold;

  static int applyScoreChange(int currentScore, int scoreChange) {
    return (currentScore + scoreChange).clamp(0, 100).toInt();
  }
}
