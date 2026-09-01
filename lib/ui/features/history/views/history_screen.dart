import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:yoyo_ir1_tracker/data/models/test_session.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

class HistoryScreen extends StatelessWidget {
  final YoYoViewModel viewModel;

  const HistoryScreen({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SessionWithResults>>(
      stream: viewModel.savedSessions,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history, color: athleticBlue, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Test History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sessions.length} past session${sessions.length == 1 ? "" : "s"}',
                        style: const TextStyle(color: slate400, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: sessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _HistorySessionCard(
                          sessionWithResults: sessions[index],
                          onDelete: () => viewModel.deleteSession(
                            sessions[index].session.id,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, color: slate700, size: 64),
          SizedBox(height: 16),
          Text(
            'No saved tests yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Complete a Yo-Yo IR1 test and save it\nto see your history here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: slate400, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _HistorySessionCard extends StatefulWidget {
  final SessionWithResults sessionWithResults;
  final VoidCallback onDelete;

  const _HistorySessionCard({
    required this.sessionWithResults,
    required this.onDelete,
  });

  @override
  State<_HistorySessionCard> createState() => _HistorySessionCardState();
}

class _HistorySessionCardState extends State<_HistorySessionCard> {
  bool _isExpanded = false;

  void _copyToClipboard(BuildContext context) {
    final s = widget.sessionWithResults.session;
    final r = widget.sessionWithResults.results;

    final dateStr = DateFormat('MMM dd, yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(s.timestampMs));

    final buffer = StringBuffer();
    buffer.writeln('🏃 Yo-Yo IR1 Test: ${s.title}');
    buffer.writeln('📅 Date: $dateStr');
    if (s.notes.isNotEmpty) {
      buffer.writeln('📝 Notes: ${s.notes}');
    }
    buffer.writeln('---');

    for (var i = 0; i < r.length; i++) {
      final res = r[i];
      String medal = '';
      if (i == 0) {
        medal = '🥇 ';
      } else if (i == 1) {
        medal = '🥈 ';
      } else if (i == 2) {
        medal = '🥉 ';
      } else {
        medal = '${i + 1}. ';
      }

      buffer.writeln(
        '$medal${res.athleteName}: ${res.finalDistanceMeters}m (Lvl ${res.finalLevel}.${res.finalShuttleNumber}, VO2max: ${res.vo2Max.toStringAsFixed(1)})',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString())).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            backgroundColor: runGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sessionWithResults.session;
    final r = widget.sessionWithResults.results;

    final dateStr = DateFormat('MMM dd, yyyy • HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(s.timestampMs));
    final maxDist = r.isEmpty
        ? 0
        : r.map((e) => e.finalDistanceMeters).reduce((a, b) => a > b ? a : b);

    return Card(
      color: slate900,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(color: slate400, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_run,
                              color: slate500,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Max: ${NumberFormat('#,###').format(maxDist)}m',
                              style: const TextStyle(
                                color: slate400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.group, color: slate500, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${r.length} athletes',
                              style: const TextStyle(
                                color: slate400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: athleticBlue),
                        onPressed: () => _copyToClipboard(context),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: warnOrange,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: slate900,
                              title: const Text(
                                'Delete Session?',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'This action cannot be undone.',
                                style: TextStyle(color: slate400),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    widget.onDelete();
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: warnOrange),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: slate500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, color: slate700),
            if (s.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Notes: ${s.notes}',
                  style: const TextStyle(
                    color: slate400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Container(
              color: slate800,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: r.asMap().entries.map((entry) {
                  final index = entry.key;
                  final res = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: const TextStyle(
                              color: slate500,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            res.athleteName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${NumberFormat('#,###').format(res.finalDistanceMeters)}m',
                              style: const TextStyle(
                                color: athleticBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Lvl ${res.finalLevel}.${res.finalShuttleNumber} • VO₂ ${res.vo2Max.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: slate400,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
