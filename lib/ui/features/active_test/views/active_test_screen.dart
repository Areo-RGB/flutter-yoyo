import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/views/athlete_card.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/views/distance_meter.dart';

enum AthleteFilter { all, active, warned, finished }

class ActiveTestScreen extends StatefulWidget {
  const ActiveTestScreen({super.key});

  @override
  State<ActiveTestScreen> createState() => _ActiveTestScreenState();
}

class _ActiveTestScreenState extends State<ActiveTestScreen> {
  AthleteFilter _selectedFilter = AthleteFilter.all;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final uiState = viewModel.state;
    final athletes = uiState.selectedAthletes;

    if (athletes.isEmpty && uiState.testState == TestState.idle) {
      return Scaffold(
        backgroundColor: slate900,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.checklist, size: 64, color: slate500),
                const SizedBox(height: 16),
                const Text(
                  'No Athletes Selected',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please select athletes in the Setup tab to start the test.',
                  style: TextStyle(color: slate400, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Go to Setup Tab'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: athleticBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => viewModel.setActiveTab(AppTab.setup),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeCount = athletes.where((a) => a.status == AthleteStatus.running).length;
    final warnedCount = athletes.where((a) => a.status == AthleteStatus.warned).length;
    final finishedCount = athletes.where((a) => a.status == AthleteStatus.eliminated).length;

    List<Athlete> filteredAthletes = athletes;
    switch (_selectedFilter) {
      case AthleteFilter.active:
        filteredAthletes = athletes.where((a) => a.status == AthleteStatus.running).toList();
        break;
      case AthleteFilter.warned:
        filteredAthletes = athletes.where((a) => a.status == AthleteStatus.warned).toList();
        break;
      case AthleteFilter.finished:
        filteredAthletes = athletes.where((a) => a.status == AthleteStatus.eliminated).toList();
        break;
      case AthleteFilter.all:
        break;
    }

    return Scaffold(
      backgroundColor: slate900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              DistanceMeter(
                uiState: uiState,
                onStartTest: viewModel.startTest,
                onPauseTest: viewModel.pauseTest,
                onResumeTest: viewModel.resumeTest,
                onStopTest: viewModel.stopAndFinishTest,
                onResetTest: viewModel.resetTest,
                onToggleSound: viewModel.toggleSound,
              ),
              const SizedBox(height: 10),
              
              // Athletes Header
              Row(
                children: [
                  const Text('LIVE ATHLETES', style: TextStyle(color: slate200, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: runGreen.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text('$activeCount running', style: const TextStyle(color: runGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (warnedCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: warnOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('$warnedCount warned', style: const TextStyle(color: warnOrangeLight, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  if (uiState.undoStack.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.undo, color: slate400),
                      onPressed: viewModel.undoLastAction,
                      tooltip: 'Undo last action',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All (${athletes.length})', AthleteFilter.all, athleticBlueLight),
                    const SizedBox(width: 8),
                    _buildFilterChip('Running ($activeCount)', AthleteFilter.active, runGreen),
                    const SizedBox(width: 8),
                    _buildFilterChip('Warned ($warnedCount)', AthleteFilter.warned, warnOrangeLight),
                    const SizedBox(width: 8),
                    _buildFilterChip('Finished ($finishedCount)', AthleteFilter.finished, slate400),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Test completed banner
              if (uiState.testState == TestState.completed)
                Card(
                  color: slate800,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Text('🏁 Test Completed!', style: TextStyle(color: slate200, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: athleticBlue, foregroundColor: Colors.white),
                          onPressed: () => viewModel.setActiveTab(AppTab.leaderboard),
                          child: const Text('View Results'),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredAthletes.length,
                  itemBuilder: (context, index) {
                    final athlete = filteredAthletes[index];
                    return AthleteCard(
                      athlete: athlete,
                      currentLiveDistance: uiState.currentDistanceMeters,
                      currentLiveLevel: uiState.currentShuttle.levelDisplay,
                      onClick: () => viewModel.onAthleteClicked(athlete),
                      onUndo: () => viewModel.undoAthlete(athlete),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, AthleteFilter filter, Color selectedColor) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? slate900 : slate200, fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      backgroundColor: slate900,
      selectedColor: selectedColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? selectedColor : slate700),
      ),
      showCheckmark: false,
    );
  }
}
