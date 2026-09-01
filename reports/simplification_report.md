# Simplification Report

Generated with the `pi-simplify` review principles: preserve behavior, follow project conventions, improve clarity, avoid over-simplifying. Scope reviewed: current project Dart sources, with emphasis on the large uncommitted remote-control changes. `flutter analyze` currently reports no issues.

## Highest-value simplification opportunities

### 1. Split `YoYoViewModel` by responsibility
- **File:** `lib/ui/features/active_test/view_models/yoyo_view_model.dart` (~1,572 lines)
- **Why:** This class owns app tabs, test lifecycle, audio, athlete mutations, persistence, CSV/summary export, remote command routing, snapshot sync, timers, command timeouts, stale detection, ranking, and token generation.
- **Simplification:** Extract focused collaborators while keeping the public view-model API stable:
  - `TestRunController` for start/pause/resume/reset/ticking/shuttle sync.
  - `AthleteResultController` for warn/eliminate/undo/ranking.
  - `RemoteCommandController` for request creation, dedupe, timeouts, and command result handling.
  - `RemoteSnapshotController` for host snapshot publishing and controller snapshot ingestion.
  - `SessionExportService` for CSV/summary text.
- **Benefit:** Smaller methods, easier tests, fewer state coupling bugs.

### 2. Deduplicate local vs remote start/pause/reset command paths
- **File:** `lib/ui/features/active_test/view_models/yoyo_view_model.dart`
- **Why:** Public methods branch on `_isController`, then mirror local helpers and remote request helpers.
- **Simplification:** Use a small command dispatcher such as `_runOrRequest({required RemoteCommandType type, required VoidCallback local})`, or a `CommandMode` helper that either sends remote command or invokes local action.
- **Benefit:** Reduces repeated controller checks and keeps allowed remote actions explicit.

### 3. Consolidate remote command factories
- **File:** `lib/domain/remote_protocol.dart`
- **Why:** `RemoteCommand.startTest`, `warnAthlete`, `eliminateAthlete`, `pauseTest`, and `resetTest` repeat validation and constructor setup.
- **Simplification:** Add one private factory/helper, e.g. `RemoteCommand._validated(type, requestId, epoch, {athleteId})`, and keep named factories as readable public entry points.
- **Benefit:** Less duplicated validation; lower risk when protocol fields change.

### 4. Extract common protocol map validation/serialization patterns
- **File:** `lib/domain/remote_protocol.dart` (~847 lines)
- **Why:** Command, result, athlete snapshot, and test snapshot parsing repeat allowed-key checks, version checks, non-empty string/int parsing, and `toMap` assembly.
- **Simplification:** Introduce small parser helpers for required keys, optional typed fields, enum wire parsing, and bounded list decoding. Avoid making it generic/clever; keep per-message factories readable.
- **Benefit:** Protocol remains strict but easier to audit.

### 5. Split `NearbyConnectionService` into transport session states
- **File:** `lib/data/services/nearby_connection_service.dart` (~1,029 lines)
- **Why:** The service mixes permissions, platform transport adapter, connection state model, reconnect scheduling, authentication timeout, discovery callbacks, and payload stream ownership.
- **Simplification:** Extract:
  - `NearbySessionSupervisor` for enable/role/start/stop/retry/reconnect.
  - `NearbyAuthenticationFlow` for pending endpoint and verification timeout.
  - Keep `PluginNearbyTransport` in its own file.
- **Benefit:** Makes reconnect/authentication behavior easier to reason about and test.

### 6. Share distance-meter UI pieces
- **File:** `lib/ui/features/active_test/views/distance_meter.dart` (~614 lines)
- **Why:** `DistanceMeter` and `RemoteDistanceMeter` duplicate elapsed-time formatting, phase colors/text, button styles, and metric/header layout concepts.
- **Simplification:** Extract private widgets/helpers:
  - `_formatElapsedTimer` as one top-level helper or extension.
  - `_PhaseBadge`, `_MeterValue`, `_ControlButtonStyle`, `_ResetButton`.
  - A small view data object for phase/status display.
- **Benefit:** UI differences stay intentional; common formatting and styling are maintained once.

### 7. Break large screen `build` methods into named sections
- **Files:**
  - `lib/ui/features/active_test/views/active_test_screen.dart` (~577 lines)
  - `lib/ui/features/setup/views/setup_screen.dart` (~431 lines)
  - `lib/ui/features/tabelle/views/tabelle_screen.dart` (~590 lines)
  - `lib/ui/features/history/views/history_screen.dart` (~361 lines)
- **Why:** Long widget trees hide business/UI conditions and make small layout changes risky.
- **Simplification:** Extract section widgets or private builder methods for headers, status cards, lists, empty states, filter bars, and action rows. Prefer stateless private widgets when props are simple.
- **Benefit:** Easier visual review and lower merge conflict risk.

### 8. Centralize repeated styling constants
- **Files:** UI feature files under `lib/ui/features/**/views/`
- **Why:** Many screens repeat `BoxDecoration`, `BorderRadius.circular(12/16/20)`, button shapes, slate backgrounds, and bold text styles.
- **Simplification:** Add small reusable style helpers in `lib/ui/core/theme.dart`, for example app card decoration, primary/outline button shapes, standard spacing constants, and badge styles.
- **Benefit:** Cleaner widget code and more consistent UI.

### 9. Move CSV and summary generation out of the view model
- **File:** `lib/ui/features/active_test/view_models/yoyo_view_model.dart`
- **Why:** `generateCsvExport` and `generateSummaryText` are formatting/presentation utilities, not reactive state management.
- **Simplification:** Move to a pure `SessionExportService` or top-level utility with focused tests.
- **Benefit:** View model shrinks and export formatting can be tested without constructing remote services/timers.

### 10. Replace ad-hoc remote status strings with typed UI messages
- **Files:** `yoyo_view_model.dart`, `nearby_connection_service.dart`, settings/remote UI files
- **Why:** Human-readable strings are set in many places (`_setRemoteMessage`, `_setError`, command result reasons). This spreads copy and makes localization/error categorization harder.
- **Simplification:** Use small enums/sealed result objects internally, then map to display strings at the UI edge.
- **Benefit:** Consistent messages and simpler tests for state transitions.

## Smaller quick wins

- Move duplicated elapsed timer formatting from `DistanceMeter` and `RemoteDistanceMeter` into one helper.
- Create constants for maximum protocol sizes/timeouts if currently repeated across remote code.
- Add unit tests around remote protocol decode failures before simplifying parser code.
- In large widgets, prefer `const` private stateless widgets for repeated static labels/cards.
- Consider adding `dart_code_metrics` or similar only if the team wants automated complexity thresholds; the current analyzer is clean.

## Recommended order

1. Extract pure helpers first: timer formatting, CSV/summary export, protocol command factory helper.
2. Add/extend tests for protocol parsing and view-model remote command behavior.
3. Split `YoYoViewModel` into collaborators incrementally; keep public methods unchanged during migration.
4. Split `NearbyConnectionService` after tests cover reconnect/authentication edge cases.
5. Refactor UI screens section-by-section, verifying layouts manually on tablet/controller sizes.
