import 'dart:convert';
import 'dart:typed_data';

import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/domain/yoyo_protocol.dart';

/// Version of the tablet/controller wire protocol.
const int remoteProtocolVersion = 1;

/// A command or snapshot is intentionally small. Nearby is a local transport,
/// but a limit is still important because malformed input must not become an
/// unbounded allocation or parsing operation.
const int maxRemotePayloadBytes = 16 * 1024;
const String nearbyServiceId = 'com.aistudio.yoyoir1.track';

/// Roles are selected in Settings. The tablet is always the authority; the
/// controller only mirrors tablet state and sends commands.
enum RemoteRole {
  tablet,
  controller;

  /// More descriptive aliases retained for callers that use the product terms.
  static const tabletHost = RemoteRole.tablet;
  static const host = RemoteRole.tablet;

  bool get isTablet => this == RemoteRole.tablet;
  bool get isController => this == RemoteRole.controller;
}

enum RemoteConnectionStatus {
  disabled,
  unsupported,
  permissionRequired,
  advertising,
  discovering,
  endpointFound,
  awaitingVerification,
  connecting,
  connected,
  disconnected,
  error,
}

enum RemoteCommandType {
  startTest('start_test'),
  pauseTest('pause_test'),
  resetTest('reset_test'),
  warnAthlete('warn_athlete'),
  eliminateAthlete('eliminate_athlete');

  const RemoteCommandType(this.wireName);
  final String wireName;

  static RemoteCommandType? fromWireName(String value) {
    for (final type in RemoteCommandType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

const Set<String> _commandCommonKeys = {
  'v',
  'type',
  'command',
  'requestId',
  'epoch',
};

/// Fields that are authority-owned and can never occur in a controller
/// command. Keeping this list close to the codec makes accidental protocol
/// widening easy to detect in review and tests.
const Set<String> forbiddenControllerCommandKeys = {
  'distance',
  'distanceMeters',
  'currentDistanceMeters',
  'level',
  'currentLevel',
  'shuttle',
  'currentShuttle',
  'currentShuttleNumber',
  'currentShuttleInLevel',
  'timestamp',
  'timestampMs',
  'warningTimestampMs',
  'finishTimestampMs',
  'elapsedTime',
  'elapsedMillis',
  'totalElapsedMillis',
  'currentShuttleElapsedMillis',
  'phase',
  'testState',
  'status',
  'sequence',
};

class RemoteProtocolException extends FormatException {
  RemoteProtocolException(super.message, [super.source]);
}

class _RemoteProtocol {
  static void checkMapKeys(
    Map<String, dynamic> map,
    Set<String> expected, {
    required String message,
  }) {
    if (map.length != expected.length ||
        map.keys.any((key) => !expected.contains(key))) {
      final unknown = map.keys.where((key) => !expected.contains(key)).toList();
      throw RemoteProtocolException(
        '$message; unknown or missing keys: ${unknown.join(', ')}',
      );
    }
  }

  static Map<String, dynamic> object(dynamic value, String message) {
    if (value is! Map) {
      throw RemoteProtocolException('$message must be a JSON object');
    }
    try {
      return Map<String, dynamic>.from(value);
    } on TypeError {
      throw RemoteProtocolException('$message must have string keys');
    }
  }

  static int intValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw RemoteProtocolException('$key must be an integer');
    }
    return value;
  }

  static int? optionalInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! int) {
      throw RemoteProtocolException('$key must be an integer or null');
    }
    return value;
  }

  static double? optionalDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      throw RemoteProtocolException('$key must be a finite number or null');
    }
    return value.toDouble();
  }

  static String stringValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String) {
      throw RemoteProtocolException('$key must be a string');
    }
    return value;
  }

  static String nonEmptyString(
    Map<String, dynamic> map,
    String key, {
    int maxLength = 128,
  }) {
    final value = stringValue(map, key);
    if (value.isEmpty || value.length > maxLength || value.contains('\u0000')) {
      throw RemoteProtocolException(
        '$key must be non-empty and at most $maxLength characters',
      );
    }
    return value;
  }

  static bool boolValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! bool) {
      throw RemoteProtocolException('$key must be a boolean');
    }
    return value;
  }

  static int version(Map<String, dynamic> map) {
    final version = intValue(map, 'v');
    if (version != remoteProtocolVersion) {
      throw RemoteProtocolException('unsupported protocol version: $version');
    }
    return version;
  }

  static Uint8List encode(Map<String, dynamic> map) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(map)));
    if (bytes.length > maxRemotePayloadBytes) {
      throw RemoteProtocolException(
        'payload exceeds $maxRemotePayloadBytes bytes',
      );
    }
    return bytes;
  }

  static Map<String, dynamic> decodeBytes(Uint8List bytes) {
    if (bytes.length > maxRemotePayloadBytes) {
      throw RemoteProtocolException(
        'payload exceeds $maxRemotePayloadBytes bytes',
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    } on FormatException catch (error) {
      throw RemoteProtocolException('invalid UTF-8 or JSON: ${error.message}');
    }
    return object(decoded, 'message');
  }

  static void nonNegative(int value, String key) {
    if (value < 0) throw RemoteProtocolException('$key must not be negative');
  }

  static String enumString(String value, Iterable<String> allowed, String key) {
    if (!allowed.contains(value)) {
      throw RemoteProtocolException('invalid $key: $value');
    }
    return value;
  }

  static T enumValue<T extends Enum>(
    Map<String, dynamic> map,
    String key,
    List<T> values,
  ) {
    final raw = stringValue(map, key);
    final allowed = values.map((v) => v.name);
    enumString(raw, allowed, key);
    return values.byName(raw);
  }

  static List<Map<String, dynamic>> boundedList(
    Map<String, dynamic> map,
    String key, {
    int maxLength = 256,
  }) {
    final raw = map[key];
    if (raw is! List || raw.length > maxLength) {
      throw RemoteProtocolException(
        '$key must be a list of at most $maxLength entries',
      );
    }
    return raw.map((e) => object(e, '$key entry')).toList();
  }
}

/// A controller-originated command. No test metrics or event time are
/// represented by this type, so they cannot be serialized accidentally.
class RemoteCommand {
  final int version;
  final RemoteCommandType command;
  final String requestId;
  final String epoch;
  final String? athleteId;

  const RemoteCommand._({
    required this.version,
    required this.command,
    required this.requestId,
    required this.epoch,
    this.athleteId,
  });

  factory RemoteCommand.startTest({
    required String requestId,
    required String epoch,
  }) =>
      RemoteCommand._validated(
        type: RemoteCommandType.startTest,
        requestId: requestId,
        epoch: epoch,
      );

  factory RemoteCommand.warnAthlete({
    required String requestId,
    required String epoch,
    required String athleteId,
  }) =>
      RemoteCommand._validated(
        type: RemoteCommandType.warnAthlete,
        requestId: requestId,
        epoch: epoch,
        athleteId: athleteId,
      );

  factory RemoteCommand.eliminateAthlete({
    required String requestId,
    required String epoch,
    required String athleteId,
  }) =>
      RemoteCommand._validated(
        type: RemoteCommandType.eliminateAthlete,
        requestId: requestId,
        epoch: epoch,
        athleteId: athleteId,
      );

  factory RemoteCommand.pauseTest({
    required String requestId,
    required String epoch,
  }) =>
      RemoteCommand._validated(
        type: RemoteCommandType.pauseTest,
        requestId: requestId,
        epoch: epoch,
      );

  factory RemoteCommand.resetTest({
    required String requestId,
    required String epoch,
  }) =>
      RemoteCommand._validated(
        type: RemoteCommandType.resetTest,
        requestId: requestId,
        epoch: epoch,
      );

  factory RemoteCommand._validated({
    required RemoteCommandType type,
    required String requestId,
    required String epoch,
    String? athleteId,
  }) {
    _validateOpaque(requestId, 'requestId');
    _validateOpaque(epoch, 'epoch');
    if (athleteId != null) _validateOpaque(athleteId, 'athleteId');
    final needsAthlete = type == RemoteCommandType.warnAthlete ||
        type == RemoteCommandType.eliminateAthlete;
    if (needsAthlete && athleteId == null) {
      throw ArgumentError('athleteId is required for $type');
    }
    if (!needsAthlete && athleteId != null) {
      throw ArgumentError('athleteId is not allowed for $type');
    }
    return RemoteCommand._(
      version: remoteProtocolVersion,
      command: type,
      requestId: requestId,
      epoch: epoch,
      athleteId: athleteId,
    );
  }

  /// Convenience constructor for tests and transport adapters.
  factory RemoteCommand.fromMap(Map<String, dynamic> map) {
    final allowedKeys = {..._commandCommonKeys, 'athleteId'};
    if (map.keys.any((key) => !allowedKeys.contains(key)) ||
        !_commandCommonKeys.every(map.containsKey)) {
      throw RemoteProtocolException('command has unknown or missing keys');
    }
    _RemoteProtocol.version(map);
    if (_RemoteProtocol.stringValue(map, 'type') != 'command') {
      throw RemoteProtocolException('message type must be command');
    }

    final type = RemoteCommandType.fromWireName(
      _RemoteProtocol.stringValue(map, 'command'),
    );
    if (type == null) throw RemoteProtocolException('unknown command');

    final requestId = _RemoteProtocol.nonEmptyString(map, 'requestId');
    final epoch = _RemoteProtocol.nonEmptyString(map, 'epoch');
    final needsAthlete =
        type == RemoteCommandType.warnAthlete ||
        type == RemoteCommandType.eliminateAthlete;
    final expected = needsAthlete
        ? {..._commandCommonKeys, 'athleteId'}
        : _commandCommonKeys;
    _RemoteProtocol.checkMapKeys(map, expected, message: 'command');
    final athleteId = needsAthlete
        ? _RemoteProtocol.nonEmptyString(map, 'athleteId')
        : null;
    return RemoteCommand._(
      version: remoteProtocolVersion,
      command: type,
      requestId: requestId,
      epoch: epoch,
      athleteId: athleteId,
    );
  }

  factory RemoteCommand.fromBytes(Uint8List bytes) {
    return RemoteCommand.fromMap(_RemoteProtocol.decodeBytes(bytes));
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'v': version,
      'type': 'command',
      'command': command.wireName,
      'requestId': requestId,
      'epoch': epoch,
      if (athleteId != null) 'athleteId': athleteId,
    };
  }

  Uint8List encode() => _RemoteProtocol.encode(toMap());

  static void _validateOpaque(String value, String field) {
    if (value.isEmpty || value.length > 128 || value.contains('\u0000')) {
      throw ArgumentError(
        '$field must be non-empty and at most 128 characters',
      );
    }
  }
}

const Set<String> _commandResultKeys = {
  'v',
  'type',
  'requestId',
  'accepted',
  'reason',
};

const Set<String> remoteCommandResultReasons = {
  'applied',
  'not_connected',
  'wrong_role',
  'stale_epoch',
  'invalid_athlete',
  'invalid_test_state',
  'already_applied',
  'malformed',
};

class RemoteCommandResult {
  final int version;
  final String requestId;
  final bool accepted;
  final String reason;

  const RemoteCommandResult({
    this.version = remoteProtocolVersion,
    required this.requestId,
    required this.accepted,
    required this.reason,
  }) : assert(reason != 'applied' || accepted);

  factory RemoteCommandResult.applied(String requestId) {
    return RemoteCommandResult(
      requestId: requestId,
      accepted: true,
      reason: 'applied',
    );
  }

  factory RemoteCommandResult.rejected(String requestId, String reason) {
    if (!remoteCommandResultReasons.contains(reason) || reason == 'applied') {
      throw ArgumentError.value(reason, 'reason', 'Unknown rejection reason');
    }
    return RemoteCommandResult(
      requestId: requestId,
      accepted: false,
      reason: reason,
    );
  }

  factory RemoteCommandResult.fromMap(Map<String, dynamic> map) {
    _RemoteProtocol.checkMapKeys(
      map,
      _commandResultKeys,
      message: 'command result',
    );
    _RemoteProtocol.version(map);
    if (_RemoteProtocol.stringValue(map, 'type') != 'command_result') {
      throw RemoteProtocolException('message type must be command_result');
    }
    final requestId = _RemoteProtocol.nonEmptyString(map, 'requestId');
    final accepted = _RemoteProtocol.boolValue(map, 'accepted');
    final reason = _RemoteProtocol.stringValue(map, 'reason');
    if (!remoteCommandResultReasons.contains(reason) ||
        (accepted && reason != 'applied') ||
        (!accepted && reason == 'applied')) {
      throw RemoteProtocolException('invalid command result reason');
    }
    return RemoteCommandResult(
      requestId: requestId,
      accepted: accepted,
      reason: reason,
    );
  }

  factory RemoteCommandResult.fromBytes(Uint8List bytes) {
    return RemoteCommandResult.fromMap(_RemoteProtocol.decodeBytes(bytes));
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'v': version,
    'type': 'command_result',
    'requestId': requestId,
    'accepted': accepted,
    'reason': reason,
  };

  Uint8List encode() => _RemoteProtocol.encode(toMap());
}

class RemoteAthleteSnapshot {
  final String id;
  final String name;
  final bool isSelected;
  final AthleteStatus status;
  final int? warningDistanceMeters;
  final String? warningLevel;
  final int? warningShuttle;
  final int? warningTimestampMs;
  final int? finalDistanceMeters;
  final String? finalLevel;
  final int? finalShuttle;
  final int? finishTimestampMs;
  final int? rank;
  final double? vo2Max;

  const RemoteAthleteSnapshot({
    required this.id,
    required this.name,
    required this.isSelected,
    required this.status,
    this.warningDistanceMeters,
    this.warningLevel,
    this.warningShuttle,
    this.warningTimestampMs,
    this.finalDistanceMeters,
    this.finalLevel,
    this.finalShuttle,
    this.finishTimestampMs,
    this.rank,
    this.vo2Max,
  });

  factory RemoteAthleteSnapshot.fromAthlete(Athlete athlete) {
    return RemoteAthleteSnapshot(
      id: athlete.id,
      name: athlete.name,
      isSelected: athlete.isSelected,
      status: athlete.status,
      warningDistanceMeters: athlete.warningDistanceMeters,
      warningLevel: athlete.warningLevel,
      warningShuttle: athlete.warningShuttle,
      warningTimestampMs: athlete.warningTimestampMs,
      finalDistanceMeters: athlete.finalDistanceMeters,
      finalLevel: athlete.finalLevel,
      finalShuttle: athlete.finalShuttle,
      finishTimestampMs: athlete.finishTimestampMs,
      rank: athlete.rank,
      vo2Max: athlete.vo2Max,
    );
  }

  factory RemoteAthleteSnapshot.fromMap(Map<String, dynamic> map) {
    const keys = {
      'id',
      'name',
      'isSelected',
      'status',
      'warningDistanceMeters',
      'warningLevel',
      'warningShuttle',
      'warningTimestampMs',
      'finalDistanceMeters',
      'finalLevel',
      'finalShuttle',
      'finishTimestampMs',
      'rank',
      'vo2Max',
    };
    _RemoteProtocol.checkMapKeys(map, keys, message: 'athlete snapshot');
    final result = RemoteAthleteSnapshot(
      id: _RemoteProtocol.nonEmptyString(map, 'id'),
      name: _RemoteProtocol.nonEmptyString(map, 'name', maxLength: 256),
      isSelected: _RemoteProtocol.boolValue(map, 'isSelected'),
      status: _RemoteProtocol.enumValue(map, 'status', AthleteStatus.values),
      warningDistanceMeters: _RemoteProtocol.optionalInt(
        map,
        'warningDistanceMeters',
      ),
      warningLevel: _optionalLevel(map, 'warningLevel'),
      warningShuttle: _RemoteProtocol.optionalInt(map, 'warningShuttle'),
      warningTimestampMs: _RemoteProtocol.optionalInt(
        map,
        'warningTimestampMs',
      ),
      finalDistanceMeters: _RemoteProtocol.optionalInt(
        map,
        'finalDistanceMeters',
      ),
      finalLevel: _optionalLevel(map, 'finalLevel'),
      finalShuttle: _RemoteProtocol.optionalInt(map, 'finalShuttle'),
      finishTimestampMs: _RemoteProtocol.optionalInt(map, 'finishTimestampMs'),
      rank: _RemoteProtocol.optionalInt(map, 'rank'),
      vo2Max: _RemoteProtocol.optionalDouble(map, 'vo2Max'),
    );
    _checkOptionalNonNegative(
      result.warningDistanceMeters,
      'warningDistanceMeters',
    );
    _checkOptionalNonNegative(result.warningShuttle, 'warningShuttle');
    _checkOptionalNonNegative(result.warningTimestampMs, 'warningTimestampMs');
    _checkOptionalNonNegative(
      result.finalDistanceMeters,
      'finalDistanceMeters',
    );
    _checkOptionalNonNegative(result.finalShuttle, 'finalShuttle');
    _checkOptionalNonNegative(result.finishTimestampMs, 'finishTimestampMs');
    _checkOptionalNonNegative(result.rank, 'rank');
    return result;
  }

  Athlete toAthlete() => Athlete(
    id: id,
    name: name,
    isSelected: isSelected,
    status: status,
    warningDistanceMeters: warningDistanceMeters,
    warningLevel: warningLevel,
    warningShuttle: warningShuttle,
    warningTimestampMs: warningTimestampMs,
    finalDistanceMeters: finalDistanceMeters,
    finalLevel: finalLevel,
    finalShuttle: finalShuttle,
    finishTimestampMs: finishTimestampMs,
    rank: rank,
    vo2Max: vo2Max,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'isSelected': isSelected,
    'status': status.name,
    'warningDistanceMeters': warningDistanceMeters,
    'warningLevel': warningLevel,
    'warningShuttle': warningShuttle,
    'warningTimestampMs': warningTimestampMs,
    'finalDistanceMeters': finalDistanceMeters,
    'finalLevel': finalLevel,
    'finalShuttle': finalShuttle,
    'finishTimestampMs': finishTimestampMs,
    'rank': rank,
    'vo2Max': vo2Max,
  };
}

/// Read-only state published by the tablet. Authority fields intentionally
/// exist here but never on [RemoteCommand].
class RemoteTestSnapshot {
  final int version;
  final String epoch;
  final int sequence;
  final TestState testState;
  final ShuttlePhase phase;
  final int totalElapsedMillis;
  final int currentShuttleElapsedMillis;
  final int currentDistanceMeters;
  final String currentLevel;
  final int currentShuttleNumber;
  final int currentShuttleInLevel;
  final List<RemoteAthleteSnapshot> athletes;

  RemoteTestSnapshot({
    this.version = remoteProtocolVersion,
    required this.epoch,
    required this.sequence,
    required this.testState,
    required this.phase,
    required this.totalElapsedMillis,
    required this.currentShuttleElapsedMillis,
    required this.currentDistanceMeters,
    required this.currentLevel,
    required this.currentShuttleNumber,
    required this.currentShuttleInLevel,
    required List<RemoteAthleteSnapshot> athletes,
  }) : athletes = List.unmodifiable(athletes);

  factory RemoteTestSnapshot.fromState({
    required String epoch,
    required int sequence,
    required TestState testState,
    required ShuttlePhase phase,
    required int totalElapsedMillis,
    required int currentShuttleElapsedMillis,
    required int currentDistanceMeters,
    required YoYoShuttle shuttle,
    required List<Athlete> athletes,
  }) {
    return RemoteTestSnapshot(
      epoch: epoch,
      sequence: sequence,
      testState: testState,
      phase: phase,
      totalElapsedMillis: totalElapsedMillis,
      currentShuttleElapsedMillis: currentShuttleElapsedMillis,
      currentDistanceMeters: currentDistanceMeters,
      currentLevel: shuttle.levelDisplay,
      currentShuttleNumber: shuttle.shuttleNumber,
      currentShuttleInLevel: shuttle.shuttleInLevel,
      athletes: athletes.map(RemoteAthleteSnapshot.fromAthlete).toList(),
    );
  }

  factory RemoteTestSnapshot.fromMap(Map<String, dynamic> map) {
    const keys = {
      'v',
      'type',
      'epoch',
      'sequence',
      'testState',
      'phase',
      'totalElapsedMillis',
      'currentShuttleElapsedMillis',
      'currentDistanceMeters',
      'currentLevel',
      'currentShuttleNumber',
      'currentShuttleInLevel',
      'athletes',
    };
    _RemoteProtocol.checkMapKeys(map, keys, message: 'host state');
    _RemoteProtocol.version(map);
    if (_RemoteProtocol.stringValue(map, 'type') != 'host_state') {
      throw RemoteProtocolException('message type must be host_state');
    }
    final athletes = _RemoteProtocol.boundedList(map, 'athletes')
        .map((raw) => RemoteAthleteSnapshot.fromMap(raw))
        .toList();
    final result = RemoteTestSnapshot(
      epoch: _RemoteProtocol.nonEmptyString(map, 'epoch'),
      sequence: _RemoteProtocol.intValue(map, 'sequence'),
      testState: _RemoteProtocol.enumValue(map, 'testState', TestState.values),
      phase: _RemoteProtocol.enumValue(map, 'phase', ShuttlePhase.values),
      totalElapsedMillis: _RemoteProtocol.intValue(map, 'totalElapsedMillis'),
      currentShuttleElapsedMillis: _RemoteProtocol.intValue(
        map,
        'currentShuttleElapsedMillis',
      ),
      currentDistanceMeters: _RemoteProtocol.intValue(
        map,
        'currentDistanceMeters',
      ),
      currentLevel: _level(_RemoteProtocol.stringValue(map, 'currentLevel')),
      currentShuttleNumber: _RemoteProtocol.intValue(
        map,
        'currentShuttleNumber',
      ),
      currentShuttleInLevel: _RemoteProtocol.intValue(
        map,
        'currentShuttleInLevel',
      ),
      athletes: athletes,
    );
    _RemoteProtocol.nonNegative(result.sequence, 'sequence');
    _RemoteProtocol.nonNegative(
      result.totalElapsedMillis,
      'totalElapsedMillis',
    );
    _RemoteProtocol.nonNegative(
      result.currentShuttleElapsedMillis,
      'currentShuttleElapsedMillis',
    );
    _RemoteProtocol.nonNegative(
      result.currentDistanceMeters,
      'currentDistanceMeters',
    );
    _RemoteProtocol.nonNegative(
      result.currentShuttleNumber,
      'currentShuttleNumber',
    );
    _RemoteProtocol.nonNegative(
      result.currentShuttleInLevel,
      'currentShuttleInLevel',
    );
    return result;
  }

  factory RemoteTestSnapshot.fromBytes(Uint8List bytes) {
    return RemoteTestSnapshot.fromMap(_RemoteProtocol.decodeBytes(bytes));
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'v': version,
    'type': 'host_state',
    'epoch': epoch,
    'sequence': sequence,
    'testState': testState.name,
    'phase': phase.name,
    'totalElapsedMillis': totalElapsedMillis,
    'currentShuttleElapsedMillis': currentShuttleElapsedMillis,
    'currentDistanceMeters': currentDistanceMeters,
    'currentLevel': currentLevel,
    'currentShuttleNumber': currentShuttleNumber,
    'currentShuttleInLevel': currentShuttleInLevel,
    'athletes': athletes.map((athlete) => athlete.toMap()).toList(),
  };

  Uint8List encode() => _RemoteProtocol.encode(toMap());
}

typedef RemoteHostStateSnapshot = RemoteTestSnapshot;

/// Small static codec facade useful to transport implementations and tests.
class RemoteProtocolCodec {
  static Uint8List encodeCommand(RemoteCommand command) => command.encode();
  static RemoteCommand decodeCommand(Uint8List bytes) =>
      RemoteCommand.fromBytes(bytes);
  static Uint8List encodeCommandResult(RemoteCommandResult result) =>
      result.encode();
  static RemoteCommandResult decodeCommandResult(Uint8List bytes) =>
      RemoteCommandResult.fromBytes(bytes);
  static Uint8List encodeHostState(RemoteTestSnapshot snapshot) =>
      snapshot.encode();
  static RemoteTestSnapshot decodeHostState(Uint8List bytes) =>
      RemoteTestSnapshot.fromBytes(bytes);

  /// Dispatches a validated envelope. Unknown message types are rejected.
  static Object decode(Uint8List bytes) {
    final map = _RemoteProtocol.decodeBytes(bytes);
    final type = map['type'];
    if (type == 'command') return RemoteCommand.fromMap(map);
    if (type == 'command_result') return RemoteCommandResult.fromMap(map);
    if (type == 'host_state') return RemoteTestSnapshot.fromMap(map);
    throw RemoteProtocolException('unknown message type');
  }
}

// A concise alias reads naturally at call sites while retaining the explicit
// class name above for source discoverability.
typedef RemoteCodec = RemoteProtocolCodec;

String? _optionalLevel(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw RemoteProtocolException('$key must be a level string or null');
  }
  return _level(value);
}

String _level(String value) {
  if (value.length > 16 || !RegExp(r'^\d+\.\d+$').hasMatch(value)) {
    throw RemoteProtocolException('invalid level');
  }
  return value;
}

void _checkOptionalNonNegative(int? value, String key) {
  if (value != null) _RemoteProtocol.nonNegative(value, key);
}
