import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

class DistanceMeter extends StatelessWidget {
  final YoYoUiState uiState;
  final VoidCallback onStartTest;
  final VoidCallback onPauseTest;
  final VoidCallback onResumeTest;
  final VoidCallback onStopTest;
  final VoidCallback onResetTest;
  final VoidCallback onToggleSound;

  const DistanceMeter({
    super.key,
    required this.uiState,
    required this.onStartTest,
    required this.onPauseTest,
    required this.onResumeTest,
    required this.onStopTest,
    required this.onResetTest,
    required this.onToggleSound,
  });

  String _formatElapsedTimer(int totalElapsedMillis) {
    final int minutes = (totalElapsedMillis ~/ 60000);
    final int seconds = (totalElapsedMillis % 60000) ~/ 1000;
    final int tenths = (totalElapsedMillis % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }

  @override
  Widget build(BuildContext context) {
    final currentShuttle = uiState.currentShuttle;

    final isRunningPhase = uiState.currentPhase == ShuttlePhase.running;
    final phaseColor = isRunningPhase ? athleticBlueLight : warnOrangeLight;
    final phaseText = isRunningPhase ? 'RUN (40m)' : 'RECOVERY (10s)';
    final phaseIcon = isRunningPhase ? Icons.directions_run : Icons.timer;
    
    final distanceFormat = NumberFormat('#,##0');
    final double remainingSeconds = isRunningPhase
        ? uiState.runningPhaseRemainingSeconds
        : uiState.recoveryPhaseRemainingSeconds;

    return Container(
      decoration: BoxDecoration(
        color: slate900,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: 0.2),
                  border: Border.all(color: phaseColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(phaseIcon, color: phaseColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      phaseText,
                      style: TextStyle(color: phaseColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                _formatElapsedTimer(uiState.totalElapsedMillis),
                style: const TextStyle(
                  color: slate200,
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  uiState.isSoundEnabled ? Icons.volume_up : Icons.volume_mute,
                  color: slate200,
                ),
                onPressed: onToggleSound,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            distanceFormat.format(uiState.currentDistanceMeters),
            style: const TextStyle(
              color: slate200,
              fontSize: 46,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'METERS',
            style: TextStyle(
              color: slate400,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Total Yo-Yo IR1 Distance',
            style: TextStyle(color: slate400, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (uiState.currentDistanceMeters / 3640).clamp(0.0, 1.0),
              backgroundColor: slate700,
              valueColor: const AlwaysStoppedAnimation<Color>(athleticBlueLight),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: MetricCard(title: 'LEVEL', value: currentShuttle.levelDisplay, subtitle: '', accentColor: runGreen)),
              const SizedBox(width: 8),
              Expanded(child: MetricCard(title: 'SPEED', value: currentShuttle.speedKmh.toStringAsFixed(1), subtitle: 'km/h', accentColor: athleticBlueLight)),
              const SizedBox(width: 8),
              Expanded(child: MetricCard(title: 'SHUTTLE', value: '${currentShuttle.shuttleNumber}', subtitle: '/91', accentColor: athleticBlueLight)),
              const SizedBox(width: 8),
              Expanded(child: MetricCard(title: isRunningPhase ? 'RUN TIME' : 'REST TIME', value: remainingSeconds.toStringAsFixed(1), subtitle: 's', accentColor: phaseColor)),
            ],
          ),
          const SizedBox(height: 24),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    switch (uiState.testState) {
      case TestState.idle:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: runGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('START TEST', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: onStartTest,
        );
      case TestState.running:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: warnOrangeLight,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.pause),
                label: const Text('PAUSE', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onPauseTest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: eliminateRed,
                  side: const BorderSide(color: eliminateRed),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('FINISH TEST', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onStopTest,
              ),
            ),
          ],
        );
      case TestState.paused:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: runGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onResumeTest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: eliminateRed,
                  side: const BorderSide(color: eliminateRed),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('FINISH', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onStopTest,
              ),
            ),
          ],
        );
      case TestState.completed:
        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: athleticBlueLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('NEW TEST / RESET', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: onResetTest,
        );
    }
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: slate800,
        borderRadius: BorderRadius.circular(12),
        border: Border(bottom: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: slate400, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: slate200, fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(color: slate400, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
