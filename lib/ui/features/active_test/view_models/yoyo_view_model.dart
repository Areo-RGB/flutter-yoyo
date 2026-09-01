import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/data/models/test_session.dart';
import 'package:yoyo_ir1_tracker/data/repositories/yoyo_repository.dart';
import 'package:yoyo_ir1_tracker/domain/yoyo_protocol.dart';
import 'package:yoyo_ir1_tracker/utils/sound_helper.dart';

enum AppTab { setup, live, leaderboard, history, settings }

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
    int? sessionSavedId,
    List<AthleteUndoAction>? undoStack,
    AppTab? activeTab,
  }) {
    return YoYoUiState(
      testState: testState ?? this.testState,
      currentShuttleIndex: currentShuttleIndex ?? this.currentShuttleIndex,
      athletes: athletes ?? this.athletes,
      totalElapsedMillis: totalElapsedMillis ?? this.totalElapsedMillis,
      currentShuttleElapsedMillis: currentShuttleElapsedMillis ?? this.currentShuttleElapsedMillis,
      currentPhase: currentPhase ?? this.currentPhase,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      volumeBoost: volumeBoost ?? this.volumeBoost,
      isBoostEnabled: isBoostEnabled ?? this.isBoostEnabled,
      sessionSavedId: sessionSavedId ?? this.sessionSavedId,
      undoStack: undoStack ?? this.undoStack,
      activeTab: activeTab ?? this.activeTab,
    );
  }

  YoYoShuttle get currentShuttle =>
      YoYoProtocol.shuttles[currentShuttleIndex.clamp(0, YoYoProtocol.shuttles.length - 1)];

  List<Athlete> get selectedAthletes => athletes.where((a) => a.isSelected).toList();

  int get currentDistanceMeters {
    if (testState == TestState.idle) return 0;
    if (testState == TestState.completed) {
      return YoYoProtocol.shuttles.length * 40;
    }
    if (currentPhase == ShuttlePhase.recovery) {
      return (currentShuttleIndex + 1) * 40;
    } else {
      return currentShuttleIndex * 40;
    }
  }

  int get activeRunnersCount =>
      selectedAthletes.where((a) => a.status == AthleteStatus.running || a.status == AthleteStatus.warned).length;

  int get warnedRunnersCount => selectedAthletes.where((a) => a.status == AthleteStatus.warned).length;

  int get eliminatedRunnersCount => selectedAthletes.where((a) => a.status == AthleteStatus.eliminated).length;

  bool get isAllAthletesFinished => selectedAthletes.isNotEmpty && activeRunnersCount == 0;

  double get runningPhaseRemainingSeconds {
    final double remaining = currentShuttle.runDurationSeconds - (currentShuttleElapsedMillis / 1000.0);
    return remaining > 0 ? remaining : 0.0;
  }

  double get recoveryPhaseRemainingSeconds {
    final double totalDuration = currentShuttle.runDurationSeconds + 10.0;
    final double remaining = totalDuration - (currentShuttleElapsedMillis / 1000.0);
    return remaining > 0 ? remaining : 0.0;
  }

  double get phaseProgressFraction {
    if (currentPhase == ShuttlePhase.running) {
      return (currentShuttleElapsedMillis / 1000.0) / currentShuttle.runDurationSeconds;
    } else {
      final double recoveryElapsed = (currentShuttleElapsedMillis / 1000.0) - currentShuttle.runDurationSeconds;
      return (recoveryElapsed / 10.0).clamp(0.0, 1.0);
    }
  }
}

class YoYoViewModel extends ChangeNotifier {
  final YoYoRepository repository;
  final SoundHelper soundHelper;

  YoYoUiState _state = YoYoUiState(athletes: Athlete.createDefaultRoster());
  Timer? _timer;
  int _lastTickTime = 0;

  YoYoUiState get state => _state;
  Stream<List<SessionWithResults>> get savedSessions => repository.allSessions;

  YoYoViewModel({required this.repository, required this.soundHelper});

  void startTest() {
    if (_state.testState == TestState.idle) {
      _state = _state.copyWith(
        testState: TestState.running,
        activeTab: AppTab.live,
        currentPhase: ShuttlePhase.running,
        currentShuttleElapsedMillis: 0,
        totalElapsedMillis: 0,
        currentShuttleIndex: 0,
      );
      if (_state.isSoundEnabled) soundHelper.startAudioTrack();
      _startTicker();
      notifyListeners();
    } else if (_state.testState == TestState.paused) {
      resumeTest();
    }
  }

  void pauseTest() {
    _timer?.cancel();
    soundHelper.pauseAudioTrack();
    _state = _state.copyWith(testState: TestState.paused);
    notifyListeners();
  }

  void resumeTest() {
    _state = _state.copyWith(testState: TestState.running);
    if (_state.isSoundEnabled) soundHelper.resumeAudioTrack();
    _lastTickTime = DateTime.now().millisecondsSinceEpoch;
    _startTicker();
    notifyListeners();
  }

  void stopAndFinishTest() {
    _timer?.cancel();
    soundHelper.stopAudioTrack();
    
    final int distance = _state.currentDistanceMeters;
    final String currentLevel = _state.currentShuttle.levelDisplay;
    final int currentShuttleInLevel = _state.currentShuttle.shuttleInLevel;
    
    final updatedAthletes = _state.athletes.map((a) {
      if (a.isSelected && a.status != AthleteStatus.eliminated) {
        return a.copyWith(
          status: AthleteStatus.eliminated,
          finalDistanceMeters: distance,
          finalLevel: currentLevel,
          finalShuttle: currentShuttleInLevel,
          vo2Max: YoYoProtocol.calculateVo2Max(distance),
          finishTimestampMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      return a;
    }).toList();
    
    _state = _state.copyWith(
      testState: TestState.completed,
      athletes: _calculateRanks(updatedAthletes),
    );
    notifyListeners();
  }

  void resetTest() {
    _timer?.cancel();
    soundHelper.stopAudioTrack();
    final resetAthletes = _state.athletes.map((a) => a.copyWith(
      status: AthleteStatus.running,
      warningDistanceMeters: null,
      warningLevel: null,
      warningShuttle: null,
      finalDistanceMeters: null,
      finalLevel: null,
      finalShuttle: null,
      rank: null,
      vo2Max: null,
      finishTimestampMs: null,
    )).toList();
    
    _state = YoYoUiState(
      athletes: resetAthletes,
      isSoundEnabled: _state.isSoundEnabled,
      isBoostEnabled: _state.isBoostEnabled,
      volumeBoost: _state.volumeBoost,
      activeTab: AppTab.setup,
    );
    notifyListeners();
  }

  void toggleAthleteSelected(String athleteId) {
    if (_state.testState != TestState.idle) return;
    final updated = _state.athletes.map((a) {
      if (a.id == athleteId) {
        return a.copyWith(isSelected: !a.isSelected);
      }
      return a;
    }).toList();
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
  }

  void selectAllAthletes() {
    if (_state.testState != TestState.idle) return;
    final updated = _state.athletes.map((a) => a.copyWith(isSelected: true)).toList();
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
  }

  void deselectAllAthletes() {
    if (_state.testState != TestState.idle) return;
    final updated = _state.athletes.map((a) => a.copyWith(isSelected: false)).toList();
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
  }

  void setActiveTab(AppTab tab) {
    _state = _state.copyWith(activeTab: tab);
    notifyListeners();
  }

  void toggleSound() {
    final nextSoundState = !_state.isSoundEnabled;
    _state = _state.copyWith(isSoundEnabled: nextSoundState);
    soundHelper.setSoundEnabledState(nextSoundState);
    notifyListeners();
  }

  void setVolumeBoost(double boost) {
    _state = _state.copyWith(volumeBoost: boost.clamp(1.0, 3.0));
    notifyListeners();
  }

  void setBoostEnabled(bool enabled) {
    _state = _state.copyWith(isBoostEnabled: enabled);
    notifyListeners();
  }

  void onAthleteClicked(Athlete athlete) {
    if (_state.testState != TestState.running && _state.testState != TestState.paused) return;
    
    final currentDistance = _state.currentDistanceMeters;
    final level = _state.currentShuttle.levelDisplay;
    final shuttle = _state.currentShuttle.shuttleInLevel;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    _recordUndoAction(athlete, athlete.status == AthleteStatus.running ? 'Warned' : 'Eliminated');

    if (athlete.status == AthleteStatus.running) {
      final updated = athlete.copyWith(
        status: AthleteStatus.warned,
        warningDistanceMeters: currentDistance,
        warningLevel: level,
        warningShuttle: shuttle,
      );
      _updateSingleAthlete(updated);
    } else if (athlete.status == AthleteStatus.warned) {
      final updated = athlete.copyWith(
        status: AthleteStatus.eliminated,
        finalDistanceMeters: currentDistance,
        finalLevel: level,
        finalShuttle: shuttle,
        vo2Max: YoYoProtocol.calculateVo2Max(currentDistance),
        finishTimestampMs: timestamp,
      );
      _updateSingleAthlete(updated);
      _recalculateAllRanks();
      _checkAutoFinish();
    }
  }

  void eliminateDirectly(Athlete athlete) {
    if (_state.testState != TestState.running && _state.testState != TestState.paused) return;
    if (athlete.status == AthleteStatus.eliminated) return;

    final currentDistance = _state.currentDistanceMeters;
    final level = _state.currentShuttle.levelDisplay;
    final shuttle = _state.currentShuttle.shuttleInLevel;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    _recordUndoAction(athlete, 'Direct Elimination');

    final updated = athlete.copyWith(
      status: AthleteStatus.eliminated,
      warningDistanceMeters: athlete.warningDistanceMeters ?? currentDistance,
      warningLevel: athlete.warningLevel ?? level,
      warningShuttle: shuttle,
      finalDistanceMeters: currentDistance,
      finalLevel: level,
      finalShuttle: shuttle,
      vo2Max: YoYoProtocol.calculateVo2Max(currentDistance),
      finishTimestampMs: timestamp,
    );
    _updateSingleAthlete(updated);
    _recalculateAllRanks();
    _checkAutoFinish();
  }

  void undoLastAction() {
    if (_state.undoStack.isEmpty) return;
    
    final stack = List<AthleteUndoAction>.from(_state.undoStack);
    final lastAction = stack.removeLast();
    
    _updateSingleAthlete(lastAction.previousState);
    _state = _state.copyWith(undoStack: stack);
    _recalculateAllRanks();
  }

  void undoAthlete(Athlete athlete) {
    if (athlete.status == AthleteStatus.eliminated) {
      final updated = athlete.copyWith(
        status: athlete.warningDistanceMeters != null ? AthleteStatus.warned : AthleteStatus.running,
        finalDistanceMeters: null,
        finalLevel: null,
        finalShuttle: null,
        rank: null,
        vo2Max: null,
        finishTimestampMs: null,
      );
      _updateSingleAthlete(updated);
    } else if (athlete.status == AthleteStatus.warned) {
      final updated = athlete.copyWith(
        status: AthleteStatus.running,
        warningDistanceMeters: null,
        warningLevel: null,
        warningShuttle: null,
      );
      _updateSingleAthlete(updated);
    }
    _recalculateAllRanks();
  }

  void updateRoster(List<String> names) {
    final newAthletes = names.asMap().entries.map((e) => Athlete(
      id: DateTime.now().millisecondsSinceEpoch.toString() + e.key.toString(),
      name: e.value,
      isSelected: true,
    )).toList();
    _state = _state.copyWith(athletes: newAthletes);
    notifyListeners();
  }

  void addAthlete(String name) {
    final updated = List<Athlete>.from(_state.athletes);
    updated.add(Athlete(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isSelected: true,
    ));
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
  }

  void removeAthlete(String id) {
    final updated = List<Athlete>.from(_state.athletes)..removeWhere((a) => a.id == id);
    _state = _state.copyWith(athletes: updated);
    notifyListeners();
  }

  void resetRosterToDefaults() {
    _state = _state.copyWith(athletes: Athlete.createDefaultRoster());
    notifyListeners();
  }

  Future<void> saveTestSession({String? customTitle, String notes = ''}) async {
    final targetAthletes = _state.selectedAthletes;
    if (targetAthletes.isEmpty) return;
    
    final now = DateTime.now();
    final title = customTitle ?? 'Yo-Yo Test ${DateFormat('MMM d, yyyy').format(now)}';
    final bestDist = targetAthletes.fold<int>(0, (max, a) => (a.finalDistanceMeters ?? 0) > max ? (a.finalDistanceMeters ?? 0) : max);
    final bestAthlete = targetAthletes.firstWhere((a) => (a.finalDistanceMeters ?? 0) == bestDist, orElse: () => targetAthletes.first);
    final bestLevel = bestAthlete.finalLevel ?? _state.currentShuttle.levelDisplay;

    final session = TestSession(
      title: title,
      timestampMs: now.millisecondsSinceEpoch,
      durationSeconds: (_state.totalElapsedMillis / 1000).round(),
      maxDistanceAchieved: bestDist,
      maxLevelAchieved: bestLevel,
      totalAthletesCount: targetAthletes.length,
      completedAthletesCount: targetAthletes.where((a) => a.status == AthleteStatus.eliminated).length,
      notes: notes,
    );
    
    final results = targetAthletes.map((a) => AthleteResult(
      sessionId: 0,
      athleteName: a.name,
      finalDistanceMeters: a.finalDistanceMeters ?? 0,
      finalLevel: a.finalLevel ?? '5.1',
      finalShuttleNumber: a.finalShuttle ?? 1,
      warningDistanceMeters: a.warningDistanceMeters,
      warningLevel: a.warningLevel,
      rank: a.rank ?? 1,
      vo2Max: a.vo2Max ?? 0.0,
    )).toList();
    
    final id = await repository.saveSession(session, results);
    _state = _state.copyWith(sessionSavedId: id);
    notifyListeners();
  }

  Future<void> deleteSession(int sessionId) async {
    await repository.deleteSession(sessionId);
  }

  String generateCsvExport(List<Athlete> athletes) {
    final sb = StringBuffer();
    sb.writeln('Rank,Name,Status,Final Distance (m),Final Level,VO2Max');
    for (final a in athletes) {
      sb.writeln('${a.rank ?? ""},${a.name},${a.status.name},${a.finalDistanceMeters ?? ""},${a.finalLevel ?? ""}.${a.finalShuttle ?? ""},${a.vo2Max ?? ""}');
    }
    return sb.toString();
  }

  String generateSummaryText(List<Athlete> athletes, {String sessionTitle = 'Yo-Yo IR1 Results'}) {
    final sb = StringBuffer();
    sb.writeln('🏃‍♂️ $sessionTitle 🏃‍♂️');
    sb.writeln('');
    
    final sorted = List<Athlete>.from(athletes)..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    
    for (int i = 0; i < sorted.length; i++) {
      final a = sorted[i];
      final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '▪️'));
      final dist = a.finalDistanceMeters != null ? '${a.finalDistanceMeters}m' : 'DNF';
      final level = a.finalLevel != null ? 'Lvl ${a.finalLevel}.${a.finalShuttle}' : '';
      sb.writeln('$medal ${a.name} - $dist $level');
    }
    return sb.toString();
  }

  void _startTicker() {
    _timer?.cancel();
    _lastTickTime = DateTime.now().millisecondsSinceEpoch;
    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final delta = now - _lastTickTime;
      _lastTickTime = now;
      _tick(delta);
    });
  }

  void _tick(int deltaMillis) {
    if (_state.testState != TestState.running) return;

    int newTotal = _state.totalElapsedMillis + deltaMillis;
    int newShuttleElapsed = _state.currentShuttleElapsedMillis + deltaMillis;
    
    ShuttlePhase newPhase = _state.currentPhase;
    int newIndex = _state.currentShuttleIndex;
    TestState newTestState = _state.testState;
    
    final currentShuttle = _state.currentShuttle;
    final double runTimeMs = currentShuttle.runDurationSeconds * 1000.0;
    final double recoveryTimeMs = 10000.0;
    
    if (newPhase == ShuttlePhase.running) {
      if (newShuttleElapsed >= runTimeMs) {
        newPhase = ShuttlePhase.recovery;
      }
    } else if (newPhase == ShuttlePhase.recovery) {
      if (newShuttleElapsed >= runTimeMs + recoveryTimeMs) {
        newPhase = ShuttlePhase.running;
        newShuttleElapsed = 0;
        newIndex++;
        
        if (newIndex >= YoYoProtocol.shuttles.length) {
          newTestState = TestState.completed;
          newIndex--;
        }
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

  void _updateSingleAthlete(Athlete updated) {
    final idx = _state.athletes.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      final list = List<Athlete>.from(_state.athletes);
      list[idx] = updated;
      _state = _state.copyWith(athletes: list);
    }
  }

  void _recordUndoAction(Athlete previous, String description) {
    final stack = List<AthleteUndoAction>.from(_state.undoStack);
    stack.add(AthleteUndoAction(
      athleteId: previous.id,
      previousState: previous,
      description: description,
    ));
    if (stack.length > 20) stack.removeAt(0);
    _state = _state.copyWith(undoStack: stack);
  }

  void _recalculateAllRanks() {
    _state = _state.copyWith(athletes: _calculateRanks(_state.athletes));
    notifyListeners();
  }

  List<Athlete> _calculateRanks(List<Athlete> athletes) {
    final selected = athletes.where((a) => a.isSelected).toList();
    final unselected = athletes.where((a) => !a.isSelected).toList();

    final eliminated = selected.where((a) => a.status == AthleteStatus.eliminated).toList();
    final others = selected.where((a) => a.status != AthleteStatus.eliminated).toList();

    eliminated.sort((a, b) {
      final distDiff = (b.finalDistanceMeters ?? 0).compareTo(a.finalDistanceMeters ?? 0);
      if (distDiff != 0) return distDiff;
      return (a.finishTimestampMs ?? 0).compareTo(b.finishTimestampMs ?? 0);
    });

    final rankedEliminated = eliminated.asMap().entries.map((e) {
      return e.value.copyWith(rank: e.key + 1);
    }).toList();

    return [...unselected, ...others, ...rankedEliminated];
  }

  void _checkAutoFinish() {
    if (_state.isAllAthletesFinished && _state.testState == TestState.running) {
      stopAndFinishTest();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
