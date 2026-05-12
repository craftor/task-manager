import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String tagName;
  final String downloadUrl;
  final String body;
  final bool isNewer;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.downloadUrl,
    required this.body,
    required this.isNewer,
  });
}

class UpdateService {
  static const String _owner = 'craftor';
  static const String _repo = 'task-manager';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Compare two version strings (e.g. "0.2.5" vs "0.2.6").
  /// Returns 1 if a > b, -1 if a < b, 0 if equal.
  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal > bVal) return 1;
      if (aVal < bVal) return -1;
    }
    return 0;
  }

  /// Check if an update is available by comparing current version
  /// with the latest GitHub release.
  static Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'TaskManager-UpdateChecker',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('UpdateService: HTTP ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String;
      // Strip leading 'v' from tag (e.g. "v0.2.6" → "0.2.6")
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final isNewer = _compareVersions(latestVersion, currentVersion) > 0;

      if (!isNewer) {
        debugPrint('UpdateService: current $currentVersion, latest $latestVersion — up to date');
        return null;
      }

      // Find Android APK asset
      String? downloadUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String?;
          if (name != null && name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      debugPrint('UpdateService: new version $latestVersion available');
      return UpdateInfo(
        version: latestVersion,
        tagName: tagName,
        downloadUrl: downloadUrl ?? data['html_url'] as String,
        body: data['body'] as String? ?? '',
        isNewer: true,
      );
    } catch (e) {
      debugPrint('UpdateService: check failed — $e');
      return null;
    }
  }
}
