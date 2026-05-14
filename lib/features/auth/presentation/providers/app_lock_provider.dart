import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return service.isLockEnabled();
});

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  return AppLockNotifier(ref.watch(appLockServiceProvider));
});

class AppLockNotifier extends StateNotifier<bool> {
  final AppLockService _service;

  AppLockNotifier(this._service) : super(false) {
    _init();
  }

  Future<void> _init() async {
    state = await _service.isLockEnabled();
  }

  Future<bool> verifyPin(String pin) => _service.verifyPin(pin);

  Future<void> setPin(String pin) async {
    await _service.setPin(pin);
    state = true;
  }

  Future<void> disableLock() async {
    await _service.removePin();
    state = false;
  }
}
