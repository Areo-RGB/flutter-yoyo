enum AthleteStatus { running, warned, eliminated }
enum ShuttlePhase { running, recovery }
enum TestState { idle, running, paused, completed }

class Athlete {
  final String id;
  final String name;
  final AthleteStatus status;
  final bool isSelected;
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

  const Athlete({
    required this.id,
    required this.name,
    this.status = AthleteStatus.running,
    this.isSelected = true,
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

  Athlete copyWith({
    String? id,
    String? name,
    AthleteStatus? status,
    bool? isSelected,
    int? warningDistanceMeters,
    String? warningLevel,
    int? warningShuttle,
    int? warningTimestampMs,
    int? finalDistanceMeters,
    String? finalLevel,
    int? finalShuttle,
    int? finishTimestampMs,
    int? rank,
    double? vo2Max,
  }) {
    return Athlete(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
      warningDistanceMeters: warningDistanceMeters ?? this.warningDistanceMeters,
      warningLevel: warningLevel ?? this.warningLevel,
      warningShuttle: warningShuttle ?? this.warningShuttle,
      warningTimestampMs: warningTimestampMs ?? this.warningTimestampMs,
      finalDistanceMeters: finalDistanceMeters ?? this.finalDistanceMeters,
      finalLevel: finalLevel ?? this.finalLevel,
      finalShuttle: finalShuttle ?? this.finalShuttle,
      finishTimestampMs: finishTimestampMs ?? this.finishTimestampMs,
      rank: rank ?? this.rank,
      vo2Max: vo2Max ?? this.vo2Max,
    );
  }

  bool get isFinished => status == AthleteStatus.eliminated;
  bool get isWarned => status == AthleteStatus.warned;
  bool get isRunning => status == AthleteStatus.running;

  static const List<String> defaultAthleteNames = [
    'Silas', 'Finley', 'Arvid', 'Lion', 'Jakob', 'Paul', 'Lennox', 'Levi',
    'Lasse', 'Milan', 'Lionel', 'Arturo', 'Peter', 'Tommy', 'Alex', 'Tayo'
  ];

  static List<Athlete> createDefaultRoster() {
    return List.generate(
      defaultAthleteNames.length,
      (index) => Athlete(
        id: 'athlete_${index + 1}',
        name: defaultAthleteNames[index],
        isSelected: true,
      ),
    );
  }
}
