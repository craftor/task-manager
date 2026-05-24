import 'package:supabase_flutter/supabase_flutter.dart';

class AiConfigService {
  Future<String?> getBaseUrl() async {
    final row = await _fetch();
    final v = row?['api_base_url'] as String?;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  Future<void> setBaseUrl(String v) async {
    await _saveAll(baseUrl: v);
  }

  Future<String?> getApiKey() async {
    final row = await _fetch();
    final v = row?['api_key'] as String?;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  Future<void> setApiKey(String v) async {
    await _saveAll(apiKey: v);
  }

  Future<String?> getModelName() async {
    final row = await _fetch();
    final v = row?['model_name'] as String?;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  Future<void> setModelName(String v) async {
    await _saveAll(modelName: v);
  }

  Future<bool> isConfigured() async {
    final url = await getBaseUrl();
    final key = await getApiKey();
    final model = await getModelName();
    return url != null && key != null && model != null;
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    final result = await Supabase.instance.client
        .from('ai_config')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return result;
  }

  Future<void> _saveAll({String? baseUrl, String? apiKey, String? modelName}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Single atomic upsert: always write all three fields together
    final data = {
      'user_id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (baseUrl != null) data['api_base_url'] = baseUrl;
    if (apiKey != null) data['api_key'] = apiKey;
    if (modelName != null) data['model_name'] = modelName;

    await Supabase.instance.client.from('ai_config').upsert(data, onConflict: 'user_id');
  }
}