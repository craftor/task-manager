import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ai/presentation/providers/ai_provider.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = ref.read(aiConfigServiceProvider);
    _baseUrlController.text = await config.getBaseUrl() ?? '';
    _apiKeyController.text = await config.getApiKey() ?? '';
    _modelController.text = await config.getModelName() ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final config = ref.read(aiConfigServiceProvider);
      await config.setBaseUrl(_baseUrlController.text.trim());
      await config.setApiKey(_apiKeyController.text.trim());
      await config.setModelName(_modelController.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildField('API Base URL', _baseUrlController, 'https://api.siliconflow.cn/v1'),
          const SizedBox(height: 16),
          _buildField('API Key', _apiKeyController, '', obscure: true),
          const SizedBox(height: 16),
          _buildField('Model Name', _modelController, 'glm-4-flash'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: ctrl, obscureText: obscure, decoration: InputDecoration(hintText: hint, filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
      ],
    );
  }
}