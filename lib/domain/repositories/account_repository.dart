import '../entities/account.dart';

abstract class AccountRepository {
  Future<List<Account>> getAll({bool onlyActive = false});
  Future<Account?> getById(int id);
  Future<Account> create(Account account);
  Future<Account> update(Account account);
  Future<void> delete(int id);
}