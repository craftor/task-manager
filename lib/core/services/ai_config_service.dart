import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiConfigService {
  static const _storage = FlutterSecureStorage();
  static const _keyBaseUrl = 'ai_api_base_url';
  static const _keyApiKey = 'ai_api_key';
  static const _keyModelName = 'ai_model_name';

  Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);
  Future<void> setBaseUrl(String v) => _storage.write(key: _keyBaseUrl, value: v);

  Future<String?> getApiKey() => _storage.read(key: _keyApiKey);
  Future<void> setApiKey(String v) => _storage.write(key: _keyApiKey, value: v);

  Future<String?> getModelName() => _storage.read(key: _keyModelName);
  Future<void> setModelName(String v) => _storage.write(key: _keyModelName, value: v);

  Future<bool> isConfigured() async {
    final url = await getBaseUrl();
    final key = await getApiKey();
    final model = await getModelName();
    return url != null && key != null && model != null;
  }
}