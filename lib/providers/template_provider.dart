import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/template_model.dart';
import '../repositories/template_repository.dart';

/// Manages saved one-tap entry templates ("favorites") — load, create,
/// delete. Templates are never edited in place; deleting and re-saving is
/// simpler than a full edit form for something meant to be quick.
class TemplateProvider extends ChangeNotifier {
  final TemplateRepository _repository;
  static const _uuid = Uuid();

  TemplateProvider({TemplateRepository? repository})
      : _repository = repository ?? TemplateRepository();

  List<TemplateModel> _templates = [];
  bool _isLoading = false;
  String? _error;

  List<TemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadTemplates() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _templates = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTemplate({
    required String name,
    required String type,
    required double amount,
    required String categoryId,
    required String accountId,
    String? merchant,
    String? note,
  }) async {
    final sortOrder = await _repository.getMaxSortOrder();
    final template = TemplateModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      merchant: merchant,
      note: note,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );

    await _repository.insert(template);
    _templates.add(template);
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    await _repository.delete(id);
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
