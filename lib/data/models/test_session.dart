class TestSession {
  final int id;
  final String title;
  final int timestampMs;
  final int durationSeconds;
  final int maxDistanceAchieved;
  final String maxLevelAchieved;
  final int totalAthletesCount;
  final int completedAthletesCount;
  final String notes;

  const TestSession({
    this.id = 0,
    required this.title,
    required this.timestampMs,
    required this.durationSeconds,
    required this.maxDistanceAchieved,
    required this.maxLevelAchieved,
    required this.totalAthletesCount,
    required this.completedAthletesCount,
    this.notes = '',
  });

  TestSession copyWith({
    int? id,
    String? title,
    int? timestampMs,
    int? durationSeconds,
    int? maxDistanceAchieved,
    String? maxLevelAchieved,
    int? totalAthletesCount,
    int? completedAthletesCount,
    String? notes,
  }) {
    return TestSession(
      id: id ?? this.id,
      title: title ?? this.title,
      timestampMs: timestampMs ?? this.timestampMs,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      maxDistanceAchieved: maxDistanceAchieved ?? this.maxDistanceAchieved,
      maxLevelAchieved: maxLevelAchieved ?? this.maxLevelAchieved,
      totalAthletesCount: totalAthletesCount ?? this.totalAthletesCount,
      completedAthletesCount:
          completedAthletesCount ?? this.completedAthletesCount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'title': title,
      'timestampMs': timestampMs,
      'durationSeconds': durationSeconds,
      'maxDistanceAchieved': maxDistanceAchieved,
      'maxLevelAchieved': maxLevelAchieved,
      'totalAthletesCount': totalAthletesCount,
      'completedAthletesCount': completedAthletesCount,
      'notes': notes,
    };
  }

  factory TestSession.fromMap(Map<String, dynamic> map) {
    return TestSession(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      timestampMs: map['timestampMs']?.toInt() ?? 0,
      durationSeconds: map['durationSeconds']?.toInt() ?? 0,
      maxDistanceAchieved: map['maxDistanceAchieved']?.toInt() ?? 0,
      maxLevelAchieved: map['maxLevelAchieved'] ?? '',
      totalAthletesCount: map['totalAthletesCount']?.toInt() ?? 0,
      completedAthletesCount: map['completedAthletesCount']?.toInt() ?? 0,
      notes: map['notes'] ?? '',
    );
  }
}

class AthleteResult {
  final int id;
  final int sessionId;
  final String athleteName;
  final int finalDistanceMeters;
  final String finalLevel;
  final int finalShuttleNumber;
  final int? warningDistanceMeters;
  final String? warningLevel;
  final int rank;
  final double vo2Max;

  const AthleteResult({
    this.id = 0,
    required this.sessionId,
    required this.athleteName,
    required this.finalDistanceMeters,
    required this.finalLevel,
    required this.finalShuttleNumber,
    this.warningDistanceMeters,
    this.warningLevel,
    required this.rank,
    required this.vo2Max,
  });

  AthleteResult copyWith({
    int? id,
    int? sessionId,
    String? athleteName,
    int? finalDistanceMeters,
    String? finalLevel,
    int? finalShuttleNumber,
    int? warningDistanceMeters,
    String? warningLevel,
    int? rank,
    double? vo2Max,
  }) {
    return AthleteResult(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      athleteName: athleteName ?? this.athleteName,
      finalDistanceMeters: finalDistanceMeters ?? this.finalDistanceMeters,
      finalLevel: finalLevel ?? this.finalLevel,
      finalShuttleNumber: finalShuttleNumber ?? this.finalShuttleNumber,
      warningDistanceMeters:
          warningDistanceMeters ?? this.warningDistanceMeters,
      warningLevel: warningLevel ?? this.warningLevel,
      rank: rank ?? this.rank,
      vo2Max: vo2Max ?? this.vo2Max,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'sessionId': sessionId,
      'athleteName': athleteName,
      'finalDistanceMeters': finalDistanceMeters,
      'finalLevel': finalLevel,
      'finalShuttleNumber': finalShuttleNumber,
      'warningDistanceMeters': warningDistanceMeters,
      'warningLevel': warningLevel,
      'rank': rank,
      'vo2Max': vo2Max,
    };
  }

  factory AthleteResult.fromMap(Map<String, dynamic> map) {
    return AthleteResult(
      id: map['id']?.toInt() ?? 0,
      sessionId: map['sessionId']?.toInt() ?? 0,
      athleteName: map['athleteName'] ?? '',
      finalDistanceMeters: map['finalDistanceMeters']?.toInt() ?? 0,
      finalLevel: map['finalLevel'] ?? '',
      finalShuttleNumber: map['finalShuttleNumber']?.toInt() ?? 0,
      warningDistanceMeters: map['warningDistanceMeters']?.toInt(),
      warningLevel: map['warningLevel'],
      rank: map['rank']?.toInt() ?? 0,
      vo2Max: map['vo2Max']?.toDouble() ?? 0.0,
    );
  }
}

class SessionWithResults {
  final TestSession session;
  final List<AthleteResult> results;

  const SessionWithResults({required this.session, required this.results});
}
