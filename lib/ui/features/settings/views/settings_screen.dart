import 'package:flutter/material.dart';

import 'package:yoyo_ir1_tracker/data/services/nearby_connection_service.dart';
import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/settings/views/remote_connection_card.dart';

class SettingsScreen extends StatelessWidget {
  final double volumeBoost;
  final bool isBoostEnabled;
  final ValueChanged<bool> onBoostEnabledChange;
  final ValueChanged<double> onVolumeBoostChange;

  final RemoteRole remoteRole;
  final bool remoteEnabled;
  final NearbyConnectionState remoteConnection;
  final ValueChanged<RemoteRole>? onRemoteRoleChange;
  final ValueChanged<bool>? onRemoteEnabledChange;
  final VoidCallback? onRemoteRetry;
  final ValueChanged<String>? onRemoteConnect;
  final VoidCallback? onRemoteDisconnect;
  final ValueChanged<bool>? onRemoteAuthenticationDecision;

  const SettingsScreen({
    super.key,
    required this.volumeBoost,
    required this.isBoostEnabled,
    required this.onBoostEnabledChange,
    required this.onVolumeBoostChange,
    this.remoteRole = RemoteRole.tablet,
    this.remoteEnabled = false,
    this.remoteConnection = const NearbyConnectionState(),
    this.onRemoteRoleChange,
    this.onRemoteEnabledChange,
    this.onRemoteRetry,
    this.onRemoteConnect,
    this.onRemoteDisconnect,
    this.onRemoteAuthenticationDecision,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: athleticBlue, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Audio, preferences & remote control',
                        style: TextStyle(color: slate400, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            RemoteConnectionCard(
              role: remoteRole,
              enabled: remoteEnabled,
              connection: remoteConnection,
              onRoleChanged: onRemoteRoleChange ?? (_) {},
              onEnabledChanged: onRemoteEnabledChange ?? (_) {},
              onRetry: onRemoteRetry ?? () {},
              onConnect: onRemoteConnect ?? (_) {},
              onDisconnect: onRemoteDisconnect ?? () {},
              onAuthenticationDecision:
                  onRemoteAuthenticationDecision ?? (_) {},
            ),
            Card(
              color: slate900,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.volume_up, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Audio Volume Boost',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${(volumeBoost * 100).toInt()}%',
                              style: const TextStyle(
                                color: athleticBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isBoostEnabled,
                              onChanged: onBoostEnabledChange,
                              activeThumbColor: athleticBlue,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isBoostEnabled) ...[
                      const SizedBox(height: 16),
                      Slider(
                        value: volumeBoost,
                        min: 1.0,
                        max: 3.0,
                        divisions: 4,
                        activeColor: athleticBlue,
                        inactiveColor: slate700,
                        onChanged: onVolumeBoostChange,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              '100%',
                              style: TextStyle(color: slate400, fontSize: 12),
                            ),
                            Text(
                              '300%',
                              style: TextStyle(color: slate400, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (volumeBoost > 2.0)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: warnOrange, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'High volume boost may cause audio distortion depending on your device.',
                                  style: TextStyle(
                                    color: warnOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
