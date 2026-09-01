import 'package:flutter/material.dart';

import 'package:yoyo_ir1_tracker/data/services/nearby_connection_service.dart';
import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';

class RemoteConnectionCard extends StatelessWidget {
  final RemoteRole role;
  final bool enabled;
  final NearbyConnectionState connection;
  final ValueChanged<RemoteRole> onRoleChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onRetry;
  final ValueChanged<String> onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<bool> onAuthenticationDecision;

  const RemoteConnectionCard({
    super.key,
    required this.role,
    required this.enabled,
    required this.connection,
    required this.onRoleChanged,
    required this.onEnabledChanged,
    required this.onRetry,
    required this.onConnect,
    required this.onDisconnect,
    required this.onAuthenticationDecision,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(connection.status);
    return Card(
      color: slate900,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_other, color: athleticBlue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Nearby remote controller',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                  activeThumbColor: athleticBlue,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'The tablet keeps the clock, measurements, audio and results authoritative.',
              style: TextStyle(color: slate400, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('This device', style: TextStyle(color: slate400)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<RemoteRole>(
                    value: role,
                    isExpanded: true,
                    dropdownColor: slate800,
                    style: const TextStyle(color: Colors.white),
                    onChanged: enabled
                        ? null
                        : (next) {
                            if (next != null) onRoleChanged(next);
                          },
                    items: const [
                      DropdownMenuItem(
                        value: RemoteRole.tablet,
                        child: Text('Tablet host'),
                      ),
                      DropdownMenuItem(
                        value: RemoteRole.controller,
                        child: Text('Controller'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(connection.status),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (connection.peerName != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '• ${connection.peerName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: slate400),
                    ),
                  ),
                ],
              ],
            ),
            if (connection.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                connection.errorMessage!,
                style: const TextStyle(color: warnOrangeLight, fontSize: 12),
              ),
            ],
            if (connection.authenticationToken != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: slate800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify this token matches the other device',
                      style: TextStyle(color: slate400, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      connection.authenticationToken!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (connection.needsAuthentication) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => onAuthenticationDecision(false),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onAuthenticationDecision(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: runGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Token matches'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (role == RemoteRole.controller &&
                connection.discoveredEndpoints.isNotEmpty &&
                !connection.isConnected) ...[
              const SizedBox(height: 12),
              const Text(
                'Tablets found nearby',
                style: TextStyle(color: slate200, fontWeight: FontWeight.bold),
              ),
              ...connection.discoveredEndpoints.map(
                (endpoint) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.tablet_android,
                    color: athleticBlueLight,
                  ),
                  title: Text(
                    endpoint.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => onConnect(endpoint.id),
                    child: const Text('Connect'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (connection.status == RemoteConnectionStatus.error ||
                    connection.status ==
                        RemoteConnectionStatus.permissionRequired ||
                    connection.status == RemoteConnectionStatus.disconnected)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                if (connection.isConnected) ...[
                  if (connection.status != RemoteConnectionStatus.error)
                    OutlinedButton.icon(
                      onPressed: onDisconnect,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('Disconnect'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(RemoteConnectionStatus status) {
    switch (status) {
      case RemoteConnectionStatus.connected:
        return runGreen;
      case RemoteConnectionStatus.error:
      case RemoteConnectionStatus.permissionRequired:
        return warnOrangeLight;
      case RemoteConnectionStatus.unsupported:
        return slate400;
      default:
        return athleticBlueLight;
    }
  }

  String _statusLabel(RemoteConnectionStatus status) {
    switch (status) {
      case RemoteConnectionStatus.disabled:
        return 'Disabled';
      case RemoteConnectionStatus.unsupported:
        return 'Unsupported on this device';
      case RemoteConnectionStatus.permissionRequired:
        return 'Permission required';
      case RemoteConnectionStatus.advertising:
        return 'Advertising as tablet';
      case RemoteConnectionStatus.discovering:
        return 'Discovering tablets';
      case RemoteConnectionStatus.endpointFound:
        return 'Tablet found';
      case RemoteConnectionStatus.awaitingVerification:
        return 'Awaiting token verification';
      case RemoteConnectionStatus.connecting:
        return 'Connecting';
      case RemoteConnectionStatus.connected:
        return 'Connected';
      case RemoteConnectionStatus.disconnected:
        return 'Disconnected';
      case RemoteConnectionStatus.error:
        return 'Error';
    }
  }
}
