import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yoyo_ir1_tracker/data/models/athlete.dart';
import 'package:yoyo_ir1_tracker/data/repositories/yoyo_repository.dart';
import 'package:yoyo_ir1_tracker/data/services/database_service.dart';
import 'package:yoyo_ir1_tracker/data/services/nearby_connection_service.dart';
import 'package:yoyo_ir1_tracker/ui/core/colors.dart';
import 'package:yoyo_ir1_tracker/ui/core/theme.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/view_models/yoyo_view_model.dart';
import 'package:yoyo_ir1_tracker/ui/features/active_test/views/active_test_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/history/views/history_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/live_results/views/live_results_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/settings/views/settings_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/setup/views/setup_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/startup/views/startup_screen.dart';
import 'package:yoyo_ir1_tracker/ui/features/tabelle/views/tabelle_screen.dart';
import 'package:yoyo_ir1_tracker/utils/sound_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable Immersive Sticky mode (fullscreen, hides status bar & navigation bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final dbService = DatabaseService();
  final repository = YoYoRepository(databaseService: dbService);
  final soundHelper = SoundHelper();
  await soundHelper.init();
  final nearbyService = NearbyConnectionService();

  runApp(
    ChangeNotifierProvider(
      create: (_) => YoYoViewModel(
        repository: repository,
        soundHelper: soundHelper,
        nearbyService: nearbyService,
      ),
      child: const YoYoApp(),
    ),
  );
}

class YoYoApp extends StatelessWidget {
  const YoYoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YoYo',
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
    final state = viewModel.state;

    // Live tabs (Live Test + Live Results) only exist while a test session
    // is active. Change the predicate to
    //   state.testState == TestState.running || state.testState == TestState.paused
    // if you want them to disappear the instant the test completes.
    final isLiveVisible = state.testState != TestState.idle;

    final visibleTabs = <AppTab>[
      AppTab.startup,
      AppTab.setup,
      if (isLiveVisible) AppTab.live,
      if (isLiveVisible) AppTab.leaderboard,
      AppTab.tabelle,
      AppTab.history,
      AppTab.settings,
    ];

    // If the stored activeTab is currently hidden (e.g. after a reset),
    // fall back to Startup for rendering and for the nav highlight.
    final effectiveTab = visibleTabs.contains(state.activeTab)
        ? state.activeTab
        : AppTab.startup;

    // Gently correct the view-model after the frame so next rebuild is
    // consistent — avoids calling notify during build.
    if (effectiveTab != state.activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Guard against the widget being disposed mid-frame.
        // No need to await — just nudge the stored tab.
        viewModel.setActiveTab(effectiveTab);
      });
    }

    Widget body;
    switch (effectiveTab) {
      case AppTab.startup:
        body = const StartupScreen();
        break;
      case AppTab.setup:
        body = const SetupScreen();
        break;
      case AppTab.live:
        body = const ActiveTestScreen();
        break;
      case AppTab.leaderboard:
        body = LiveResultsScreen(
          uiState: state,
          viewModel: viewModel,
          onBackToTest: () => viewModel.setActiveTab(AppTab.live),
        );
        break;
      case AppTab.tabelle:
        body = TabelleScreen(viewModel: viewModel);
        break;
      case AppTab.history:
        body = HistoryScreen(viewModel: viewModel);
        break;
      case AppTab.settings:
        body = SettingsScreen(
          volumeBoost: state.volumeBoost,
          isBoostEnabled: state.isBoostEnabled,
          onBoostEnabledChange: viewModel.setBoostEnabled,
          onVolumeBoostChange: viewModel.setVolumeBoost,
          remoteRole: state.remoteRole,
          remoteEnabled: state.remoteEnabled,
          remoteConnection: state.remoteConnection,
          onRemoteRoleChange: (role) {
            viewModel.setRemoteRole(role);
          },
          onRemoteEnabledChange: (enabled) {
            viewModel.setRemoteEnabled(enabled);
          },
          onRemoteRetry: () {
            viewModel.retryRemoteConnection();
          },
          onRemoteConnect: (endpointId) {
            viewModel.connectToRemoteEndpoint(endpointId);
          },
          onRemoteDisconnect: () {
            viewModel.disconnectRemote();
          },
          onRemoteAuthenticationDecision: (accepted) {
            viewModel.confirmRemoteAuthentication(accepted);
          },
        );
        break;
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: visibleTabs.indexOf(effectiveTab),
        onDestinationSelected: (index) {
          viewModel.setActiveTab(visibleTabs[index]);
        },
        backgroundColor: slate900,
        indicatorColor: athleticBlue,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Startup',
          ),
          const NavigationDestination(
            icon: Icon(Icons.playlist_add_check),
            label: 'Setup',
          ),
          if (isLiveVisible)
            const NavigationDestination(
              icon: Icon(Icons.directions_run),
              label: 'Live Test',
            ),
          if (isLiveVisible)
            const NavigationDestination(
              icon: Icon(Icons.leaderboard),
              label: 'Live Results',
            ),
          const NavigationDestination(
            icon: Icon(Icons.table_chart),
            label: 'Tabelle',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
