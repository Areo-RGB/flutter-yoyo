import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/athlete_avatar.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';
import 'package:yoyo_ir1_tracker/ui/features/roster/views/roster_management_dialog.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final state = viewModel.state;
    if (state.isController) {
      return _buildControllerSetup(viewModel);
    }
    final athletes = state.athletes;
    final selectedCount = state.selectedAthletes.length;

    return SafeArea(
      child: Column(
        children: [
          // Header Card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: slate900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Test Setup',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: runGreenDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$selectedCount / ${athletes.length} Selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.group_add, color: slate400),
                      tooltip: 'Manage Roster',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => RosterManagementDialog(
                            athletes: athletes,
                            onAddAthlete: viewModel.addAthlete,
                            onRemoveAthlete: viewModel.removeAthlete,
                            onResetDefaults: viewModel.resetRosterToDefaults,
                            onDismiss: () => Navigator.of(context).pop(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Active Test Protocol Banner
                InkWell(
                  onTap: () => viewModel.setActiveTab(AppTab.startup),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: athleticBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: athleticBlue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fitness_center, color: athleticBlueLight, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Test: ${state.selectedTestType.displayName}',
                              style: const TextStyle(
                                color: athleticBlueLight,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Change Protocol',
                              style: TextStyle(
                                color: slate400,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, color: slate400, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.select_all, size: 18),
                        label: const Text('Select All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: athleticBlueLight,
                          side: const BorderSide(color: slate700),
                        ),
                        onPressed: viewModel.selectAllAthletes,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.deselect, size: 18),
                        label: const Text('Deselect All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: slate400,
                          side: const BorderSide(color: slate700),
                        ),
                        onPressed: viewModel.deselectAllAthletes,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Athlete Selection Grid
          Expanded(
            child: athletes.isEmpty
                ? const Center(
                    child: Text(
                      'No athletes in roster. Add athletes to begin.',
                      style: TextStyle(color: slate400, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisExtent: 68,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: athletes.length,
                    itemBuilder: (context, index) {
                      final athlete = athletes[index];
                      return InkWell(
                        onTap: () =>
                            viewModel.toggleAthleteSelected(athlete.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: athlete.isSelected
                                ? slate800
                                : slate900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: athlete.isSelected
                                  ? athleticBlue
                                  : slate700.withValues(alpha: 0.5),
                              width: athlete.isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AthleteAvatar(
                                name: athlete.name,
                                radius: 18,
                                backgroundColor: athlete.isSelected
                                    ? athleticBlue
                                    : slate700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  athlete.name,
                                  style: TextStyle(
                                    color: athlete.isSelected
                                        ? Colors.white
                                        : slate500,
                                    fontSize: 15,
                                    fontWeight: athlete.isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Checkbox(
                                value: athlete.isSelected,
                                activeColor: athleticBlue,
                                onChanged: (_) =>
                                    viewModel.toggleAthleteSelected(athlete.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Start Test Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: slate900,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  selectedCount > 0
                      ? 'START TEST ($selectedCount ATHLETES)'
                      : 'SELECT ATHLETES TO START',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCount > 0 ? runGreen : slate700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedCount > 0
                    ? () {
                        viewModel.startTest();
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerSetup(YoYoViewModel viewModel) {
    final state = viewModel.state;
    final snapshot = state.remoteSnapshot;
    final athletes =
        snapshot?.athletes.map((athlete) => athlete.toAthlete()).toList() ??
        const [];
    final selectedCount = athletes
        .where((athlete) => athlete.isSelected)
        .length;
    final connected = state.remoteCommandsAvailable;

    return SafeArea(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: slate900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.gamepad, color: athleticBlueLight, size: 26),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controller setup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Roster and test state are read-only from the tablet.',
                        style: TextStyle(color: slate400, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  connected ? Icons.link : Icons.link_off,
                  color: connected ? runGreen : slate500,
                ),
              ],
            ),
          ),
          if (snapshot == null)
            Expanded(
              child: Center(
                child: Text(
                  state.remoteConnection.errorMessage ??
                      (state.remoteSnapshotStale
                          ? 'Waiting for a fresh tablet snapshot.'
                          : 'Connect to a tablet in Settings.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: slate400, fontSize: 16),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$selectedCount / ${athletes.length} selected on tablet',
                    style: const TextStyle(
                      color: slate200,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    snapshot.testState.name.toUpperCase(),
                    style: const TextStyle(
                      color: athleticBlueLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 68,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: athletes.length,
                itemBuilder: (context, index) {
                  final athlete = athletes[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: athlete.isSelected
                          ? slate800
                          : slate900.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: athlete.isSelected
                            ? athleticBlue
                            : slate700.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        AthleteAvatar(
                          name: athlete.name,
                          radius: 18,
                          backgroundColor: athlete.isSelected
                              ? athleticBlue
                              : slate700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            athlete.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: athlete.isSelected
                                  ? Colors.white
                                  : slate500,
                              fontWeight: athlete.isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Icon(
                          athlete.isSelected
                              ? Icons.check_circle
                              : Icons.remove_circle_outline,
                          color: athlete.isSelected ? runGreen : slate500,
                          size: 18,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: slate900,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 26),
                  label: Text(
                    snapshot.testState == TestState.paused
                        ? 'RESUME ON TABLET'
                        : 'START ON TABLET',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed:
                      connected &&
                          (snapshot.testState == TestState.idle ||
                              snapshot.testState == TestState.paused)
                      ? viewModel.startTest
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
