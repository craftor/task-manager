import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../projects/presentation/providers/projects_provider.dart';
import '../../../auth/presentation/providers/app_lock_provider.dart';
import '../../data/import_export_service.dart';

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  final db = ref.watch(databaseProvider);
  return ImportExportService(db);
});

class ImportExportScreen extends ConsumerStatefulWidget {
  const ImportExportScreen({super.key});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _lastResult;

  Future<void> _doExport() async {
    setState(() {
      _isExporting = true;
      _lastResult = null;
    });
    try {
      final service = ref.read(importExportServiceProvider);
      await service.shareExport();
      if (mounted) {
        setState(() => _lastResult = 'Export ready to share');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lastResult = 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _doImport() async {
    setState(() {
      _isImporting = true;
      _lastResult = null;
    });
    try {
      final service = ref.read(importExportServiceProvider);
      final result = await service.importFromFile();
      if (mounted) {
        setState(() => _lastResult = result.message);
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lastResult = 'Import failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showPinSetupDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final lockAsync = ref.read(appLockEnabledProvider);
    final existingPin = lockAsync.valueOrNull ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existingPin ? 'Change PIN' : 'Set App Lock PIN',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '4-digit PIN',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              counterText: '',
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, letterSpacing: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'Confirm PIN',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              counterText: '',
            ),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, letterSpacing: 12),
          ),
        ]),
        actions: [
          if (existingPin)
            TextButton(
              onPressed: () {
                ref.read(appLockProvider.notifier).disableLock();
                ref.invalidate(appLockEnabledProvider);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App Lock disabled'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                );
              },
              child: const Text('Remove PIN', style: TextStyle(color: AppColors.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text;
              final confirm = confirmController.text;
              if (pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
                );
                return;
              }
              if (pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
                );
                return;
              }
              await ref.read(appLockProvider.notifier).setPin(pin);
              ref.invalidate(appLockEnabledProvider);
              if (mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App Lock PIN set'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockAsync = ref.watch(appLockEnabledProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── App Lock Section ───
          const Text('Security', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          lockAsync.when(
            data: (locked) => _buildSettingsCard(
              icon: locked ? Icons.lock : Icons.lock_open,
              iconColor: locked ? AppColors.primary : AppColors.textMuted,
              title: 'App Lock',
              subtitle: locked ? 'PIN is required to open app' : 'Protect app with a 4-digit PIN',
              trailing: Switch(
                value: locked,
                activeColor: AppColors.primary,
                onChanged: (_) => _showPinSetupDialog(),
              ),
              onTap: _showPinSetupDialog,
            ),
            loading: () => _buildSettingsCard(
              icon: Icons.lock,
              iconColor: AppColors.textMuted,
              title: 'App Lock',
              subtitle: 'Loading...',
              trailing: const SizedBox(width: 48),
              onTap: null,
            ),
            error: (_, __) => _buildSettingsCard(
              icon: Icons.lock_open,
              iconColor: AppColors.textMuted,
              title: 'App Lock',
              subtitle: 'Error loading',
              trailing: const SizedBox(width: 48),
              onTap: null,
            ),
          ),

          const SizedBox(height: 24),

          // ─── Import/Export Section ───
          const Text('Data', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildSettingsCard(
            icon: Icons.upload_outlined,
            iconColor: AppColors.primary,
            title: 'Export Data',
            subtitle: 'Export tasks, projects and time entries to JSON',
            trailing: _isExporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: _isExporting ? null : _doExport,
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(
            icon: Icons.download_outlined,
            iconColor: AppColors.primary,
            title: 'Import Data',
            subtitle: 'Import from JSON backup file',
            trailing: _isImporting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: _isImporting ? null : _doImport,
          ),

          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_lastResult!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // ─── Version Section ───
          const Text('About', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildSettingsCard(
            icon: Icons.info_outline,
            iconColor: AppColors.textMuted,
            title: 'Version',
            subtitle: AppConstants.appVersion,
            trailing: null,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ])),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }
}
