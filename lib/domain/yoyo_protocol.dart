import 'package:yoyo_ir1_tracker/domain/test_protocol.dart';

typedef YoYoShuttle = TestShuttle;

class YoYoProtocol {
  static final YoYoProtocolInstance _instance = YoYoProtocolInstance();

  static List<TestShuttle> get shuttles => _instance.shuttles;
  static int get totalShuttlesCount => _instance.totalShuttlesCount;
  static int get maxDistanceMeters => _instance.maxDistanceMeters;

  static int getCumulativeTimeUpToShuttleMs(int shuttleIndex) {
    double totalSeconds = 0.0;
    for (int i = 0; i < shuttleIndex && i < shuttles.length; i++) {
      totalSeconds += shuttles[i].totalDurationSeconds;
    }
    return (totalSeconds * 1000).toInt();
  }

  static double calculateVo2Max(int distanceMeters) {
    return _instance.calculateVo2Max(distanceMeters);
  }

  static String getFitnessRating(int distanceMeters) {
    return _instance.getFitnessRating(distanceMeters);
  }
}
