enum AthleteStatus { running, warned, eliminated }

enum ShuttlePhase { running, recovery }

enum TestState { idle, running, paused, completed }

// A sentinel lets copyWith distinguish an omitted nullable value from an
// explicit null. The latter is required when resetting a warning or result.
const Object _copyWithUnset = Object();

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
    Object? warningDistanceMeters = _copyWithUnset,
    Object? warningLevel = _copyWithUnset,
    Object? warningShuttle = _copyWithUnset,
    Object? warningTimestampMs = _copyWithUnset,
    Object? finalDistanceMeters = _copyWithUnset,
    Object? finalLevel = _copyWithUnset,
    Object? finalShuttle = _copyWithUnset,
    Object? finishTimestampMs = _copyWithUnset,
    Object? rank = _copyWithUnset,
    Object? vo2Max = _copyWithUnset,
  }) {
    return Athlete(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
      warningDistanceMeters: identical(warningDistanceMeters, _copyWithUnset)
          ? this.warningDistanceMeters
          : warningDistanceMeters as int?,
      warningLevel: identical(warningLevel, _copyWithUnset)
          ? this.warningLevel
          : warningLevel as String?,
      warningShuttle: identical(warningShuttle, _copyWithUnset)
          ? this.warningShuttle
          : warningShuttle as int?,
      warningTimestampMs: identical(warningTimestampMs, _copyWithUnset)
          ? this.warningTimestampMs
          : warningTimestampMs as int?,
      finalDistanceMeters: identical(finalDistanceMeters, _copyWithUnset)
          ? this.finalDistanceMeters
          : finalDistanceMeters as int?,
      finalLevel: identical(finalLevel, _copyWithUnset)
          ? this.finalLevel
          : finalLevel as String?,
      finalShuttle: identical(finalShuttle, _copyWithUnset)
          ? this.finalShuttle
          : finalShuttle as int?,
      finishTimestampMs: identical(finishTimestampMs, _copyWithUnset)
          ? this.finishTimestampMs
          : finishTimestampMs as int?,
      rank: identical(rank, _copyWithUnset) ? this.rank : rank as int?,
      vo2Max: identical(vo2Max, _copyWithUnset)
          ? this.vo2Max
          : vo2Max as double?,
    );
  }

  bool get isFinished => status == AthleteStatus.eliminated;
  bool get isWarned => status == AthleteStatus.warned;
  bool get isRunning => status == AthleteStatus.running;

  static const List<String> defaultAthleteNames = [
    'Silas',
    'Finley',
    'Arvid',
    'Lion',
    'Jakob',
    'Paul',
    'Lennox',
    'Levi',
    'Lasse',
    'Milan',
    'Lionel',
    'Arturo',
    'Peter',
    'Tommy',
    'Alex',
    'Tayo',
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
