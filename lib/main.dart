import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/data/repositories/yoyo_repository.dart';
import 'package:yoyo_ir1_tracker/data/services/database_service.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/core/theme.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/views/active_test_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/history/views/history_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/session_summary/views/session_summary_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/settings/views/settings_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/setup/views/setup_screen.dart';
import 'package:yoyo_ir1_tracker/utils/sound_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Immersive Sticky mode (fullscreen, hides status bar & navigation bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final dbService = DatabaseService();
  final repository = YoYoRepository(databaseService: dbService);
  final soundHelper = SoundHelper();
  await soundHelper.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => YoYoViewModel(repository: repository, soundHelper: soundHelper),
      child: const YoYoApp(),
    ),
  );
}

class YoYoApp extends StatelessWidget {
  const YoYoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yo-Yo IR1',
      debugShowCheckedModeBanner: false,
      theme: yoYoDarkTheme(),
      home: const YoYoHome(),
    );
  }
}

class YoYoHome extends StatelessWidget {
  const YoYoHome({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<YoYoViewModel>();
    final activeTab = viewModel.state.activeTab;

    Widget body;
    switch (activeTab) {
      case AppTab.setup:
        body = const SetupScreen();
        break;
      case AppTab.live:
        body = const ActiveTestScreen();
        break;
      case AppTab.leaderboard:
        body = SessionSummaryScreen(
          uiState: viewModel.state,
          viewModel: viewModel,
          onBackToTest: () => viewModel.setActiveTab(AppTab.live),
        );
        break;
      case AppTab.history:
        body = HistoryScreen(viewModel: viewModel);
        break;
      case AppTab.settings:
        body = SettingsScreen(
          volumeBoost: viewModel.state.volumeBoost,
          isBoostEnabled: viewModel.state.isBoostEnabled,
          onBoostEnabledChange: viewModel.setBoostEnabled,
          onVolumeBoostChange: viewModel.setVolumeBoost,
        );
        break;
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeTab.index,
        onDestinationSelected: (index) {
          viewModel.setActiveTab(AppTab.values[index]);
        },
        backgroundColor: slate900,
        indicatorColor: athleticBlue,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.playlist_add_check),
            label: 'Setup',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'Live Test',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard),
            label: 'Results',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
