import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yoyo_ir1_tracker/data/models/test_session.dart';
import 'package:yoyo_ir1_tracker/ui/core/athlete_avatar.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

enum TabelleMode { total, latest }

/// All-time leaderboard: sums every saved [AthleteResult.finalDistanceMeters]
/// per athlete name across the full history, plus a toggle to view only the
/// latest saved session. No live-session UI — no badges, no LIVE pill.
class TabelleScreen extends StatefulWidget {
  final YoYoViewModel viewModel;

  const TabelleScreen({super.key, required this.viewModel});

  @override
  State<TabelleScreen> createState() => _TabelleScreenState();
}

class _TabelleScreenState extends State<TabelleScreen> {
  TabelleMode _mode = TabelleMode.total;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionWithResults>>(
      stream: widget.viewModel.savedSessions,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <SessionWithResults>[];
        // Keep a stable sort newest-first for "latest".
        final sortedSessions = List<SessionWithResults>.from(sessions)
          ..sort((a, b) => b.session.timestampMs.compareTo(a.session.timestampMs));
        final latest = sortedSessions.isNotEmpty ? sortedSessions.first : null;

        final isLatest = _mode == TabelleMode.latest;
        final entries = isLatest
            ? (latest == null ? const <_TabelleEntry>[] : _buildLatest(latest))
            : _buildTabelle(sessions);

        final hasToggle = sessions.isNotEmpty;

        return SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: athleticBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: athleticBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tabelle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _subtitle(entries, sessions, latest, isLatest),
                            style: const TextStyle(
                              color: slate400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasToggle) _ModeToggle(
                      mode: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                    if (hasToggle) const SizedBox(width: 8),
                    if (entries.isNotEmpty && !isLatest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: slate800,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: slate700),
                        ),
                        child: Text(
                          '${_fmt(entries.fold<int>(0, (s, e) => s + e.totalDistance))} m total',
                          style: const TextStyle(
                            color: slate200,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Column header for the table
              if (entries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      const Expanded(
                        child: Text(
                          'ATHLETE',
                          style: TextStyle(
                            color: slate500,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Text(
                        isLatest ? 'DISTANCE' : 'TOTAL DISTANCE',
                        style: const TextStyle(
                          color: slate500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              if (entries.isNotEmpty) const SizedBox(height: 8),

              // List
              Expanded(
                child: entries.isEmpty
                    ? _EmptyTabelle(
                        hasSessions: sessions.isNotEmpty,
                        isLatest: isLatest,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return _TabelleCard(
                            entry: entries[index],
                            rank: index + 1,
                            isLatest: isLatest,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(
    List<_TabelleEntry> entries,
    List<SessionWithResults> sessions,
    SessionWithResults? latest,
    bool isLatest,
  ) {
    if (sessions.isEmpty) return 'No tests saved yet';
    if (isLatest) {
      if (latest == null) return 'No latest run';
      final d = DateTime.fromMillisecondsSinceEpoch(latest.session.timestampMs);
      final date = DateFormat('MMM dd, HH:mm').format(d);
      return 'Latest • $date • ${entries.length} athletes';
    }
    return '${entries.length} athletes • ${sessions.length} test${sessions.length == 1 ? '' : 's'} • all-time distance';
  }

  // ---------------------------------------------------------------------------
  // Aggregation — pure functions, easy to unit-test
  // ---------------------------------------------------------------------------

  static List<_TabelleEntry> _buildTabelle(
    List<SessionWithResults> sessions,
  ) {
    // Keyed by normalized name so "Paul" / "paul " collapse.
    final Map<String, _TabelleEntry> byKey = {};

    for (final swr in sessions) {
      for (final r in swr.results) {
        final rawName = r.athleteName.trim();
        if (rawName.isEmpty) continue;
        final key = rawName.toLowerCase();
        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = _TabelleEntry(
            displayName: rawName,
            totalDistance: r.finalDistanceMeters,
            testCount: 1,
            bestDistance: r.finalDistanceMeters,
            bestLevel: r.finalLevel,
            bestShuttle: r.finalShuttleNumber,
            avgVo2Max: r.vo2Max,
            lastTimestampMs: swr.session.timestampMs,
          );
        } else {
          final bestDist = r.finalDistanceMeters > existing.bestDistance
              ? r.finalDistanceMeters
              : existing.bestDistance;
          // Keep the level/shuttle that corresponds to the best distance.
          final keepNewBest = r.finalDistanceMeters > existing.bestDistance;
          byKey[key] = existing.copyWith(
            totalDistance: existing.totalDistance + r.finalDistanceMeters,
            testCount: existing.testCount + 1,
            bestDistance: bestDist,
            bestLevel: keepNewBest ? r.finalLevel : existing.bestLevel,
            bestShuttle: keepNewBest
                ? r.finalShuttleNumber
                : existing.bestShuttle,
            // Running average of VO2max weighted equally.
            avgVo2Max:
                (existing.avgVo2Max * existing.testCount + r.vo2Max) /
                (existing.testCount + 1),
            lastTimestampMs: r.finalDistanceMeters == bestDist
                ? swr.session.timestampMs
                : existing.lastTimestampMs,
          );
        }
      }
    }

    final list = byKey.values.toList()
      ..sort((a, b) {
        if (a.totalDistance != b.totalDistance) {
          return b.totalDistance.compareTo(a.totalDistance);
        }
        if (a.bestDistance != b.bestDistance) {
          return b.bestDistance.compareTo(a.bestDistance);
        }
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
    return list;
  }

  static List<_TabelleEntry> _buildLatest(SessionWithResults latest) {
    final entries = latest.results.map((r) {
      return _TabelleEntry(
        displayName: r.athleteName.trim(),
        totalDistance: r.finalDistanceMeters,
        testCount: 1,
        bestDistance: r.finalDistanceMeters,
        bestLevel: r.finalLevel,
        bestShuttle: r.finalShuttleNumber,
        avgVo2Max: r.vo2Max,
        lastTimestampMs: latest.session.timestampMs,
      );
    }).toList()
      ..sort((a, b) {
        if (a.totalDistance != b.totalDistance) {
          return b.totalDistance.compareTo(a.totalDistance);
        }
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
    return entries;
  }

  static String _fmt(int meters) => NumberFormat('#,###').format(meters);
}

// ---------------------------------------------------------------------------
// Small toggle — two icons in one pill
// ---------------------------------------------------------------------------

class _ModeToggle extends StatelessWidget {
  final TabelleMode mode;
  final ValueChanged<TabelleMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: slate800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slate700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleIcon(
            icon: Icons.leaderboard_outlined,
            selectedIcon: Icons.leaderboard,
            tooltip: 'All-time total',
            selected: mode == TabelleMode.total,
            onTap: () => onChanged(TabelleMode.total),
          ),
          _ToggleIcon(
            icon: Icons.history_outlined,
            selectedIcon: Icons.history,
            tooltip: 'Latest run',
            selected: mode == TabelleMode.latest,
            onTap: () => onChanged(TabelleMode.latest),
          ),
        ],
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleIcon({
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? athleticBlue.withValues(alpha: 0.22) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            selected ? selectedIcon : icon,
            size: 18,
            color: selected ? athleticBlueLight : slate400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model (private to this feature)
// ---------------------------------------------------------------------------

class _TabelleEntry {
  final String displayName;
  final int totalDistance;
  final int testCount;
  final int bestDistance;
  final String bestLevel;
  final int bestShuttle;
  final double avgVo2Max;
  final int lastTimestampMs;

  const _TabelleEntry({
    required this.displayName,
    required this.totalDistance,
    required this.testCount,
    required this.bestDistance,
    required this.bestLevel,
    required this.bestShuttle,
    required this.avgVo2Max,
    required this.lastTimestampMs,
  });

  _TabelleEntry copyWith({
    String? displayName,
    int? totalDistance,
    int? testCount,
    int? bestDistance,
    String? bestLevel,
    int? bestShuttle,
    double? avgVo2Max,
    int? lastTimestampMs,
  }) {
    return _TabelleEntry(
      displayName: displayName ?? this.displayName,
      totalDistance: totalDistance ?? this.totalDistance,
      testCount: testCount ?? this.testCount,
      bestDistance: bestDistance ?? this.bestDistance,
      bestLevel: bestLevel ?? this.bestLevel,
      bestShuttle: bestShuttle ?? this.bestShuttle,
      avgVo2Max: avgVo2Max ?? this.avgVo2Max,
      lastTimestampMs: lastTimestampMs ?? this.lastTimestampMs,
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets — deliberately free of any FINISHED / RUNNING / LIVE affordances
// ---------------------------------------------------------------------------

class _TabelleCard extends StatelessWidget {
  final _TabelleEntry entry;
  final int rank;
  final bool isLatest;

  const _TabelleCard({required this.entry, required this.rank, required this.isLatest});

  Color _rankColor(int r) {
    switch (r) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return slate700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    final avgDist = isLatest ? entry.totalDistance : (entry.totalDistance / entry.testCount).round();

    return Card(
      color: isPodium ? slate800 : slate800.withValues(alpha: 0.9),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPodium
              ? _rankColor(rank).withValues(alpha: 0.35)
              : Colors.transparent,
          width: isPodium ? 1 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _rankColor(rank),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: slate900,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Avatar (no status tint — pure identity)
            AthleteAvatar(
              name: entry.displayName,
              radius: 18,
              backgroundColor: slate700,
            ),
            const SizedBox(width: 12),
            // Name + meta (no warning/finished labels)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLatest
                        ? 'Lvl ${entry.bestLevel}.${entry.bestShuttle}  •  VO₂ ${entry.avgVo2Max.toStringAsFixed(1)}'
                        : '${entry.testCount} test${entry.testCount == 1 ? '' : 's'}'
                            '  •  avg ${_fmt(avgDist)} m'
                            '  •  best ${_fmt(entry.bestDistance)} m'
                            '  (Lvl ${entry.bestLevel}.${entry.bestShuttle})',
                    style: const TextStyle(color: slate400, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isLatest && entry.avgVo2Max > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '⌀ VO₂ ${entry.avgVo2Max.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: slate500,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Distance — hero metric
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(entry.totalDistance)} m',
                  style: const TextStyle(
                    color: athleticBlueLight,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isLatest ? 'FINAL' : 'TOTAL',
                  style: const TextStyle(
                    color: slate500,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => NumberFormat('#,###').format(v);
}

class _EmptyTabelle extends StatelessWidget {
  final bool hasSessions;
  final bool isLatest;
  const _EmptyTabelle({required this.hasSessions, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, color: slate700, size: 56),
            const SizedBox(height: 14),
            Text(
              isLatest ? 'No latest run' : 'No Tabelle yet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSessions
                  ? (isLatest
                      ? 'No results in the most recent session.'
                      : 'History exists but has no athlete results to aggregate.')
                  : 'Finish and save a test to populate the ranking.\n'
                      'Total sums every session; Latest shows the last run only.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: slate400, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
