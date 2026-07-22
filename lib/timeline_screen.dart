import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'analytics/usage_analytics.dart';
import 'block_item.dart';
import 'edit_sheet.dart';
import 'models.dart';
import 'persistence/persistence_providers.dart';
import 'persistence/plan_repository.dart';
import 'persistence/timeline_template_repository.dart';
import 'plan_panel.dart';
import 'platform_time_picker.dart';
import 'billing/gate_helper.dart';
import 'settings/settings_screen.dart';
import 'state.dart';
import 'template_sheet.dart';
import 'theme.dart';

const _floatingControlBottomInset = 16.0;
const _floatingControlSize = 56.0;
const _floatingControlStackGap = 12.0;
const _timelineBottomExtraSpacer = 16.0;
const _timelineBottomSpacer =
    _floatingControlBottomInset +
    _floatingControlSize +
    _floatingControlStackGap +
    _floatingControlSize +
    _timelineBottomExtraSpacer;
const _reorderAutoScrollEdgeExtent = 72.0;
const _reorderAutoScrollTick = Duration(milliseconds: 16);
const _reorderAutoScrollMaxDelta = 18.0;

@visibleForTesting
const kTimelineTargetAnchorVisualHeight = 72.0;

@visibleForTesting
const kTimelinePointBlockVisualHeight = 52.0;

@visibleForTesting
int normalizeTimelineMinuteNearTarget({
  required int minutes,
  required int targetTime,
}) {
  var normalized = minutes;
  var bestDistance = (targetTime - normalized).abs();

  for (final candidate in [minutes - 24 * 60, minutes + 24 * 60]) {
    final distance = (targetTime - candidate).abs();
    if (distance < bestDistance) {
      normalized = candidate;
      bestDistance = distance;
    }
  }

  return normalized;
}

@visibleForTesting
double timelineBlockVisualHeight(Block block, double pixelsPerMinute) {
  if (block.type == BlockType.actionPoint) {
    return kTimelinePointBlockVisualHeight;
  }

  final naturalHeight = block.effectiveDuration * pixelsPerMinute;
  if (pixelsPerMinute >= kOverviewThresholdPpm) return naturalHeight.toDouble();

  final minOverviewHeight = block.normalizedBufferMinutes > 0
      ? kMinBufferedOverviewBlockHeight
      : kMinOverviewBlockHeight;
  return naturalHeight.clamp(minOverviewHeight, double.infinity).toDouble();
}

class _PendingBlockDelete {
  const _PendingBlockDelete({
    required this.block,
    required this.originalIndex,
    required this.deletedAt,
  });

  final Block block;
  final int originalIndex;
  final DateTime deletedAt;
}

class _ReorderItemGeometry {
  const _ReorderItemGeometry({
    required this.sourceIndex,
    required this.globalTop,
    required this.globalBottom,
  });

  final int sourceIndex;
  final double globalTop;
  final double globalBottom;

  double get centerY => (globalTop + globalBottom) / 2;
}

class _ReorderInsertionEstimate {
  const _ReorderInsertionEstimate({
    required this.sourceInsertIndex,
    required this.globalY,
  });

  final int sourceInsertIndex;
  final double globalY;
}

class _ReorderGeometrySnapshot {
  const _ReorderGeometrySnapshot({
    required this.sourceLength,
    required this.scrollOffset,
    required this.geometries,
  });

  final int sourceLength;
  final double scrollOffset;
  final List<_ReorderItemGeometry> geometries;

  _ReorderInsertionEstimate? estimate(
    Offset globalPosition, {
    required double currentScrollOffset,
  }) {
    if (geometries.isEmpty) return null;

    // The timeline uses reverse:true, where increasing offset moves content
    // down on screen. Keep the cached global geometry aligned with scrolling.
    final scrollDelta = currentScrollOffset - scrollOffset;
    for (final geometry in geometries) {
      final globalTop = geometry.globalTop + scrollDelta;
      final globalBottom = geometry.globalBottom + scrollDelta;
      final centerY = (globalTop + globalBottom) / 2;
      if (globalPosition.dy < centerY) {
        return _ReorderInsertionEstimate(
          sourceInsertIndex: geometry.sourceIndex,
          globalY: globalTop,
        );
      }
    }

    return _ReorderInsertionEstimate(
      sourceInsertIndex: sourceLength,
      globalY: geometries.last.globalBottom + scrollDelta,
    );
  }
}

class _ReorderPreviewFrame {
  const _ReorderPreviewFrame({
    required this.block,
    required this.globalPosition,
  });

  final Block block;
  final Offset globalPosition;
}

class _ReorderInsertionFrame {
  const _ReorderInsertionFrame({
    required this.sourceInsertIndex,
    required this.globalY,
  });

  final int sourceInsertIndex;
  final double globalY;
}

typedef _ReorderInsertionEstimator =
    _ReorderInsertionEstimate? Function(Offset globalPosition);

class _ReorderInteractionController {
  final preview = ValueNotifier<_ReorderPreviewFrame?>(null);
  final insertion = ValueNotifier<_ReorderInsertionFrame?>(null);

  Offset? _pendingGlobalPosition;
  _ReorderInsertionEstimator? _pendingEstimator;
  bool _frameScheduled = false;
  int _scheduledFrameGeneration = 0;
  bool _disposed = false;

  bool get isActive => preview.value != null;

  Offset? get latestGlobalPosition =>
      _pendingGlobalPosition ?? preview.value?.globalPosition;

  int? get candidateSourceIndex => insertion.value?.sourceInsertIndex;

  void start({
    required Block block,
    required Offset globalPosition,
    required _ReorderInsertionEstimate? insertionEstimate,
  }) {
    _clearPending(invalidateScheduledFrame: true);
    preview.value = _ReorderPreviewFrame(
      block: block,
      globalPosition: globalPosition,
    );
    _setInsertionEstimate(insertionEstimate);
  }

  void queueMove(Offset globalPosition, _ReorderInsertionEstimator estimator) {
    if (_disposed || !isActive) return;
    _pendingGlobalPosition = globalPosition;
    _pendingEstimator = estimator;
    if (_frameScheduled) return;

    _frameScheduled = true;
    final generation = ++_scheduledFrameGeneration;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (_disposed || generation != _scheduledFrameGeneration) return;
      _flushScheduledMove();
    });
  }

  void updateImmediately(
    Offset globalPosition,
    _ReorderInsertionEstimate? insertionEstimate,
  ) {
    if (_disposed || !isActive) return;
    _publishFrame(globalPosition, insertionEstimate);
  }

  void flushPendingMove() {
    if (_pendingGlobalPosition == null && !_frameScheduled) return;
    _scheduledFrameGeneration++;
    _flushScheduledMove();
  }

  void end() {
    _clearPending(invalidateScheduledFrame: true);
    if (preview.value != null) preview.value = null;
    if (insertion.value != null) insertion.value = null;
  }

  void dispose() {
    _disposed = true;
    preview.dispose();
    insertion.dispose();
  }

  void _flushScheduledMove() {
    final position = _pendingGlobalPosition;
    final estimator = _pendingEstimator;
    _clearPending(invalidateScheduledFrame: false);
    if (_disposed || !isActive || position == null || estimator == null) {
      return;
    }
    _publishFrame(position, estimator(position));
  }

  void _publishFrame(
    Offset globalPosition,
    _ReorderInsertionEstimate? insertionEstimate,
  ) {
    final currentPreview = preview.value;
    if (currentPreview == null) return;
    if (currentPreview.globalPosition != globalPosition) {
      preview.value = _ReorderPreviewFrame(
        block: currentPreview.block,
        globalPosition: globalPosition,
      );
    }
    _setInsertionEstimate(insertionEstimate);
  }

  void _setInsertionEstimate(_ReorderInsertionEstimate? estimate) {
    if (estimate == null) {
      if (insertion.value != null) insertion.value = null;
      return;
    }

    final current = insertion.value;
    if (current != null &&
        current.sourceInsertIndex == estimate.sourceInsertIndex &&
        current.globalY == estimate.globalY) {
      return;
    }

    insertion.value = _ReorderInsertionFrame(
      sourceInsertIndex: estimate.sourceInsertIndex,
      globalY: estimate.globalY,
    );
  }

  void _clearPending({required bool invalidateScheduledFrame}) {
    if (invalidateScheduledFrame) _scheduledFrameGeneration++;
    _frameScheduled = false;
    _pendingGlobalPosition = null;
    _pendingEstimator = null;
  }
}

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();
  final _timelineStackKey = GlobalKey();
  final _reorderController = _ReorderInteractionController();
  final Map<String, GlobalKey> _reorderItemKeys = {};
  bool _sheetVisible = false;
  bool _templateSheetVisible = false;
  bool _templateSheetLoading = false;
  int _templateSheetLoadGeneration = 0;
  List<TimelineTemplateSummary> _templateSheetInitialTemplates = const [];
  bool _timelineListVisible = false;
  bool _timelineSwitching = false;
  bool _suppressAutoSave = false;
  String? _currentTimelineTitle;
  String? _reorderPreviewBlockId;
  _ReorderGeometrySnapshot? _reorderGeometrySnapshot;
  Timer? _reorderAutoScrollTimer;
  Offset? _reorderAutoScrollGlobalPosition;
  bool _reorderAutoScrollGeometryRefreshScheduled = false;
  final Map<int, Offset> _activePointers = {};
  double _basePixelsPerMinute = kPixelsPerMinute;
  double _initialPinchDistance = 0;
  double _pendingPixelsPerMinute = kPixelsPerMinute;
  bool _isPinching = false;
  DateTime _now = DateTime.now();
  late final Timer _clockTimer;
  Timer? _saveDebounce;
  Timer? _swipeDeleteSnackBarTimer;
  _PendingBlockDelete? _pendingBlockDelete;

  // Search
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchHighlightTimer;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _isPinching = true;
      _basePixelsPerMinute = ref.read(timelineProvider).pixelsPerMinute;
      _pendingPixelsPerMinute = _basePixelsPerMinute;
      final pts = _activePointers.values.toList();
      _initialPinchDistance = (pts[0] - pts[1]).distance;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length != 2 || _initialPinchDistance == 0) return;
    final pts = _activePointers.values.toList();
    final dist = (pts[0] - pts[1]).distance;
    final v = (_basePixelsPerMinute * dist / _initialPinchDistance).clamp(
      kOverviewPixelsPerMinute,
      kPixelsPerMinute,
    );
    _pendingPixelsPerMinute = v;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isPinching) {
      _isPinching = false;
      ref
          .read(timelineProvider.notifier)
          .setPixelsPerMinute(_pendingPixelsPerMinute);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isPinching) {
      _isPinching = false;
      ref
          .read(timelineProvider.notifier)
          .setPixelsPerMinute(_pendingPixelsPerMinute);
    }
  }

  bool _dismissInlineEditorIfNeeded() {
    if (ref.read(timelineProvider).activeInlineEditorId == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  bool get _isReorderPreviewActive => _reorderPreviewBlockId != null;

  GlobalKey _reorderItemKeyFor(String blockId) {
    return _reorderItemKeys.putIfAbsent(blockId, GlobalKey.new);
  }

  double get _currentReorderScrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  Future<void> _prepareReorderPreview(
    String blockId,
    Offset globalPosition,
  ) async {
    if (ref.read(timelineProvider).viewMode != TimelineViewMode.edit) {
      return;
    }
    if (_isReorderPreviewActive) _cancelReorderPreview();
    _dismissInlineEditorIfNeeded();
    if (_sheetVisible) _dismissSheet();
    if (_templateSheetVisible) _dismissTemplateSheet();
    if (_timelineListVisible) _closeTimelineList();
    if (_isSearchActive || _exportPanelVisible) _closeHeaderPopovers();
    if (!mounted) return;
    final block = ref
        .read(timelineProvider)
        .blocks
        .where((block) => block.id == blockId)
        .firstOrNull;
    if (block == null) return;
    final estimate = _estimateReorderInsertionFromLive(
      globalPosition,
      excludedBlockId: blockId,
    );
    _reorderGeometrySnapshot = null;
    _reorderController.start(
      block: block,
      globalPosition: globalPosition,
      insertionEstimate: estimate,
    );
    setState(() {
      _reorderPreviewBlockId = blockId;
    });
    _updateReorderAutoScroll(globalPosition);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _reorderPreviewBlockId != blockId) return;
    _reorderGeometrySnapshot = _captureReorderGeometrySnapshot(
      excludedBlockId: blockId,
    );
    final latestPosition =
        _reorderController.latestGlobalPosition ?? globalPosition;
    _reorderController.updateImmediately(
      latestPosition,
      _estimateReorderInsertionFromSession(latestPosition),
    );
  }

  void _updateReorderPreview(String blockId, Offset globalPosition) {
    if (_reorderPreviewBlockId != blockId) return;
    _reorderController.queueMove(
      globalPosition,
      _estimateReorderInsertionFromSession,
    );
    _updateReorderAutoScroll(globalPosition);
  }

  void _endReorderPreview(String blockId, {required bool commit}) {
    if (_reorderPreviewBlockId == null) return;
    if (_reorderPreviewBlockId != blockId) return;
    _stopReorderAutoScroll(clearPosition: true);
    _reorderController.flushPendingMove();
    final sourceInsertIndex = _reorderController.candidateSourceIndex;
    if (!mounted) return;
    _reorderController.end();
    _reorderGeometrySnapshot = null;
    setState(() {
      _reorderPreviewBlockId = null;
    });
    if (!commit || sourceInsertIndex == null) return;
    _commitReorderPreview(blockId, sourceInsertIndex);
  }

  void _cancelReorderPreview() {
    final blockId = _reorderPreviewBlockId;
    if (blockId == null) return;
    _endReorderPreview(blockId, commit: false);
  }

  void _updateReorderAutoScroll(Offset globalPosition) {
    _reorderAutoScrollGlobalPosition = globalPosition;
    _syncReorderAutoScrollTimer();
  }

  void _syncReorderAutoScrollTimer() {
    if (!_isReorderPreviewActive ||
        _reorderAutoScrollDeltaForLatestPosition() == 0.0) {
      _stopReorderAutoScroll();
      return;
    }

    _reorderAutoScrollTimer ??= Timer.periodic(
      _reorderAutoScrollTick,
      (_) => _tickReorderAutoScroll(),
    );
  }

  double _reorderAutoScrollDeltaForLatestPosition() {
    final globalPosition = _reorderAutoScrollGlobalPosition;
    if (globalPosition == null) return 0.0;
    return _reorderAutoScrollDeltaFor(globalPosition);
  }

  double _reorderAutoScrollDeltaFor(Offset globalPosition) {
    if (!_scrollController.hasClients) return 0.0;
    final renderObject = _timelineStackKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return 0.0;

    final localY = renderObject.globalToLocal(globalPosition).dy;
    final height = renderObject.size.height;
    if (height <= 0) return 0.0;

    if (localY < _reorderAutoScrollEdgeExtent) {
      final strength =
          ((_reorderAutoScrollEdgeExtent - localY) /
                  _reorderAutoScrollEdgeExtent)
              .clamp(0.0, 1.0);
      return _reorderAutoScrollMaxDelta * strength;
    }

    if (localY > height - _reorderAutoScrollEdgeExtent) {
      final strength =
          ((localY - (height - _reorderAutoScrollEdgeExtent)) /
                  _reorderAutoScrollEdgeExtent)
              .clamp(0.0, 1.0);
      return -_reorderAutoScrollMaxDelta * strength;
    }

    return 0.0;
  }

  void _tickReorderAutoScroll() {
    if (!_isReorderPreviewActive || !_scrollController.hasClients) {
      _stopReorderAutoScroll(clearPosition: !_isReorderPreviewActive);
      return;
    }

    final globalPosition = _reorderAutoScrollGlobalPosition;
    if (globalPosition == null) {
      _stopReorderAutoScroll();
      return;
    }

    final delta = _reorderAutoScrollDeltaFor(globalPosition);
    if (delta == 0.0) {
      _stopReorderAutoScroll();
      return;
    }

    final scrollPosition = _scrollController.position;
    final currentOffset = _scrollController.offset;
    final nextOffset = (currentOffset + delta)
        .clamp(scrollPosition.minScrollExtent, scrollPosition.maxScrollExtent)
        .toDouble();
    if (nextOffset == currentOffset) {
      _stopReorderAutoScroll();
      return;
    }

    _scrollController.jumpTo(nextOffset);
    _reorderController.updateImmediately(
      globalPosition,
      _estimateReorderInsertionFromSession(globalPosition),
    );
    _scheduleReorderGeometryRefreshAfterAutoScroll();
  }

  void _scheduleReorderGeometryRefreshAfterAutoScroll() {
    if (_reorderAutoScrollGeometryRefreshScheduled) return;
    _reorderAutoScrollGeometryRefreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reorderAutoScrollGeometryRefreshScheduled = false;
      if (!mounted || !_isReorderPreviewActive) return;
      final blockId = _reorderPreviewBlockId;
      if (blockId == null) return;
      _reorderGeometrySnapshot = _captureReorderGeometrySnapshot(
        excludedBlockId: blockId,
      );
      final latestPosition =
          _reorderAutoScrollGlobalPosition ??
          _reorderController.latestGlobalPosition;
      if (latestPosition == null) return;
      _reorderController.updateImmediately(
        latestPosition,
        _estimateReorderInsertionFromSession(latestPosition),
      );
      _syncReorderAutoScrollTimer();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _stopReorderAutoScroll({bool clearPosition = false}) {
    _reorderAutoScrollTimer?.cancel();
    _reorderAutoScrollTimer = null;
    if (clearPosition) _reorderAutoScrollGlobalPosition = null;
  }

  void _commitReorderPreview(String blockId, int sourceInsertIndex) {
    if (ref.read(timelineProvider).viewMode == TimelineViewMode.compact) return;
    final blocks = ref.read(timelineProvider).blocks;
    final fromIndex = blocks.indexWhere((block) => block.id == blockId);
    if (fromIndex < 0) return;
    final toIndex = fromIndex < sourceInsertIndex
        ? sourceInsertIndex - 1
        : sourceInsertIndex;
    final boundedToIndex = toIndex.clamp(0, blocks.length - 1).toInt();
    if (fromIndex == boundedToIndex) return;
    ref
        .read(timelineProvider.notifier)
        .moveBlockByIndex(fromIndex, boundedToIndex);
    unawaited(
      _track(
        UsageAnalyticsEvent.blockReordered,
        properties: {
          'block_count_bucket': analyticsCountBucket(
            ref.read(timelineProvider).blocks.length,
          ),
        },
      ),
    );
  }

  bool _reorderSessionInvalidated(TimelineState previous, TimelineState next) {
    if (previous.viewMode != next.viewMode) return true;
    if (previous.pixelsPerMinute != next.pixelsPerMinute) return true;
    if (previous.blocks.length != next.blocks.length) return true;

    for (var i = 0; i < previous.blocks.length; i++) {
      final previousBlock = previous.blocks[i];
      final nextBlock = next.blocks[i];
      if (previousBlock.id != nextBlock.id) return true;
      if (previousBlock.type != nextBlock.type) return true;
      if (previousBlock.effectiveDuration != nextBlock.effectiveDuration) {
        return true;
      }
      if (previousBlock.normalizedBufferMinutes !=
          nextBlock.normalizedBufferMinutes) {
        return true;
      }
    }

    return false;
  }

  _ReorderInsertionEstimate? _estimateReorderInsertionFromSession(
    Offset globalPosition,
  ) {
    final snapshot = _reorderGeometrySnapshot;
    if (snapshot == null) {
      return _estimateReorderInsertionFromLive(globalPosition);
    }
    return snapshot.estimate(
      globalPosition,
      currentScrollOffset: _currentReorderScrollOffset,
    );
  }

  _ReorderGeometrySnapshot? _captureReorderGeometrySnapshot({
    required String excludedBlockId,
  }) {
    final computed = ref.read(computedBlocksProvider);
    if (computed.isEmpty) return null;
    final geometries = _collectReorderItemGeometries(
      computed: computed,
      excludedBlockId: excludedBlockId,
    );
    if (geometries.isEmpty) return null;

    return _ReorderGeometrySnapshot(
      sourceLength: computed.length,
      scrollOffset: _currentReorderScrollOffset,
      geometries: geometries,
    );
  }

  _ReorderInsertionEstimate? _estimateReorderInsertionFromLive(
    Offset globalPosition, {
    String? excludedBlockId,
  }) {
    final computed = ref.read(computedBlocksProvider);
    if (computed.isEmpty) return null;
    final activeBlockId = excludedBlockId ?? _reorderPreviewBlockId;
    final geometries = _collectReorderItemGeometries(
      computed: computed,
      excludedBlockId: activeBlockId,
    );
    if (geometries.isEmpty) return null;

    for (final geometry in geometries) {
      if (globalPosition.dy < geometry.centerY) {
        return _ReorderInsertionEstimate(
          sourceInsertIndex: geometry.sourceIndex,
          globalY: geometry.globalTop,
        );
      }
    }

    return _ReorderInsertionEstimate(
      sourceInsertIndex: computed.length,
      globalY: geometries.last.globalBottom,
    );
  }

  List<_ReorderItemGeometry> _collectReorderItemGeometries({
    required List<ComputedBlock> computed,
    required String? excludedBlockId,
  }) {
    final geometries = <_ReorderItemGeometry>[];
    for (var displayIndex = 0; displayIndex < computed.length; displayIndex++) {
      final sourceIndex = computed.length - 1 - displayIndex;
      final blockId = computed[sourceIndex].block.id;
      if (blockId == excludedBlockId) continue;
      final context = _reorderItemKeys[blockId]?.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final topLeft = renderObject.localToGlobal(Offset.zero);
      geometries.add(
        _ReorderItemGeometry(
          sourceIndex: sourceIndex,
          globalTop: topLeft.dy,
          globalBottom: topLeft.dy + renderObject.size.height,
        ),
      );
    }
    // CustomScrollView(reverse: true) means builder order and screen order are
    // not the same; RenderBox positions are the source of truth here. Once
    // sorted by globalTop, the visual insertion line maps back to source order.
    geometries.sort((a, b) => a.globalTop.compareTo(b.globalTop));
    return geometries;
  }

  Future<void> _saveCurrentPlanNow({TimelineState? state}) async {
    _saveDebounce?.cancel();
    final planId = ref.read(currentPlanIdProvider);
    if (planId == null) return;
    await ref
        .read(planRepositoryProvider)
        .savePlan(
          planId: planId,
          state: state ?? ref.read(timelineProvider),
          createSnapshot: false,
        );
    final TimelineState savedState = state ?? ref.read(timelineProvider);
    await _track(
      UsageAnalyticsEvent.planSaved,
      properties: {
        'block_count_bucket': analyticsCountBucket(savedState.blocks.length),
        'has_buffer': savedState.blocks.any((block) => block.bufferMinutes > 0),
      },
    );
    if (mounted) setState(() => _saveIndicatorVisible = false);
  }

  Future<void> _track(
    UsageAnalyticsEvent event, {
    Map<String, Object?> properties = const {},
  }) {
    return ref
        .read(usageAnalyticsServiceProvider)
        .track(event, properties: properties);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0); // reverse:true → 0.0 = visual bottom
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    ref.listenManual(timelineProvider, (prev, next) {
      if (prev != null &&
          _isReorderPreviewActive &&
          _reorderSessionInvalidated(prev, next)) {
        _cancelReorderPreview();
      }
      if (_isPinching || _suppressAutoSave) return;
      _saveDebounce?.cancel();
      _saveIndicatorTimer?.cancel();
      if (mounted) setState(() => _saveIndicatorVisible = true);
      _saveIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _saveIndicatorVisible = false);
      });
      _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
        final planId = ref.read(currentPlanIdProvider);
        if (planId == null) return;
        try {
          await ref
              .read(planRepositoryProvider)
              .savePlan(planId: planId, state: next, createSnapshot: false);
          await _track(
            UsageAnalyticsEvent.planSaved,
            properties: {
              'block_count_bucket': analyticsCountBucket(next.blocks.length),
              'has_buffer': next.blocks.any((block) => block.bufferMinutes > 0),
            },
          );
        } catch (e, st) {
          debugPrint('Auto-save error: $e\n$st');
          if (mounted) setState(() => _saveIndicatorVisible = false);
        }
      });
    });

    ref.listenManual<String?>(
      timelineProvider.select((s) => s.selectedBlockId),
      (prev, next) {
        if (next != null &&
            !_sheetVisible &&
            ref.read(timelineProvider).viewMode == TimelineViewMode.edit) {
          _showSheet();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _track(
          UsageAnalyticsEvent.appOpened,
          properties: {
            'launch_source': 'cold_start',
            'platform': currentAnalyticsPlatform(),
          },
        );
        final repo = ref.read(planRepositoryProvider);
        final plans = await repo.listPlans();
        if (!mounted) return;
        if (plans.isNotEmpty) {
          final currentPlanId = await repo.loadCurrentPlanId();
          final plan = await repo.loadPlan(currentPlanId ?? plans.first.id);
          if (!mounted || plan == null) return;
          if (currentPlanId != plan.id) {
            await repo.saveCurrentPlanId(plan.id);
            if (!mounted) return;
          }
          _suppressAutoSave = true;
          _currentTimelineTitle = plan.title;
          ref.read(currentPlanIdProvider.notifier).set(plan.id);
          ref.read(timelineProvider.notifier).loadState(plan.state);
          _suppressAutoSave = false;
        } else {
          final plan = await repo.createPlan(state: ref.read(timelineProvider));
          if (!mounted) return;
          _currentTimelineTitle = plan.title;
          ref.read(currentPlanIdProvider.notifier).set(plan.id);
          await repo.saveCurrentPlanId(plan.id);
          await _track(
            UsageAnalyticsEvent.firstPlanCreated,
            properties: {
              'block_count_bucket': analyticsCountBucket(
                plan.state.blocks.length,
              ),
            },
          );
          await _track(
            UsageAnalyticsEvent.planCreated,
            properties: {
              'source': 'initial_bootstrap',
              'block_count_bucket': analyticsCountBucket(
                plan.state.blocks.length,
              ),
            },
          );
        }
      } catch (e, st) {
        _suppressAutoSave = false;
        debugPrint('Timeline init error: $e\n$st');
      }
    });
  }

  bool _exportPanelVisible = false;
  bool _saveIndicatorVisible = false;
  Timer? _saveIndicatorTimer;

  void _toggleExportPanel() {
    if (_dismissWorkSurfaceIfNeeded()) return;
    if (_closeHeaderPopovers()) return;
    if (_dismissTemplateSheetIfNeeded()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(timelineProvider.notifier).setActiveInlineEditor(null);
    setState(() {
      _timelineListVisible = false;
      _templateSheetVisible = false;
      _exportPanelVisible = !_exportPanelVisible;
    });
  }

  void _closeExportPanel() => setState(() => _exportPanelVisible = false);

  bool _dismissWorkSurfaceIfNeeded() {
    if (_sheetVisible) {
      _dismissSheet();
      return true;
    }
    if (_timelineListVisible) {
      _closeTimelineList();
      return true;
    }
    return false;
  }

  void _showTimelineList() {
    FocusManager.instance.primaryFocus?.unfocus();
    _cancelReorderPreview();
    _closeHeaderPopovers();
    if (_templateSheetVisible) _dismissTemplateSheet();
    if (_sheetVisible) _dismissSheet();
    if (_isSearchActive) _closeSearch();
    ref.read(timelineProvider.notifier).setActiveInlineEditor(null);
    setState(() {
      _exportPanelVisible = false;
      _timelineListVisible = true;
    });
  }

  void _closeTimelineList() => setState(() => _timelineListVisible = false);

  Future<void> _selectTimeline(TimelinePlanSummary summary) async {
    if (_timelineSwitching) return;
    setState(() => _timelineSwitching = true);
    try {
      await _saveCurrentPlanNow();
      final repo = ref.read(planRepositoryProvider);
      final plan = await repo.loadPlan(summary.id);
      if (!mounted || plan == null) return;
      await repo.saveCurrentPlanId(plan.id);
      _suppressAutoSave = true;
      _currentTimelineTitle = plan.title;
      ref.read(currentPlanIdProvider.notifier).set(plan.id);
      ref
          .read(timelineProvider.notifier)
          .loadState(
            plan.state.copyWith(
              selectedBlockId: null,
              preciseDraggingId: null,
              activeInlineEditorId: null,
            ),
          );
      _suppressAutoSave = false;
      setState(() {
        _timelineListVisible = false;
        _timelineSwitching = false;
      });
    } catch (e, st) {
      _suppressAutoSave = false;
      debugPrint('Timeline switch error: $e\n$st');
      if (mounted) setState(() => _timelineSwitching = false);
    }
  }

  Future<void> _createTimelineFromList(String title) async {
    if (_timelineSwitching) return;
    setState(() => _timelineSwitching = true);
    try {
      await _saveCurrentPlanNow();
      final repo = ref.read(planRepositoryProvider);
      final currentState = ref.read(timelineProvider);
      final plan = await repo.createPlan(
        state: const TimelineState(),
        title: title.trim().isEmpty ? '無題のタイムライン' : title.trim(),
        createInitialSnapshot: false,
      );
      if (!mounted) return;
      await repo.saveCurrentPlanId(plan.id);
      await _track(
        UsageAnalyticsEvent.planCreated,
        properties: {
          'source': 'timeline_list',
          'block_count_bucket': analyticsCountBucket(plan.state.blocks.length),
        },
      );
      _suppressAutoSave = true;
      _currentTimelineTitle = plan.title;
      ref.read(currentPlanIdProvider.notifier).set(plan.id);
      ref
          .read(timelineProvider.notifier)
          .loadState(
            plan.state.copyWith(pixelsPerMinute: currentState.pixelsPerMinute),
          );
      _suppressAutoSave = false;
      setState(() {
        _timelineSwitching = false;
      });
    } catch (e, st) {
      _suppressAutoSave = false;
      debugPrint('Timeline create error: $e\n$st');
      if (mounted) setState(() => _timelineSwitching = false);
    }
  }

  Future<void> _renameTimelineFromList(
    TimelinePlanSummary summary,
    String title,
  ) async {
    if (_timelineSwitching) return;
    setState(() => _timelineSwitching = true);
    try {
      await ref.read(planRepositoryProvider).renamePlan(summary.id, title);
      if (summary.id == ref.read(currentPlanIdProvider)) {
        _currentTimelineTitle = title.trim().isEmpty
            ? '無題のタイムライン'
            : title.trim();
      }
      if (mounted) setState(() => _timelineSwitching = false);
    } catch (e, st) {
      debugPrint('Timeline rename error: $e\n$st');
      if (mounted) setState(() => _timelineSwitching = false);
    }
  }

  Future<void> _deleteTimelineFromList(TimelinePlanSummary summary) async {
    if (_timelineSwitching) return;
    setState(() => _timelineSwitching = true);
    try {
      await _saveCurrentPlanNow();
      final repo = ref.read(planRepositoryProvider);
      final currentPlanId = ref.read(currentPlanIdProvider);
      final currentState = ref.read(timelineProvider);

      await repo.deletePlan(summary.id);
      if (!mounted) return;

      if (summary.id == currentPlanId) {
        final remaining = await repo.listPlans();
        final nextPlan = remaining.isNotEmpty
            ? await repo.loadPlan(remaining.first.id)
            : await repo.createPlan(
                state: const TimelineState(),
                title: '無題のタイムライン',
                createInitialSnapshot: false,
              );
        if (!mounted) return;
        await repo.saveCurrentPlanId(nextPlan!.id);
        _suppressAutoSave = true;
        _currentTimelineTitle = nextPlan.title;
        ref.read(currentPlanIdProvider.notifier).set(nextPlan.id);
        ref
            .read(timelineProvider.notifier)
            .loadState(
              nextPlan.state.copyWith(
                pixelsPerMinute: currentState.pixelsPerMinute,
                selectedBlockId: null,
                preciseDraggingId: null,
                activeInlineEditorId: null,
              ),
            );
        _suppressAutoSave = false;
      }

      setState(() => _timelineSwitching = false);
    } catch (e, st) {
      _suppressAutoSave = false;
      debugPrint('Timeline delete error: $e\n$st');
      if (mounted) setState(() => _timelineSwitching = false);
    }
  }

  void _showSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    _cancelReorderPreview();
    _closeHeaderPopovers();
    if (_templateSheetVisible) _dismissTemplateSheet();
    if (_timelineListVisible) _closeTimelineList();
    setState(() {
      _templateSheetVisible = false;
      _sheetVisible = true;
    });
  }

  void _dismissSheet() {
    setState(() => _sheetVisible = false);
    ref.read(timelineProvider.notifier).selectBlock(null);
  }

  void _showTemplateSheet() {
    if (_templateSheetLoading) return;
    _cancelReorderPreview();
    if (_closeHeaderPopovers()) return;
    if (_dismissWorkSurfaceIfNeeded()) return;
    final proAccess = ref.read(effectiveProAccessProvider);
    if (proAccess.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認しています。少し待ってから再試行してください。')),
      );
      return;
    }
    if (proAccess.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認できませんでした。通信状態を確認してください。')),
      );
      return;
    }
    if (!proAccess.isPro) return;
    if (_templateSheetVisible) {
      _dismissTemplateSheet();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSearchActive) _closeSearch();
    ref.read(timelineProvider.notifier).setActiveInlineEditor(null);
    setState(() {
      _timelineListVisible = false;
      _exportPanelVisible = false;
      _templateSheetLoading = true;
    });
    final loadGeneration = ++_templateSheetLoadGeneration;
    unawaited(_openTemplateSheetAfterLoad(loadGeneration));
  }

  Future<void> _openTemplateSheetAfterLoad(int loadGeneration) async {
    try {
      final repo = ref.read(timelineTemplateRepositoryProvider);
      final templates = await repo.listTemplates();
      if (!mounted || loadGeneration != _templateSheetLoadGeneration) return;
      setState(() {
        _templateSheetInitialTemplates = templates;
        _templateSheetLoading = false;
        _templateSheetVisible = true;
      });
    } catch (e, st) {
      debugPrint('TemplateSheet preload error: $e\n$st');
      if (!mounted || loadGeneration != _templateSheetLoadGeneration) return;
      setState(() => _templateSheetLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートを読み込めませんでした。少し待ってから再試行してください。')),
      );
    }
  }

  void _dismissTemplateSheet() {
    _templateSheetLoadGeneration++;
    setState(() {
      _templateSheetLoading = false;
      _templateSheetVisible = false;
    });
  }

  bool _dismissTemplateSheetIfNeeded() {
    if (!_templateSheetVisible && !_templateSheetLoading) return false;
    _dismissTemplateSheet();
    return true;
  }

  bool _closeHeaderPopovers() {
    final wasSearchActive = _isSearchActive;
    final wasExportPanelVisible = _exportPanelVisible;
    if (!wasSearchActive && !wasExportPanelVisible) {
      return false;
    }

    setState(() {
      _isSearchActive = false;
      _exportPanelVisible = false;
    });

    if (wasSearchActive) {
      _searchController.clear();
      ref.read(timelineProvider.notifier).clearSearch();
      _searchHighlightTimer?.cancel();
      _searchHighlightTimer = null;
    }
    return true;
  }

  EdgeInsets _topSnackBarMargin({
    required double estimatedSnackBarHeight,
    double horizontal = 16.0,
  }) {
    const planHeaderHeight = 58.0;
    const topOffset = planHeaderHeight + 12.0;
    final media = MediaQuery.of(context);
    final bottomMargin =
        media.size.height -
        media.padding.top -
        topOffset -
        estimatedSnackBarHeight;
    return EdgeInsets.fromLTRB(
      horizontal,
      0,
      horizontal,
      bottomMargin.clamp(16.0, double.infinity),
    );
  }

  void _showActionBufferLockedSnackBar() {
    const estimatedSnackBarHeight = 48.0;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            '余裕時間の追加はProで使えます',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.canvas,
            ),
          ),
          backgroundColor: AppColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          margin: _topSnackBarMargin(
            estimatedSnackBarHeight: estimatedSnackBarHeight,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _deletedBlockMessage(Block block) {
    final title = block.title.trim();
    if (title.isEmpty) {
      return block.type == BlockType.action ? '行動を削除しました' : '行動ピンを削除しました';
    }
    return '「$title」を削除しました';
  }

  void _handleSwipeDeleteBlock(String blockId) {
    final blocks = ref.read(timelineProvider).blocks;
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index < 0) return;

    final pendingDelete = _PendingBlockDelete(
      block: blocks[index],
      originalIndex: index,
      deletedAt: DateTime.now(),
    );
    setState(() => _pendingBlockDelete = pendingDelete);
    ref.read(timelineProvider.notifier).deleteBlock(blockId);
    _showSwipeDeleteSnackBar(pendingDelete);
  }

  void _restorePendingDeletedBlock(_PendingBlockDelete pendingDelete) {
    if (_pendingBlockDelete != pendingDelete) return;
    _swipeDeleteSnackBarTimer?.cancel();
    _swipeDeleteSnackBarTimer = null;
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
    ref
        .read(timelineProvider.notifier)
        .restoreDeletedBlock(pendingDelete.block, pendingDelete.originalIndex);
    if (mounted) setState(() => _pendingBlockDelete = null);
  }

  void _showSwipeDeleteSnackBar(_PendingBlockDelete pendingDelete) {
    const estimatedSnackBarHeight = 52.0;
    var restored = false;
    final messenger = ScaffoldMessenger.of(context);
    _swipeDeleteSnackBarTimer?.cancel();
    messenger.hideCurrentSnackBar();
    _swipeDeleteSnackBarTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || restored || _pendingBlockDelete != pendingDelete) return;
      _swipeDeleteSnackBarTimer = null;
      messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.timeout);
    });
    messenger
        .showSnackBar(
          SnackBar(
            content: Text(
              _deletedBlockMessage(pendingDelete.block),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.canvas,
              ),
            ),
            action: SnackBarAction(
              label: '元に戻す',
              textColor: AppColors.accentOlive,
              onPressed: () {
                restored = true;
                _restorePendingDeletedBlock(pendingDelete);
              },
            ),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            margin: _topSnackBarMargin(
              estimatedSnackBarHeight: estimatedSnackBarHeight,
            ),
            duration: const Duration(seconds: 3),
            persist: false,
          ),
        )
        .closed
        .then((_) {
          if (_pendingBlockDelete == pendingDelete) {
            _swipeDeleteSnackBarTimer?.cancel();
            _swipeDeleteSnackBarTimer = null;
          }
          if (!mounted || restored || _pendingBlockDelete != pendingDelete) {
            return;
          }
          setState(() => _pendingBlockDelete = null);
        });
  }

  void _handleActionBufferDoubleTap(String blockId) {
    final proAccess = ref.read(effectiveProAccessProvider);
    if (proAccess.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認しています。少し待ってから再試行してください。')),
      );
      return;
    }
    if (proAccess.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認できませんでした。通信状態を確認してください。')),
      );
      return;
    }
    if (!proAccess.isPro) {
      _showActionBufferLockedSnackBar();
      return;
    }
    ref.read(timelineProvider.notifier).incrementActionBuffer(blockId);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveIndicatorTimer?.cancel();
    _swipeDeleteSnackBarTimer?.cancel();
    _stopReorderAutoScroll(clearPosition: true);
    _clockTimer.cancel();
    _searchHighlightTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _reorderController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _openSearch() {
    if (_dismissWorkSurfaceIfNeeded()) return;
    if (_exportPanelVisible) {
      _closeHeaderPopovers();
      return;
    }
    if (_dismissTemplateSheetIfNeeded()) return;
    _dismissInlineEditorIfNeeded();
    if (_exportPanelVisible) _closeExportPanel();
    setState(() => _isSearchActive = true);
  }

  void _closeSearch() {
    setState(() => _isSearchActive = false);
    _searchController.clear();
    ref.read(timelineProvider.notifier).clearSearch();
    _searchHighlightTimer?.cancel();
    _searchHighlightTimer = null;
  }

  void _onSearchChanged(String value) {
    ref.read(timelineProvider.notifier).setSearchQuery(value);
  }

  void _onSearchSubmit() => _jumpToActiveSearchMatch();
  void _onSearchNext() {
    ref.read(timelineProvider.notifier).nextSearchMatch();
    _jumpToActiveSearchMatch();
  }

  void _onSearchPrev() {
    ref.read(timelineProvider.notifier).prevSearchMatch();
    _jumpToActiveSearchMatch();
  }

  static const double _kSearchJumpTopMargin = 32.0;

  void _jumpToActiveSearchMatch() {
    final timelineState = ref.read(timelineProvider);
    final index = timelineState.activeSearchMatchIndex;
    if (index < 0 || index >= timelineState.searchMatches.length) return;

    final blockId = timelineState.searchMatches[index];
    final computed = ref.read(computedBlocksProvider);
    final sourceIndex = computed.indexWhere((cb) => cb.block.id == blockId);
    if (sourceIndex < 0) return;

    final ppm = timelineState.pixelsPerMinute;
    final bottomSpacer = MediaQuery.of(context).padding.bottom + 88;

    // Estimate scroll offset to the BOTTOM edge of the target block.
    // In reverse:true, larger offset = higher up (towards visual top).
    double estimatedOffset = bottomSpacer + kTimelineTargetAnchorVisualHeight;
    for (int i = sourceIndex + 1; i < computed.length; i++) {
      final cb = computed[i];
      estimatedOffset += timelineBlockVisualHeight(cb.block, ppm);
    }

    // Target block height
    final targetCb = computed[sourceIndex];
    final targetHeight = timelineBlockVisualHeight(targetCb.block, ppm);

    // Top edge of the target block
    final targetTop = estimatedOffset - targetHeight;
    final viewportHeight =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    var desiredOffset = targetTop - viewportHeight + _kSearchJumpTopMargin;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      desiredOffset = desiredOffset.clamp(0.0, maxScroll);
      _scrollController.jumpTo(desiredOffset);
    }

    // Temporary highlight
    ref.read(timelineProvider.notifier).highlightSearchBlock(blockId);
    _searchHighlightTimer?.cancel();
    _searchHighlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(timelineProvider.notifier).highlightSearchBlock(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final computed = ref.watch(computedBlocksProvider);
    final proAccess = ref.watch(effectiveProAccessProvider);
    final isPro = proAccess.isPro;
    final notifier = ref.read(timelineProvider.notifier);
    final computedBlockIds = computed.map((cb) => cb.block.id).toSet();
    _reorderItemKeys.removeWhere((id, _) => !computedBlockIds.contains(id));
    final currentTimelineMinute =
        state.viewMode == TimelineViewMode.edit && !_sheetVisible
        ? normalizeTimelineMinuteNearTarget(
            minutes: _now.hour * 60 + _now.minute,
            targetTime: state.targetTime,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PlanHeader(
              exportPanelVisible: _exportPanelVisible,
              onExportTap: _toggleExportPanel,
              saveIndicatorVisible: _saveIndicatorVisible,
              onSettingsTap: () {
                if (_dismissWorkSurfaceIfNeeded()) return;
                if (_closeHeaderPopovers()) return;
                if (_dismissTemplateSheetIfNeeded()) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              onSearchTap: _openSearch,
              isSearchActive: _isSearchActive,
            ),
            if (_isSearchActive)
              _SearchPopover(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onNext: _onSearchNext,
                onPrev: _onSearchPrev,
                onSubmit: _onSearchSubmit,
                onClose: _closeSearch,
                matchCount: state.searchMatches.length,
                activeMatchIndex: state.activeSearchMatchIndex,
              ),
            Expanded(
              child: Stack(
                key: _timelineStackKey,
                children: [
                  // Timeline view
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerCancel,
                    child: CustomScrollView(
                      controller: _scrollController,
                      reverse: true,
                      slivers: [
                        // Visual bottom spacer for the stacked left controls.
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                MediaQuery.of(context).padding.bottom +
                                _timelineBottomSpacer,
                          ),
                        ),
                        // Target anchor — visual bottom
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, right: 28),
                            child: _TargetTimeAnchor(
                              targetTime: state.targetTime,
                              targetTimeTitle: state.targetTimeTitle,
                              isSelected:
                                  state.selectedBlockId == kTargetTimeId,
                              readOnly:
                                  state.viewMode == TimelineViewMode.compact,
                              onSelect: state.viewMode == TimelineViewMode.edit
                                  ? () => notifier.selectBlock(kTargetTimeId)
                                  : () {},
                            ),
                          ),
                        ),
                        // Blocks or empty state
                        if (computed.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(),
                          )
                        else ...[
                          SliverPadding(
                            padding: const EdgeInsets.only(left: 20, right: 28),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final n = computed.length;
                                final sourceIndex = n - 1 - index;
                                final cb = computed[sourceIndex];
                                final itemKey = _reorderItemKeyFor(cb.block.id);
                                return KeyedSubtree(
                                  key: itemKey,
                                  child: Offstage(
                                    offstage:
                                        _reorderPreviewBlockId == cb.block.id,
                                    child: BlockItem(
                                      computedBlock: cb,
                                      isSelected:
                                          state.selectedBlockId == cb.block.id,
                                      isSearchHighlighted:
                                          state.searchHighlightedBlockId ==
                                          cb.block.id,
                                      preciseDraggingId:
                                          state.preciseDraggingId,
                                      allBlocks: state.blocks,
                                      sourceIndex: sourceIndex,
                                      pixelsPerMinute: state.pixelsPerMinute,
                                      currentTimelineMinute:
                                          currentTimelineMinute,
                                      sheetVisible: _sheetVisible,
                                      onReorderIntentStart:
                                          _prepareReorderPreview,
                                      onReorderIntentMove:
                                          _updateReorderPreview,
                                      onReorderIntentEnd: _endReorderPreview,
                                      onActionBufferDoubleTap:
                                          _handleActionBufferDoubleTap,
                                      onSwipeDelete: _handleSwipeDeleteBlock,
                                      readOnly:
                                          state.viewMode ==
                                          TimelineViewMode.compact,
                                    ),
                                  ),
                                );
                              }, childCount: computed.length),
                            ),
                          ),
                          // Visual top spacer
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 120),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 上部フェードオーバーレイ
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 20,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.canvas.withValues(alpha: 0.85),
                              AppColors.canvas.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 下部フェードオーバーレイ
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 20,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.canvas.withValues(alpha: 0),
                              AppColors.canvas.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_isReorderPreviewActive)
                    _ReorderInteractionOverlay(
                      stackKey: _timelineStackKey,
                      controller: _reorderController,
                    ),

                  // Backdrop (only when sheet is visible)
                  if (_sheetVisible)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissSheet,
                        child: Container(color: AppColors.scrim),
                      ),
                    ),

                  // Edit sheet panel
                  if (_sheetVisible)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: EditSheet(onDismiss: _dismissSheet),
                    ),

                  if (_timelineListVisible) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeTimelineList,
                        child: Container(color: AppColors.scrim),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 28,
                      child: TimelineListIslandModal(
                        onClose: _closeTimelineList,
                        onSelect: _selectTimeline,
                        onCreate: _createTimelineFromList,
                        onRename: _renameTimelineFromList,
                        onDelete: _deleteTimelineFromList,
                        switching: _timelineSwitching,
                      ),
                    ),
                  ],

                  // 浮遊ツールバー（edit view only）
                  if (state.viewMode == TimelineViewMode.edit &&
                      !_sheetVisible &&
                      !_timelineListVisible)
                    Positioned(
                      left: 88,
                      right: 20,
                      bottom:
                          MediaQuery.of(context).padding.bottom +
                          _floatingControlBottomInset,
                      child: _FloatingToolbar(
                        showTemplateAction: isPro || !proAccess.isKnown,
                        templateAccessPending:
                            !proAccess.isKnown || _templateSheetLoading,
                        onTemplateTap: _showTemplateSheet,
                        onAdd: () {
                          if (_closeHeaderPopovers()) return;
                          if (_dismissTemplateSheetIfNeeded()) return;
                          if (_dismissInlineEditorIfNeeded()) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          notifier.addBlock(0, BlockType.action);
                          unawaited(
                            _track(
                              UsageAnalyticsEvent.blockAdded,
                              properties: {
                                'block_type': 'action',
                                'block_count_bucket': analyticsCountBucket(
                                  ref.read(timelineProvider).blocks.length,
                                ),
                              },
                            ),
                          );
                        },
                        onAddPoint: () {
                          if (_closeHeaderPopovers()) return;
                          if (_dismissTemplateSheetIfNeeded()) return;
                          if (_dismissInlineEditorIfNeeded()) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          notifier.addBlock(0, BlockType.actionPoint);
                          unawaited(
                            _track(
                              UsageAnalyticsEvent.blockAdded,
                              properties: {
                                'block_type': 'actionPoint',
                                'block_count_bucket': analyticsCountBucket(
                                  ref.read(timelineProvider).blocks.length,
                                ),
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  if (!_sheetVisible && !_timelineListVisible)
                    Positioned(
                      left: 20,
                      bottom:
                          MediaQuery.of(context).padding.bottom +
                          _floatingControlBottomInset,
                      child: _TimelineListButton(onTap: _showTimelineList),
                    ),

                  if (!_sheetVisible && !_timelineListVisible)
                    Positioned(
                      left: 20,
                      bottom:
                          MediaQuery.of(context).padding.bottom +
                          _floatingControlBottomInset +
                          _floatingControlSize +
                          _floatingControlStackGap,
                      child: _DensityToggleButton(
                        viewMode: state.viewMode,
                        onTap: () {
                          _cancelReorderPreview();
                          if (_closeHeaderPopovers()) return;
                          if (_dismissTemplateSheetIfNeeded()) return;
                          if (_sheetVisible) _dismissSheet();
                          notifier.setViewMode(
                            state.viewMode == TimelineViewMode.edit
                                ? TimelineViewMode.compact
                                : TimelineViewMode.edit,
                          );
                        },
                      ),
                    ),

                  if (_templateSheetVisible)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissTemplateSheet,
                        child: const SizedBox.expand(),
                      ),
                    ),

                  if (_templateSheetVisible)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(context).padding.bottom + 84,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.62,
                        ),
                        child: TemplateSheet(
                          onDismiss: _dismissTemplateSheet,
                          presentation: TemplateSheetPresentation.popover,
                          initialTemplates: _templateSheetInitialTemplates,
                          currentTimelineTitle: _currentTimelineTitle,
                          onBeforeSaveCurrent: _saveCurrentPlanNow,
                        ),
                      ),
                    ),

                  if (state.activeInlineEditorId != null &&
                      !_sheetVisible &&
                      !_templateSheetVisible &&
                      !_timelineListVisible &&
                      state.viewMode == TimelineViewMode.edit)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        child: const SizedBox.expand(),
                      ),
                    ),

                  if (_isSearchActive &&
                      !_sheetVisible &&
                      !_templateSheetVisible &&
                      !_timelineListVisible)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeHeaderPopovers,
                        child: const SizedBox.expand(),
                      ),
                    ),

                  // エクスポートパネル（Quick Overlay）
                  if (_exportPanelVisible) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closeExportPanel,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ExportPanel(onDismiss: _closeExportPanel),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reorder Preview Overlay
// ---------------------------------------------------------------------------

class _ReorderInteractionOverlay extends StatelessWidget {
  const _ReorderInteractionOverlay({
    required this.stackKey,
    required this.controller,
  });

  final GlobalKey stackKey;
  final _ReorderInteractionController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<_ReorderInsertionFrame?>(
              valueListenable: controller.insertion,
              builder: (context, insertion, _) {
                return _ReorderInsertionOverlay(
                  stackKey: stackKey,
                  insertion: insertion,
                );
              },
            ),
            ValueListenableBuilder<_ReorderPreviewFrame?>(
              valueListenable: controller.preview,
              builder: (context, preview, _) {
                return _ReorderDragPreviewOverlay(
                  stackKey: stackKey,
                  preview: preview,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderInsertionOverlay extends StatelessWidget {
  const _ReorderInsertionOverlay({
    required this.stackKey,
    required this.insertion,
  });

  final GlobalKey stackKey;
  final _ReorderInsertionFrame? insertion;

  @override
  Widget build(BuildContext context) {
    final frame = insertion;
    final renderObject = stackKey.currentContext?.findRenderObject();
    if (frame == null || renderObject is! RenderBox || !renderObject.hasSize) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final localY = renderObject
              .globalToLocal(Offset(0, frame.globalY))
              .dy;
          final maxTop = (constraints.maxHeight - 8).clamp(
            8.0,
            double.infinity,
          );
          final top = (localY - 1.5).clamp(8.0, maxTop).toDouble();
          return Stack(
            children: [
              Positioned(
                key: const ValueKey('reorder-insertion-line'),
                left: 20,
                right: 28,
                top: top,
                child: Semantics(
                  label: '並び替え挿入位置 ${frame.sourceInsertIndex}',
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accentOlive,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.canvas.withValues(alpha: 0.9),
                          blurRadius: 0,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.accentOlive.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReorderDragPreviewOverlay extends StatelessWidget {
  const _ReorderDragPreviewOverlay({
    required this.stackKey,
    required this.preview,
  });

  final GlobalKey stackKey;
  final _ReorderPreviewFrame? preview;

  @override
  Widget build(BuildContext context) {
    final frame = preview;
    final renderObject = stackKey.currentContext?.findRenderObject();
    if (frame == null || renderObject is! RenderBox || !renderObject.hasSize) {
      return const SizedBox.shrink();
    }

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final localPosition = renderObject.globalToLocal(
            frame.globalPosition,
          );
          final width = constraints.maxWidth < 230
              ? (constraints.maxWidth - 32).clamp(136.0, 198.0).toDouble()
              : 198.0;
          final height = frame.block.type == BlockType.actionPoint
              ? 62.0
              : 72.0;
          final maxLeft = (constraints.maxWidth - width - 12).clamp(
            12.0,
            double.infinity,
          );
          final maxTop = (constraints.maxHeight - height - 12).clamp(
            12.0,
            double.infinity,
          );

          var left = localPosition.dx + 16;
          if (left + width + 12 > constraints.maxWidth) {
            left = localPosition.dx - width - 16;
          }
          var top = localPosition.dy - height - 16;
          if (top < 12) top = localPosition.dy + 16;

          return Stack(
            children: [
              Positioned(
                left: left.clamp(12.0, maxLeft).toDouble(),
                top: top.clamp(12.0, maxTop).toDouble(),
                width: width,
                child: _ReorderDragPreview(block: frame.block),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReorderDragPreview extends StatelessWidget {
  const _ReorderDragPreview({required this.block});

  final Block block;

  @override
  Widget build(BuildContext context) {
    final color =
        AppColors.blockColors[block.colorIndex % AppColors.blockColors.length];
    final isPoint = block.type == BlockType.actionPoint;
    final title = block.title.trim().isEmpty ? '名称なし' : block.title.trim();
    final meta = isPoint
        ? 'ピン'
        : block.normalizedBufferMinutes > 0
        ? '計${block.effectiveDuration}分'
        : '${block.duration}分';

    return Container(
      key: ValueKey('reorder-drag-preview:${block.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentOlive.withValues(alpha: 0.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: -5,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.accentOlive.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -6,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: isPoint ? 28 : 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedInk.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Header
// ---------------------------------------------------------------------------

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.onExportTap,
    this.exportPanelVisible = false,
    this.saveIndicatorVisible = false,
    required this.onSettingsTap,
    required this.onSearchTap,
    this.isSearchActive = false,
  });

  final VoidCallback onExportTap;
  final bool exportPanelVisible;
  final bool saveIndicatorVisible;
  final VoidCallback onSettingsTap;
  final VoidCallback onSearchTap;
  final bool isSearchActive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final actionSize = compact ? 34.0 : 38.0;
        final actionGap = compact ? 4.0 : AppSpacing.sm;
        final iconSize = compact ? 20.0 : 22.0;

        Widget headerAction({
          required VoidCallback onTap,
          required IconData icon,
          Color? color,
          Color backgroundColor = Colors.transparent,
        }) {
          return Pressable(
            onTap: onTap,
            scale: 0.88,
            child: Container(
              margin: EdgeInsets.only(left: actionGap),
              width: actionSize,
              height: actionSize,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: color ?? AppColors.mutedInk,
              ),
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            boxShadow: AppShadows.header,
          ),
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 16,
            10,
            compact ? 12 : 16,
            10,
          ),
          child: Row(
            children: [
              Image.asset('assets/images/medo_icon.png', width: 28, height: 28),
              if (!compact) ...[
                const SizedBox(width: 8),
                const Text(
                  'Medo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.6,
                    color: AppColors.darkSurface,
                  ),
                ),
              ],
              const Spacer(),
              if (saveIndicatorVisible) const _SaveIndicatorDot(),
              headerAction(
                onTap: onSearchTap,
                icon: PhosphorIcons.magnifyingGlass(),
                backgroundColor: isSearchActive
                    ? AppColors.selectionFill
                    : Colors.transparent,
                color: isSearchActive
                    ? AppColors.accentOlive
                    : AppColors.mutedInk,
              ),
              headerAction(
                onTap: onExportTap,
                icon: PhosphorIcons.calendarBlank(),
                backgroundColor: exportPanelVisible
                    ? AppColors.selectionFill
                    : Colors.transparent,
                color: exportPanelVisible
                    ? AppColors.accentOlive
                    : AppColors.mutedInk,
              ),
              headerAction(onTap: onSettingsTap, icon: PhosphorIcons.gear()),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Search Popover — appears below header with slightly narrower width
// ---------------------------------------------------------------------------

class _SearchPopover extends StatelessWidget {
  const _SearchPopover({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onSubmit,
    required this.onClose,
    required this.matchCount,
    required this.activeMatchIndex,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final int matchCount;
  final int activeMatchIndex;

  @override
  Widget build(BuildContext context) {
    final hasMatches = matchCount > 0;
    final countText = hasMatches
        ? '${activeMatchIndex + 1}/$matchCount'
        : '0/0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.softGray.withValues(alpha: 0.55)),
          boxShadow: AppShadows.quickOverlay,
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass(),
              size: 18,
              color: AppColors.mutedInk,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                onTapOutside: (_) => onClose(),
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '行動タイトルを検索',
                  hintStyle: TextStyle(color: AppColors.mutedInk, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
            ),
            // Match count
            if (controller.text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasMatches
                      ? AppColors.selectionFill
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasMatches
                        ? AppColors.accentOlive
                        : AppColors.mutedInk,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            // Prev
            Pressable(
              onTap: onPrev,
              scale: 0.88,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  PhosphorIcons.caretUp(),
                  size: 18,
                  color: hasMatches
                      ? AppColors.mutedInk
                      : AppColors.mutedInk.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Next
            Pressable(
              onTap: onNext,
              scale: 0.88,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  PhosphorIcons.caretDown(),
                  size: 18,
                  color: hasMatches
                      ? AppColors.mutedInk
                      : AppColors.mutedInk.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Close
            Pressable(
              onTap: onClose,
              scale: 0.88,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  PhosphorIcons.x(),
                  size: 18,
                  color: AppColors.mutedInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target Time Anchor
// ---------------------------------------------------------------------------

class _TargetTimeAnchor extends ConsumerStatefulWidget {
  const _TargetTimeAnchor({
    required this.targetTime,
    required this.targetTimeTitle,
    required this.isSelected,
    this.readOnly = false,
    required this.onSelect,
  });

  final int targetTime;
  final String targetTimeTitle;
  final bool isSelected;
  final bool readOnly;
  final VoidCallback onSelect;

  @override
  ConsumerState<_TargetTimeAnchor> createState() => _TargetTimeAnchorState();
}

class _TargetTimeAnchorState extends ConsumerState<_TargetTimeAnchor> {
  static const _connectorGap = 8.0;
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocusNode;

  static const _inlineEditorId = 'target-title';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.targetTimeTitle);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_handleTitleFocusChange);
  }

  @override
  void didUpdateWidget(_TargetTimeAnchor old) {
    super.didUpdateWidget(old);
    if (widget.targetTimeTitle != old.targetTimeTitle &&
        _titleCtrl.text != widget.targetTimeTitle) {
      _titleCtrl.text = widget.targetTimeTitle;
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_handleTitleFocusChange);
    _titleFocusNode.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _handleTitleFocusChange() {
    final notifier = ref.read(timelineProvider.notifier);
    if (_titleFocusNode.hasFocus) {
      notifier.setActiveInlineEditor(_inlineEditorId);
      return;
    }

    final activeInlineEditorId = ref
        .read(timelineProvider)
        .activeInlineEditorId;
    if (activeInlineEditorId == _inlineEditorId) {
      notifier.setActiveInlineEditor(null);
    }
  }

  bool _dismissInlineEditorIfNeeded() {
    if (ref.read(timelineProvider).activeInlineEditorId == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  Future<void> _pickTargetTime() async {
    if (_dismissInlineEditorIfNeeded()) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final pickedMinutes = await showPlatformTimePicker(
      context,
      initialMinutes: widget.targetTime,
    );
    if (!mounted || pickedMinutes == null) return;

    ref.read(timelineProvider.notifier).setTargetTime(pickedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(timelineProvider.notifier);
    final targetLineColor = AppColors.accentOlive.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(top: _connectorGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left sidebar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              if (_dismissInlineEditorIfNeeded()) return;
              final insertIndex = ref.read(timelineProvider).blocks.length;
              HapticFeedback.selectionClick();
              ref
                  .read(timelineProvider.notifier)
                  .addBlock(insertIndex, BlockType.action);
              unawaited(
                ref
                    .read(usageAnalyticsServiceProvider)
                    .track(
                      UsageAnalyticsEvent.blockAdded,
                      properties: {
                        'block_type': 'action',
                        'block_count_bucket': analyticsCountBucket(
                          ref.read(timelineProvider).blocks.length,
                        ),
                      },
                    ),
              );
            },
            child: SizedBox(
              width: 48,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -_connectorGap,
                    right: 0,
                    bottom: -_connectorGap,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              targetLineColor.withValues(alpha: 0.0),
                              targetLineColor,
                              targetLineColor,
                              targetLineColor.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.12, 0.88, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -_connectorGap,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.mutedInk,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: 8,
                    child: Container(
                      color: AppColors.canvas,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Text(
                        formatTime(widget.targetTime),
                        style: AppTextStyles.time(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right body — アンカー本体。ラベル「目標」+ タイトル + 大きな目標時刻
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_dismissInlineEditorIfNeeded()) return;
                widget.onSelect();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 4),
                          TextField(
                            controller: _titleCtrl,
                            focusNode: _titleFocusNode,
                            readOnly: widget.readOnly,
                            canRequestFocus: !widget.readOnly,
                            onChanged: widget.readOnly
                                ? null
                                : (v) => notifier.setTargetTimeTitle(v),
                            onTap: () {},
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Pressable(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickTargetTime,
                      scale: 0.95,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          formatTime(widget.targetTime),
                          style: AppTextStyles.time(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentOlive,
                            letterSpacing: -0.6,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Button
// ---------------------------------------------------------------------------

class _TimelineListButton extends StatelessWidget {
  const _TimelineListButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.floatingToolbar,
          border: Border.all(color: AppColors.softGray),
        ),
        child: Icon(
          PhosphorIcons.stack(),
          size: 22,
          color: AppColors.darkSurface,
        ),
      ),
    );
  }
}

class _DensityToggleButton extends StatelessWidget {
  const _DensityToggleButton({required this.viewMode, required this.onTap});

  final TimelineViewMode viewMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOverview = viewMode == TimelineViewMode.compact;
    return Tooltip(
      message: isOverview ? '詳細編集' : '俯瞰',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isOverview
                ? AppColors.selectionFill
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.floatingToolbar,
            border: Border.all(
              color: isOverview ? AppColors.accentOlive : AppColors.softGray,
            ),
          ),
          child: Icon(
            isOverview
                ? PhosphorIcons.listDashes()
                : PhosphorIcons.squaresFour(),
            size: 22,
            color: isOverview ? AppColors.accentOlive : AppColors.darkSurface,
          ),
        ),
      ),
    );
  }
}

class TimelineListIslandModal extends ConsumerStatefulWidget {
  const TimelineListIslandModal({
    super.key,
    required this.onClose,
    required this.onSelect,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    required this.switching,
  });

  final VoidCallback onClose;
  final ValueChanged<TimelinePlanSummary> onSelect;
  final Future<void> Function(String title) onCreate;
  final Future<void> Function(TimelinePlanSummary summary, String title)
  onRename;
  final Future<void> Function(TimelinePlanSummary summary) onDelete;
  final bool switching;

  @override
  ConsumerState<TimelineListIslandModal> createState() =>
      _TimelineListIslandModalState();
}

class _TimelineListIslandModalState
    extends ConsumerState<TimelineListIslandModal> {
  List<TimelinePlanSummary> _plans = [];
  final _createTitleController = TextEditingController();
  final _createTitleFocusNode = FocusNode();
  final _editTitleController = TextEditingController();
  final _editTitleFocusNode = FocusNode();
  bool _loading = true;
  bool _creating = false;
  String? _editingPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _createTitleController.dispose();
    _createTitleFocusNode.dispose();
    _editTitleController.dispose();
    _editTitleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await ref.read(planRepositoryProvider).listPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Timeline list load error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatUpdatedAt(DateTime value) {
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showCreateForm() {
    setState(() {
      _creating = true;
      _editingPlanId = null;
      _createTitleController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _createTitleFocusNode.requestFocus();
    });
  }

  void _cancelCreate() {
    setState(() {
      _creating = false;
      _createTitleController.clear();
    });
  }

  Future<void> _submitCreate() async {
    await widget.onCreate(_createTitleController.text);
    if (!mounted) return;
    setState(() {
      _creating = false;
      _createTitleController.clear();
      _loading = true;
    });
    await _loadPlans();
  }

  void _startRename(TimelinePlanSummary summary) {
    setState(() {
      _creating = false;
      _editingPlanId = summary.id;
      _editTitleController.text = summary.title;
      _editTitleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: summary.title.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editTitleFocusNode.requestFocus();
    });
  }

  void _cancelRename() {
    setState(() {
      _editingPlanId = null;
      _editTitleController.clear();
    });
  }

  Future<void> _submitRename(TimelinePlanSummary summary) async {
    await widget.onRename(summary, _editTitleController.text);
    if (!mounted) return;
    setState(() {
      _editingPlanId = null;
      _editTitleController.clear();
      _loading = true;
    });
    await _loadPlans();
  }

  Future<void> _confirmDelete(TimelinePlanSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.canvas,
        title: const Text('タイムラインを削除しますか？'),
        content: Text('「${summary.title}」を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await widget.onDelete(summary);
    if (!mounted) return;
    setState(() {
      _editingPlanId = null;
      _loading = true;
    });
    await _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlanId = ref.watch(currentPlanIdProvider);
    final proAccess = ref.watch(effectiveProAccessProvider);
    final isPro = proAccess.isPro;
    final accessPending = !proAccess.isKnown;
    final canCreate =
        !accessPending && (isPro || _plans.length < kFreeTimelineLimit);
    final freeAvailablePlanIds = <String>{
      ?currentPlanId,
      for (final plan in _plans)
        if (currentPlanId == null || plan.id != currentPlanId) plan.id,
    }.take(kFreeTimelineLimit).toSet();
    final bottomLimit = MediaQuery.of(context).size.height * 0.58;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: bottomLimit.clamp(280.0, 520.0)),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.workSurface,
          border: Border.all(color: AppColors.softGray),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'タイムライン',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkSurface,
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: widget.onClose,
                    scale: 0.88,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        PhosphorIcons.x(),
                        size: 18,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_creating) ...[
                _TimelineCreateForm(
                  controller: _createTitleController,
                  focusNode: _createTitleFocusNode,
                  busy: widget.switching,
                  onSubmit: _submitCreate,
                  onCancel: _cancelCreate,
                ),
                const SizedBox(height: 10),
              ],
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentOlive,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final isCurrent = plan.id == currentPlanId;
                          final isAvailable =
                              isPro || freeAvailablePlanIds.contains(plan.id);
                          return _TimelineListRow(
                            summary: plan,
                            subtitle:
                                '${plan.targetTimeTitle} · ${formatTime(plan.targetTime)} · ${plan.blockCount}ブロック · ${_formatUpdatedAt(plan.updatedAt)}'
                                '${isAvailable ? '' : ' · Proで利用可'}',
                            isCurrent: isCurrent,
                            isEditing: _editingPlanId == plan.id,
                            disabled:
                                widget.switching ||
                                accessPending ||
                                isCurrent ||
                                !isAvailable,
                            editController: _editTitleController,
                            editFocusNode: _editTitleFocusNode,
                            onTap: () => widget.onSelect(plan),
                            onRename: () => _startRename(plan),
                            onDelete: () => _confirmDelete(plan),
                            onSubmitRename: () => _submitRename(plan),
                            onCancelRename: _cancelRename,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Pressable(
                onTap: canCreate && !widget.switching && !_creating
                    ? _showCreateForm
                    : null,
                scale: 0.97,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: canCreate
                        ? AppColors.darkSurface
                        : AppColors.softGray,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: widget.switching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.canvas,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                PhosphorIcons.plus(),
                                size: 18,
                                color: canCreate
                                    ? AppColors.canvas
                                    : AppColors.mutedInk,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                accessPending
                                    ? '課金状態を確認中'
                                    : canCreate
                                    ? '新しいタイムライン'
                                    : 'Freeは2件まで',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: canCreate
                                      ? AppColors.canvas
                                      : AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineCreateForm extends StatelessWidget {
  const _TimelineCreateForm({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accentOlive, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'タイムライン名',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.softGray),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '例: 朝の準備',
                hintStyle: TextStyle(color: AppColors.mutedInk),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: busy ? null : onCancel,
                  scale: 0.97,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.softGray,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Center(
                      child: Text(
                        'キャンセル',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: busy ? null : onSubmit,
                  scale: 0.97,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.canvas,
                              ),
                            )
                          : const Text(
                              '作成',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.canvas,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineListRow extends StatelessWidget {
  const _TimelineListRow({
    required this.summary,
    required this.subtitle,
    required this.isCurrent,
    required this.isEditing,
    required this.disabled,
    required this.editController,
    required this.editFocusNode,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onSubmitRename,
    required this.onCancelRename,
  });

  final TimelinePlanSummary summary;
  final String subtitle;
  final bool isCurrent;
  final bool isEditing;
  final bool disabled;
  final TextEditingController editController;
  final FocusNode editFocusNode;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSubmitRename;
  final VoidCallback onCancelRename;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        key: ValueKey('timeline-row-${summary.id}'),
        onTap: disabled ? null : onTap,
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEditing)
                      TextField(
                        controller: editController,
                        focusNode: editFocusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onSubmitRename(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'タイムライン名',
                          hintStyle: TextStyle(color: AppColors.mutedInk),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      )
                    else
                      Text(
                        summary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCurrent && !isEditing) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    PhosphorIcons.checkCircle(),
                    size: 16,
                    color: AppColors.accentOlive,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isEditing) ...[
                Pressable(
                  key: ValueKey('timeline-rename-submit-${summary.id}'),
                  onTap: onSubmitRename,
                  scale: 0.88,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      PhosphorIcons.check(),
                      size: 16,
                      color: AppColors.accentOlive,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  key: ValueKey('timeline-rename-cancel-${summary.id}'),
                  onTap: onCancelRename,
                  scale: 0.88,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      PhosphorIcons.x(),
                      size: 16,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
              ] else ...[
                Pressable(
                  key: ValueKey('timeline-rename-${summary.id}'),
                  onTap: onRename,
                  scale: 0.88,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      PhosphorIcons.pencilSimple(),
                      size: 16,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  key: ValueKey('timeline-delete-${summary.id}'),
                  onTap: onDelete,
                  scale: 0.88,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      PhosphorIcons.trash(),
                      size: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingToolbar extends StatelessWidget {
  const _FloatingToolbar({
    required this.onAdd,
    required this.onAddPoint,
    required this.showTemplateAction,
    required this.templateAccessPending,
    required this.onTemplateTap,
  });

  final VoidCallback onAdd;
  final VoidCallback onAddPoint;
  final bool showTemplateAction;
  final bool templateAccessPending;
  final VoidCallback onTemplateTap;

  @override
  Widget build(BuildContext context) {
    Widget circularAction({
      required VoidCallback onTap,
      required IconData icon,
      required String label,
      Key? key,
      bool isPending = false,
      bool useNeutralStyle = false,
    }) {
      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: Pressable(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            scale: 0.88,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: useNeutralStyle
                    ? AppColors.cardBackground
                    : isPending
                    ? AppColors.softGray
                    : AppColors.accentOlive,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.floatingToolbar,
                border: useNeutralStyle
                    ? Border.all(color: AppColors.softGray)
                    : null,
              ),
              child: isPending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      size: 20,
                      color: useNeutralStyle
                          ? AppColors.darkSurface
                          : AppColors.canvas,
                    ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showAddLabel = !showTemplateAction || constraints.maxWidth >= 284;

        return SizedBox(
          height: 56,
          child: Row(
            children: [
              if (showTemplateAction) ...[
                circularAction(
                  key: const ValueKey('template-toolbar-button'),
                  onTap: onTemplateTap,
                  icon: PhosphorIcons.cards(),
                  label: 'テンプレート',
                  isPending: templateAccessPending,
                  useNeutralStyle: true,
                ),
                const SizedBox(width: 10),
              ],
              circularAction(
                onTap: onAddPoint,
                icon: PhosphorIcons.pushPin(),
                label: '通過点を追加',
              ),
              const SizedBox(width: 10),
              // 行動追加
              Expanded(
                child: Tooltip(
                  message: '前の行動を追加',
                  child: Pressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAdd,
                    scale: 0.97,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accentOlive,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: AppShadows.floatingToolbar,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIcons.plus(),
                            size: 20,
                            color: AppColors.canvas,
                          ),
                          if (showAddLabel) ...[
                            const SizedBox(width: 6),
                            const Text(
                              '前の行動を追加',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.canvas,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final bottomCompensation =
        MediaQuery.of(context).padding.bottom + _timelineBottomSpacer + 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(48, bottomCompensation.toDouble(), 48, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.selectionFill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.accentDivider),
            ),
            child: Icon(
              PhosphorIcons.listChecks(),
              color: AppColors.accentOlive,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '前の行動を追加しましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '下のツールバーから、目標時刻に間に合わせるための行動や通過点を積み上げられます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedInk,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save Indicator Dot
// ---------------------------------------------------------------------------

class _SaveIndicatorDot extends StatelessWidget {
  const _SaveIndicatorDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.accentOlive,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
