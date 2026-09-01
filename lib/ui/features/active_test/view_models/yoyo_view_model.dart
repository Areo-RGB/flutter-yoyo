import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/data/models/test_session.dart';
import 'package:yoyo_ir1_tracker/data/repositories/yoyo_repository.dart';
import 'package:yoyo_ir1_tracker/data/services/nearby_connection_service.dart';
import 'package:yoyo_ir1_tracker/data/services/remote_preferences.dart';
import 'package:yoyo_ir1_tracker/domain/remote_messages.dart';
import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';
import 'package:yoyo_ir1_tracker/domain/session_export.dart';
import 'package:yoyo_ir1_tracker/domain/test_runtime.dart';
import 'package:yoyo_ir1_tracker/domain/yoyo_protocol.dart';
import 'package:yoyo_ir1_tracker/utils/sound_helper.dart';

enum AppTab { setup, live, leaderboard, tabelle, history, settings }

class AthleteUndoAction {
  final String athleteId;
  final Athlete previousState;
  final String description;

  AthleteUndoAction({
    required this.athleteId,
    required this.previousState,
    required this.description,
  });
}

class YoYoUiState {
  final TestState testState;
  final int currentShuttleIndex;
  final List<Athlete> athletes;
  final int totalElapsedMillis;
  final int currentShuttleElapsedMillis;
  final ShuttlePhase currentPhase;
  final bool isSoundEnabled;
  final double volumeBoost;
  final bool isBoostEnabled;
  final int? sessionSavedId;
  final List<AthleteUndoAction> undoStack;
  final AppTab activeTab;

  // Remote state is a session-only mirror/configuration surface. A controller
  // must render remoteSnapshot instead of the host's local timer fields.
  final RemoteRole remoteRole;
  final bool remoteEnabled;
  final NearbyConnectionState remoteConnection;
  final RemoteTestSnapshot? remoteSnapshot;
  final bool remoteSnapshotStale;
  final Set<String> pendingRemoteRequestIds;
  final String? lastRemoteCommandMessage;

  YoYoUiState({
    this.testState = TestState.idle,
    this.currentShuttleIndex = 0,
    this.athletes = const [],
    this.totalElapsedMillis = 0,
    this.currentShuttleElapsedMillis = 0,
    this.currentPhase = ShuttlePhase.running,
    this.isSoundEnabled = true,
    this.volumeBoost = 1.0,
    this.isBoostEnabled = false,
    this.sessionSavedId,
    this.undoStack = const [],
    this.activeTab = AppTab.setup,
    this.remoteRole = RemoteRole.tablet,
    this.remoteEnabled = false,
    this.remoteConnection = const NearbyConnectionState(),
    this.remoteSnapshot,
    this.remoteSnapshotStale = false,
    this.pendingRemoteRequestIds = const {},
    this.lastRemoteCommandMessage,
  });

  YoYoUiState copyWith({
    TestState? testState,
    int? currentShuttleIndex,
    List<Athlete>? athletes,
    int? totalElapsedMillis,
    int? currentShuttleElapsedMillis,
    ShuttlePhase? currentPhase,
    bool? isSoundEnabled,
    double? volumeBoost,
    bool? isBoostEnabled,
    Object? sessionSavedId = _unset,
    List<AthleteUndoAction>? undoStack,
    AppTab? activeTab,
    RemoteRole? remoteRole,
    bool? remoteEnabled,
    NearbyConnectionState? remoteConnection,
    Object? remoteSnapshot = _unset,
    bool? remoteSnapshotStale,
    Set<String>? pendingRemoteRequestIds,
    Object? lastRemoteCommandMessage = _unset,
  }) {
    return YoYoUiState(
      testState: testState ?? this.testState,
      currentShuttleIndex: currentShuttleIndex ?? this.currentShuttleIndex,
      athletes: athletes ?? this.athletes,
      totalElapsedMillis: totalElapsedMillis ?? this.totalElapsedMillis,
      currentShuttleElapsedMillis:
          currentShuttleElapsedMillis ?? this.currentShuttleElapsedMillis,
      currentPhase: currentPhase ?? this.currentPhase,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      isBoostEnabled: isBoostEnabled ?? this.isBoostEnabled,
      sessionSavedId: identical(sessionSavedId, _unset)
          ? this.sessionSavedId
          : sessionSavedId as int?,
      undoStack: undoStack ?? this.undoStack,
      activeTab: activeTab ?? this.activeTab,
      remoteRole: remoteRole ?? this.remoteRole,
      remoteEnabled: remoteEnabled ?? this.remoteEnabled,
      remoteConnection: remoteConnection ?? this.remoteConnection,
      remoteSnapshot: identical(remoteSnapshot, _unset)
          ? this.remoteSnapshot
          : remoteSnapshot as RemoteTestSnapshot?,
      remoteSnapshotStale: remoteSnapshotStale ?? this.remoteSnapshotStale,
      pendingRemoteRequestIds:
          pendingRemoteRequestIds ?? this.pendingRemoteRequestIds,
      lastRemoteCommandMessage: identical(lastRemoteCommandMessage, _unset)
          ? this.lastRemoteCommandMessage
          : lastRemoteCommandMessage as String?,
    );
  }

  YoYoShuttle get currentShuttle =>
      YoYoProtocol.shuttles[currentShuttleIndex.clamp(
        0,
        YoYoProtocol.shuttles.length - 1,
      )];

  List<Athlete> get selectedAthletes =>
      athletes.where((athlete) => athlete.isSelected).toList();

  int get currentDistanceMeters {
    if (testState == TestState.idle) return 0;
    if (testState == TestState.completed) {
      return YoYoProtocol.shuttles.length * 40;
    }
    if (currentPhase == ShuttlePhase.recovery) {
      return (currentShuttleIndex + 1) * 40;
    }
    return currentShuttleIndex * 40;
  }

  int get activeRunnersCount => selectedAthletes
      .where(
        (athlete) =>
            athlete.status == AthleteStatus.running ||
            athlete.status == AthleteStatus.warned,
      )
      .length;

  int get warnedRunnersCount => selectedAthletes
      .where((athlete) => athlete.status == AthleteStatus.warned)
      .length;

  int get eliminatedRunnersCount => selectedAthletes
      .where((athlete) => athlete.status == AthleteStatus.eliminated)
      .length;

  bool get isAllAthletesFinished =>
      selectedAthletes.isNotEmpty && activeRunnersCount == 0;

  double get runningPhaseRemainingSeconds {
    final remaining =
        currentShuttle.runDurationSeconds -
        (currentShuttleElapsedMillis / 1000.0);
    return remaining > 0 ? remaining : 0.0;
  }

  double get recoveryPhaseRemainingSeconds {
    final totalDuration = currentShuttle.runDurationSeconds + 10.0;
    final remaining = totalDuration - (currentShuttleElapsedMillis / 1000.0);
    return remaining > 0 ? remaining : 0.0;
  }

  double get phaseProgressFraction {
    if (currentPhase == ShuttlePhase.running) {
      return ((currentShuttleElapsedMillis / 1000.0) /
              currentShuttle.runDurationSeconds)
          .clamp(0.0, 1.0);
    }
    final recoveryElapsed =
        (currentShuttleElapsedMillis / 1000.0) -
        currentShuttle.runDurationSeconds;
    return (recoveryElapsed / 10.0).clamp(0.0, 1.0);
  }

  bool get isController => remoteRole == RemoteRole.controller;
  bool get remoteCommandsAvailable =>
      isController &&
      remoteEnabled &&
      remoteConnection.isConnected &&
      !remoteSnapshotStale &&
      remoteSnapshot != null;
}

const Object _unset = Object();

class YoYoViewModel extends ChangeNotifier {
  final YoYoRepository repository;
  final SoundHelper soundHelper;
  final NearbyConnectionService nearbyService;
  final RemotePreferences remotePreferences;
  final DateTime Function() _clock;
  bool _remotePrefsLoaded = false;
  bool _autoConnectEnabled = true;
  String? _lastPeerName;
  bool _verifiedOnce = false;

  YoYoUiState _state = YoYoUiState(athletes: Athlete.createDefaultRoster());
  Timer? _timer;
  Timer? _snapshotTimer;
  Timer? _heartbeatTimer;
  Timer? _staleSnapshotTimer;
  int _runningSinceMs = 0;
  int _elapsedBeforePauseMs = 0;
  int _lastTickTime = 0;
  int _snapshotSequence = 0;
  late String _remoteEpoch;
  final Set<String> _handledRemoteRequestIds = <String>{};
  final Map<String, RemoteCommandResult> _remoteResultsByRequestId =
      <String, RemoteCommandResult>{};
  final Map<String, Timer> _commandTimeoutTimers = <String, Timer>{};
  StreamSubscription<NearbyConnectionState>? _connectionSubscription;
  StreamSubscription<Uint8List>? _payloadSubscription;
  bool _disposed = false;

  YoYoUiState get state => _state;
  Stream<List<SessionWithResults>> get savedSessions => repository.allSessions;

  YoYoViewModel({
    required this.repository,
    required this.soundHelper,
    NearbyConnectionService? nearbyService,
    RemotePreferences? remotePreferences,
    DateTime Function()? clock,
    int Function()? nowMilliseconds,
  }) : nearbyService = nearbyService ?? NearbyConnectionService(),
       remotePreferences = remotePreferences ?? RemotePreferences(),
       _clock =
           clock ??
           (nowMilliseconds == null
               ? DateTime.now
               : () => DateTime.fromMillisecondsSinceEpoch(nowMilliseconds())) {
    _remoteEpoch = _newOpaqueToken();
    _connectionSubscription = this.nearbyService.stateChanges.listen((
      connection,
    ) {
      _onConnectionStateChanged(connection);
    });
    _payloadSubscription = this.nearbyService.receivedBytes.listen((bytes) {
      unawaited(handleRemotePayload(bytes));
    });
    // Keep state in sync for a service supplied by an integration test that
    // already has a lifecycle state before constructing the view model.
    _onConnectionStateChanged(this.nearbyService.state);
    unawaited(_loadPersistedRemoteSettings());
  }

  Future<void> _loadPersistedRemoteSettings() async {
    try {
      final loaded = await remotePreferences.load();
      _autoConnectEnabled = loaded.autoConnect;
      _lastPeerName = loaded.lastPeerName;
      _verifiedOnce = loaded.verifiedOnce;
      if (_disposed) return;
      _state = _state.copyWith(remoteRole: loaded.role);
      notifyListeners();
      if (loaded.enabled) {
        await setRemoteEnabled(true);
      }
      _remotePrefsLoaded = true;
    } catch (_) {
      _remotePrefsLoaded = true;
    }
  }

  /// Starts or resumes a local tablet test. On a controller this only sends
  /// the allowlisted start command; it never starts a local ticker or audio.
  void startTest() => _runOrRequest(
        commandType: RemoteCommandType.startTest,
        local: _startTestLocally,
        remote: requestRemoteStart,
      );

  void _startTestLocally() {
    if (_state.testState == TestState.idle) {
      if (_state.selectedAthletes.isEmpty) return;
      _beginNewHostEpoch();
      _elapsedBeforePauseMs = 0;
      _runningSinceMs = _nowMilliseconds();
      _state = _state.copyWith(
        testState: TestState.running,
        activeTab: AppTab.leaderboard,
        currentPhase: ShuttlePhase.running,
        currentShuttleElapsedMillis: 0,
        totalElapsedMillis: 0,
        currentShuttleIndex: 0,
        lastRemoteCommandMessage: null,
      );
      if (_state.isSoundEnabled) soundHelper.startAudioTrack();
      _startTicker();
      notifyListeners();
      _publishHostSnapshot(immediate: true);
    } else if (_state.testState == TestState.paused) {
      _resumeTestLocally();
    }
  }

  void pauseTest() => _runOrRequest(
        commandType: RemoteCommandType.pauseTest,
        local: _pauseTestLocally,
        remote: requestRemotePause,
      );

  void _pauseTestLocally() {
    if (_state.testState != TestState.running) return;
    _timer?.cancel();
    // Freeze elapsed: accumulate time up to now.
    _elapsedBeforePauseMs = _currentElapsedMs();
    _runningSinceMs = 0;
    soundHelper.pauseAudioTrack();
    _state = _state.copyWith(testState: TestState.paused);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void resumeTest() => _runOrRequest(
        commandType: RemoteCommandType.startTest,
        local: _resumeTestLocally,
        remote: requestRemoteStart,
      );

  void _resumeTestLocally() {
    if (_state.testState != TestState.paused) return;
    _state = _state.copyWith(testState: TestState.running);
    if (_state.isSoundEnabled) soundHelper.resumeAudioTrack();
    _runningSinceMs = _nowMilliseconds();
    _startTicker();
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void stopAndFinishTest() {
    if (_isController) return;
    _timer?.cancel();
    _runningSinceMs = 0;
    soundHelper.stopAudioTrack();

    final receipt = _captureHostMetrics();
    final updatedAthletes = _state.athletes.map((athlete) {
      if (athlete.isSelected && athlete.status != AthleteStatus.eliminated) {
        return athlete.copyWith(
          status: AthleteStatus.eliminated,
          finalDistanceMeters: receipt.distanceMeters,
          finalLevel: receipt.level,
          finalShuttle: receipt.shuttleInLevel,
          vo2Max: YoYoProtocol.calculateVo2Max(receipt.distanceMeters),
          finishTimestampMs: receipt.timestampMs,
        );
      }
      return athlete;
    }).toList();

    _state = _state.copyWith(
      testState: TestState.completed,
      athletes: _calculateRanks(updatedAthletes),
    );
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  /// Finishes the test and persists the results to the local history DB.
  /// Tablet only — controller finishing is not meaningful, the tablet is the
  /// authority. Guarded against double-save via [sessionSavedId].
  Future<void> finishAndSaveTest() async {
    if (_isController) {
      return;
    }
    if (_state.testState != TestState.running &&
        _state.testState != TestState.paused) {
      return;
    }
    if (_state.selectedAthletes.isEmpty) {
      return;
    }
    // If already completed (e.g. auto-finish) just save.
    if (_state.testState != TestState.completed) {
      stopAndFinishTest();
    }
    if (_state.sessionSavedId != null) {
      return;
    }
    await saveTestSession();
  }

  void resetTest() => _runOrRequest(
        commandType: RemoteCommandType.resetTest,
        local: _resetTestLocally,
        remote: requestRemoteReset,
      );

  void _resetTestLocally() {
    _timer?.cancel();
    _runningSinceMs = 0;
    _elapsedBeforePauseMs = 0;
    soundHelper.stopAudioTrack();
    _beginNewHostEpoch();
    final resetAthletes = _state.athletes
        .map(
          (athlete) => athlete.copyWith(
            status: AthleteStatus.running,
            warningDistanceMeters: null,
            warningLevel: null,
            warningShuttle: null,
            warningTimestampMs: null,
            finalDistanceMeters: null,
            finalLevel: null,
            finalShuttle: null,
            rank: null,
            vo2Max: null,
            finishTimestampMs: null,
          ),
        )
        .toList();

    _state = YoYoUiState(
      athletes: resetAthletes,
      isSoundEnabled: _state.isSoundEnabled,
      isBoostEnabled: _state.isBoostEnabled,
      volumeBoost: _state.volumeBoost,
      activeTab: AppTab.setup,
      remoteRole: _state.remoteRole,
      remoteEnabled: _state.remoteEnabled,
      remoteConnection: _state.remoteConnection,
    );
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void toggleAthleteSelected(String athleteId) {
    if (_isController || _state.testState != TestState.idle) return;
    final updated = _state.athletes
        .map(
          (athlete) => athlete.id == athleteId
              ? athlete.copyWith(isSelected: !athlete.isSelected)
              : athlete,
        )
        .toList();
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void selectAllAthletes() {
    if (_isController || _state.testState != TestState.idle) return;
    _state = _state.copyWith(
      athletes: _state.athletes
          .map((athlete) => athlete.copyWith(isSelected: true))
          .toList(),
    );
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void deselectAllAthletes() {
    if (_isController || _state.testState != TestState.idle) return;
    _state = _state.copyWith(
      athletes: _state.athletes
          .map((athlete) => athlete.copyWith(isSelected: false))
          .toList(),
    );
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void setActiveTab(AppTab tab) {
    _state = _state.copyWith(activeTab: tab);
    notifyListeners();
  }

  void toggleSound() {
    if (_isController) return;
    final nextSoundState = !_state.isSoundEnabled;
    _state = _state.copyWith(isSoundEnabled: nextSoundState);
    soundHelper.setSoundEnabledState(nextSoundState);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void setVolumeBoost(double boost) {
    if (_isController) return;
    _state = _state.copyWith(volumeBoost: boost.clamp(1.0, 3.0));
    notifyListeners();
  }

  void setBoostEnabled(bool enabled) {
    if (_isController) return;
    _state = _state.copyWith(isBoostEnabled: enabled);
    notifyListeners();
  }

  /// Local and remote warnings share this host transition. Receipt distance,
  /// level, shuttle and timestamp are sampled together on the tablet.
  void onAthleteClicked(Athlete athlete) {
    if (_isController) {
      if (athlete.status == AthleteStatus.running) {
        unawaited(requestRemoteWarning(athlete.id));
      } else if (athlete.status == AthleteStatus.warned) {
        unawaited(requestRemoteElimination(athlete.id));
      }
      return;
    }
    if (athlete.status == AthleteStatus.running) {
      _warnAthleteById(athlete.id);
    } else if (athlete.status == AthleteStatus.warned) {
      _eliminateAthleteById(athlete.id);
    }
  }

  void eliminateDirectly(Athlete athlete) {
    if (_isController) {
      if (athlete.status != AthleteStatus.eliminated) {
        unawaited(requestRemoteElimination(athlete.id));
      }
      return;
    }
    _eliminateAthleteById(athlete.id);
  }

  void _warnAthleteById(String athleteId) {
    if (!_hostActionStateAllowed) return;
    final athlete = _findSelectedAthlete(athleteId);
    if (athlete == null || athlete.status != AthleteStatus.running) return;
    final receipt = _captureHostMetrics();
    _recordUndoAction(athlete, 'Warned');
    final updated = athlete.copyWith(
      status: AthleteStatus.warned,
      warningDistanceMeters: receipt.distanceMeters,
      warningLevel: receipt.level,
      warningShuttle: receipt.shuttleInLevel,
      warningTimestampMs: receipt.timestampMs,
    );
    _updateSingleAthlete(updated);
    _commitHostAthletes(recalculateRanks: false);
  }

  void _eliminateAthleteById(String athleteId) {
    if (!_hostActionStateAllowed) return;
    final athlete = _findSelectedAthlete(athleteId);
    if (athlete == null || athlete.status == AthleteStatus.eliminated) return;
    final receipt = _captureHostMetrics();
    _recordUndoAction(athlete, 'Direct Elimination');
    final updated = athlete.copyWith(
      status: AthleteStatus.eliminated,
      warningDistanceMeters:
          athlete.warningDistanceMeters ?? receipt.distanceMeters,
      warningLevel: athlete.warningLevel ?? receipt.level,
      warningShuttle: athlete.warningShuttle ?? receipt.shuttleInLevel,
      warningTimestampMs: athlete.warningTimestampMs ?? receipt.timestampMs,
      finalDistanceMeters: receipt.distanceMeters,
      finalLevel: receipt.level,
      finalShuttle: receipt.shuttleInLevel,
      vo2Max: YoYoProtocol.calculateVo2Max(receipt.distanceMeters),
      finishTimestampMs: receipt.timestampMs,
    );
    _updateSingleAthlete(updated);
    _commitHostAthletes(recalculateRanks: true);
    _checkAutoFinish();
  }

  void undoLastAction() {
    if (_isController || _state.undoStack.isEmpty) return;
    final stack = List<AthleteUndoAction>.from(_state.undoStack);
    final lastAction = stack.removeLast();
    _updateSingleAthlete(lastAction.previousState);
    _state = _state.copyWith(undoStack: stack);
    _commitHostAthletes(recalculateRanks: true);
  }

  void undoAthlete(Athlete athlete) {
    if (_isController) return;
    if (athlete.status == AthleteStatus.eliminated) {
      _updateSingleAthlete(
        athlete.copyWith(
          status: athlete.warningDistanceMeters != null
              ? AthleteStatus.warned
              : AthleteStatus.running,
          finalDistanceMeters: null,
          finalLevel: null,
          finalShuttle: null,
          rank: null,
          vo2Max: null,
          finishTimestampMs: null,
        ),
      );
    } else if (athlete.status == AthleteStatus.warned) {
      _updateSingleAthlete(
        athlete.copyWith(
          status: AthleteStatus.running,
          warningDistanceMeters: null,
          warningLevel: null,
          warningShuttle: null,
          warningTimestampMs: null,
        ),
      );
    }
    _commitHostAthletes(recalculateRanks: true);
  }

  void updateRoster(List<String> names) {
    if (_isController) return;
    final newAthletes = names
        .asMap()
        .entries
        .map(
          (entry) => Athlete(
            id: _newOpaqueToken(),
            name: entry.value,
            isSelected: true,
          ),
        )
        .toList();
    _state = _state.copyWith(athletes: newAthletes);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void addAthlete(String name) {
    if (_isController) return;
    final updated = List<Athlete>.from(_state.athletes)
      ..add(Athlete(id: _newOpaqueToken(), name: name, isSelected: true));
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void removeAthlete(String id) {
    if (_isController) return;
    final updated = List<Athlete>.from(_state.athletes)
      ..removeWhere((athlete) => athlete.id == id);
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  void resetRosterToDefaults() {
    if (_isController) return;
    _state = _state.copyWith(athletes: Athlete.createDefaultRoster());
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  Future<void> saveTestSession({String? customTitle, String notes = ''}) async {
    if (_isController) return;
    final targetAthletes = _state.selectedAthletes;
    if (targetAthletes.isEmpty) return;

    final now = _clock();
    final title =
        customTitle ?? 'Yo-Yo Test ${DateFormat('MMM d, yyyy').format(now)}';
    final bestDist = targetAthletes.fold<int>(
      0,
      (maxDistance, athlete) => (athlete.finalDistanceMeters ?? 0) > maxDistance
          ? (athlete.finalDistanceMeters ?? 0)
          : maxDistance,
    );
    final bestAthlete = targetAthletes.firstWhere(
      (athlete) => (athlete.finalDistanceMeters ?? 0) == bestDist,
      orElse: () => targetAthletes.first,
    );
    final bestLevel =
        bestAthlete.finalLevel ?? _state.currentShuttle.levelDisplay;

    final session = TestSession(
      title: title,
      timestampMs: now.millisecondsSinceEpoch,
      durationSeconds: (_state.totalElapsedMillis / 1000).round(),
      maxDistanceAchieved: bestDist,
      maxLevelAchieved: bestLevel,
      totalAthletesCount: targetAthletes.length,
      completedAthletesCount: targetAthletes
          .where((athlete) => athlete.status == AthleteStatus.eliminated)
          .length,
      notes: notes,
    );

    final results = targetAthletes
        .map(
          (athlete) => AthleteResult(
            sessionId: 0,
            athleteName: athlete.name,
            finalDistanceMeters: athlete.finalDistanceMeters ?? 0,
            finalLevel: athlete.finalLevel ?? '5.1',
            finalShuttleNumber: athlete.finalShuttle ?? 1,
            warningDistanceMeters: athlete.warningDistanceMeters,
            warningLevel: athlete.warningLevel,
            rank: athlete.rank ?? 1,
            vo2Max: athlete.vo2Max ?? 0.0,
          ),
        )
        .toList();

    final id = await repository.saveSession(session, results);
    _state = _state.copyWith(sessionSavedId: id);
    notifyListeners();
  }

  Future<void> deleteSession(int sessionId) =>
      repository.deleteSession(sessionId);

  static const _exportService = SessionExportService();

  String generateCsvExport(List<Athlete> athletes) =>
      _exportService.generateCsvExport(athletes);

  String generateSummaryText(
    List<Athlete> athletes, {
    String sessionTitle = 'Yo-Yo IR1 Results',
  }) =>
      _exportService.generateSummaryText(
        athletes,
        sessionTitle: sessionTitle,
      );

  // ------------------------------------------------------------------------
  // Remote configuration and command API
  // ------------------------------------------------------------------------

  bool get _isController => _state.remoteRole == RemoteRole.controller;
  bool get _hostActionStateAllowed =>
      !_isController &&
      (_state.testState == TestState.running ||
          _state.testState == TestState.paused);

  void _runOrRequest({
    required RemoteCommandType commandType,
    required VoidCallback local,
    required Future<bool> Function() remote,
  }) {
    if (_isController) {
      unawaited(remote());
      return;
    }
    local();
  }

  Future<bool> setRemoteEnabled(bool enabled) async {
    if (enabled == _state.remoteEnabled) return true;
    if (_state.testState != TestState.idle &&
        _state.testState != TestState.completed) {
      _setRemoteMessage(
        'Disable or change remote role after the current test.',
      );
      return false;
    }
    final role = _state.remoteRole;
    await nearbyService.setEnabled(enabled, role: role);
    _state = _state.copyWith(
      remoteEnabled: enabled,
      remoteConnection: nearbyService.state,
      remoteSnapshotStale: enabled && _isController,
    );
    notifyListeners();
    if (_remotePrefsLoaded) unawaited(remotePreferences.saveEnabled(enabled));
    if (enabled && role == RemoteRole.tablet) {
      _publishHostSnapshot(immediate: true);
    }
    return true;
  }

  Future<bool> setRemoteRole(RemoteRole role) async {
    if (role == _state.remoteRole) return true;
    if (_state.testState != TestState.idle &&
        _state.testState != TestState.completed) {
      _setRemoteMessage('Remote role cannot change during a running test.');
      return false;
    }
    final wasEnabled = _state.remoteEnabled;
    if (wasEnabled) {
      await nearbyService.setEnabled(false, role: _state.remoteRole);
    }
    _state = _state.copyWith(
      remoteRole: role,
      remoteEnabled: false,
      remoteConnection: nearbyService.state,
      remoteSnapshot: null,
      remoteSnapshotStale: role == RemoteRole.controller,
      pendingRemoteRequestIds: <String>{},
    );
    notifyListeners();
    if (_remotePrefsLoaded) unawaited(remotePreferences.saveRole(role));
    if (_remotePrefsLoaded) unawaited(remotePreferences.saveEnabled(false));
    if (wasEnabled) {
      await nearbyService.setEnabled(true, role: role);
      _state = _state.copyWith(
        remoteEnabled: true,
        remoteConnection: nearbyService.state,
      );
      notifyListeners();
      if (_remotePrefsLoaded) unawaited(remotePreferences.saveEnabled(true));
      if (role == RemoteRole.tablet) _publishHostSnapshot(immediate: true);
    }
    return true;
  }

  Future<void> retryRemoteConnection() async {
    await nearbyService.retry();
    _state = _state.copyWith(remoteConnection: nearbyService.state);
    notifyListeners();
  }

  Future<void> connectToRemoteEndpoint(String endpointId) async {
    await nearbyService.connectToEndpoint(endpointId);
  }

  Future<void> confirmRemoteAuthentication(bool accepted) async {
    await nearbyService.confirmAuthentication(accepted);
  }

  Future<void> disconnectRemote() => nearbyService.disconnect();

  Future<bool> requestRemoteStart() async {
    final sent = await _sendControllerCommand(
      RemoteCommand.startTest(
        requestId: _newOpaqueToken(),
        epoch: _controllerEpoch,
      ),
    );
    if (sent && _isController) {
      _state = _state.copyWith(activeTab: AppTab.live);
      notifyListeners();
    }
    return sent;
  }

  Future<bool> requestRemoteWarning(String athleteId) {
    return _sendControllerCommand(
      RemoteCommand.warnAthlete(
        requestId: _newOpaqueToken(),
        epoch: _controllerEpoch,
        athleteId: athleteId,
      ),
    );
  }

  Future<bool> requestRemoteElimination(String athleteId) {
    return _sendControllerCommand(
      RemoteCommand.eliminateAthlete(
        requestId: _newOpaqueToken(),
        epoch: _controllerEpoch,
        athleteId: athleteId,
      ),
    );
  }

  Future<bool> requestRemotePause() {
    return _sendControllerCommand(
      RemoteCommand.pauseTest(
        requestId: _newOpaqueToken(),
        epoch: _controllerEpoch,
      ),
    );
  }

  Future<bool> requestRemoteReset() {
    return _sendControllerCommand(
      RemoteCommand.resetTest(
        requestId: _newOpaqueToken(),
        epoch: _controllerEpoch,
      ),
    );
  }

  /// Public transport seam for focused protocol/view-model tests.
  Future<bool> sendRemoteCommand(RemoteCommand command) =>
      _sendControllerCommand(command);

  String get _controllerEpoch => _state.remoteSnapshot?.epoch ?? _remoteEpoch;

  Future<bool> _sendControllerCommand(RemoteCommand command) async {
    if (!_isController || !_state.remoteCommandsAvailable) {
      _setRemoteMessage('Connect to the tablet before sending a command.');
      return false;
    }
    final pending = Set<String>.from(_state.pendingRemoteRequestIds)
      ..add(command.requestId);
    _state = _state.copyWith(
      pendingRemoteRequestIds: pending,
      lastRemoteCommandMessage: null,
    );
    notifyListeners();
    _armCommandTimeout(command.requestId);
    // One immediate attempt + one short retry on transient transport pull.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await nearbyService.sendBytes(command.encode());
        return true;
      } catch (error) {
        if (attempt == 1) {
          _cancelCommandTimeout(command.requestId);
          pending.remove(command.requestId);
          _state = _state.copyWith(
            pendingRemoteRequestIds: Set<String>.from(pending),
            lastRemoteCommandMessage:
                'Command could not be sent: ${_safeError(error)}',
          );
          notifyListeners();
          return false;
        }
        // Transient glitch during a radio hop — small backoff before retry.
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!_state.remoteCommandsAvailable ||
            _state.remoteConnection.isConnected == false) {
          _cancelCommandTimeout(command.requestId);
          pending.remove(command.requestId);
          _state = _state.copyWith(
            pendingRemoteRequestIds: Set<String>.from(pending),
            lastRemoteCommandMessage: 'Connection lost before command sent.',
          );
          notifyListeners();
          return false;
        }
      }
    }
    return false;
  }

  /// Decodes a received payload and applies only tablet-originated snapshots
  /// or command acknowledgements. Malformed payloads have no side effects.
  Future<RemoteCommandResult?> handleRemotePayload(Uint8List bytes) async {
    debugPrint(
      '[YoYoVM] handleRemotePayload bytes=${bytes.length} isController=$_isController role=${_state.remoteRole} connected=${nearbyService.state.isConnected}',
    );
    Object message;
    try {
      message = RemoteProtocolCodec.decode(bytes);
      debugPrint('[YoYoVM] decoded message type=${message.runtimeType}');
    } on RemoteProtocolException catch (e) {
      debugPrint('[YoYoVM] decode failed: $e bytes=${bytes.length}');
      return null;
    }
    if (message is RemoteCommand) {
      return handleRemoteCommand(message);
    }
    if (message is RemoteCommandResult) {
      _handleRemoteCommandResult(message);
    } else if (message is RemoteTestSnapshot) {
      _handleRemoteSnapshot(message);
    }
    return null;
  }

  /// Handles a controller command on the tablet. All authority values are
  /// sampled here, never read from the command.
  Future<RemoteCommandResult> handleRemoteCommand(RemoteCommand command) async {
    RemoteCommandResult result;
    if (_isController || !_state.remoteRole.isTablet) {
      result = RemoteCommandResult.rejected(command.requestId, 'wrong_role');
    } else if (command.epoch != _remoteEpoch) {
      result = RemoteCommandResult.rejected(command.requestId, 'stale_epoch');
    } else if (_handledRemoteRequestIds.contains(command.requestId)) {
      result =
          _remoteResultsByRequestId[command.requestId] ??
          RemoteCommandResult.rejected(command.requestId, 'already_applied');
    } else {
      result = _applyRemoteCommand(command);
      _handledRemoteRequestIds.add(command.requestId);
      _remoteResultsByRequestId[command.requestId] = result;
    }

    if (nearbyService.state.isConnected) {
      try {
        await nearbyService.sendBytes(result.encode());
        if (result.accepted) _publishHostSnapshot(immediate: true);
      } catch (_) {
        // The command has already been applied locally. A lost link must not
        // roll back the host; the next connection receives a fresh snapshot.
      }
    }
    return result;
  }

  RemoteCommandResult _applyRemoteCommand(RemoteCommand command) {
    switch (command.command) {
      case RemoteCommandType.startTest:
        if (_state.selectedAthletes.isEmpty ||
            (_state.testState != TestState.idle &&
                _state.testState != TestState.paused)) {
          return RemoteCommandResult.rejected(
            command.requestId,
            'invalid_test_state',
          );
        }
        _startTestLocally();
        return RemoteCommandResult.applied(command.requestId);
      case RemoteCommandType.warnAthlete:
        final athlete = command.athleteId == null
            ? null
            : _findSelectedAthlete(command.athleteId!);
        if (!_hostActionStateAllowed ||
            athlete == null ||
            athlete.status != AthleteStatus.running) {
          return RemoteCommandResult.rejected(
            command.requestId,
            athlete == null ? 'invalid_athlete' : 'invalid_test_state',
          );
        }
        _warnAthleteById(athlete.id);
        return RemoteCommandResult.applied(command.requestId);
      case RemoteCommandType.eliminateAthlete:
        final athlete = command.athleteId == null
            ? null
            : _findSelectedAthlete(command.athleteId!);
        if (!_hostActionStateAllowed ||
            athlete == null ||
            athlete.status == AthleteStatus.eliminated) {
          return RemoteCommandResult.rejected(
            command.requestId,
            athlete == null ? 'invalid_athlete' : 'invalid_test_state',
          );
        }
        _eliminateAthleteById(athlete.id);
        return RemoteCommandResult.applied(command.requestId);
      case RemoteCommandType.pauseTest:
        if (_state.testState != TestState.running) {
          return RemoteCommandResult.rejected(
            command.requestId,
            'invalid_test_state',
          );
        }
        _pauseTestLocally();
        return RemoteCommandResult.applied(command.requestId);
      case RemoteCommandType.resetTest:
        // Reset is allowed from any non-idle state; tablet samples its own epoch/timestamp.
        _resetTestLocally();
        return RemoteCommandResult.applied(command.requestId);
    }
  }

  void _handleRemoteCommandResult(RemoteCommandResult result) {
    if (!_isController) return;
    if (!_state.pendingRemoteRequestIds.contains(result.requestId)) return;
    _cancelCommandTimeout(result.requestId);
    final pending = Set<String>.from(_state.pendingRemoteRequestIds)
      ..remove(result.requestId);
    final RemoteUiMessage message = result.accepted
        ? const RemoteCommandApplied()
        : RemoteCommandRejected(result.reason);
    _state = _state.copyWith(
      pendingRemoteRequestIds: pending,
      lastRemoteCommandMessage: message.toDisplayString(),
    );
    notifyListeners();
  }

  void _handleRemoteSnapshot(RemoteTestSnapshot snapshot) {
    debugPrint(
      '[YoYoVM] _handleRemoteSnapshot epoch=${snapshot.epoch.substring(0, 6)} seq=${snapshot.sequence} dist=${snapshot.currentDistanceMeters} state=${snapshot.testState} isController=$_isController',
    );
    if (!_isController) {
      debugPrint('[YoYoVM] _handleRemoteSnapshot ignored: not controller');
      return;
    }
    final current = _state.remoteSnapshot;
    if (current != null &&
        current.epoch == snapshot.epoch &&
        snapshot.sequence <= current.sequence) {
      debugPrint(
        '[YoYoVM] _handleRemoteSnapshot dropped stale seq ${snapshot.sequence} <= ${current.sequence}',
      );
      return;
    }
    _remoteEpoch = snapshot.epoch;
    _snapshotSequence = snapshot.sequence;
    final mirroredAthletes = snapshot.athletes
        .map((athlete) => athlete.toAthlete())
        .toList();
    final shouldAutoSwitchToLive =
        snapshot.testState == TestState.running &&
        _state.activeTab != AppTab.live;
    // Anchor controller local clock to host snapshot, then let local ticker
    // free-run (phase/recovery transitions happen on-device). Re-anchoring
    // on each snapshot keeps drift bounded without requiring exact sync.
    final shuttleIndex =
        (snapshot.currentShuttleNumber - 1).clamp(0, YoYoProtocol.shuttles.length - 1);
    _state = _state.copyWith(
      testState: snapshot.testState,
      currentShuttleIndex: shuttleIndex,
      currentPhase: snapshot.phase,
      totalElapsedMillis: snapshot.totalElapsedMillis,
      currentShuttleElapsedMillis: snapshot.currentShuttleElapsedMillis,
      athletes: mirroredAthletes,
      remoteSnapshot: snapshot,
      remoteSnapshotStale: false,
      lastRemoteCommandMessage: null,
      activeTab: shouldAutoSwitchToLive ? AppTab.live : null,
    );
    notifyListeners();
    _armStaleTimer();
    // Drive local ticker for smooth countdown even between snapshots.
    if (snapshot.testState == TestState.running && _timer == null) {
      _lastTickTime = _nowMilliseconds();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final now = _nowMilliseconds();
        final delta = now - _lastTickTime;
        _lastTickTime = now;
        _tickForController(delta < 0 ? 0 : delta);
      });
    } else if (snapshot.testState != TestState.running) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onConnectionStateChanged(NearbyConnectionState connection) {
    if (_disposed) return;
    final wasConnected = _state.remoteConnection.isConnected;
    final connected = connection.isConnected;
    // Clear timed-out command trackers on disconnect so we don't leak timers.
    if (!connected && wasConnected) {
      for (final id in _state.pendingRemoteRequestIds) {
        _cancelCommandTimeout(id);
      }
      _timer?.cancel();
      _timer = null;
    }
    _state = _state.copyWith(
      remoteConnection: connection,
      remoteSnapshotStale: _isController && !connected,
      remoteSnapshot: _isController && !connected
          ? null
          : _state.remoteSnapshot,
      pendingRemoteRequestIds: connected
          ? _state.pendingRemoteRequestIds
          : <String>{},
      lastRemoteCommandMessage: !connected && wasConnected
          ? const RemoteConnectionLost().toDisplayString()
          : _state.lastRemoteCommandMessage,
    );
    notifyListeners();
    // Tablet heartbeat: publish an authoritative snapshot periodically even
    // when idle, so the controller can detect a silent link loss.
    // Controller stale timer: mark snapshot stale if no heartbeat arrives.
    if (connected) {
      if (_state.remoteRole == RemoteRole.tablet) {
        _startTabletHeartbeat();
      } else {
        _armStaleTimer();
      }
    } else {
      _stopTabletHeartbeat();
      _cancelStaleTimer();
    }
    if (connected && !wasConnected) {
      _lastPeerName = connection.peerName ?? _lastPeerName;
      if (_lastPeerName != null) {
        unawaited(remotePreferences.saveLastPeerName(_lastPeerName));
      }
      if (!_verifiedOnce) {
        _verifiedOnce = true;
        unawaited(remotePreferences.saveVerifiedOnce(true));
      }
      if (_state.remoteRole == RemoteRole.tablet) {
        _publishHostSnapshot(immediate: true);
      }
    }
    // Persistent auto-reconnect for fixed device pairs.
    if (_remotePrefsLoaded && _autoConnectEnabled && _state.remoteEnabled) {
      if (_isController &&
          connection.status == RemoteConnectionStatus.endpointFound &&
          connection.discoveredEndpoints.isNotEmpty) {
        final target = connection.discoveredEndpoints.first;
        unawaited(connectToRemoteEndpoint(target.id));
      }
      if (connection.needsAuthentication &&
          _verifiedOnce &&
          _lastPeerName != null &&
          connection.peerName == _lastPeerName) {
        unawaited(confirmRemoteAuthentication(true));
      }
    }
  }

  int _currentElapsedMs() {
    if (_runningSinceMs == 0) return _elapsedBeforePauseMs;
    return _elapsedBeforePauseMs + (_nowMilliseconds() - _runningSinceMs);
  }

  void _startTicker() {
    _timer?.cancel();
    if (_runningSinceMs == 0) _runningSinceMs = _nowMilliseconds();
    // Simple wall-clock timer: starts on signal, pauses, resumes. No audio sync.
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_isController || _state.testState != TestState.running) return;
      final elapsed = _currentElapsedMs();
      _syncFromElapsed(elapsed);
    });
  }

  void _syncFromElapsed(int elapsedMs) {
    if (_isController || _state.testState != TestState.running) return;
    final derived = _deriveFromElapsedMs(elapsedMs);
    final sameIndex = derived.index == _state.currentShuttleIndex;
    final samePhase = derived.phase == _state.currentPhase;
    final sameTotalSec = (derived.totalMs ~/ 1000) == (_state.totalElapsedMillis ~/ 1000);
    if (sameIndex && samePhase && sameTotalSec && _state.testState == derived.testState) {
      _state = _state.copyWith(
        totalElapsedMillis: derived.totalMs,
        currentShuttleElapsedMillis: derived.shuttleElapsedMs,
      );
      return;
    }
    _state = _state.copyWith(
      totalElapsedMillis: derived.totalMs,
      currentShuttleElapsedMillis: derived.shuttleElapsedMs,
      currentPhase: derived.phase,
      currentShuttleIndex: derived.index,
      testState: derived.testState,
    );
    if (derived.testState == TestState.completed) {
      _timer?.cancel();
      _runningSinceMs = 0;
      soundHelper.stopAudioTrack();
    }
    notifyListeners();
    _publishHostSnapshot();
  }

  ({int totalMs, int shuttleElapsedMs, ShuttlePhase phase, int index, TestState testState})
  _deriveFromElapsedMs(int elapsedMs) =>
      TestRuntime.deriveFromElapsedMs(elapsedMs);

  // --- tablet heartbeat / controller stale + command timeout helpers ---

  void _startTabletHeartbeat() {
    if (_heartbeatTimer != null) return;
    if (_isController || _disposed) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_disposed || _isController) return;
      if (!_state.remoteEnabled ||
          _state.remoteRole != RemoteRole.tablet ||
          !nearbyService.state.isConnected) {
        return;
      }
      // Idle/completed still need a liveness ping — running already streams.
      if (_state.testState != TestState.running) {
        _publishHostSnapshotNow();
      }
    });
  }

  void _stopTabletHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _armStaleTimer() {
    _cancelStaleTimer();
    if (!_isController || _disposed) return;
    _staleSnapshotTimer = Timer(const Duration(seconds: 8), () {
      if (_disposed || !_isController) return;
      if (_state.remoteSnapshot == null) return;
      if (!nearbyService.state.isConnected) return;
      _state = _state.copyWith(remoteSnapshotStale: true);
      notifyListeners();
    });
  }

  void _cancelStaleTimer() {
    _staleSnapshotTimer?.cancel();
    _staleSnapshotTimer = null;
  }

  void _armCommandTimeout(String requestId) {
    _cancelCommandTimeout(requestId);
    _commandTimeoutTimers[requestId] = Timer(
      const Duration(seconds: 6),
      () {
        _commandTimeoutTimers.remove(requestId);
        if (_disposed || !_isController) return;
        if (!_state.pendingRemoteRequestIds.contains(requestId)) return;
        final pending = Set<String>.from(_state.pendingRemoteRequestIds)
          ..remove(requestId);
        _state = _state.copyWith(
          pendingRemoteRequestIds: pending,
          lastRemoteCommandMessage:
              const RemoteCommandTimeout().toDisplayString(),
        );
        notifyListeners();
      },
    );
  }

  void _cancelCommandTimeout(String requestId) {
    final t = _commandTimeoutTimers.remove(requestId);
    t?.cancel();
  }

  void _cancelAllCommandTimeouts() {
    for (final t in _commandTimeoutTimers.values) {
      t.cancel();
    }
    _commandTimeoutTimers.clear();
  }

  void _tickForController(int deltaMillis) {
    if (_state.testState != TestState.running) return;
    var newTotal = _state.totalElapsedMillis + deltaMillis;
    var newShuttleElapsed = _state.currentShuttleElapsedMillis + deltaMillis;
    var newPhase = _state.currentPhase;
    var newIndex = _state.currentShuttleIndex;
    var newTestState = _state.testState;
    final currentShuttle = _state.currentShuttle;
    final runTimeMs = currentShuttle.runDurationSeconds * 1000.0;
    const recoveryTimeMs = 10000.0;
    if (newPhase == ShuttlePhase.running && newShuttleElapsed >= runTimeMs) {
      newPhase = ShuttlePhase.recovery;
    } else if (newPhase == ShuttlePhase.recovery &&
        newShuttleElapsed >= runTimeMs + recoveryTimeMs) {
      newPhase = ShuttlePhase.running;
      newShuttleElapsed = 0;
      newIndex++;
      if (newIndex >= YoYoProtocol.shuttles.length) {
        newTestState = TestState.completed;
        newIndex--;
        _timer?.cancel();
      }
    }
    _state = _state.copyWith(
      totalElapsedMillis: newTotal,
      currentShuttleElapsedMillis: newShuttleElapsed,
      currentPhase: newPhase,
      currentShuttleIndex: newIndex,
      testState: newTestState,
    );
    notifyListeners();
  }

  void _publishHostSnapshot({bool immediate = false}) {
    if (_isController || _disposed) return;
    if (immediate) {
      _snapshotTimer?.cancel();
      _snapshotTimer = null;
      _publishHostSnapshotNow();
      return;
    }
    if (_snapshotTimer != null) return;
    _snapshotTimer = Timer(const Duration(milliseconds: 300), () {
      _snapshotTimer = null;
      _publishHostSnapshotNow();
    });
  }

  void _publishHostSnapshotNow() {
    if (_isController || _disposed) return;
    final snapshot = RemoteTestSnapshot.fromState(
      epoch: _remoteEpoch,
      sequence: ++_snapshotSequence,
      testState: _state.testState,
      phase: _state.currentPhase,
      totalElapsedMillis: _state.totalElapsedMillis,
      currentShuttleElapsedMillis: _state.currentShuttleElapsedMillis,
      currentDistanceMeters: _state.currentDistanceMeters,
      shuttle: _state.currentShuttle,
      athletes: _state.athletes,
    );
    debugPrint(
      '[YoYoVM] _publishHostSnapshotNow epoch=${_remoteEpoch.substring(0, 6)} seq=$_snapshotSequence dist=${snapshot.currentDistanceMeters} totalElapsed=${snapshot.totalElapsedMillis} state=${snapshot.testState} connected=${nearbyService.state.isConnected}',
    );
    _state = _state.copyWith(
      remoteSnapshot: snapshot,
      remoteSnapshotStale: false,
    );
    notifyListeners();
    if (_state.remoteEnabled &&
        _state.remoteRole == RemoteRole.tablet &&
        nearbyService.state.isConnected) {
      final bytes = snapshot.encode();
      debugPrint('[YoYoVM] sending snapshot bytes=${bytes.length} to ${nearbyService.state.endpointId}');
      unawaited(nearbyService.sendBytes(bytes).catchError((e) {
        debugPrint('[YoYoVM] send snapshot failed: $e');
      }));
    } else {
      debugPrint(
        '[YoYoVM] skip send enabled=${_state.remoteEnabled} role=${_state.remoteRole} connected=${nearbyService.state.isConnected}',
      );
    }
  }

  void _beginNewHostEpoch() {
    _remoteEpoch = _newOpaqueToken();
    _snapshotSequence = 0;
    _handledRemoteRequestIds.clear();
    _remoteResultsByRequestId.clear();
  }

  ({int distanceMeters, String level, int shuttleInLevel, int timestampMs})
  _captureHostMetrics() {
    // Do not split this into controller-provided values: these four values are
    // sampled from host state and one tablet receipt time.
    return (
      distanceMeters: _state.currentDistanceMeters,
      level: _state.currentShuttle.levelDisplay,
      shuttleInLevel: _state.currentShuttle.shuttleInLevel,
      timestampMs: _nowMilliseconds(),
    );
  }

  Athlete? _findSelectedAthlete(String id) {
    for (final athlete in _state.athletes) {
      if (athlete.id == id && athlete.isSelected) return athlete;
    }
    return null;
  }

  void _updateSingleAthlete(Athlete updated) {
    final index = _state.athletes.indexWhere(
      (athlete) => athlete.id == updated.id,
    );
    if (index == -1) return;
    final list = List<Athlete>.from(_state.athletes);
    list[index] = updated;
    _state = _state.copyWith(athletes: list);
  }

  void _recordUndoAction(Athlete previous, String description) {
    final stack = List<AthleteUndoAction>.from(_state.undoStack)
      ..add(
        AthleteUndoAction(
          athleteId: previous.id,
          previousState: previous,
          description: description,
        ),
      );
    if (stack.length > 20) stack.removeAt(0);
    _state = _state.copyWith(undoStack: stack);
  }

  void _commitHostAthletes({required bool recalculateRanks}) {
    if (recalculateRanks) {
      _state = _state.copyWith(athletes: _calculateRanks(_state.athletes));
    }
    notifyListeners();
    _publishHostSnapshot(immediate: true);
  }

  List<Athlete> _calculateRanks(List<Athlete> athletes) =>
      TestRuntime.calculateRanks(athletes);

  void _checkAutoFinish() {
    if (_state.isAllAthletesFinished && _state.testState == TestState.running) {
      stopAndFinishTest();
    }
  }

  void _setRemoteMessage(String message) {
    _state = _state.copyWith(lastRemoteCommandMessage: message);
    notifyListeners();
  }

  int _nowMilliseconds() => _clock().millisecondsSinceEpoch;

  String _newOpaqueToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlNoPadding(bytes);
  }

  String base64UrlNoPadding(List<int> bytes) =>
      _base64UrlEncode(bytes).replaceAll('=', '');

  String _base64UrlEncode(List<int> bytes) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var index = 0; index < bytes.length; index += 3) {
      final remaining = bytes.length - index;
      final a = bytes[index];
      final b = remaining > 1 ? bytes[index + 1] : 0;
      final c = remaining > 2 ? bytes[index + 2] : 0;
      result
        ..write(alphabet[(a >> 2) & 0x3f])
        ..write(alphabet[((a & 3) << 4) | (b >> 4)])
        ..write(remaining > 1 ? alphabet[((b & 15) << 2) | (c >> 6)] : '=')
        ..write(remaining > 2 ? alphabet[c & 0x3f] : '=');
    }
    return result.toString();
  }

  String _safeError(Object error) {
    final text = error.toString();
    return text.length > 160 ? text.substring(0, 160) : text;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _snapshotTimer?.cancel();
    _stopTabletHeartbeat();
    _cancelStaleTimer();
    _cancelAllCommandTimeouts();
    unawaited(_connectionSubscription?.cancel());
    unawaited(_payloadSubscription?.cancel());
    nearbyService.dispose();
    super.dispose();
  }
}
