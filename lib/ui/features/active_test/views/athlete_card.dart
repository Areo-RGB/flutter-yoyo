import 'package:flutter/material.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';

class AthleteCard extends StatelessWidget {
  final Athlete athlete;
  final int currentLiveDistance;
  final String currentLiveLevel;
  final VoidCallback onClick;
  final VoidCallback onUndo;

  const AthleteCard({
    super.key,
    required this.athlete,
    required this.currentLiveDistance,
    required this.currentLiveLevel,
    required this.onClick,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = athlete.status == AthleteStatus.running;
    final isWarned = athlete.status == AthleteStatus.warned;
    final isEliminated = athlete.status == AthleteStatus.eliminated;

    final targetBorderWidth = isWarned ? 3.5 : 1.0;
    final targetBorderColor = isWarned ? warnOrange : (isEliminated ? slate700 : Colors.transparent);
    final bgColor = isWarned ? warnOrange.withValues(alpha: 0.1) : (isEliminated ? slate800.withValues(alpha: 0.5) : slate800);
    final avatarColor = isEliminated ? slate700 : (isWarned ? warnOrange : athleticBlue);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 1.0, end: targetBorderWidth),
      builder: (context, borderWidth, child) {
        return TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 300),
          tween: ColorTween(begin: Colors.transparent, end: targetBorderColor),
          builder: (context, borderColor, child) {
            return Card(
              margin: EdgeInsets.zero,
              color: bgColor,
              elevation: isEliminated ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor ?? Colors.transparent, width: borderWidth),
              ),
              child: InkWell(
                onTap: isEliminated ? null : onClick,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: avatarColor,
                            child: Text(
                              _getInitials(athlete.name),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  athlete.name,
                                  style: TextStyle(
                                    color: isEliminated ? slate400 : slate200,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                _buildStatusTag(isRunning, isWarned, isEliminated),
                              ],
                            ),
                          ),
                          if (isWarned || isEliminated)
                            IconButton(
                              icon: const Icon(Icons.undo, color: slate400),
                              onPressed: onUndo,
                              tooltip: 'Undo',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                      const Spacer(),
                      _buildActionBox(isRunning, isWarned, isEliminated),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  Widget _buildStatusTag(bool isRunning, bool isWarned, bool isEliminated) {
    Color color;
    String text;
    IconData? icon;

    if (isRunning) {
      color = runGreen;
      text = 'RUNNING';
      icon = Icons.circle;
    } else if (isWarned) {
      color = warnOrangeLight;
      text = '1st WARNING';
      icon = Icons.warning_rounded;
    } else {
      color = slate400;
      text = 'FINISHED • Rank #${athlete.rank ?? "-"}';
      icon = null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionBox(bool isRunning, bool isWarned, bool isEliminated) {
    if (isRunning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: slate900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Tap to warn athlete',
          textAlign: TextAlign.center,
          style: TextStyle(color: slate400, fontSize: 12),
        ),
      );
    } else if (isWarned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: warnOrange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              'Warned at: ${athlete.warningDistanceMeters ?? currentLiveDistance}m (Lvl ${athlete.warningLevel ?? currentLiveLevel})',
              style: const TextStyle(color: warnOrangeLight, fontSize: 10),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap again to save distance & finish',
              textAlign: TextAlign.center,
              style: TextStyle(color: slate200, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: slate900,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildResultStat('Dist', '${athlete.finalDistanceMeters ?? "-"}m'),
            _buildResultStat('Lvl', '${athlete.finalLevel ?? "-"}.${athlete.finalShuttle ?? ""}'),
            _buildResultStat('VO2', athlete.vo2Max?.toStringAsFixed(1) ?? '-'),
          ],
        ),
      );
    }
  }

  Widget _buildResultStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: slate400, fontSize: 10)),
        Text(value, style: const TextStyle(color: slate200, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
