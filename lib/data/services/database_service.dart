import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/test_session.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;
  final StreamController<List<SessionWithResults>> _sessionsController =
      StreamController<List<SessionWithResults>>.broadcast();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('yoyo_ir1_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE test_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        timestampMs INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        maxDistanceAchieved INTEGER NOT NULL,
        maxLevelAchieved TEXT NOT NULL,
        totalAthletesCount INTEGER NOT NULL,
        completedAthletesCount INTEGER NOT NULL,
        notes TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE athlete_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId INTEGER NOT NULL,
        athleteName TEXT NOT NULL,
        finalDistanceMeters INTEGER NOT NULL,
        finalLevel TEXT NOT NULL,
        finalShuttleNumber INTEGER NOT NULL,
        warningDistanceMeters INTEGER,
        warningLevel TEXT,
        rank INTEGER NOT NULL,
        vo2Max REAL NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES test_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _notifyListeners() async {
    final sessions = await getAllSessions();
    _sessionsController.add(sessions);
  }

  Stream<List<SessionWithResults>> watchAllSessions() {
    _notifyListeners(); // Initial load
    return _sessionsController.stream;
  }

  Future<int> insertSession(TestSession session) async {
    final db = await database;
    final id = await db.insert('test_sessions', session.toMap());
    await _notifyListeners();
    return id;
  }

  Future<void> insertResults(List<AthleteResult> results) async {
    final db = await database;
    final batch = db.batch();
    for (final result in results) {
      batch.insert('athlete_results', result.toMap());
    }
    await batch.commit(noResult: true);
    await _notifyListeners();
  }

  Future<int> saveCompleteSession(
    TestSession session,
    List<AthleteResult> results,
  ) async {
    final db = await database;
    int sessionId = 0;

    await db.transaction((txn) async {
      sessionId = await txn.insert('test_sessions', session.toMap());

      for (final result in results) {
        final resultWithId = result.copyWith(sessionId: sessionId);
        await txn.insert('athlete_results', resultWithId.toMap());
      }
    });

    await _notifyListeners();
    return sessionId;
  }

  Future<List<SessionWithResults>> getAllSessions() async {
    final db = await database;
    final sessionMaps = await db.query(
      'test_sessions',
      orderBy: 'timestampMs DESC',
    );

    List<SessionWithResults> results = [];

    for (final sessionMap in sessionMaps) {
      final session = TestSession.fromMap(sessionMap);

      final resultMaps = await db.query(
        'athlete_results',
        where: 'sessionId = ?',
        whereArgs: [session.id],
      );

      final athleteResults = resultMaps
          .map((m) => AthleteResult.fromMap(m))
          .toList();

      results.add(
        SessionWithResults(session: session, results: athleteResults),
      );
    }

    return results;
  }

  Future<SessionWithResults?> getSessionById(int id) async {
    final db = await database;
    final sessionMaps = await db.query(
      'test_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (sessionMaps.isEmpty) return null;

    final session = TestSession.fromMap(sessionMaps.first);

    final resultMaps = await db.query(
      'athlete_results',
      where: 'sessionId = ?',
      whereArgs: [session.id],
    );

    final athleteResults = resultMaps
        .map((m) => AthleteResult.fromMap(m))
        .toList();

    return SessionWithResults(session: session, results: athleteResults);
  }

  Future<void> deleteSession(int id) async {
    final db = await database;
    await db.delete('test_sessions', where: 'id = ?', whereArgs: [id]);
    await _notifyListeners();
  }

  Future<void> deleteAllSessions() async {
    final db = await database;
    await db.delete('test_sessions');
    await _notifyListeners();
  }
}
