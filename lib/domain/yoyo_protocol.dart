class YoYoShuttle {
  final int shuttleNumber;
  final int speedLevel;
  final int shuttleInLevel;
  final double speedKmh;
  final int cumulativeDistanceMeters;
  final double runDurationSeconds;
  final double recoveryDurationSeconds;

  const YoYoShuttle({
    required this.shuttleNumber,
    required this.speedLevel,
    required this.shuttleInLevel,
    required this.speedKmh,
    required this.cumulativeDistanceMeters,
    required this.runDurationSeconds,
    this.recoveryDurationSeconds = 10.0,
  });

  String get levelDisplay => '$speedLevel.$shuttleInLevel';
  double get totalDurationSeconds => runDurationSeconds + recoveryDurationSeconds;
}

class YoYoProtocol {
  static final List<YoYoShuttle> shuttles = _generateShuttles();

  static List<YoYoShuttle> _generateShuttles() {
    final List<YoYoShuttle> list = [];
    int shuttleNumber = 1;
    int distance = 0;

    void addStage(int speedLevel, double speedKmh, int shuttleCount) {
      for (int i = 1; i <= shuttleCount; i++) {
        distance += 40;
        list.add(YoYoShuttle(
          shuttleNumber: shuttleNumber,
          speedLevel: speedLevel,
          shuttleInLevel: i,
          speedKmh: speedKmh,
          cumulativeDistanceMeters: distance,
          runDurationSeconds: 144.0 / speedKmh,
        ));
        shuttleNumber++;
      }
    }

    addStage(5, 10.0, 1);
    addStage(9, 11.5, 1);
    addStage(11, 12.0, 2);
    addStage(12, 12.5, 3);
    addStage(13, 13.0, 4);

    double speed = 13.5;
    for (int level = 14; level <= 23; level++) {
      addStage(level, speed, 8);
      speed += 0.5;
    }

    return list;
  }

  static int get totalShuttlesCount => 91;
  static int get maxDistanceMeters => 3640;

  static int getCumulativeTimeUpToShuttleMs(int shuttleIndex) {
    double totalSeconds = 0.0;
    for (int i = 0; i < shuttleIndex; i++) {
      totalSeconds += shuttles[i].totalDurationSeconds;
    }
    return (totalSeconds * 1000).toInt();
  }

  static double calculateVo2Max(int distanceMeters) {
    if (distanceMeters <= 0) return 0.0;
    final double result = (distanceMeters * 0.0084) + 36.4;
    return double.parse(result.toStringAsFixed(1));
  }

  static String getFitnessRating(int distanceMeters) {
    if (distanceMeters >= 2400) return 'Elite (Professional)';
    if (distanceMeters >= 2000) return 'Excellent';
    if (distanceMeters >= 1600) return 'Good / Advanced';
    if (distanceMeters >= 1200) return 'Average / Intermediate';
    if (distanceMeters >= 800) return 'Below Average';
    return 'Novice / Needs Improvement';
  }
}
