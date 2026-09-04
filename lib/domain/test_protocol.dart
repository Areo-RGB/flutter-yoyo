class TestShuttle {
  final int shuttleNumber;
  final int speedLevel;
  final int shuttleInLevel;
  final double speedKmh;
  final int cumulativeDistanceMeters;
  final double runDurationSeconds;
  final double recoveryDurationSeconds;

  const TestShuttle({
    required this.shuttleNumber,
    required this.speedLevel,
    required this.shuttleInLevel,
    required this.speedKmh,
    required this.cumulativeDistanceMeters,
    required this.runDurationSeconds,
    this.recoveryDurationSeconds = 10.0,
  });

  String get levelDisplay => '$speedLevel.$shuttleInLevel';
  double get totalDurationSeconds =>
      runDurationSeconds + recoveryDurationSeconds;
}

abstract class TestProtocol {
  List<TestShuttle> get shuttles;
  int get totalShuttlesCount;
  int get maxDistanceMeters;
  double calculateVo2Max(int distanceMeters, {double? speedKmh});
  String getFitnessRating(int distanceMeters);
}

class YoYoProtocolInstance implements TestProtocol {
  static final List<TestShuttle> _shuttles = _generateShuttles();

  @override
  List<TestShuttle> get shuttles => _shuttles;

  @override
  int get totalShuttlesCount => _shuttles.length;

  @override
  int get maxDistanceMeters =>
      _shuttles.isNotEmpty ? _shuttles.last.cumulativeDistanceMeters : 0;

  static List<TestShuttle> _generateShuttles() {
    final List<TestShuttle> list = [];
    int shuttleNumber = 1;
    int distance = 0;

    void addStage(int speedLevel, double speedKmh, int shuttleCount) {
      for (int i = 1; i <= shuttleCount; i++) {
        distance += 40;
        list.add(
          TestShuttle(
            shuttleNumber: shuttleNumber,
            speedLevel: speedLevel,
            shuttleInLevel: i,
            speedKmh: speedKmh,
            cumulativeDistanceMeters: distance,
            runDurationSeconds: 144.0 / speedKmh,
            recoveryDurationSeconds: 10.0,
          ),
        );
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

  @override
  double calculateVo2Max(int distanceMeters, {double? speedKmh}) {
    if (distanceMeters <= 0) return 0.0;
    final double result = (distanceMeters * 0.0084) + 36.4;
    return double.parse(result.toStringAsFixed(1));
  }

  @override
  String getFitnessRating(int distanceMeters) {
    if (distanceMeters >= 2400) return 'Elite (Professional)';
    if (distanceMeters >= 2000) return 'Excellent';
    if (distanceMeters >= 1600) return 'Good / Advanced';
    if (distanceMeters >= 1200) return 'Average / Intermediate';
    if (distanceMeters >= 800) return 'Below Average';
    return 'Novice / Needs Improvement';
  }
}

class BeepTestProtocolInstance implements TestProtocol {
  static final List<TestShuttle> _shuttles = _generateShuttles();

  @override
  List<TestShuttle> get shuttles => _shuttles;

  @override
  int get totalShuttlesCount => _shuttles.length;

  @override
  int get maxDistanceMeters =>
      _shuttles.isNotEmpty ? _shuttles.last.cumulativeDistanceMeters : 0;

  static List<TestShuttle> _generateShuttles() {
    final List<TestShuttle> list = [];
    int shuttleNumber = 1;
    int distance = 0;

    final stages = <(int level, double speed, int count)>[
      (1, 8.5, 7),
      (2, 9.0, 8),
      (3, 9.5, 8),
      (4, 10.0, 9),
      (5, 10.5, 9),
      (6, 11.0, 10),
      (7, 11.5, 10),
      (8, 12.0, 11),
      (9, 12.5, 11),
      (10, 13.0, 11),
      (11, 13.5, 12),
      (12, 14.0, 12),
      (13, 14.5, 13),
      (14, 15.0, 13),
      (15, 15.5, 13),
      (16, 16.0, 14),
      (17, 16.5, 14),
      (18, 17.0, 15),
      (19, 17.5, 15),
      (20, 18.0, 16),
      (21, 18.5, 16),
    ];

    for (final stage in stages) {
      for (int i = 1; i <= stage.$3; i++) {
        distance += 20;
        list.add(
          TestShuttle(
            shuttleNumber: shuttleNumber,
            speedLevel: stage.$1,
            shuttleInLevel: i,
            speedKmh: stage.$2,
            cumulativeDistanceMeters: distance,
            runDurationSeconds: 72.0 / stage.$2,
            recoveryDurationSeconds: 0.0,
          ),
        );
        shuttleNumber++;
      }
    }

    return list;
  }

  @override
  double calculateVo2Max(int distanceMeters, {double? speedKmh}) {
    if (distanceMeters <= 0) return 0.0;
    double speed = speedKmh ?? 0.0;
    if (speed <= 0) {
      for (final s in _shuttles) {
        if (s.cumulativeDistanceMeters >= distanceMeters) {
          speed = s.speedKmh;
          break;
        }
      }
      if (speed <= 0 && _shuttles.isNotEmpty) {
        speed = _shuttles.last.speedKmh;
      }
    }
    final double result = (speed * 3.1) + 3.5;
    return double.parse(result.toStringAsFixed(1));
  }

  @override
  String getFitnessRating(int distanceMeters) {
    if (distanceMeters >= 2600) return 'Elite (Professional)';
    if (distanceMeters >= 2000) return 'Excellent';
    if (distanceMeters >= 1600) return 'Good / Advanced';
    if (distanceMeters >= 1200) return 'Average / Intermediate';
    if (distanceMeters >= 800) return 'Below Average';
    return 'Novice / Needs Improvement';
  }
}

enum TestType {
  yoyoIR1('Yo-Yo IR1', 'Yo-Yo Intermittent Recovery Level 1'),
  beepTest('Beep Test', '20m Multi-Stage Fitness Test');

  final String displayName;
  final String fullName;

  const TestType(this.displayName, this.fullName);

  TestProtocol get protocol {
    switch (this) {
      case TestType.yoyoIR1:
        return YoYoProtocolInstance();
      case TestType.beepTest:
        return BeepTestProtocolInstance();
    }
  }
}
