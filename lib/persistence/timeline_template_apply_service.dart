import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state.dart';
import 'persistence_providers.dart';
import 'plan_repository.dart';
import 'timeline_template_repository.dart';

/// Orchestrates safely applying a saved timeline template to the current plan.
///
/// Responsibilities:
/// - Restore the template with fresh block IDs.
/// - Snapshot the current plan state before overwrite.
/// - Clear transient UI state (selection, inline editor, precise drag).
/// - Persist the applied state immediately.
class TimelineTemplateApplyService {
  TimelineTemplateApplyService(this._ref);

  final Ref _ref;

  /// Applies the template identified by [templateId] to the current timeline.
  ///
  /// Execution order:
  /// 1. Restore [TimelineState] from the template (fresh block IDs).
  /// 2. Create a snapshot of the current plan labelled
  ///    `'Before template apply'`.
  /// 3. Apply the restored state via [TimelineNotifier.applyTemplateState],
  ///    which clears transient UI state.
  /// 4. Save the plan immediately so the change is persisted even if the
  ///    user closes the app before the autosave debounce fires.
  ///
  /// Throws [StateError] if no plan is currently loaded.
  Future<void> applyTemplate(String templateId) async {
    final planId = _ref.read(currentPlanIdProvider);
    if (planId == null) {
      throw StateError('No current plan is loaded');
    }

    final templateRepo = _ref.read(timelineTemplateRepositoryProvider);
    final planRepo = _ref.read(planRepositoryProvider);
    final notifier = _ref.read(timelineProvider.notifier);

    // 1. Restore template with fresh block IDs.
    final restoredState = await templateRepo.restoreTemplateState(templateId);

    // 2. Snapshot current state before overwrite.
    final currentState = _ref.read(timelineProvider);
    await planRepo.createSnapshot(
      planId: planId,
      state: currentState,
      label: 'Before template apply',
    );

    // 3. Apply to timeline (clears transient UI state).
    notifier.applyTemplateState(restoredState);

    // 4. Save plan immediately.
    await planRepo.savePlan(
      planId: planId,
      state: restoredState,
      createSnapshot: false,
    );
  }
}
