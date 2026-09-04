import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/domain/test_protocol.dart';

/// Pure helpers extracted from [YoYoViewModel] so test-timing and ranking
/// logic can be unit-tested without constructing timers or preferences.
class TestRuntime {
  const TestRuntime._();

  /// Derives shuttle index/phase/testState from wall-clock elapsed milliseconds.
  static ({
    int totalMs,
    int shuttleElapsedMs,
    ShuttlePhase phase,
    int index,
    TestState testState
  }) deriveFromElapsedMs(int elapsedMs, {TestProtocol? protocol}) {
    final activeProtocol = protocol ?? YoYoProtocolInstance();
    final shuttles = activeProtocol.shuttles;
    if (elapsedMs < 0) elapsedMs = 0;
    int cumMs = 0;
    for (int i = 0; i < shuttles.length; i++) {
      final s = shuttles[i];
      final runMs = (s.runDurationSeconds * 1000).round();
      final recMs = (s.recoveryDurationSeconds * 1000).round();
      final totalMs = runMs + recMs;
      if (elapsedMs < cumMs + runMs) {
        return (
          totalMs: elapsedMs,
          shuttleElapsedMs: elapsedMs - cumMs,
          phase: ShuttlePhase.running,
          index: i,
          testState: TestState.running,
        );
      }
      if (recMs > 0 && elapsedMs < cumMs + totalMs) {
        return (
          totalMs: elapsedMs,
          shuttleElapsedMs: elapsedMs - cumMs,
          phase: ShuttlePhase.recovery,
          index: i,
          testState: TestState.running,
        );
      }
      cumMs += totalMs;
    }
    final last = shuttles.length - 1;
    final lastRunMs = (shuttles[last].runDurationSeconds * 1000).round();
    final lastRecMs = (shuttles[last].recoveryDurationSeconds * 1000).round();
    return (
      totalMs: elapsedMs,
      shuttleElapsedMs: lastRunMs + lastRecMs,
      phase: lastRecMs > 0 ? ShuttlePhase.recovery : ShuttlePhase.running,
      index: last,
      testState: TestState.completed,
    );
  }

  static List<Athlete> calculateRanks(List<Athlete> athletes) {
    final selected = athletes.where((a) => a.isSelected).toList();
    final unselected = athletes.where((a) => !a.isSelected).toList();
    final eliminated = selected
        .where((a) => a.status == AthleteStatus.eliminated)
        .toList();
    final others =
        selected.where((a) => a.status != AthleteStatus.eliminated).toList();

    eliminated.sort((a, b) {
      final d = (b.finalDistanceMeters ?? 0).compareTo(a.finalDistanceMeters ?? 0);
      if (d != 0) return d;
      return (a.finishTimestampMs ?? 0).compareTo(b.finishTimestampMs ?? 0);
    });
    final ranked = eliminated
        .asMap()
        .entries
        .map((e) => e.value.copyWith(rank: e.key + 1))
        .toList();
    return [...unselected, ...others, ...ranked];
  }
}
