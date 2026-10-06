/// WebDAV sync configuration screen.
///
/// Lets the user:
///   * Enter / edit the WebDAV server URL, username, password and
///     remote path.
///   * Test the connection.
///   * Push the current local snapshot up.
///   * Pull / merge the remote snapshot down.
///   * Toggle automatic 5-minute sync.
///   * See the last sync result.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/sync/sync_status.dart';
import '../../../../data/sync/webdav/webdav_credentials.dart';
import '../../../../data/sync/webdav/webdav_exceptions.dart';
import '../../../sync/presentation/providers/sync_status_provider.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _remotePathCtrl;

  bool _autoSync = false;
  bool _busy = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final creds = ref.read(webdavCredentialsProvider);
    _baseUrlCtrl = TextEditingController(text: creds.baseUrl);
    _usernameCtrl = TextEditingController(text: creds.username);
    _passwordCtrl = TextEditingController(text: creds.password);
    _remotePathCtrl =
        TextEditingController(text: creds.remotePath.isEmpty ? '/task_manager' : creds.remotePath);
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _remotePathCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final creds = WebDavCredentials(
      baseUrl: _baseUrlCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      remotePath: _remotePathCtrl.text.trim().isEmpty
          ? '/task_manager'
          : _remotePathCtrl.text.trim(),
    );
    await ref.read(webdavCredentialsProvider.notifier).save(creds);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() {
      _busy = true;
      _testResult = null;
    });
    try {
      final engine = ref.read(syncEngineProvider);
      await engine.testConnection();
      if (!mounted) return;
      setState(() => _testResult = '✅ Connection OK');
    } on WebDavAuthException catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '❌ ${e.message}');
    } on WebDavNetworkException catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '❌ Network: ${e.message}');
    } on WebDavException catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '❌ ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '❌ $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _push() async {
    await _save();
    setState(() => _busy = true);
    try {
      final n = await ref.read(syncEngineProvider).push();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pushed $n records.')),
      );
    } on WebDavException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Push failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Push failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    await _save();
    setState(() => _busy = true);
    try {
      final n = await ref.read(syncEngineProvider).pull();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pulled $n records (merged).')),
      );
    } on WebDavException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pull failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pull failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleAutoSync(bool v) {
    setState(() => _autoSync = v);
    final engine = ref.read(syncEngineProvider);
    if (v) {
      engine.startPeriodic();
    } else {
      engine.stopPeriodic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncReport = ref.watch(syncStatusProvider).valueOrNull ?? SyncReport.idle;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sync (WebDAV)'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('Server'),
            _field(
              label: 'Base URL',
              hint: 'https://dav.example.com',
              controller: _baseUrlCtrl,
              keyboardType: TextInputType.url,
            ),
            _field(
              label: 'Remote path',
              hint: '/task_manager',
              controller: _remotePathCtrl,
            ),
            const SizedBox(height: 20),
            _section('Credentials'),
            _field(
              label: 'Username',
              controller: _usernameCtrl,
            ),
            _field(
              label: 'Password',
              controller: _passwordCtrl,
              obscure: true,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _testConnection,
                    icon: const Icon(Icons.wifi_find, size: 18),
                    label: const Text('Test'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('✅')
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _section('Manual sync'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _push,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Push'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pull,
                    icon: const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Pull & merge'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _section('Automatic'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync every 5 minutes',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text(
                'Runs a pull-merge in the background while credentials are valid.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              value: _autoSync,
              onChanged: _busy ? null : _toggleAutoSync,
            ),
            const SizedBox(height: 12),
            _statusPanel(syncReport),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _statusPanel(SyncReport r) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final last = r.lastSuccessAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForPhase(r.phase),
                size: 16,
                color: _colorForPhase(r.phase),
              ),
              const SizedBox(width: 8),
              Text(
                _labelForPhase(r.phase),
                style: TextStyle(
                  color: _colorForPhase(r.phase),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            last == null
                ? 'Never synced.'
                : 'Last ${r.lastDirection?.name ?? "sync"}: ${fmt.format(last.toLocal())}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          if (r.lastError != null) ...[
            const SizedBox(height: 6),
            Text(
              r.lastError!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForPhase(SyncPhase p) {
    switch (p) {
      case SyncPhase.idle:
        return Icons.cloud_done_outlined;
      case SyncPhase.pulling:
        return Icons.cloud_download_outlined;
      case SyncPhase.pushing:
        return Icons.cloud_upload_outlined;
      case SyncPhase.conflict:
        return Icons.warning_amber_outlined;
      case SyncPhase.error:
        return Icons.error_outline;
    }
  }

  Color _colorForPhase(SyncPhase p) {
    switch (p) {
      case SyncPhase.idle:
        return AppColors.success;
      case SyncPhase.pulling:
      case SyncPhase.pushing:
        return AppColors.primary;
      case SyncPhase.conflict:
      case SyncPhase.error:
        return AppColors.error;
    }
  }

  String _labelForPhase(SyncPhase p) {
    switch (p) {
      case SyncPhase.idle:
        return 'Idle';
      case SyncPhase.pulling:
        return 'Pulling…';
      case SyncPhase.pushing:
        return 'Pushing…';
      case SyncPhase.conflict:
        return 'Conflicts present';
      case SyncPhase.error:
        return 'Error';
    }
  }
}
