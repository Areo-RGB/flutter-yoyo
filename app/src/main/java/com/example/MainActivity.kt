package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Leaderboard
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.ui.screens.ActiveTestScreen
import com.example.ui.screens.HistoryScreen
import com.example.ui.screens.RosterManagementDialog
import com.example.ui.screens.SessionSummaryScreen
import com.example.ui.screens.SettingsScreen
import com.example.ui.theme.AthleticBlue
import com.example.ui.theme.Slate900
import com.example.ui.theme.YoYoTheme
import com.example.viewmodel.AppTab
import com.example.viewmodel.YoYoViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: YoYoViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            YoYoTheme {
                YoYoApp(viewModel = viewModel)
            }
        }
    }
}

@Composable
fun YoYoApp(viewModel: YoYoViewModel) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val savedSessions by viewModel.savedSessions.collectAsStateWithLifecycle()

    var showRosterManager by remember { mutableStateOf(false) }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            NavigationBar(
                containerColor = Slate900,
                tonalElevation = 8.dp,
                modifier = Modifier.testTag("bottom_navigation_bar")
            ) {
                NavigationBarItem(
                    selected = uiState.activeTab == AppTab.TEST,
                    onClick = { viewModel.setActiveTab(AppTab.TEST) },
                    icon = { Icon(Icons.Default.DirectionsRun, contentDescription = "Yo-Yo Test") },
                    label = { Text("Yo-Yo Test") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.White,
                        selectedTextColor = Color.White,
                        indicatorColor = AthleticBlue,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray
                    ),
                    modifier = Modifier.testTag("nav_test_tab")
                )

                NavigationBarItem(
                    selected = uiState.activeTab == AppTab.LEADERBOARD,
                    onClick = { viewModel.setActiveTab(AppTab.LEADERBOARD) },
                    icon = { Icon(Icons.Default.Leaderboard, contentDescription = "Results") },
                    label = { Text("Results") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.White,
                        selectedTextColor = Color.White,
                        indicatorColor = AthleticBlue,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray
                    ),
                    modifier = Modifier.testTag("nav_results_tab")
                )

                NavigationBarItem(
                    selected = uiState.activeTab == AppTab.HISTORY,
                    onClick = { viewModel.setActiveTab(AppTab.HISTORY) },
                    icon = { Icon(Icons.Default.History, contentDescription = "History") },
                    label = { Text("History") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.White,
                        selectedTextColor = Color.White,
                        indicatorColor = AthleticBlue,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray
                    ),
                    modifier = Modifier.testTag("nav_history_tab")
                )

                NavigationBarItem(
                    selected = uiState.activeTab == AppTab.SETTINGS,
                    onClick = { viewModel.setActiveTab(AppTab.SETTINGS) },
                    icon = { Icon(Icons.Default.Settings, contentDescription = "Settings") },
                    label = { Text("Settings") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.White,
                        selectedTextColor = Color.White,
                        indicatorColor = AthleticBlue,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray
                    ),
                    modifier = Modifier.testTag("nav_settings_tab")
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (uiState.activeTab) {
                AppTab.TEST -> {
                    ActiveTestScreen(
                        uiState = uiState,
                        onStartTest = { viewModel.startTest() },
                        onPauseTest = { viewModel.pauseTest() },
                        onResumeTest = { viewModel.resumeTest() },
                        onStopTest = { viewModel.stopAndFinishTest() },
                        onResetTest = { viewModel.resetTest() },
                        onToggleSound = { viewModel.toggleSound() },
                        onAdjustTime = { delta -> viewModel.adjustTimeSeconds(delta) },
                        onNextShuttle = { viewModel.advanceToNextShuttle() },
                        onPrevShuttle = { viewModel.previousShuttle() },
                        onAthleteClicked = { athlete -> viewModel.onAthleteClicked(athlete) },
                        onAthleteUndo = { athlete -> viewModel.undoAthlete(athlete) },
                        onUndoLast = { viewModel.undoLastAction() },
                        onOpenRosterManager = { showRosterManager = true },
                        onViewLeaderboard = { viewModel.setActiveTab(AppTab.LEADERBOARD) }
                    )
                }

                AppTab.LEADERBOARD -> {
                    SessionSummaryScreen(
                        uiState = uiState,
                        viewModel = viewModel,
                        onBackToTest = { viewModel.setActiveTab(AppTab.TEST) }
                    )
                }

                AppTab.HISTORY -> {
                    HistoryScreen(
                        sessions = savedSessions,
                        viewModel = viewModel
                    )
                }

                AppTab.SETTINGS -> {
                    SettingsScreen(
                        volumeBoost = uiState.volumeBoost,
                        isBoostEnabled = uiState.isBoostEnabled,
                        onBoostEnabledChange = { viewModel.setBoostEnabled(it) },
                        onVolumeBoostChange = { viewModel.setVolumeBoost(it) }
                    )
                }
            }
        }
    }

    if (showRosterManager) {
        RosterManagementDialog(
            athletes = uiState.athletes,
            onAddAthlete = { name -> viewModel.addAthlete(name) },
            onRemoveAthlete = { id -> viewModel.removeAthlete(id) },
            onResetDefaults = { viewModel.resetRosterToDefaults() },
            onDismiss = { showRosterManager = false }
        )
    }
}
