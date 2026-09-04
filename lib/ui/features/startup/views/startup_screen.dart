import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/domain/test_protocol.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final state = viewModel.state;
    final selectedType = state.selectedTestType;
    final selectedAthletesCount = state.selectedAthletes.length;

    return Scaffold(
      backgroundColor: slate950,
      body: SafeArea(
        child: Column(
          children: [
            // Header Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: slate900,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Yo-Yo Fitness Tracker',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a test protocol to start your session',
                          style: TextStyle(
                            color: slate400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isController)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: athleticBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: athleticBlue),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.gamepad, color: athleticBlueLight, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Controller',
                            style: TextStyle(
                              color: athleticBlueLight,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Protocol Selection Section
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'AVAILABLE TEST PROTOCOLS',
                      style: TextStyle(
                        color: slate400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  _TestProtocolCard(
                    testType: TestType.yoyoIR1,
                    isSelected: selectedType == TestType.yoyoIR1,
                    icon: Icons.directions_run,
                    accentColor: athleticBlue,
                    badges: const ['2 × 20m Shuttles', '10s Active Rest', 'Intermittent Recovery'],
                    description:
                        'Progressive intermittent shuttle test with 10-second active recovery walk between 40m shuttles. Ideal for soccer, basketball, and team sports.',
                    vo2Formula: 'VO₂max = Distance × 0.0084 + 36.4',
                    onSelect: () => viewModel.setSelectedTestType(TestType.yoyoIR1),
                  ),
                  const SizedBox(height: 14),
                  _TestProtocolCard(
                    testType: TestType.beepTest,
                    isSelected: selectedType == TestType.beepTest,
                    icon: Icons.speed,
                    accentColor: runGreen,
                    badges: const ['1 × 20m Shuttles', 'No Rest', '21 Speed Levels'],
                    description:
                        'Continuous multi-stage 20m shuttle run test with increasing pace per level and zero recovery intervals. Standard aerobic capacity test.',
                    vo2Formula: 'VO₂max = Speed (km/h) × 3.1 + 3.5',
                    onSelect: () => viewModel.setSelectedTestType(TestType.beepTest),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: slate900,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: Text(
                        selectedAthletesCount > 0
                            ? 'PROCEED TO SETUP ($selectedAthletesCount ATHLETES READY)'
                            : 'PROCEED TO TEST SETUP',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: runGreen,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        viewModel.setActiveTab(AppTab.setup);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestProtocolCard extends StatelessWidget {
  final TestType testType;
  final bool isSelected;
  final IconData icon;
  final Color accentColor;
  final List<String> badges;
  final String description;
  final String vo2Formula;
  final VoidCallback onSelect;

  const _TestProtocolCard({
    required this.testType,
    required this.isSelected,
    required this.icon,
    required this.accentColor,
    required this.badges,
    required this.description,
    required this.vo2Formula,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? slate900 : slate900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : slate700.withValues(alpha: 0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testType.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        testType.fullName,
                        style: const TextStyle(
                          color: slate400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? accentColor : slate800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.white : slate400,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSelected ? 'SELECTED' : 'SELECT',
                        style: TextStyle(
                          color: isSelected ? Colors.white : slate400,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                color: slate300,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: badges
                  .map(
                    (b) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: slate800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: slate700.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        b,
                        style: const TextStyle(
                          color: slate300,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: slate950.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calculate_outlined, color: athleticBlueLight, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    vo2Formula,
                    style: const TextStyle(
                      color: athleticBlueLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

