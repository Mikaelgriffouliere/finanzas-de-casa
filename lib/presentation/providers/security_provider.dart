import 'package:flutter/foundation.dart';

import '../../data/repositories/security_repository.dart';

class SecurityProvider extends ChangeNotifier {
  SecurityProvider({SecurityRepository? repository})
      : _repository = repository ?? SecurityRepository();

  final SecurityRepository _repository;

  bool _pinEnabled = false;
  bool get pinEnabled => _pinEnabled;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  bool _unlocked = false;
  bool get unlocked => _unlocked;

  Future<void> load() async {
    _pinEnabled = await _repository.isPinEnabled();
    _biometricEnabled = await _repository.isBiometricEnabled();
    _unlocked = !_pinEnabled;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) {
    return _repository.verifyPin(pin);
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _repository.verifyPin(pin);
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  void unlock() {
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    _unlocked = false;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await _repository.setPin(pin);
    _pinEnabled = true;
    _biometricEnabled = await _repository.isBiometricEnabled();
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _repository.disablePin();
    _pinEnabled = false;
    _biometricEnabled = false;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _repository.setBiometricEnabled(enabled);
    _biometricEnabled = enabled;
    notifyListeners();
  }
}