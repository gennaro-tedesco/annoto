import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

const _githubOwner = 'gennaro-tedesco';
const _githubRepo = 'annoto';
const _currentVersion = String.fromEnvironment('APP_VERSION', defaultValue: '');

const _channel = MethodChannel('com.example.annoto/update');

class UpdateInfo {
  final String version;
  final String downloadUrl;
  const UpdateInfo({required this.version, required this.downloadUrl});
}

abstract final class UpdateService {
  static bool get isVersionedBuild =>
      _currentVersion.isNotEmpty && _currentVersion.startsWith('v');

  static String get currentVersion => _currentVersion;

  static Future<UpdateInfo?> checkForUpdate() async {
    final response = await Dio().get<Map<String, dynamic>>(
      'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );

    final data = response.data!;
    final latestTag = data['tag_name'] as String? ?? '';
    if (latestTag.isEmpty) return null;
    try {
      final current = Version.parse(_currentVersion.replaceFirst('v', ''));
      final latest = Version.parse(latestTag.replaceFirst('v', ''));
      if (latest <= current) return null;
    } on FormatException {}

    final assets = (data['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => (a['name'] as String).endsWith('.apk'))
        .firstOrNull;
    final downloadUrl = apk?['browser_download_url'] as String?;
    if (downloadUrl == null) {
      throw Exception('No APK asset found in release $latestTag');
    }

    return UpdateInfo(version: latestTag, downloadUrl: downloadUrl);
  }

  static Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  static Future<void> openInstallSettings() =>
      _channel.invokeMethod('openInstallSettings');

  static Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final apkPath = '${dir.path}/annoto-update.apk';

    await Dio().download(
      url,
      apkPath,
      onReceiveProgress: onProgress == null
          ? null
          : (received, total) {
              if (total > 0) onProgress(received / total);
            },
    );

    await _channel.invokeMethod('installApk', {'path': apkPath});
  }
}
