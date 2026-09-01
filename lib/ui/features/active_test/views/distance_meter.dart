import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/domain/remote_protocol.dart';
// ignore: unused_import - ShuttlePhase/TestState are referenced via type checks
import 'package:yoyo_ir1_tracker/domain/yoyo_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/core/format_helpers.dart';
import 'package:yoyo_ir1_tracker/ui/core/theme.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

/// Shared view data for the phase badge so DistanceMeter and
/// RemoteDistanceMeter render consistently.
class _PhaseDisplay {
  final bool isRunning;
  final Color color;
  final String text;
  final IconData icon;

  const _PhaseDisplay({
    required this.isRunning,
    required this.color,
    required this.text,
    required this.icon,
  });

  factory _PhaseDisplay.fromPhase(ShuttlePhase phase) {
    final isRunning = phase == ShuttlePhase.running;
    return _PhaseDisplay(
      isRunning: isRunning,
      color: isRunning ? athleticBlueLight : warnOrangeLight,
      text: isRunning ? 'RUN (40m)' : 'RECOVERY (10s)',
      icon: isRunning ? Icons.directions_run : Icons.timer,
    );
  }

  factory _PhaseDisplay.compactFromPhase(ShuttlePhase phase) {
    final isRunning = phase == ShuttlePhase.running;
    return _PhaseDisplay(
      isRunning: isRunning,
      color: isRunning ? athleticBlueLight : warnOrangeLight,
      text: isRunning ? 'RUN · 40m' : 'RECOVERY · 10s',
      icon: isRunning ? Icons.directions_run : Icons.timer,
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final _PhaseDisplay phase;
  final bool compact;

  const _PhaseBadge({required this.phase, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: phase.color.withValues(alpha: 0.18),
          border: Border.all(color: phase.color, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          phase.text,
          style: TextStyle(
            color: phase.color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: phase.color.withValues(alpha: 0.2),
        border: Border.all(color: phase.color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(phase.icon, color: phase.color, size: 16),
          const SizedBox(width: 8),
          Text(
            phase.text,
            style: TextStyle(color: phase.color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTimerText extends StatelessWidget {
  final int totalElapsedMillis;
  final double fontSize;

  const _ElapsedTimerText({
    required this.totalElapsedMillis,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatElapsedTimer(totalElapsedMillis),
      style: TextStyle(
        color: slate200,
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: fontSize > 18 ? 0.5 : null,
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle(Color bg, {Size? minSize}) =>
    ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      minimumSize: minSize ?? const Size(double.infinity, 48),
      shape: AppDecorations.roundedButtonShape(),
    );

ButtonStyle _outlineButtonStyle(Color fg, {Size? minSize}) =>
    OutlinedButton.styleFrom(
      foregroundColor: fg,
      side: BorderSide(color: fg),
      minimumSize: minSize ?? const Size(0, 48),
      shape: AppDecorations.roundedButtonShape(),
    );

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

  @override
  Widget build(BuildContext context) {
    final currentShuttle = uiState.currentShuttle;
    final phase = _PhaseDisplay.fromPhase(uiState.currentPhase);
    final distanceFormat = NumberFormat('#,##0');
    final double remainingSeconds = phase.isRunning
        ? uiState.runningPhaseRemainingSeconds
        : uiState.recoveryPhaseRemainingSeconds;

    return Container(
      decoration: AppDecorations.slateCard(radius: 20),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PhaseBadge(phase: phase),
              _ElapsedTimerText(totalElapsedMillis: uiState.totalElapsedMillis),
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
              valueColor: const AlwaysStoppedAnimation<Color>(
                athleticBlueLight,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'LEVEL',
                  value: currentShuttle.levelDisplay,
                  subtitle: '',
                  accentColor: runGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  title: 'SPEED',
                  value: currentShuttle.speedKmh.toStringAsFixed(1),
                  subtitle: 'km/h',
                  accentColor: athleticBlueLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  title: 'SHUTTLE',
                  value: '${currentShuttle.shuttleNumber}',
                  subtitle: '/91',
                  accentColor: athleticBlueLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricCard(
                  title: phase.isRunning ? 'RUN TIME' : 'REST TIME',
                  value: remainingSeconds.toStringAsFixed(1),
                  subtitle: 's',
                  accentColor: phase.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildControls(phase),
        ],
      ),
    );
  }

  Widget _buildControls(_PhaseDisplay phase) {
    switch (uiState.testState) {
      case TestState.idle:
        return ElevatedButton.icon(
          style: _primaryButtonStyle(runGreen),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            'START TEST',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: onStartTest,
        );
      case TestState.running:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: _primaryButtonStyle(
                  warnOrangeLight,
                  minSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.pause),
                label: const Text(
                  'PAUSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onPauseTest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                style: _outlineButtonStyle(
                  eliminateRed,
                  minSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.stop),
                label: const Text(
                  'FINISH TEST',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
                style: _primaryButtonStyle(
                  runGreen,
                  minSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'RESUME',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onResumeTest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                style: _outlineButtonStyle(
                  eliminateRed,
                  minSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.stop),
                label: const Text(
                  'FINISH',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onStopTest,
              ),
            ),
          ],
        );
      case TestState.completed:
        return ElevatedButton.icon(
          style: _primaryButtonStyle(athleticBlueLight),
          icon: const Icon(Icons.refresh),
          label: const Text(
            'NEW TEST / RESET',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: onResetTest,
        );
    }
  }
}

class RemoteDistanceMeter extends StatelessWidget {
  final RemoteTestSnapshot snapshot;
  final YoYoUiState? controllerState;
  final bool commandsAvailable;
  final VoidCallback onStartTest;
  final VoidCallback onPauseTest;
  final VoidCallback onResetTest;

  const RemoteDistanceMeter({
    super.key,
    required this.snapshot,
    this.controllerState,
    required this.commandsAvailable,
    required this.onStartTest,
    required this.onPauseTest,
    required this.onResetTest,
  });

  @override
  Widget build(BuildContext context) {
    final effPhase = controllerState?.currentPhase ?? snapshot.phase;
    final effTotalMs =
        controllerState?.totalElapsedMillis ?? snapshot.totalElapsedMillis;
    final effDistance =
        controllerState?.currentDistanceMeters ?? snapshot.currentDistanceMeters;
    final effTestState = controllerState?.testState ?? snapshot.testState;
    final phase = _PhaseDisplay.compactFromPhase(effPhase);

    return Container(
      decoration: AppDecorations.slateCard(radius: 16),
      padding: AppDecorations.cardPaddingCompact,
      child: Column(
        children: [
          Row(
            children: [
              _PhaseBadge(phase: phase, compact: true),
              const Spacer(),
              _ElapsedTimerText(totalElapsedMillis: effTotalMs, fontSize: 18),
              const SizedBox(width: 8),
              const Icon(Icons.lock, color: slate500, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                NumberFormat('#,##0').format(effDistance),
                style: const TextStyle(
                  color: slate200,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'm',
                style: TextStyle(
                  color: slate400,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildControllerControl(effTestState),
        ],
      ),
    );
  }

  Widget _buildControllerControl(TestState effTestState) {
    switch (effTestState) {
      case TestState.idle:
        return ElevatedButton.icon(
          style: _primaryButtonStyle(
            runGreen,
            minSize: const Size(double.infinity, 42),
          ),
          icon: const Icon(Icons.play_arrow, size: 20),
          label: const Text(
            'START ON TABLET',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: commandsAvailable ? onStartTest : null,
        );
      case TestState.running:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: _primaryButtonStyle(
                  warnOrangeLight,
                  minSize: const Size(0, 42),
                ),
                icon: const Icon(Icons.pause, size: 18),
                label: const Text(
                  'PAUSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: commandsAvailable ? onPauseTest : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: _outlineButtonStyle(
                  eliminateRed,
                  minSize: const Size(0, 42),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'RESET',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: commandsAvailable ? onResetTest : null,
              ),
            ),
          ],
        );
      case TestState.paused:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: _primaryButtonStyle(
                  runGreen,
                  minSize: const Size(0, 42),
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'RESUME',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: commandsAvailable ? onStartTest : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: _outlineButtonStyle(
                  eliminateRed,
                  minSize: const Size(0, 42),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'RESET',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: commandsAvailable ? onResetTest : null,
              ),
            ),
          ],
        );
      case TestState.completed:
        return ElevatedButton.icon(
          style: _primaryButtonStyle(
            athleticBlueLight,
            minSize: const Size(double.infinity, 42),
          ),
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text(
            'RESET ON TABLET',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: commandsAvailable ? onResetTest : null,
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
        borderRadius: BorderRadius.circular(AppDecorations.badgeRadius),
        border: Border(bottom: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: slate400,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: slate200,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(color: slate400, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
