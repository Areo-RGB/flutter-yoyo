import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';
import 'package:yoyo_ir1_tracker/ui/features/roster/views/roster_management_dialog.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final state = viewModel.state;
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
                        const Icon(Icons.checklist, color: athleticBlueLight, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Test Setup',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: runGreenDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$selectedCount / ${athletes.length} Selected',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 68,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: athletes.length,
                    itemBuilder: (context, index) {
                      final athlete = athletes[index];
                      final initials = athlete.name.isNotEmpty ? athlete.name[0].toUpperCase() : '?';

                      return InkWell(
                        onTap: () => viewModel.toggleAthleteSelected(athlete.id),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: athlete.isSelected ? slate800 : slate900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: athlete.isSelected ? athleticBlue : slate700.withValues(alpha: 0.5),
                              width: athlete.isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: athlete.isSelected ? athleticBlue : slate700,
                                child: Text(
                                  initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  athlete.name,
                                  style: TextStyle(
                                    color: athlete.isSelected ? Colors.white : slate500,
                                    fontSize: 15,
                                    fontWeight: athlete.isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Checkbox(
                                value: athlete.isSelected,
                                activeColor: athleticBlue,
                                onChanged: (_) => viewModel.toggleAthleteSelected(athlete.id),
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
                  selectedCount > 0 ? 'START TEST ($selectedCount ATHLETES)' : 'SELECT ATHLETES TO START',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCount > 0 ? runGreen : slate700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}

