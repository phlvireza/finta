import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../models/transaction_model.dart';
import '../repositories/goal_repository.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/goal_projection.dart';

/// Manages goal state — load, create, update, archive, and the
/// derived-from-transactions progress map goal cards read from.
class GoalProvider extends ChangeNotifier {
  final GoalRepository _repository;

  /// Held so the detail screen can list the contributions behind
  /// [progressOf] without a screen reaching for a repository itself — the
  /// same arrangement `BudgetProvider` uses for its transaction queries.
  final TransactionRepository _transactionRepo;

  static const _uuid = Uuid();

  GoalProvider({GoalRepository? repository, TransactionRepository? transactionRepository})
      : _repository = repository ?? GoalRepository(),
        _transactionRepo = transactionRepository ?? TransactionRepository();

  List<GoalModel> _goals = [];
  Map<String, double> _progress = {};
  bool _isLoading = false;
  String? _error;

  List<GoalModel> get goals => _goals;
  List<GoalModel> get activeGoals => _goals.where((g) => !g.isArchived).toList();

  /// Goals that were archived rather than deleted because they still had
  /// contributions. Surfaced so the archive is somewhere the user can reach:
  /// an archived goal used to vanish from every screen, which made the
  /// promise that "your history stays intact" impossible to verify.
  List<GoalModel> get archivedGoals => _goals.where((g) => g.isArchived).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  double progressOf(String goalId) => _progress[goalId] ?? 0;

  Future<void> loadGoals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goals = await _repository.getAll();
      _progress = await _repository.getAllProgress();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Every contribution and withdrawal tagged with this goal, newest first —
  /// the rows that add up to [progressOf].
  Future<List<TransactionModel>> transactionsFor(String goalId) =>
      _transactionRepo.getByGoalId(goalId);

  GoalModel? getGoalById(String id) {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Projected completion date from the last 3 months' contribution
  /// average, or null if there's not enough recent activity to project
  /// from.
  Future<({DateTime? date, double monthlyAverage})> getProjection(GoalModel goal) async {
    final recent = await _repository.getRecentMonthlyContributions(goal.id);
    return projectGoalCompletion(
      targetAmount: goal.targetAmount,
      currentProgress: progressOf(goal.id),
      recentMonthlyContributions: recent,
    );
  }

  Future<GoalModel> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String icon = 'savings',
    required String color,
  }) async {
    final goal = GoalModel(
      id: _uuid.v4(),
      name: name,
      targetAmount: targetAmount,
      targetDate: targetDate,
      icon: icon,
      color: color,
      createdAt: DateTime.now(),
    );
    await _repository.insert(goal);
    await loadGoals();
    return goal;
  }

  Future<void> updateGoal(GoalModel goal) async {
    await _repository.update(goal);
    await loadGoals();
  }

  Future<int> countUsage(String id) => _repository.countUsage(id);

  /// Remove a goal.
  ///
  /// By default a goal with contributions is archived rather than deleted:
  /// the money genuinely left the account, so dropping those transactions
  /// would rewrite history and leave every past account balance wrong.
  ///
  /// [deleteContributions] is the explicit opt-out for the one case where
  /// that reasoning doesn't hold — a goal created by mistake, whose
  /// contributions were never real spending. It removes the tagged
  /// transactions too, so callers must reload the providers that derive from
  /// them (accounts, budgets, analytics, transactions).
  Future<void> deleteGoal(String id, {bool deleteContributions = false}) async {
    if (deleteContributions) {
      await _repository.deleteWithTransactions(id);
      await loadGoals();
      return;
    }
    final usage = await _repository.countUsage(id);
    if (usage > 0) {
      await _repository.archive(id);
    } else {
      await _repository.deleteUnused(id);
    }
    await loadGoals();
  }

  Future<void> unarchiveGoal(String id) async {
    await _repository.unarchive(id);
    await loadGoals();
  }
}
