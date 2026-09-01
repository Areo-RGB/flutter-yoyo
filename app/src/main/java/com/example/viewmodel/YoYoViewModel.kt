package com.example.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.dao.SessionWithResults
import com.example.data.db.YoYoDatabase
import com.example.data.entity.AthleteResultEntity
import com.example.data.entity.TestSessionEntity
import com.example.data.repository.YoYoRepository
import com.example.model.Athlete
import com.example.model.AthleteStatus
import com.example.model.ShuttlePhase
import com.example.model.TestState
import com.example.model.YoYoProtocol
import com.example.model.YoYoShuttle
import com.example.util.SoundHelper
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class YoYoUiState(
    val testState: TestState = TestState.IDLE,
    val currentShuttleIndex: Int = 0,
    val athletes: List<Athlete> = Athlete.createDefaultRoster(),
    val totalElapsedMillis: Long = 0L,
    val currentShuttleElapsedMillis: Long = 0L,
    val currentPhase: ShuttlePhase = ShuttlePhase.RUNNING,
    val isSoundEnabled: Boolean = true,
    val volumeBoost: Float = 1f,
    val isBoostEnabled: Boolean = false,
    val sessionSavedId: Long? = null,
    val undoStack: List<AthleteUndoAction> = emptyList(),
    val activeTab: AppTab = AppTab.TEST
) {
    val currentShuttle: YoYoShuttle
        get() = YoYoProtocol.shuttles.getOrElse(currentShuttleIndex) {
            YoYoProtocol.shuttles.last()
        }

    val currentDistanceMeters: Int
        get() = when {
            testState == TestState.IDLE -> 0
            testState == TestState.COMPLETED -> YoYoProtocol.maxDistanceMeters
            currentPhase == ShuttlePhase.RECOVERY -> (currentShuttleIndex + 1) * 40
            else -> currentShuttleIndex * 40
        }

    val activeRunnersCount: Int
        get() = athletes.count { it.status == AthleteStatus.RUNNING || it.status == AthleteStatus.WARNED }

    val warnedRunnersCount: Int
        get() = athletes.count { it.status == AthleteStatus.WARNED }

    val eliminatedRunnersCount: Int
        get() = athletes.count { it.status == AthleteStatus.ELIMINATED }

    val isAllAthletesFinished: Boolean
        get() = athletes.isNotEmpty() && athletes.all { it.isFinished }

    val runningPhaseRemainingSeconds: Double
        get() {
            val runDuration = currentShuttle.runDurationSeconds
            val elapsedSec = currentShuttleElapsedMillis / 1000.0
            return (runDuration - elapsedSec).coerceAtLeast(0.0)
        }

    val recoveryPhaseRemainingSeconds: Double
        get() {
            val runDuration = currentShuttle.runDurationSeconds
            val totalDuration = currentShuttle.totalDurationSeconds
            val elapsedSec = currentShuttleElapsedMillis / 1000.0
            return (totalDuration - elapsedSec).coerceAtLeast(0.0)
        }

    val phaseProgressFraction: Float
        get() {
            val elapsedSec = currentShuttleElapsedMillis / 1000.0
            return if (currentPhase == ShuttlePhase.RUNNING) {
                val totalRun = currentShuttle.runDurationSeconds.toFloat()
                if (totalRun > 0) (elapsedSec.toFloat() / totalRun).coerceIn(0f, 1f) else 0f
            } else {
                val runSec = currentShuttle.runDurationSeconds
                val recSec = currentShuttle.recoveryDurationSeconds.toFloat()
                val recElapsed = (elapsedSec - runSec).toFloat()
                if (recSec > 0) (recElapsed / recSec).coerceIn(0f, 1f) else 0f
            }
        }
}

enum class AppTab {
    TEST,
    LEADERBOARD,
    HISTORY,
    SETTINGS
}

data class AthleteUndoAction(
    val athleteId: String,
    val previousState: Athlete,
    val description: String
)

class YoYoViewModel(application: Application) : AndroidViewModel(application) {
    private val repository: YoYoRepository
    val soundHelper: SoundHelper = SoundHelper(application)

    private val _uiState = MutableStateFlow(YoYoUiState())
    val uiState: StateFlow<YoYoUiState> = _uiState.asStateFlow()

    private var timerJob: Job? = null
    private var lastTickTime: Long = 0L

    val savedSessions: StateFlow<List<SessionWithResults>>

    init {
        val db = YoYoDatabase.getDatabase(application)
        repository = YoYoRepository(db.testSessionDao())
        savedSessions = repository.allSessions.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
    }

    fun startTest() {
        if (_uiState.value.testState == TestState.IDLE) {
            // Reset state for new run
            _uiState.update { current ->
                current.copy(
                    testState = TestState.RUNNING,
                    currentShuttleIndex = 0,
                    totalElapsedMillis = 0L,
                    currentShuttleElapsedMillis = 0L,
                    currentPhase = ShuttlePhase.RUNNING,
                    sessionSavedId = null
                )
            }
            soundHelper.startAudioTrack()
            soundHelper.playStartBeep()
            startTicker()
        } else if (_uiState.value.testState == TestState.PAUSED) {
            resumeTest()
        }
    }

    fun pauseTest() {
        if (_uiState.value.testState == TestState.RUNNING) {
            timerJob?.cancel()
            soundHelper.pauseAudioTrack()
            _uiState.update { it.copy(testState = TestState.PAUSED) }
        }
    }

    fun resumeTest() {
        if (_uiState.value.testState == TestState.PAUSED) {
            _uiState.update { it.copy(testState = TestState.RUNNING) }
            soundHelper.resumeAudioTrack()
            startTicker()
        }
    }

    fun stopAndFinishTest() {
        timerJob?.cancel()
        soundHelper.stopAudioTrack()
        val currentDistance = _uiState.value.currentDistanceMeters
        val currentLevel = _uiState.value.currentShuttle.levelDisplay
        val currentShuttleNum = _uiState.value.currentShuttle.shuttleNumber

        // Auto-finalize any remaining active athletes at the final achieved distance
        _uiState.update { current ->
            val updatedAthletes = current.athletes.map { athlete ->
                if (!athlete.isFinished) {
                    athlete.copy(
                        status = AthleteStatus.ELIMINATED,
                        finalDistanceMeters = athlete.finalDistanceMeters ?: currentDistance,
                        finalLevel = athlete.finalLevel ?: currentLevel,
                        finalShuttle = athlete.finalShuttle ?: currentShuttleNum,
                        finishTimestampMs = System.currentTimeMillis(),
                        vo2Max = YoYoProtocol.calculateVo2Max(
                            athlete.finalDistanceMeters ?: currentDistance
                        )
                    )
                } else {
                    athlete
                }
            }
            val ranked = calculateRanks(updatedAthletes)
            current.copy(
                testState = TestState.COMPLETED,
                athletes = ranked
            )
        }
    }

    fun resetTest() {
        timerJob?.cancel()
        soundHelper.resetAudioTrack()
        _uiState.update { current ->
            val resetAthletes = current.athletes.map {
                it.copy(
                    status = AthleteStatus.RUNNING,
                    warningDistanceMeters = null,
                    warningLevel = null,
                    warningShuttle = null,
                    warningTimestampMs = null,
                    finalDistanceMeters = null,
                    finalLevel = null,
                    finalShuttle = null,
                    finishTimestampMs = null,
                    rank = null,
                    vo2Max = null
                )
            }
            current.copy(
                testState = TestState.IDLE,
                currentShuttleIndex = 0,
                totalElapsedMillis = 0L,
                currentShuttleElapsedMillis = 0L,
                currentPhase = ShuttlePhase.RUNNING,
                athletes = resetAthletes,
                sessionSavedId = null,
                undoStack = emptyList()
            )
        }
    }

    fun setActiveTab(tab: AppTab) {
        _uiState.update { it.copy(activeTab = tab) }
    }

    fun toggleSound() {
        val newSound = !_uiState.value.isSoundEnabled
        soundHelper.setSoundEnabledState(newSound)
        _uiState.update { it.copy(isSoundEnabled = newSound) }
    }

    fun setVolumeBoost(boost: Float) {
        _uiState.update { it.copy(volumeBoost = boost.coerceIn(1f, 3f)) }
        soundHelper.setVolumeBoost(boost, _uiState.value.isBoostEnabled)
    }

    fun setBoostEnabled(enabled: Boolean) {
        _uiState.update { it.copy(isBoostEnabled = enabled) }
        soundHelper.setVolumeBoost(_uiState.value.volumeBoost, enabled)
    }

    fun adjustTimeSeconds(deltaSeconds: Double) {
        val deltaMillis = (deltaSeconds * 1000).toLong()
        _uiState.update { current ->
            val newTotal = (current.totalElapsedMillis + deltaMillis).coerceAtLeast(0L)
            val newShuttleElapsed =
                (current.currentShuttleElapsedMillis + deltaMillis).coerceAtLeast(0L)
            soundHelper.seekAudioTrackTo(newTotal)
            current.copy(
                totalElapsedMillis = newTotal,
                currentShuttleElapsedMillis = newShuttleElapsed
            )
        }
    }

    fun advanceToNextShuttle() {
        val currentIdx = _uiState.value.currentShuttleIndex
        if (currentIdx < YoYoProtocol.totalShuttlesCount - 1) {
            val newIdx = currentIdx + 1
            val newTotal = YoYoProtocol.getCumulativeTimeUpToShuttleMs(newIdx)
            soundHelper.seekAudioTrackTo(newTotal)
            _uiState.update { current ->
                current.copy(
                    currentShuttleIndex = newIdx,
                    totalElapsedMillis = newTotal,
                    currentShuttleElapsedMillis = 0L,
                    currentPhase = ShuttlePhase.RUNNING
                )
            }
            soundHelper.playStartBeep()
        }
    }

    fun previousShuttle() {
        val currentIdx = _uiState.value.currentShuttleIndex
        if (currentIdx > 0) {
            val newIdx = currentIdx - 1
            val newTotal = YoYoProtocol.getCumulativeTimeUpToShuttleMs(newIdx)
            soundHelper.seekAudioTrackTo(newTotal)
            _uiState.update { current ->
                current.copy(
                    currentShuttleIndex = newIdx,
                    totalElapsedMillis = newTotal,
                    currentShuttleElapsedMillis = 0L,
                    currentPhase = ShuttlePhase.RUNNING
                )
            }
        }
    }

    /**
     * Handles athlete card press during test:
     * - Tap 1 (when RUNNING): Warns them, adds orange border, records warning distance & level.
     * - Tap 2 (when WARNED): Eliminates them, saves the current distance and maps it to athlete!
     */
    fun onAthleteClicked(athlete: Athlete) {
        val current = _uiState.value
        val currentDistance = current.currentDistanceMeters
        val currentLevel = current.currentShuttle.levelDisplay
        val currentShuttleNum = current.currentShuttle.shuttleNumber

        when (athlete.status) {
            AthleteStatus.RUNNING -> {
                // 1st Tap: Give warning (Orange border frame)
                val updatedAthlete = athlete.copy(
                    status = AthleteStatus.WARNED,
                    warningDistanceMeters = currentDistance,
                    warningLevel = currentLevel,
                    warningShuttle = currentShuttleNum,
                    warningTimestampMs = System.currentTimeMillis()
                )
                recordUndoAction(
                    athlete,
                    "Warned ${athlete.name} at ${currentDistance}m ($currentLevel)"
                )
                updateSingleAthlete(updatedAthlete)
                soundHelper.playWarningBeep()
            }

            AthleteStatus.WARNED -> {
                // 2nd Tap: Save current distance and finalize athlete
                val updatedAthlete = athlete.copy(
                    status = AthleteStatus.ELIMINATED,
                    finalDistanceMeters = currentDistance,
                    finalLevel = currentLevel,
                    finalShuttle = currentShuttleNum,
                    finishTimestampMs = System.currentTimeMillis(),
                    vo2Max = YoYoProtocol.calculateVo2Max(currentDistance)
                )
                recordUndoAction(
                    athlete,
                    "Eliminated ${athlete.name} at ${currentDistance}m ($currentLevel)"
                )
                updateSingleAthlete(updatedAthlete)
                soundHelper.playEliminationBeep()
                recalculateAllRanks()

                // Check if all athletes finished
                checkAutoFinish()
            }

            AthleteStatus.ELIMINATED -> {
                // Already finished, can be undone via undo button
            }
        }
    }

    fun eliminateDirectly(athlete: Athlete) {
        val current = _uiState.value
        val currentDistance = current.currentDistanceMeters
        val currentLevel = current.currentShuttle.levelDisplay
        val currentShuttleNum = current.currentShuttle.shuttleNumber

        val updatedAthlete = athlete.copy(
            status = AthleteStatus.ELIMINATED,
            finalDistanceMeters = currentDistance,
            finalLevel = currentLevel,
            finalShuttle = currentShuttleNum,
            finishTimestampMs = System.currentTimeMillis(),
            vo2Max = YoYoProtocol.calculateVo2Max(currentDistance)
        )
        recordUndoAction(athlete, "Directly finished ${athlete.name} at ${currentDistance}m")
        updateSingleAthlete(updatedAthlete)
        soundHelper.playEliminationBeep()
        recalculateAllRanks()
        checkAutoFinish()
    }

    fun undoLastAction() {
        val current = _uiState.value
        if (current.undoStack.isEmpty()) return

        val lastAction = current.undoStack.last()
        val remainingStack = current.undoStack.dropLast(1)

        _uiState.update { state ->
            val updatedAthletes = state.athletes.map {
                if (it.id == lastAction.athleteId) lastAction.previousState else it
            }
            state.copy(
                athletes = calculateRanks(updatedAthletes),
                undoStack = remainingStack
            )
        }
    }

    fun undoAthlete(athlete: Athlete) {
        val current = _uiState.value
        val previousState = when (athlete.status) {
            AthleteStatus.ELIMINATED -> {
                athlete.copy(
                    status = if (athlete.warningDistanceMeters != null) AthleteStatus.WARNED else AthleteStatus.RUNNING,
                    finalDistanceMeters = null,
                    finalLevel = null,
                    finalShuttle = null,
                    finishTimestampMs = null,
                    rank = null,
                    vo2Max = null
                )
            }

            AthleteStatus.WARNED -> {
                athlete.copy(
                    status = AthleteStatus.RUNNING,
                    warningDistanceMeters = null,
                    warningLevel = null,
                    warningShuttle = null,
                    warningTimestampMs = null
                )
            }

            AthleteStatus.RUNNING -> athlete
        }
        updateSingleAthlete(previousState)
        recalculateAllRanks()
    }

    fun updateRoster(names: List<String>) {
        val newAthletes = names.filter { it.isNotBlank() }.mapIndexed { index, name ->
            Athlete(
                id = "athlete_${index + 1}",
                name = name.trim(),
                status = AthleteStatus.RUNNING
            )
        }
        _uiState.update { it.copy(athletes = newAthletes) }
    }

    fun addAthlete(name: String) {
        if (name.isBlank()) return
        val current = _uiState.value
        val newAthlete = Athlete(
            id = "athlete_${System.currentTimeMillis()}",
            name = name.trim(),
            status = AthleteStatus.RUNNING
        )
        _uiState.update { it.copy(athletes = it.athletes + newAthlete) }
    }

    fun removeAthlete(athleteId: String) {
        _uiState.update { current ->
            current.copy(athletes = current.athletes.filterNot { it.id == athleteId })
        }
    }

    fun resetRosterToDefaults() {
        _uiState.update { it.copy(athletes = Athlete.createDefaultRoster()) }
    }

    fun saveTestSession(customTitle: String? = null, notes: String = "") {
        val state = _uiState.value
        val dateFormat = SimpleDateFormat("MMM dd, yyyy - HH:mm", Locale.getDefault())
        val defaultTitle = "Yo-Yo IR1 Test (${dateFormat.format(Date())})"
        val title = if (!customTitle.isNullOrBlank()) customTitle else defaultTitle

        val maxDistance = state.athletes.mapNotNull { it.finalDistanceMeters }.maxOrNull()
            ?: state.currentDistanceMeters
        val maxLevel = state.athletes.mapNotNull { it.finalLevel }.maxOrNull()
            ?: state.currentShuttle.levelDisplay

        val sessionEntity = TestSessionEntity(
            title = title,
            timestampMs = System.currentTimeMillis(),
            durationSeconds = state.totalElapsedMillis / 1000L,
            maxDistanceAchieved = maxDistance,
            maxLevelAchieved = maxLevel,
            totalAthletesCount = state.athletes.size,
            completedAthletesCount = state.eliminatedRunnersCount,
            notes = notes
        )

        val athleteEntities = state.athletes.map { athlete ->
            AthleteResultEntity(
                sessionId = 0L,
                athleteName = athlete.name,
                finalDistanceMeters = athlete.finalDistanceMeters ?: 0,
                finalLevel = athlete.finalLevel ?: "5.1",
                finalShuttleNumber = athlete.finalShuttle ?: 1,
                warningDistanceMeters = athlete.warningDistanceMeters,
                warningLevel = athlete.warningLevel,
                rank = athlete.rank ?: 99,
                vo2Max = athlete.vo2Max ?: YoYoProtocol.calculateVo2Max(
                    athlete.finalDistanceMeters ?: 0
                )
            )
        }

        viewModelScope.launch {
            val sessionId = repository.saveSession(sessionEntity, athleteEntities)
            _uiState.update { it.copy(sessionSavedId = sessionId) }
        }
    }

    fun deleteSession(sessionId: Long) {
        viewModelScope.launch {
            repository.deleteSession(sessionId)
        }
    }

    fun generateCsvExport(athletes: List<Athlete>): String {
        val sb = StringBuilder()
        sb.append("Rank,Athlete Name,Final Distance (m),Final Level,VO2max (ml/kg/min),Warning Distance (m),Warning Level,Rating\n")
        val sorted = athletes.sortedWith(
            compareByDescending<Athlete> { it.finalDistanceMeters ?: 0 }
                .thenBy { it.name }
        )
        sorted.forEachIndexed { index, athlete ->
            val distance = athlete.finalDistanceMeters ?: 0
            val level = athlete.finalLevel ?: "N/A"
            val vo2 = athlete.vo2Max ?: YoYoProtocol.calculateVo2Max(distance)
            val warnDist = athlete.warningDistanceMeters?.toString() ?: "None"
            val warnLvl = athlete.warningLevel ?: "None"
            val rating = YoYoProtocol.getFitnessRating(distance)
            sb.append("${index + 1},\"${athlete.name}\",$distance,$level,$vo2,$warnDist,$warnLvl,\"$rating\"\n")
        }
        return sb.toString()
    }

    fun generateSummaryText(
        athletes: List<Athlete>,
        sessionTitle: String = "Yo-Yo IR1 Results"
    ): String {
        val sb = StringBuilder()
        sb.append("🏃 $sessionTitle\n")
        sb.append("═".repeat(32)).append("\n")
        val sorted = athletes.sortedWith(
            compareByDescending<Athlete> { it.finalDistanceMeters ?: 0 }
                .thenBy { it.name }
        )
        sorted.forEachIndexed { index, a ->
            val rankIcon = when (index) {
                0 -> "🥇"
                1 -> "🥈"
                2 -> "🥉"
                else -> "#${index + 1}"
            }
            val dist = a.finalDistanceMeters ?: 0
            val lvl = a.finalLevel ?: "-"
            val vo2 = a.vo2Max ?: YoYoProtocol.calculateVo2Max(dist)
            sb.append("$rankIcon ${a.name}: ${dist}m (Lvl $lvl) • VO2max: $vo2 ml/kg/min\n")
        }
        return sb.toString()
    }

    private fun startTicker() {
        timerJob?.cancel()
        lastTickTime = System.currentTimeMillis()

        timerJob = viewModelScope.launch {
            while (_uiState.value.testState == TestState.RUNNING) {
                val now = System.currentTimeMillis()
                val delta = (now - lastTickTime).coerceAtLeast(0L)
                lastTickTime = now

                tick(delta)
                delay(40L) // smooth 25 FPS UI updates
            }
        }
    }

    private fun tick(deltaMillis: Long) {
        _uiState.update { current ->
            if (current.testState != TestState.RUNNING) return@update current

            val newTotalElapsed = current.totalElapsedMillis + deltaMillis
            val newShuttleElapsed = current.currentShuttleElapsedMillis + deltaMillis

            val shuttle = current.currentShuttle
            val runDurationMillis = (shuttle.runDurationSeconds * 1000).toLong()
            val totalShuttleDurationMillis = (shuttle.totalDurationSeconds * 1000).toLong()

            var newShuttleIndex = current.currentShuttleIndex
            var nextShuttleElapsed = newShuttleElapsed
            var newPhase = if (newShuttleElapsed < runDurationMillis) {
                ShuttlePhase.RUNNING
            } else {
                ShuttlePhase.RECOVERY
            }

            // Check if shuttle completed (Sprint + Recovery finished)
            if (newShuttleElapsed >= totalShuttleDurationMillis) {
                if (newShuttleIndex < YoYoProtocol.totalShuttlesCount - 1) {
                    newShuttleIndex++
                    nextShuttleElapsed = newShuttleElapsed - totalShuttleDurationMillis
                    newPhase = ShuttlePhase.RUNNING
                    soundHelper.playStartBeep()
                } else {
                    // Completed entire protocol!
                    return@update current.copy(
                        testState = TestState.COMPLETED,
                        totalElapsedMillis = newTotalElapsed
                    )
                }
            } else if (current.currentPhase == ShuttlePhase.RUNNING && newPhase == ShuttlePhase.RECOVERY) {
                // Transitioned to recovery
                soundHelper.playCountdownBeep()
            }

            current.copy(
                totalElapsedMillis = newTotalElapsed,
                currentShuttleIndex = newShuttleIndex,
                currentShuttleElapsedMillis = nextShuttleElapsed,
                currentPhase = newPhase
            )
        }
    }

    private fun updateSingleAthlete(updated: Athlete) {
        _uiState.update { current ->
            val list = current.athletes.map { if (it.id == updated.id) updated else it }
            current.copy(athletes = list)
        }
    }

    private fun recordUndoAction(previous: Athlete, description: String) {
        _uiState.update { current ->
            val stack = (current.undoStack + AthleteUndoAction(
                previous.id,
                previous,
                description
            )).takeLast(20)
            current.copy(undoStack = stack)
        }
    }

    private fun recalculateAllRanks() {
        _uiState.update { current ->
            current.copy(athletes = calculateRanks(current.athletes))
        }
    }

    private fun calculateRanks(athletes: List<Athlete>): List<Athlete> {
        val eliminated = athletes.filter { it.isFinished }
            .sortedWith(
                compareByDescending<Athlete> { it.finalDistanceMeters ?: 0 }
                    .thenBy { it.finishTimestampMs ?: 0L }
            )

        val rankMap = mutableMapOf<String, Int>()
        eliminated.forEachIndexed { index, athlete ->
            rankMap[athlete.id] = index + 1
        }

        return athletes.map { athlete ->
            if (athlete.isFinished) {
                athlete.copy(rank = rankMap[athlete.id])
            } else {
                athlete.copy(rank = null)
            }
        }
    }

    private fun checkAutoFinish() {
        if (_uiState.value.isAllAthletesFinished && _uiState.value.testState == TestState.RUNNING) {
            stopAndFinishTest()
        }
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
        soundHelper.release()
    }
}
