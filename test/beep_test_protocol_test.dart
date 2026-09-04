import 'package:flutter_test/flutter_test.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/domain/test_protocol.dart';
import 'package:yoyo_ir1_tracker/domain/test_runtime.dart';

void main() {
  group('YoYoProtocolInstance', () {
    final protocol = YoYoProtocolInstance();

    test('generates correct number of shuttles', () {
      expect(protocol.shuttles.length, equals(91));
      expect(protocol.totalShuttlesCount, equals(91));
      expect(protocol.maxDistanceMeters, equals(3640));
    });

    test('calculates VO2max correctly', () {
      expect(protocol.calculateVo2Max(1000), equals(44.8));
      expect(protocol.calculateVo2Max(0), equals(0.0));
    });

    test('returns correct fitness ratings', () {
      expect(protocol.getFitnessRating(2500), equals('Elite (Professional)'));
      expect(protocol.getFitnessRating(500), equals('Novice / Needs Improvement'));
    });
  });

  group('BeepTestProtocolInstance', () {
    final protocol = BeepTestProtocolInstance();

    test('generates correct number of shuttles and total distance', () {
      expect(protocol.shuttles.length, equals(247));
      expect(protocol.maxDistanceMeters, equals(4940));
    });

    test('calculates VO2max correctly based on speed', () {
      expect(protocol.calculateVo2Max(100, speedKmh: 10.0), equals(34.5));
      expect(protocol.calculateVo2Max(0), equals(0.0));
    });

    test('shuttles have zero recovery duration', () {
      for (final shuttle in protocol.shuttles) {
        expect(shuttle.recoveryDurationSeconds, equals(0.0));
      }
    });
  });

  group('TestType', () {
    test('returns correct protocol for type', () {
      expect(TestType.yoyoIR1.protocol, isA<YoYoProtocolInstance>());
      expect(TestType.beepTest.protocol, isA<BeepTestProtocolInstance>());
    });
  });

  group('TestRuntime deriveFromElapsedMs with custom protocol', () {
    test('derives correct state using BeepTestProtocolInstance', () {
      final beepProtocol = BeepTestProtocolInstance();
      final result = TestRuntime.deriveFromElapsedMs(0, protocol: beepProtocol);
      expect(result.index, equals(0));
      expect(result.phase, equals(ShuttlePhase.running));
    });
  });
}
