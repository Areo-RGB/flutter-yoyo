import 'package:yoyo_ir1_tracker/data/models/athlete.dart';

/// Pure formatting helpers — intentionally free of view-model, timer, or
/// remote state so they can be tested without a [YoYoViewModel].
class SessionExportService {
  const SessionExportService();

  String generateCsvExport(List<Athlete> athletes) {
    final sb = StringBuffer();
    sb.writeln('Rank,Name,Status,Final Distance (m),Final Level,VO2Max');
    for (final athlete in athletes) {
      sb.writeln(
        '${athlete.rank ?? ""},${athlete.name},${athlete.status.name},'
        '${athlete.finalDistanceMeters ?? ""},'
        '${athlete.finalLevel ?? ""}.${athlete.finalShuttle ?? ""},'
        '${athlete.vo2Max ?? ""}',
      );
    }
    return sb.toString();
  }

  String generateSummaryText(
    List<Athlete> athletes, {
    String sessionTitle = 'Yo-Yo IR1 Results',
  }) {
    final sb = StringBuffer();
    sb.writeln('🏃‍♂️ $sessionTitle 🏃‍♂️');
    sb.writeln('');
    final sorted = List<Athlete>.from(athletes)
      ..sort((a, b) => (a.rank ?? 999).compareTo(b.rank ?? 999));
    for (var index = 0; index < sorted.length; index++) {
      final athlete = sorted[index];
      final medal = index == 0
          ? '🥇'
          : (index == 1 ? '🥈' : (index == 2 ? '🥉' : '▪️'));
      final distance = athlete.finalDistanceMeters != null
          ? '${athlete.finalDistanceMeters}m'
          : 'DNF';
      final level = athlete.finalLevel != null
          ? 'Lvl ${athlete.finalLevel}.${athlete.finalShuttle}'
          : '';
      sb.writeln('$medal ${athlete.name} - $distance $level');
    }
    return sb.toString();
  }
}

/// Backwards-compatible top-level shims so callers can migrate incrementally.
const _exportService = SessionExportService();

String buildCsvExport(List<Athlete> athletes) =>
    _exportService.generateCsvExport(athletes);

String buildSummaryText(
  List<Athlete> athletes, {
  String sessionTitle = 'Yo-Yo IR1 Results',
}) =>
    _exportService.generateSummaryText(
      athletes,
      sessionTitle: sessionTitle,
    );
