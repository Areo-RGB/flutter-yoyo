import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

/// Live Results is now the collective meter only — no per-athlete list.
/// Optimized to fill the whole tab so it's readable from a few metres away.
/// Individual rankings live in Tabelle (with latest ↔ total toggle).
class LiveResultsScreen extends StatelessWidget {
  final YoYoUiState uiState;
  final YoYoViewModel viewModel;
  final VoidCallback onBackToTest;

  const LiveResultsScreen({
    super.key,
    required this.uiState,
    required this.viewModel,
    required this.onBackToTest,
  });

  // Backwards-compat alias.
  static const alias = SessionSummaryScreen;

  @override
  Widget build(BuildContext context) {
    final isLive = uiState.testState == TestState.running ||
        uiState.testState == TestState.paused;
    final isCompleted = uiState.testState == TestState.completed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            if (isLive) _LivePill(uiState: uiState),
            if (isLive) const SizedBox(height: 10),
            // The meter expands to consume every remaining pixel so the
            // distance + 4 stat cards are as large as possible.
            Expanded(
              child: isLive || isCompleted
                  ? _ExpandedMeterCard(uiState: uiState)
                  : const Center(
                      child: Text(
                        'No active test.\nStart one in Setup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: slate400, fontSize: 18, height: 1.4),
                      ),
                    ),
            ),
            if (isLive) const SizedBox(height: 12),
            if (isLive)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: eliminateRed,
                    side: const BorderSide(color: eliminateRed, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.stop, size: 22),
                  label: const Text(
                    'FINISH TEST & SAVE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.3),
                  ),
                  onPressed: uiState.isController
                      ? null
                      : () async {
                          await viewModel.finishAndSaveTest();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  viewModel.state.sessionSavedId != null
                                      ? 'Saved to History #${viewModel.state.sessionSavedId}'
                                      : 'Test finished',
                                ),
                                backgroundColor: runGreen,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                ),
              ),
            if (isCompleted) const SizedBox(height: 12),
            if (isCompleted)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: uiState.sessionSavedId != null ? slate700 : runGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(uiState.sessionSavedId != null ? Icons.check_circle : Icons.save),
                      label: Text(
                        uiState.sessionSavedId != null ? 'SAVED #${uiState.sessionSavedId}' : 'SAVE TO HISTORY',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: uiState.sessionSavedId != null || uiState.isController
                          ? null
                          : () async {
                              await viewModel.saveTestSession();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Saved to History #${viewModel.state.sessionSavedId}'),
                                    backgroundColor: runGreen,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: slate200,
                        side: const BorderSide(color: slate500),
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text('VIEW HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => viewModel.setActiveTab(AppTab.history),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Backwards-compat alias: old code imports SessionSummaryScreen.
typedef SessionSummaryScreen = LiveResultsScreen;

class _LivePill extends StatelessWidget {
  final YoYoUiState uiState;
  const _LivePill({required this.uiState});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: slate900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: athleticBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: runGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('● LIVE', style: TextStyle(color: runGreen, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${uiState.currentDistanceMeters} m  •  Lvl ${uiState.currentShuttle.levelDisplay}  •  ${uiState.activeRunnersCount} running  •  ${uiState.warnedRunnersCount} warned',
              style: const TextStyle(color: slate200, fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (uiState.testState == TestState.paused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: warnOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text('PAUSED', style: TextStyle(color: warnOrangeLight, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// Fills its parent and scales every element for far-distance legibility.
class _ExpandedMeterCard extends StatelessWidget {
  final YoYoUiState uiState;
  const _ExpandedMeterCard({required this.uiState});

  @override
  Widget build(BuildContext context) {
    final shuttle = uiState.currentShuttle;
    final isRunningPhase = uiState.currentPhase == ShuttlePhase.running;
    final remaining = isRunningPhase ? uiState.runningPhaseRemainingSeconds : uiState.recoveryPhaseRemainingSeconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the available height to pick comfortable proportions.
        // Tall screens get bigger type + thicker bar + taller stat cards.
        final h = constraints.maxHeight;
        final isTall = h > 520;
        final distanceSize = isTall ? 96.0 : 72.0;
        final metersLabelSize = isTall ? 20.0 : 16.0;
        final barHeight = isTall ? 16.0 : 12.0;
        final statValueSize = isTall ? 28.0 : 22.0;
        final statTitleSize = isTall ? 12.0 : 10.0;
        final statCardPaddingV = isTall ? 18.0 : 12.0;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: slate900, borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.fromLTRB(16, isTall ? 20 : 14, 16, isTall ? 20 : 14),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Distance — dominant, readable from ~5 m
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat('#,##0').format(uiState.currentDistanceMeters),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: distanceSize,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
              SizedBox(height: isTall ? 6 : 2),
              Text(
                'METERS',
                style: TextStyle(
                  color: slate400,
                  fontSize: metersLabelSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4.0,
                ),
              ),
              SizedBox(height: isTall ? 8 : 4),
              const Text('Total Yo-Yo IR1 Distance', style: TextStyle(color: slate400, fontSize: 15)),
              SizedBox(height: isTall ? 22 : 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (uiState.currentDistanceMeters / 3640).clamp(0.0, 1.0),
                  backgroundColor: slate700,
                  valueColor: const AlwaysStoppedAnimation<Color>(athleticBlueLight),
                  minHeight: barHeight,
                ),
              ),
              const Spacer(flex: 2),
              // 4 stat cards — stretched tall so they dominate the lower half
              Row(
                children: [
                  Expanded(child: _BigStatCard(title: 'LEVEL', value: shuttle.levelDisplay, subtitle: '', accentColor: runGreen, valueSize: statValueSize, titleSize: statTitleSize, paddingV: statCardPaddingV)),
                  const SizedBox(width: 10),
                  Expanded(child: _BigStatCard(title: 'SPEED', value: shuttle.speedKmh.toStringAsFixed(1), subtitle: 'km/h', accentColor: athleticBlueLight, valueSize: statValueSize, titleSize: statTitleSize, paddingV: statCardPaddingV)),
                  const SizedBox(width: 10),
                  Expanded(child: _BigStatCard(title: 'SHUTTLE', value: '${shuttle.shuttleNumber}', subtitle: '/91', accentColor: athleticBlueLight, valueSize: statValueSize, titleSize: statTitleSize, paddingV: statCardPaddingV)),
                  const SizedBox(width: 10),
                  Expanded(child: _BigStatCard(title: isRunningPhase ? 'RUN TIME' : 'REST TIME', value: remaining.toStringAsFixed(1), subtitle: 's', accentColor: isRunningPhase ? athleticBlueLight : warnOrangeLight, valueSize: statValueSize, titleSize: statTitleSize, paddingV: statCardPaddingV)),
                ],
              ),
              const Spacer(flex: 1),
            ],
          ),
        );
      },
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final double valueSize;
  final double titleSize;
  final double paddingV;
  const _BigStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.valueSize,
    required this.titleSize,
    required this.paddingV,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: 6),
      decoration: BoxDecoration(
        color: slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border(bottom: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: slate400, fontSize: titleSize, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          SizedBox(height: paddingV * 0.35),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(color: Colors.white, fontSize: valueSize, fontWeight: FontWeight.w900, height: 1.0)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(subtitle, style: TextStyle(color: slate400, fontSize: valueSize * 0.48, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
