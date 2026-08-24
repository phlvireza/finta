enum SquiMoment { firstTransaction, goalReached, debtSettled }

SquiMoment? selectSquiMoment({
  required Set<SquiMoment> eligible,
  required Set<String> alreadyCelebrated,
  required String Function(SquiMoment) keyFor,
}) {
  const priority = [
    SquiMoment.goalReached,
    SquiMoment.debtSettled,
    SquiMoment.firstTransaction,
  ];
  for (final moment in priority) {
    if (eligible.contains(moment) &&
        !alreadyCelebrated.contains(keyFor(moment))) {
      return moment;
    }
  }
  return null;
}

class SquiSaveResult {
  final bool saved;
  final SquiMoment? moment;
  final String? subjectName;

  const SquiSaveResult({required this.saved, this.moment, this.subjectName});
  static const notSaved = SquiSaveResult(saved: false);
}

bool shouldCelebrateRecap({
  required bool isInProgress,
  required double totalIncome,
  required double previousIncome,
  required double savingsRate,
  required double previousSavingsRate,
}) =>
    !isInProgress &&
    totalIncome > 0 &&
    previousIncome > 0 &&
    savingsRate > 0 &&
    savingsRate > previousSavingsRate;
