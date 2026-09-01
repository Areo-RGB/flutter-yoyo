import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String releaseUrl;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.releaseUrl,
  });
}

class UpdateService {
  static const String repoOwner = 'Areo-RGB';
  static const String repoName = 'flutter-yoyo';
  static const String currentVersion = '1.0.0';

  /// Check GitHub Releases API for new version
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (json['tag_name'] as String? ?? '').replaceAll('v', '');
        final releaseNotes = json['body'] as String? ?? 'New version available.';
        final releaseUrl = json['html_url'] as String? ?? '';

        final assets = json['assets'] as List<dynamic>? ?? [];
        String apkUrl = '';
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }

        if (apkUrl.isEmpty && releaseUrl.isNotEmpty) {
          apkUrl = releaseUrl;
        }

        if (_isVersionNewer(currentVersion, tagName)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: tagName,
            releaseNotes: releaseNotes,
            apkDownloadUrl: apkUrl,
            releaseUrl: releaseUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed (network/offline): $e');
    }
    return null;
  }

  /// Download the APK and trigger native package installer
  Future<bool> downloadAndInstallApk(
    String apkUrl,
    Function(double progress) onProgress,
  ) async {
    try {
      if (apkUrl.isEmpty) return false;

      // If non-APK link (e.g. web fallback), open browser
      if (!apkUrl.endsWith('.apk')) {
        final uri = Uri.parse(apkUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/YoYo-update.apk';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloaded = 0;

      await response.stream.listen((chunk) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }).asFuture();

      await sink.close();
      client.close();

      // Open downloaded APK to trigger package installer
      final result = await OpenFile.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error downloading/installing APK: $e');
      return false;
    }
  }

  /// Helper to compare semver strings (e.g., "1.0.1" > "1.0.0")
  bool _isVersionNewer(String current, String latest) {
    try {
      final cParts = current.split('+')[0].split('.').map(int.parse).toList();
      final lParts = latest.split('+')[0].split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Version parsing error: $e');
    }
    return false;
  }
}
