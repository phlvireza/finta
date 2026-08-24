import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finta/core/services/squi_milestone_service.dart';
import 'package:finta/core/utils/squi_moments.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('claims a milestone exactly once', () async {
    final service = SquiMilestoneService.forTesting();
    final first = await service.claim(eligible: {SquiMoment.firstTransaction});
    final second = await service.claim(eligible: {SquiMoment.firstTransaction});
    expect(first, SquiMoment.firstTransaction);
    expect(second, isNull);
  });

  test('concurrent claims produce one winner', () async {
    final service = SquiMilestoneService.forTesting();
    final results = await Future.wait([
      service.claim(eligible: {SquiMoment.firstTransaction}),
      service.claim(eligible: {SquiMoment.firstTransaction}),
    ]);
    expect(results.whereType<SquiMoment>(), [SquiMoment.firstTransaction]);
  });

  test('higher priority subject milestone wins and persists one key', () async {
    final service = SquiMilestoneService.forTesting();
    final result = await service.claim(
      eligible: {SquiMoment.goalReached, SquiMoment.firstTransaction},
      goalId: 'goal-1',
    );
    expect(result, SquiMoment.goalReached);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('squi_celebrated_milestones'), [
      'goal:goal-1',
    ]);
  });
}
