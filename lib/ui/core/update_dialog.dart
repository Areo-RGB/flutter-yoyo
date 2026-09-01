import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yoyo_ir1_tracker/data/services/update_service.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> showIfAvailable(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusText = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusText = 'Downloading update...';
    });

    final service = UpdateService();
    final success = await service.downloadAndInstallApk(
      widget.updateInfo.apkDownloadUrl,
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _statusText = 'Downloading... ${(progress * 100).toStringAsFixed(0)}%';
          });
        }
      },
    );

    if (mounted) {
      if (!success && widget.updateInfo.releaseUrl.isNotEmpty) {
        setState(() {
          _statusText = 'Redirecting to release page...';
        });
        final uri = Uri.parse(widget.updateInfo.releaseUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: athleticBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update,
              color: athleticBlueLight,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Available!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Version v${widget.updateInfo.latestVersion}',
                  style: TextStyle(
                    color: athleticBlueLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current version: v${widget.updateInfo.currentVersion}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: slate800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: slate700),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Release Notes:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.updateInfo.releaseNotes.isNotEmpty
                        ? widget.updateInfo.releaseNotes
                        : 'Bug fixes and performance improvements.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                backgroundColor: slate700,
                valueColor: const AlwaysStoppedAnimation<Color>(athleticBlueLight),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    color: athleticBlueLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: athleticBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _startDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Install Update'),
          ),
        ],
      ],
    );
  }
}
