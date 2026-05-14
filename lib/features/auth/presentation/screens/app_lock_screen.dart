import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/app_lock_provider.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? _errorText;
  bool _biometricAvailable = false;
  bool _checkingBio = true;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck && mounted) {
        final types = await _localAuth.getAvailableBiometrics();
        setState(() {
          _biometricAvailable = types.isNotEmpty;
          _checkingBio = false;
        });
        if (_biometricAvailable) {
          _authenticateWithBiometric();
        }
      } else {
        if (mounted) setState(() => _checkingBio = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checkingBio = false);
    }
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock Task Manager with fingerprint',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (ok && mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {}
  }

  void _onDigit(String digit) {
    if (_pinController.text.length < 4) {
      _pinController.text += digit;
      setState(() => _errorText = null);
      if (_pinController.text.length == 4) _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pinController.text.isNotEmpty) {
      _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
      setState(() => _errorText = null);
    }
  }

  Future<void> _verifyPin() async {
    final ok = await ref.read(appLockProvider.notifier).verifyPin(_pinController.text);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() { _errorText = 'Wrong PIN'; _pinController.text = ''; });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingBio) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final filled = _pinController.text.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.lock, size: 40, color: AppColors.background),
                ),
                const SizedBox(height: 32),
                if (_biometricAvailable) ...[
                  // Fingerprint is primary
                  GestureDetector(
                    onTap: _authenticateWithBiometric,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.fingerprint, size: 40, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Touch the fingerprint sensor',
                      style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  const Row(children: [
                    Expanded(child: Divider(color: AppColors.border)),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or use PIN', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
                    Expanded(child: Divider(color: AppColors.border)),
                  ]),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text('Enter PIN',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                ],
                Text(
                  _errorText ?? 'Enter your 4-digit PIN to unlock',
                  style: TextStyle(color: _errorText != null ? AppColors.error : AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    return Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < filled ? AppColors.primary : AppColors.border,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                _buildNumPad(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Column(children: [
      for (final row in [['1','2','3'],['4','5','6'],['7','8','9'],['','0','⌫']])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map((d) {
            if (d.isEmpty) return const SizedBox(width: 72, height: 56);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(width: 72, height: 56,
                child: Material(color: d == '⌫' ? Colors.transparent : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      d == '⌫' ? _onBackspace() : _onDigit(d);
                    },
                    child: Center(child: d == '⌫'
                        ? const Icon(Icons.backspace_outlined, color: AppColors.textMuted, size: 22)
                        : Text(d, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w500)))),
                ),
              ),
            );
          }).toList()),
        ),
    ]);
  }
}
