import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return service.isLockEnabled();
});

final appLockProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

class AppLockNotifier extends Notifier<bool> {
  late final AppLockService _service;

  @override
  bool build() {
    _service = ref.watch(appLockServiceProvider);
    // Kick off async init; failures keep `state` at false (lock disabled).
    _init();
    return false;
  }

  Future<void> _init() async {
    final enabled = await _service.isLockEnabled();
    state = enabled;
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