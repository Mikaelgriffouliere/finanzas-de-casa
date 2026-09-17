import 'package:flutter/foundation.dart';

import '../../../domain/entities/account.dart';
import '../../../data/repositories/account_repository_impl.dart';

class AccountProvider extends ChangeNotifier {
  final AccountRepositoryImpl _repository;

  List<Account> _accounts = [];
  List<Account> get accounts => List.unmodifiable(_accounts);

  int _totalBalance = 0;
  int get totalBalance => _totalBalance;

  AccountProvider({AccountRepositoryImpl? repository})
      : _repository = repository ?? AccountRepositoryImpl();

  Future<void> loadAll() async {
    try {
      _accounts = await _repository.getAll();
      _totalBalance = await _repository.getTotalBalance();
      notifyListeners();
    } catch (e, stack) {
      debugPrint('AccountProvider.loadAll error: $e\n$stack');
    }
  }

  Future<void> refreshBalance() async {
    try {
      _totalBalance = await _repository.getTotalBalance();
      notifyListeners();
    } catch (e, stack) {
      debugPrint('AccountProvider.refreshBalance error: $e\n$stack');
    }
  }

  Future<void> add(Account account) async {
    try {
      final created = await _repository.create(account);
      _accounts.add(created);
      await refreshBalance();
    } catch (e, stack) {
      debugPrint('AccountProvider.add error: $e\n$stack');
    }
  }

  Future<void> update(Account account) async {
    try {
      final updated = await _repository.update(account);
      final index = _accounts.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        _accounts[index] = updated;
        await refreshBalance();
      }
    } catch (e, stack) {
      debugPrint('AccountProvider.update error: $e\n$stack');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _repository.delete(id);
      _accounts.removeWhere((a) => a.id == id);
      await refreshBalance();
    } catch (e, stack) {
      debugPrint('AccountProvider.delete error: $e\n$stack');
    }
  }
}
