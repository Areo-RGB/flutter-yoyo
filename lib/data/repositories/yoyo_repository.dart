import 'dart:async';

import '../models/test_session.dart';
import '../services/database_service.dart';

class YoYoRepository {
  final DatabaseService _databaseService;

  YoYoRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  Stream<List<SessionWithResults>> get allSessions =>
      _databaseService.watchAllSessions();

  Future<int> saveSession(TestSession session, List<AthleteResult> results) {
    return _databaseService.saveCompleteSession(session, results);
  }

  Future<SessionWithResults?> getSessionById(int id) {
    return _databaseService.getSessionById(id);
  }

  Future<void> deleteSession(int id) {
    return _databaseService.deleteSession(id);
  }
}
