import 'package:flutter/material.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

class SessionSummaryScreen extends StatelessWidget {
  final YoYoUiState uiState;
  final YoYoViewModel viewModel;
  final VoidCallback onBackToTest;

  const SessionSummaryScreen({
    super.key,
    required this.uiState,
    required this.viewModel,
    required this.onBackToTest,
  });

  @override
  Widget build(BuildContext context) {
    final athletes = uiState.selectedAthletes;

    final sortedAthletes = List<Athlete>.from(athletes)
      ..sort((a, b) {
        final distA = a.finalDistanceMeters ?? 0;
        final distB = b.finalDistanceMeters ?? 0;
        if (distA != distB) return distB.compareTo(distA);
        
        final timeA = a.finishTimestampMs ?? 0;
        final timeB = b.finishTimestampMs ?? 0;
        if (timeA != timeB) return timeA.compareTo(timeB);
        
        return a.name.compareTo(b.name);
      });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0, left: 12.0, right: 12.0),
        child: sortedAthletes.isEmpty
            ? const Center(
                child: Text(
                  'No athletes selected for results.',
                  style: TextStyle(color: slate400, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: sortedAthletes.length,
                itemBuilder: (context, index) {
                  return _LeaderboardCard(athlete: sortedAthletes[index], rank: index + 1);
                },
              ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final Athlete athlete;
  final int rank;

  const _LeaderboardCard({required this.athlete, required this.rank});

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return slate700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = athlete.finalDistanceMeters ?? 0;

    return Card(
      color: slate800,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(color: slate900, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                athlete.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${distance}m',
              style: const TextStyle(color: athleticBlue, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
