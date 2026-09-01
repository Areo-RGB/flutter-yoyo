import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart' as nearby;

import 'nearby_connection_service.dart';

/// Adapter around Google Nearby Connections. No application code talks to the
/// plugin singleton directly; this is the only class that does so.
///
/// Extracted from [nearby_connection_service.dart] so the session state
/// machine can be read without interleaving platform plumbing.
class PluginNearbyTransport implements NearbyTransport {
  final nearby.Nearby _nearby;
  void Function(String endpointId, NearbyConnectionInfo info)?
      _discoveryConnectionInitiated;
  void Function(String endpointId, NearbyTransportResult result)?
      _discoveryConnectionResult;
  void Function(String endpointId)? _discoveryDisconnected;

  PluginNearbyTransport({nearby.Nearby? nearbyClient})
      : _nearby = nearbyClient ?? nearby.Nearby();

  @override
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> startAdvertising({
    required String deviceName,
    required String serviceId,
    required void Function(String endpointId, NearbyConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, NearbyTransportResult result)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    try {
      return await _nearby.startAdvertising(
        deviceName,
        nearby.Strategy.P2P_POINT_TO_POINT,
        serviceId: serviceId,
        onConnectionInitiated: (endpointId, info) {
          onConnectionInitiated(
            endpointId,
            NearbyConnectionInfo(
              endpointName: info.endpointName,
              authenticationToken: info.authenticationToken,
              isIncomingConnection: info.isIncomingConnection,
            ),
          );
        },
        onConnectionResult: (endpointId, result) {
          onConnectionResult(endpointId, _mapStatus(result));
        },
        onDisconnected: onDisconnected,
      );
    } catch (e) {
      debugPrint('[NearbyTransport] startAdvertising failed: $e');
      return false;
    }
  }

  @override
  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (e) {
      debugPrint('[NearbyTransport] stopAdvertising: $e');
    }
  }

  @override
  Future<bool> startDiscovery({
    required String deviceName,
    required String serviceId,
    required void Function(String endpointId, String endpointName, String serviceId)
        onEndpointFound,
    required void Function(String? endpointId) onEndpointLost,
    required void Function(String endpointId, NearbyConnectionInfo info)
        onConnectionInitiated,
    required void Function(String endpointId, NearbyTransportResult result)
        onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  }) async {
    _discoveryConnectionInitiated = onConnectionInitiated;
    _discoveryConnectionResult = onConnectionResult;
    _discoveryDisconnected = onDisconnected;
    try {
      return await _nearby.startDiscovery(
        deviceName,
        nearby.Strategy.P2P_POINT_TO_POINT,
        serviceId: serviceId,
        onEndpointFound: onEndpointFound,
        onEndpointLost: onEndpointLost,
      );
    } catch (e) {
      debugPrint('[NearbyTransport] startDiscovery failed: $e');
      return false;
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (e) {
      debugPrint('[NearbyTransport] stopDiscovery: $e');
    }
  }

  @override
  Future<bool> requestConnection(String endpointId) async {
    final onInitiated = _discoveryConnectionInitiated;
    final onResult = _discoveryConnectionResult;
    final onDisconnected = _discoveryDisconnected;
    if (onInitiated == null || onResult == null || onDisconnected == null) {
      throw StateError('Nearby discovery has not been started');
    }
    try {
      return await _nearby.requestConnection(
        controllerEndpointName,
        endpointId,
        onConnectionInitiated: (id, info) {
          onInitiated(
            id,
            NearbyConnectionInfo(
              endpointName: info.endpointName,
              authenticationToken: info.authenticationToken,
              isIncomingConnection: info.isIncomingConnection,
            ),
          );
        },
        onConnectionResult: (id, result) {
          onResult(id, _mapStatus(result));
        },
        onDisconnected: onDisconnected,
      );
    } catch (e) {
      debugPrint('[NearbyTransport] requestConnection failed: $e');
      return false;
    }
  }

  @override
  Future<bool> acceptConnection(
    String endpointId, {
    required void Function(String endpointId, Uint8List bytes) onPayloadReceived,
  }) async {
    try {
      return await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (id, payload) {
          if (payload.type == nearby.PayloadType.BYTES && payload.bytes != null) {
            onPayloadReceived(id, payload.bytes!);
          }
        },
      );
    } catch (e) {
      debugPrint('[NearbyTransport] acceptConnection failed: $e');
      return false;
    }
  }

  @override
  Future<bool> rejectConnection(String endpointId) async {
    try {
      return await _nearby.rejectConnection(endpointId);
    } catch (e) {
      debugPrint('[NearbyTransport] rejectConnection: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
    } catch (e) {
      debugPrint('[NearbyTransport] disconnect: $e');
    }
  }

  @override
  Future<void> stopAllEndpoints() async {
    try {
      await _nearby.stopAllEndpoints();
    } catch (e) {
      debugPrint('[NearbyTransport] stopAllEndpoints: $e');
    }
  }

  @override
  Future<void> sendBytes(String endpointId, Uint8List bytes) async {
    try {
      await _nearby.sendBytesPayload(endpointId, bytes);
      debugPrint('[NearbyTransport] sendBytes OK endpoint=$endpointId bytes=${bytes.length}');
    } catch (e) {
      debugPrint('[NearbyTransport] sendBytes failed: $e');
      rethrow;
    }
  }

  NearbyTransportResult _mapStatus(nearby.Status status) {
    switch (status) {
      case nearby.Status.CONNECTED:
        return NearbyTransportResult.connected;
      case nearby.Status.REJECTED:
        return NearbyTransportResult.rejected;
      case nearby.Status.ERROR:
        return NearbyTransportResult.error;
    }
  }
}
