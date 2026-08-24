import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/squi_moments.dart';

class SquiMilestoneService {
  SquiMilestoneService._();
  static final SquiMilestoneService instance = SquiMilestoneService._();

  @visibleForTesting
  SquiMilestoneService.forTesting();

  static const _preferencesKey = 'squi_celebrated_milestones';
  Set<String>? _consumed;
  Future<void> _tail = Future.value();

  Future<SquiMoment?> claim({
    required Set<SquiMoment> eligible,
    String? goalId,
    String? debtId,
  }) {
    final completer = Completer<SquiMoment?>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(
          await _claim(eligible: eligible, goalId: goalId, debtId: debtId),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<SquiMoment?> _claim({
    required Set<SquiMoment> eligible,
    String? goalId,
    String? debtId,
  }) async {
    if (eligible.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    final consumed = _consumed ??=
        preferences.getStringList(_preferencesKey)?.toSet() ?? <String>{};
    String keyFor(SquiMoment moment) => switch (moment) {
      SquiMoment.firstTransaction => 'first_transaction',
      SquiMoment.goalReached =>
        'goal:${goalId ?? (throw ArgumentError('goalId required'))}',
      SquiMoment.debtSettled =>
        'debt:${debtId ?? (throw ArgumentError('debtId required'))}',
    };
    final selected = selectSquiMoment(
      eligible: eligible,
      alreadyCelebrated: consumed,
      keyFor: keyFor,
    );
    if (selected == null) return null;
    consumed.add(keyFor(selected));
    await preferences.setStringList(_preferencesKey, consumed.toList()..sort());
    return selected;
  }
}
