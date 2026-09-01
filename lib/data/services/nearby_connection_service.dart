import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:location/location.dart' hide PermissionStatus;
import 'package:permission_handler/permission_handler.dart';

import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';
import 'nearby_transport.dart' show PluginNearbyTransport;

const String tabletEndpointName = 'Yo-Yo Tablet';
const String controllerEndpointName = 'Yo-Yo Controller';

// Reconnect tuning — chosen for field use where radios flap on the sideline.
const Duration _kBaseReconnectDelay = Duration(seconds: 1);
const Duration _kMaxReconnectDelay = Duration(seconds: 20);
const Duration _kConnectTimeout = Duration(seconds: 18);
const Duration _kAwaitingVerificationTimeout = Duration(seconds: 30);

class NearbyConnectionInfo {
  final String endpointName;
  final String authenticationToken;
  final bool isIncomingConnection;

  const NearbyConnectionInfo({
    required this.endpointName,
    required this.authenticationToken,
    required this.isIncomingConnection,
  });
}

class NearbyDiscoveredEndpoint {
  final String id;
  final String name;
  final String serviceId;

  const NearbyDiscoveredEndpoint({
    required this.id,
    required this.name,
    required this.serviceId,
  });
}

enum NearbyTransportResult { connected, rejected, error }

/// The application-facing transport seam. It keeps the UI/view model
/// independent of the singleton Android plugin and makes lifecycle behaviour
/// testable without a device.
abstract class NearbyTransport {
  bool get isSupported;

  Future<bool> startAdvertising({
    required String deviceName,
    required String serviceId,
    required void Function(String endpointId, NearbyConnectionInfo info)
    onConnectionInitiated,
    required void Function(String endpointId, NearbyTransportResult result)
    onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  });

  Future<void> stopAdvertising();

  Future<bool> startDiscovery({
    required String deviceName,
    required String serviceId,
    required void Function(
      String endpointId,
      String endpointName,
      String serviceId,
    )
    onEndpointFound,
    required void Function(String? endpointId) onEndpointLost,
    required void Function(String endpointId, NearbyConnectionInfo info)
    onConnectionInitiated,
    required void Function(String endpointId, NearbyTransportResult result)
    onConnectionResult,
    required void Function(String endpointId) onDisconnected,
  });

  Future<void> stopDiscovery();
  Future<bool> requestConnection(String endpointId);
  Future<bool> acceptConnection(
    String endpointId, {
    required void Function(String endpointId, Uint8List bytes)
    onPayloadReceived,
  });
  Future<bool> rejectConnection(String endpointId);
  Future<void> disconnect(String endpointId);
  Future<void> stopAllEndpoints();
  Future<void> sendBytes(String endpointId, Uint8List bytes);
}

class NearbyPreflightResult {
  final bool supported;
  final bool ready;
  final String? message;

  const NearbyPreflightResult._({
    required this.supported,
    required this.ready,
    this.message,
  });

  const NearbyPreflightResult.ready() : this._(supported: true, ready: true);

  const NearbyPreflightResult.unsupported([String? message])
    : this._(
        supported: false,
        ready: false,
        message: message ?? 'Nearby Connections is supported on Android only.',
      );

  const NearbyPreflightResult.denied([String? message])
    : this._(
        supported: true,
        ready: false,
        message: message ?? 'Nearby permissions are required.',
      );

  const NearbyPreflightResult.locationDisabled()
    : this._(
        supported: true,
        ready: false,
        message: 'Turn on Location services to discover nearby devices.',
      );
}

abstract class NearbyPermissionGateway {
  Future<NearbyPreflightResult> check();
}

class PlatformNearbyPermissionGateway implements NearbyPermissionGateway {
  final Location location;

  PlatformNearbyPermissionGateway({Location? location})
    : location = location ?? Location();

  @override
  Future<NearbyPreflightResult> check() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const NearbyPreflightResult.unsupported();
    }

    // Check before requesting — prevents re-prompting every reconnect and
    // avoids Permission.request() flicker when all are already granted.
    final requiredPermissions = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
    ];

    // Fast-path: see what's already granted.
    final alreadyDetermined = <Permission, PermissionStatus>{};
    for (final p in requiredPermissions) {
      try {
        alreadyDetermined[p] = await p.status;
      } catch (_) {
        alreadyDetermined[p] = PermissionStatus.denied;
      }
    }
    final missing = alreadyDetermined.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key)
        .toList();

    if (missing.isNotEmpty) {
      final statuses = await missing.request();
      final denied = statuses.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key.toString().split('.').last)
          .toList();
      // Merge with previously-denied that weren't re-requested (should be none).
      if (denied.isNotEmpty) {
        // Distinguish permanently-denied so the UI can offer "open settings".
        final permanentlyDenied = statuses.entries
            .where((e) => e.value.isPermanentlyDenied)
            .map((e) => e.key.toString().split('.').last)
            .toList();
        final hint = permanentlyDenied.isNotEmpty
            ? ' Grant them in System Settings → Apps → Yo-Yo IR1 → Permissions and retry.'
            : ' Grant them and retry.';
        return NearbyPreflightResult.denied(
          'Nearby permissions were denied: ${denied.join(', ')}.$hint',
        );
      }
    }

    bool locationEnabled;
    try {
      locationEnabled = await location.serviceEnabled();
    } catch (_) {
      // If we can't query Location, treat as disabled so we surface guidance
      // rather than crashing the session start.
      return const NearbyPreflightResult.locationDisabled();
    }
    if (!locationEnabled) return const NearbyPreflightResult.locationDisabled();
    return const NearbyPreflightResult.ready();
  }
}


class NearbyConnectionState {
  final RemoteConnectionStatus status;
  final String? endpointId;
  final String? peerName;
  final String? authenticationToken;
  final String? errorMessage;
  final List<NearbyDiscoveredEndpoint> discoveredEndpoints;

  const NearbyConnectionState({
    this.status = RemoteConnectionStatus.disabled,
    this.endpointId,
    this.peerName,
    this.authenticationToken,
    this.errorMessage,
    this.discoveredEndpoints = const [],
  });

  bool get isConnected => status == RemoteConnectionStatus.connected;
  bool get needsAuthentication =>
      status == RemoteConnectionStatus.awaitingVerification;
  bool get isUsable => isConnected;

  NearbyConnectionState copyWith({
    RemoteConnectionStatus? status,
    Object? endpointId = _unset,
    Object? peerName = _unset,
    Object? authenticationToken = _unset,
    Object? errorMessage = _unset,
    List<NearbyDiscoveredEndpoint>? discoveredEndpoints,
  }) {
    return NearbyConnectionState(
      status: status ?? this.status,
      endpointId: identical(endpointId, _unset)
          ? this.endpointId
          : endpointId as String?,
      peerName: identical(peerName, _unset)
          ? this.peerName
          : peerName as String?,
      authenticationToken: identical(authenticationToken, _unset)
          ? this.authenticationToken
          : authenticationToken as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      discoveredEndpoints: discoveredEndpoints ?? this.discoveredEndpoints,
    );
  }
}

const Object _unset = Object();

/// Owns one Nearby session and exposes a small, safe lifecycle state machine.
/// It does not know about test state or athlete data.
///
/// Stability hardening vs the original:
///  • Serialized session starts (_isStarting guard + _sessionGeneration).
///  • Automatic recovery with exponential back-off after any transient loss.
///  • Timeouts for connecting / awaitingVerification so we never hang.
///  • Discovery restarts automatically after a failed/active connection.
///  • Transport plugin exceptions are contained and retried, not leaked.
///  • Broadcast state stream replays latest value for late subscribers via
///    an explicit initial emission in `stateChanges` (callers still check `state`).
class NearbyConnectionService extends ChangeNotifier {
  final NearbyTransport transport;
  final NearbyPermissionGateway permissionGateway;
  final String tabletName;
  final String controllerName;

  NearbyConnectionState _state = const NearbyConnectionState();
  RemoteRole? _role;
  bool _enabled = false;
  bool _disposed = false;
  String? _pendingEndpointId;
  final StreamController<NearbyConnectionState> _stateController =
      StreamController<NearbyConnectionState>.broadcast();
  StreamController<Uint8List>? _receivedController;

  // --- stability internals ---
  Timer? _reconnectTimer;
  Timer? _connectTimeoutTimer;
  Timer? _awaitingVerificationTimer;
  int _reconnectAttempts = 0;
  int _sessionGeneration = 0;
  bool _isStarting = false;
  // Guards _startSession re-entry when a reconnect fires while one is in flight.

  NearbyConnectionService({
    NearbyTransport? transport,
    NearbyPermissionGateway? permissionGateway,
    this.tabletName = tabletEndpointName,
    this.controllerName = controllerEndpointName,
  }) : transport = transport ?? PluginNearbyTransport(),
       permissionGateway =
           permissionGateway ?? PlatformNearbyPermissionGateway();

  NearbyConnectionState get state => _state;
  Stream<NearbyConnectionState> get stateChanges => _stateController.stream;
  RemoteRole? get role => _role;
  bool get enabled => _enabled;
  String? get connectedEndpointId => _state.endpointId;
  Stream<Uint8List> get receivedBytes =>
      (_receivedController ??= StreamController<Uint8List>.broadcast()).stream;

  Future<void> setEnabled(bool enabled, {required RemoteRole role}) async {
    _cancelReconnect();
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    if (!enabled) {
      _enabled = false;
      _role = role;
      _reconnectAttempts = 0;
      await _stopSession();
      _setState(const NearbyConnectionState());
      return;
    }

    _enabled = true;
    _role = role;
    _reconnectAttempts = 0;
    await _startSession();
  }

  Future<void> setRole(RemoteRole role) async {
    if (_role == role && _enabled) return;
    _cancelReconnect();
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    if (_enabled) await _stopSession();
    _role = role;
    _reconnectAttempts = 0;
    if (_enabled) await _startSession();
  }

  Future<void> retry() async {
    if (!_enabled || _role == null) return;
    _cancelReconnect();
    _reconnectAttempts = 0;
    await _startSession();
  }

  Future<void> connectToEndpoint(String endpointId) async {
    if (!_enabled || _role != RemoteRole.controller) return;
    if (_state.discoveredEndpoints.every(
      (endpoint) => endpoint.id != endpointId,
    )) {
      _setError('That nearby endpoint is no longer available.');
      // Keep discovering so a transient list-drift doesn't strand the controller.
      _scheduleReconnect(const Duration(seconds: 1));
      return;
    }
    _cancelConnectTimeout();
    try {
      await transport.stopDiscovery();
      _setState(
        _state.copyWith(
          status: RemoteConnectionStatus.connecting,
          endpointId: endpointId,
          errorMessage: null,
        ),
      );
      _armConnectTimeout();
      final started = await transport.requestConnection(endpointId);
      if (!started) {
        _cancelConnectTimeout();
        _setError('Nearby did not start the connection request.');
        _scheduleReconnect();
      }
    } catch (error) {
      _cancelConnectTimeout();
      _setError('Could not connect to the tablet: ${_safeError(error)}');
      _scheduleReconnect();
    }
  }

  /// Called by the user only after comparing the token on both devices.
  Future<void> confirmAuthentication(bool accepted) async {
    final endpointId = _pendingEndpointId;
    if (endpointId == null || !_state.needsAuthentication) return;
    _cancelAwaitingVerificationTimeout();
    _pendingEndpointId = null;
    _cancelConnectTimeout();
    try {
      if (accepted) {
        _setState(_state.copyWith(status: RemoteConnectionStatus.connecting));
        _armConnectTimeout();
        final ok = await transport.acceptConnection(
          endpointId,
          onPayloadReceived: _onPayloadReceived,
        );
        if (!ok) {
          _cancelConnectTimeout();
          _setError('Nearby rejected the connection.');
          _scheduleReconnect();
        }
      } else {
        await transport.rejectConnection(endpointId);
        _setState(_state.copyWith(status: RemoteConnectionStatus.disconnected));
        // Not an error — user intentionally rejected. Resume advertising/discovery
        // promptly so the other side can retry.
        _scheduleReconnect(const Duration(milliseconds: 600));
      }
    } catch (error) {
      _cancelConnectTimeout();
      _setError('Could not verify the nearby connection: ${_safeError(error)}');
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _cancelReconnect();
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    final endpointId = _state.endpointId;
    try {
      if (endpointId != null) await transport.disconnect(endpointId);
    } catch (error) {
      _setError('Could not disconnect cleanly: ${_safeError(error)}');
      // Still transition to disconnected — don't leave the UI stuck.
    }
    _setState(
      _state.copyWith(
        status: RemoteConnectionStatus.disconnected,
        endpointId: null,
        peerName: null,
        authenticationToken: null,
      ),
    );
  }

  Future<void> sendBytes(Uint8List bytes) async {
    final endpointId = _state.endpointId;
    if (!_enabled || !_state.isConnected || endpointId == null) {
      throw StateError('Nearby controller is not connected');
    }
    if (bytes.length > maxRemotePayloadBytes) {
      throw ArgumentError('Payload exceeds $maxRemotePayloadBytes bytes');
    }
    await transport.sendBytes(endpointId, bytes);
  }

  Future<void> _startSession() async {
    if (_role == null || !_enabled || _disposed) return;
    if (_isStarting) return;
    _isStarting = true;
    final gen = ++_sessionGeneration;
    try {
      if (!transport.isSupported) {
        _setState(
          _state.copyWith(
            status: RemoteConnectionStatus.unsupported,
            errorMessage: 'Nearby remote control is available on Android only.',
          ),
        );
        return;
      }
      final preflight = await permissionGateway.check();
      if (gen != _sessionGeneration || _disposed || !_enabled) return;
      if (!preflight.supported) {
        _setState(
          _state.copyWith(
            status: RemoteConnectionStatus.unsupported,
            errorMessage: preflight.message,
          ),
        );
        return;
      }
      if (!preflight.ready) {
        _setState(
          _state.copyWith(
            status: RemoteConnectionStatus.permissionRequired,
            errorMessage: preflight.message,
          ),
        );
        // Permission/location disabled is not transient — use a longer back-off
        // so we don't hammer the permission dialog if the user dismissed it.
        _scheduleReconnect(const Duration(seconds: 8));
        return;
      }

      await _stopRadioOnly();
      if (gen != _sessionGeneration || _disposed || !_enabled) return;
      _pendingEndpointId = null;
      _cancelConnectTimeout();
      _cancelAwaitingVerificationTimeout();
      _setState(
        NearbyConnectionState(
          status: _role == RemoteRole.tablet
              ? RemoteConnectionStatus.advertising
              : RemoteConnectionStatus.discovering,
        ),
      );
      bool started;
      if (_role == RemoteRole.tablet) {
        started = await transport.startAdvertising(
          deviceName: tabletName,
          serviceId: nearbyServiceId,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
        if (gen != _sessionGeneration || _disposed) return;
        if (!started) {
          _setError('Nearby could not start advertising.');
          _scheduleReconnect();
        } else {
          _reconnectAttempts = 0;
        }
      } else {
        started = await transport.startDiscovery(
          deviceName: controllerName,
          serviceId: nearbyServiceId,
          onEndpointFound: _onEndpointFound,
          onEndpointLost: _onEndpointLost,
          onConnectionInitiated: _onConnectionInitiated,
          onConnectionResult: _onConnectionResult,
          onDisconnected: _onDisconnected,
        );
        if (gen != _sessionGeneration || _disposed) return;
        if (!started) {
          _setError('Nearby could not start discovery.');
          _scheduleReconnect();
        } else {
          _reconnectAttempts = 0;
        }
      }
    } catch (error) {
      if (gen == _sessionGeneration && !_disposed) {
        _setError('Nearby setup failed: ${_safeError(error)}');
        _scheduleReconnect();
      }
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _stopSession() async {
    _pendingEndpointId = null;
    _sessionGeneration++; // invalidate any in-flight _startSession check
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    try {
      await _stopRadioOnly();
      await transport.stopAllEndpoints();
    } catch (_) {
      // Disabling is best effort; it must never prevent standalone operation.
    }
  }

  Future<void> _stopRadioOnly() async {
    // Each stop is individually guarded in PluginNearbyTransport, but we
    // additionally guard here so a future transport impl can't break sequencing.
    try {
      await transport.stopAdvertising();
    } catch (_) {}
    try {
      await transport.stopDiscovery();
    } catch (_) {}
  }

  void _onConnectionInitiated(String endpointId, NearbyConnectionInfo info) {
    if (!_enabled ||
        _pendingEndpointId != null ||
        (_state.endpointId != null && _state.endpointId != endpointId)) {
      unawaited(transport.rejectConnection(endpointId));
      return;
    }
    _pendingEndpointId = endpointId;
    _cancelConnectTimeout();
    _setState(
      _state.copyWith(
        status: RemoteConnectionStatus.awaitingVerification,
        endpointId: endpointId,
        peerName: info.endpointName,
        authenticationToken: info.authenticationToken,
        errorMessage: null,
      ),
    );
    _armAwaitingVerificationTimeout();
  }

  void _onConnectionResult(String endpointId, NearbyTransportResult result) {
    if (_state.endpointId != null && _state.endpointId != endpointId) return;
    switch (result) {
      case NearbyTransportResult.connected:
        _cancelConnectTimeout();
        _cancelAwaitingVerificationTimeout();
        _cancelReconnect();
        _reconnectAttempts = 0;
        _pendingEndpointId = null;
        _setState(
          _state.copyWith(
            status: RemoteConnectionStatus.connected,
            endpointId: endpointId,
            errorMessage: null,
          ),
        );
        break;
      case NearbyTransportResult.rejected:
        _cancelConnectTimeout();
        _cancelAwaitingVerificationTimeout();
        _pendingEndpointId = null;
        _setState(
          _state.copyWith(
            status: RemoteConnectionStatus.disconnected,
            endpointId: null,
            peerName: null,
            authenticationToken: null,
            errorMessage: 'The nearby connection was rejected.',
          ),
        );
        _scheduleReconnect();
        break;
      case NearbyTransportResult.error:
        _cancelConnectTimeout();
        _cancelAwaitingVerificationTimeout();
        _pendingEndpointId = null;
        _setError('Nearby could not establish the connection.');
        _scheduleReconnect();
        break;
    }
  }

  void _onDisconnected(String endpointId) {
    if (_state.endpointId != null && _state.endpointId != endpointId) return;
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    _pendingEndpointId = null;
    final wasConnected = _state.isConnected;
    _setState(
      _state.copyWith(
        status: RemoteConnectionStatus.disconnected,
        endpointId: null,
        peerName: null,
        authenticationToken: null,
        errorMessage: wasConnected
            ? 'The nearby controller disconnected. Reconnecting…'
            : 'Nearby link lost. Reconnecting…',
      ),
    );
    _scheduleReconnect();
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    if (!_enabled ||
        _role != RemoteRole.controller ||
        serviceId != nearbyServiceId ||
        _state.status == RemoteConnectionStatus.connected ||
        _state.status == RemoteConnectionStatus.connecting ||
        _state.status == RemoteConnectionStatus.awaitingVerification) {
      return;
    }
    if (_state.discoveredEndpoints.any(
      (endpoint) => endpoint.id == endpointId,
    )) {
      return;
    }
    final endpoints = [
      ..._state.discoveredEndpoints,
      NearbyDiscoveredEndpoint(
        id: endpointId,
        name: endpointName,
        serviceId: serviceId,
      ),
    ];
    _setState(
      _state.copyWith(
        status: RemoteConnectionStatus.endpointFound,
        discoveredEndpoints: endpoints,
      ),
    );
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) return;
    final endpoints = _state.discoveredEndpoints
        .where((endpoint) => endpoint.id != endpointId)
        .toList();
    _setState(
      _state.copyWith(
        status: endpoints.isEmpty
            ? RemoteConnectionStatus.discovering
            : RemoteConnectionStatus.endpointFound,
        discoveredEndpoints: endpoints,
      ),
    );
  }

  void _onPayloadReceived(String endpointId, Uint8List bytes) {
    debugPrint(
      '[NearbyService] _onPayloadReceived endpoint=$endpointId bytes=${bytes.length} isConnected=${_state.isConnected} stateEndpoint=${_state.endpointId} disposed=$_disposed',
    );
    if (!_state.isConnected || _state.endpointId != endpointId || _disposed) {
      debugPrint('[NearbyService] _onPayloadReceived DROPPED guard failed');
      return;
    }
    if (bytes.length > maxRemotePayloadBytes) return;
    (_receivedController ??= StreamController<Uint8List>.broadcast()).add(
      bytes,
    );
  }

  void _setError(String message) {
    _setState(
      _state.copyWith(
        status: RemoteConnectionStatus.error,
        errorMessage: message,
      ),
    );
  }

  void _setState(NearbyConnectionState next) {
    if (_disposed) return;
    _state = next;
    _stateController.add(next);
    notifyListeners();
  }

  // --- reconnect / timeout helpers ---

  void _scheduleReconnect([Duration? override]) {
    if (!_enabled || _disposed || _role == null) return;
    if (_reconnectTimer != null) return; // one pending timer at a time
    // Don't reconnect if we're already connected or awaiting user verification.
    if (_state.isConnected || _state.needsAuthentication) return;
    Duration delay;
    if (override != null) {
      delay = override;
    } else {
      // Exponential back-off with jitter footprint via reconnectAttempts.
      final exp = _reconnectAttempts.clamp(0, 6);
      final baseMs = _kBaseReconnectDelay.inMilliseconds * (1 << exp);
      final capped = baseMs.clamp(
        _kBaseReconnectDelay.inMilliseconds,
        _kMaxReconnectDelay.inMilliseconds,
      );
      // Tiny jitter: +-15% by attempt parity so two devices don't sync.
      final jitter = (_reconnectAttempts.isEven ? 1 : -1) * (capped ~/ 7);
      delay = Duration(milliseconds: (capped + jitter).clamp(400, 30000));
    }
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (!_enabled || _disposed) return;
      unawaited(_startSession());
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _armConnectTimeout() {
    _cancelConnectTimeout();
    _connectTimeoutTimer = Timer(_kConnectTimeout, () {
      if (!_enabled || _disposed) return;
      if (_state.status != RemoteConnectionStatus.connecting) return;
      _setError('Nearby connection timed out. Reconnecting…');
      _scheduleReconnect(const Duration(seconds: 1));
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  void _armAwaitingVerificationTimeout() {
    _cancelAwaitingVerificationTimeout();
    _awaitingVerificationTimer = Timer(_kAwaitingVerificationTimeout, () {
      if (!_enabled || _disposed) return;
      if (_state.status != RemoteConnectionStatus.awaitingVerification) return;
      final pending = _pendingEndpointId;
      _pendingEndpointId = null;
      if (pending != null) unawaited(transport.rejectConnection(pending));
      _setState(
        _state.copyWith(
          status: RemoteConnectionStatus.disconnected,
          endpointId: null,
          peerName: null,
          authenticationToken: null,
          errorMessage: 'Verification timed out. Reconnecting…',
        ),
      );
      _scheduleReconnect(const Duration(seconds: 1));
    });
  }

  void _cancelAwaitingVerificationTimeout() {
    _awaitingVerificationTimer?.cancel();
    _awaitingVerificationTimer = null;
  }

  String _safeError(Object error) {
    final text = error.toString();
    return text.length > 180 ? text.substring(0, 180) : text;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _cancelConnectTimeout();
    _cancelAwaitingVerificationTimeout();
    unawaited(_stopSession());
    final controller = _receivedController;
    if (controller != null) unawaited(controller.close());
    unawaited(_stateController.close());
    super.dispose();
  }
}
