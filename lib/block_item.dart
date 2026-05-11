import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

const double _swipeDeleteDistanceThreshold = 144;
const double _swipeDeleteDismissThreshold = 0.62;

// ---------------------------------------------------------------------------
// TimeField — HH:mm inline editable widget
// ---------------------------------------------------------------------------

class TimeField extends StatefulWidget {
  const TimeField({
    super.key,
    required this.minutes,
    required this.onChanged,
    this.style,
  });

  final int minutes;
  final void Function(int minutes) onChanged;
  final TextStyle? style;

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: formatTime(widget.minutes));
  }

  @override
  void didUpdateWidget(TimeField old) {
    super.didUpdateWidget(old);
    if (old.minutes != widget.minutes) {
      final formatted = formatTime(widget.minutes);
      if (_ctrl.text != formatted) _ctrl.text = formatted;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit(String value) {
    var v = value.trim();
    // 4桁の数字を HH:mm に自動変換（貼り付け対応）
    if (RegExp(r'^\d{4}$').hasMatch(v)) {
      v = '${v.substring(0, 2)}:${v.substring(2, 4)}';
    }
    final parts = v.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        widget.onChanged(h * 60 + m);
        return;
      }
    }
    _ctrl.text = formatTime(widget.minutes);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: _ctrl,
        onEditingComplete: () => _commit(_ctrl.text),
        onTapOutside: (_) => _commit(_ctrl.text),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        style: widget.style,
        keyboardType: TextInputType.datetime,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BlockItem
// ---------------------------------------------------------------------------

class BlockItem extends ConsumerStatefulWidget {
  const BlockItem({
    super.key,
    required this.computedBlock,
    required this.isSelected,
    this.isSearchHighlighted = false,
    required this.preciseDraggingId,
    required this.allBlocks,
    required this.index,
    required this.sourceIndex,
    required this.pixelsPerMinute,
    this.currentTimelineMinute,
    this.sheetVisible = false,
    this.readOnly = false,
    this.onReorderIntentStart,
    this.onReorderIntentEnd,
    this.onActionBufferDoubleTap,
    this.onSwipeDelete,
  });

  final ComputedBlock computedBlock;
  final bool isSelected;
  final bool isSearchHighlighted;
  final String? preciseDraggingId;
  final List<Block> allBlocks;
  final int index;
  final int sourceIndex;
  final double pixelsPerMinute;
  final int? currentTimelineMinute;
  final bool sheetVisible;
  final bool readOnly;
  final void Function(String blockId)? onReorderIntentStart;
  final void Function(String blockId)? onReorderIntentEnd;
  final void Function(String blockId)? onActionBufferDoubleTap;
  final void Function(String blockId)? onSwipeDelete;

  @override
  ConsumerState<BlockItem> createState() => _BlockItemState();
}

@visibleForTesting
double? currentTimelineMarkerOffsetForBlock({
  required ComputedBlock computedBlock,
  required int? currentTimelineMinute,
  required double visualHeight,
}) {
  final minute = currentTimelineMinute;
  if (minute == null) return null;

  if (computedBlock.block.type == BlockType.actionPoint) {
    return minute == computedBlock.startTime ? visualHeight / 2 : null;
  }

  if (minute <= computedBlock.startTime || minute > computedBlock.endTime) {
    return null;
  }

  final effectiveDuration = computedBlock.block.effectiveDuration;
  if (effectiveDuration <= 0) return null;

  final elapsed = minute - computedBlock.startTime;
  return (visualHeight * elapsed / effectiveDuration)
      .clamp(0.0, visualHeight)
      .toDouble();
}

class _BlockItemState extends ConsumerState<BlockItem> {
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocusNode;
  Offset? _swipeStart;
  Offset _swipeDelta = Offset.zero;
  bool _animateHeightChange = false;

  String get _inlineEditorId => 'block-title:${widget.computedBlock.block.id}';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.computedBlock.block.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_handleTitleFocusChange);
  }

  @override
  void didUpdateWidget(BlockItem old) {
    super.didUpdateWidget(old);
    _animateHeightChange = old.pixelsPerMinute != widget.pixelsPerMinute;
    // Sync title from external changes (e.g., edit sheet)
    final newTitle = widget.computedBlock.block.title;
    if (newTitle != old.computedBlock.block.title &&
        _titleCtrl.text != newTitle) {
      _titleCtrl.text = newTitle;
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
    ref.read(timelineProvider.notifier).setActiveInlineEditor(null);
    return true;
  }

  bool get _isPreciseImpactTarget {
    if (widget.preciseDraggingId == null) return false;
    final dragIndex = widget.allBlocks.indexWhere(
      (b) => b.id == widget.preciseDraggingId,
    );
    if (dragIndex < 0) return false;
    return widget.sourceIndex <= dragIndex;
  }

  void _handleSidebarDoubleTap(int insertIndex) {
    if (widget.readOnly) return;
    if (widget.sheetVisible) return;
    if (_dismissInlineEditorIfNeeded()) return;
    if (widget.preciseDraggingId != null) return;
    HapticFeedback.selectionClick();
    ref.read(timelineProvider.notifier).addBlock(insertIndex, BlockType.action);
  }

  Future<bool> _confirmSwipeDelete() async {
    if (widget.readOnly) return false;
    if (widget.sheetVisible) return false;
    if (_dismissInlineEditorIfNeeded()) return false;
    if (widget.preciseDraggingId != null) return false;
    HapticFeedback.selectionClick();
    return true;
  }

  void _deleteBlockBySwipe(DismissDirection direction) {
    _deleteCurrentBlockBySwipe();
  }

  void _deleteCurrentBlockBySwipe() {
    final blockId = widget.computedBlock.block.id;
    final onSwipeDelete = widget.onSwipeDelete;
    if (onSwipeDelete != null) {
      onSwipeDelete(blockId);
      return;
    }
    ref.read(timelineProvider.notifier).deleteBlock(blockId);
  }

  void _handleActionBodyDoubleTap(Block block) {
    if (widget.readOnly) return;
    if (widget.sheetVisible) return;
    if (_dismissInlineEditorIfNeeded()) return;
    if (widget.preciseDraggingId != null) return;
    HapticFeedback.selectionClick();
    widget.onActionBufferDoubleTap?.call(block.id);
  }

  Widget _wrapSwipeDelete({required Block block, required Widget child}) {
    if (widget.readOnly) return child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _swipeStart = event.position;
        _swipeDelta = Offset.zero;
      },
      onPointerMove: (event) {
        final start = _swipeStart;
        if (start == null) return;
        _swipeDelta = event.position - start;
      },
      onPointerUp: (_) => _handlePointerSwipeDelete(),
      onPointerCancel: (_) => _resetPointerSwipe(),
      child: Dismissible(
        key: ValueKey('swipe-delete:${block.id}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: _swipeDeleteDismissThreshold,
        },
        confirmDismiss: (_) => _confirmSwipeDelete(),
        onDismissed: _deleteBlockBySwipe,
        background: _SwipeDeleteBackground(
          isPoint: block.type == BlockType.actionPoint,
        ),
        child: child,
      ),
    );
  }

  void _resetPointerSwipe() {
    _swipeStart = null;
    _swipeDelta = Offset.zero;
  }

  Future<void> _handlePointerSwipeDelete() async {
    final delta = _swipeDelta;
    _resetPointerSwipe();
    final isRightSwipe =
        delta.dx > _swipeDeleteDistanceThreshold &&
        delta.dx.abs() > delta.dy.abs() * 1.4;
    if (!isRightSwipe) return;
    if (!await _confirmSwipeDelete()) return;
    _deleteCurrentBlockBySwipe();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.computedBlock.block;
    final notifier = ref.read(timelineProvider.notifier);

    return block.type == BlockType.action
        ? _buildDuration(block, notifier)
        : _buildPoint(block, notifier);
  }

  Widget _buildDuration(Block block, TimelineNotifier notifier) {
    final ppm = widget.pixelsPerMinute;
    final isOverview = ppm < kOverviewThresholdPpm;
    final bufferMinutes = block.normalizedBufferMinutes;
    final effectiveDuration = block.effectiveDuration;
    final naturalHeight = effectiveDuration * ppm;
    final minOverviewHeight = bufferMinutes > 0
        ? kMinBufferedOverviewBlockHeight
        : kMinOverviewBlockHeight;
    final height =
        (isOverview
                ? naturalHeight.clamp(minOverviewHeight, double.infinity)
                : naturalHeight)
            .toDouble();
    final actionSectionHeight =
        (bufferMinutes > 0 && effectiveDuration > 0
                ? (height * block.duration / effectiveDuration).clamp(
                    24.0,
                    double.infinity,
                  )
                : height)
            .toDouble();
    final pillAndHandleBottomInset = bufferMinutes > 0
        ? (height - actionSectionHeight).clamp(0.0, double.infinity)
        : 0.0;
    final isCompact = actionSectionHeight < 56.0;
    final actionBodyTapHeight = actionSectionHeight < 28.0
        ? actionSectionHeight
        : (actionSectionHeight * 0.42).clamp(28.0, actionSectionHeight);
    final actionFlex = block.duration > 0 ? block.duration : 1;
    final color =
        AppColors.blockColors[block.colorIndex % AppColors.blockColors.length];
    final startTime = widget.computedBlock.startTime;
    final actionEndTime = startTime + block.duration;
    final currentMarkerOffset = currentTimelineMarkerOffsetForBlock(
      computedBlock: widget.computedBlock,
      currentTimelineMinute: widget.currentTimelineMinute,
      visualHeight: height,
    );
    final isCurrentBlock = currentMarkerOffset != null;

    return AnimatedContainer(
      key: ValueKey('block-item-body:${block.id}'),
      duration: _animateHeightChange
          ? const Duration(milliseconds: 160)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left sidebar
              _Sidebar(
                startTime: startTime,
                accentColor: color,
                lineColor: color,
                isPoint: false,
                sourceIndex: widget.sourceIndex,
                onInsert: _handleSidebarDoubleTap,
                isSearchHighlighted: widget.isSearchHighlighted,
                currentTimeMinute: widget.currentTimelineMinute,
                currentMarkerOffset: currentMarkerOffset,
                currentMarkerKey: ValueKey(
                  'current-time-rail-marker:${block.id}',
                ),
              ),
              const SizedBox(width: 8),
              // Block body
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Block container
                    Positioned.fill(
                      child: _wrapSwipeDelete(
                        block: block,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (widget.readOnly) return;
                            if (_dismissInlineEditorIfNeeded()) return;
                            notifier.selectBlock(block.id);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: bufferMinutes > 0 ? actionFlex : 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isSelected
                                        ? AppColors.cardBackgroundSelected
                                        : widget.isSearchHighlighted
                                        ? AppColors.accentOlive.withValues(
                                            alpha: 0.08,
                                          )
                                        : AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    boxShadow: bufferMinutes > 0
                                        ? null
                                        : (widget.isSelected
                                              ? AppShadows.cardSelected
                                              : AppShadows.card),
                                  ),
                                  foregroundDecoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    border: Border.all(
                                      color:
                                          _isPreciseImpactTarget ||
                                              isCurrentBlock
                                          ? AppColors.accentOlive.withValues(
                                              alpha: 0.70,
                                            )
                                          : (widget.isSearchHighlighted &&
                                                    !widget.isSelected
                                                ? AppColors.accentOlive
                                                      .withValues(alpha: 0.25)
                                                : Colors.transparent),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: isCompact
                                            ? const EdgeInsets.fromLTRB(
                                                12,
                                                2,
                                                10,
                                                2,
                                              )
                                            : const EdgeInsets.fromLTRB(
                                                16,
                                                20,
                                                16,
                                                8,
                                              ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment: isCompact
                                              ? MainAxisAlignment.center
                                              : MainAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 60,
                                              ),
                                              child: Stack(
                                                children: [
                                                  ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                          stops: [0.60, 1.0],
                                                          colors: [
                                                            Colors.white,
                                                            Colors.transparent,
                                                          ],
                                                        ).createShader(bounds),
                                                    blendMode: BlendMode.dstIn,
                                                    child: TextField(
                                                      controller: _titleCtrl,
                                                      focusNode:
                                                          _titleFocusNode,
                                                      readOnly: widget.readOnly,
                                                      canRequestFocus:
                                                          !widget.readOnly,
                                                      maxLines: 1,
                                                      textInputAction:
                                                          TextInputAction.done,
                                                      onChanged: widget.readOnly
                                                          ? null
                                                          : (v) => notifier
                                                                .updateBlock(
                                                                  block.id,
                                                                  (b) => b
                                                                      .copyWith(
                                                                        title:
                                                                            v,
                                                                      ),
                                                                ),
                                                      onTap: () {},
                                                      onTapOutside: (_) =>
                                                          FocusManager
                                                              .instance
                                                              .primaryFocus
                                                              ?.unfocus(),
                                                      decoration:
                                                          const InputDecoration(
                                                            border: InputBorder
                                                                .none,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                          ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                        color: AppColors.ink,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    bottom: 0,
                                                    width: 40,
                                                    child: IgnorePointer(
                                                      child: SizedBox.expand(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (actionSectionHeight >=
                                                80.0) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${formatTime(startTime)} - ${formatTime(actionEndTime)}',
                                                style: AppTextStyles.time(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.mutedInk,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: actionBodyTapHeight.toDouble(),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (widget.readOnly) return;
                                            if (_dismissInlineEditorIfNeeded()) {
                                              return;
                                            }
                                            notifier.selectBlock(block.id);
                                          },
                                          onDoubleTap: () =>
                                              _handleActionBodyDoubleTap(block),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (bufferMinutes > 0)
                                Expanded(
                                  flex: bufferMinutes,
                                  child: _BufferSegment(
                                    minutes: bufferMinutes,
                                    color: color,
                                    isSelected: widget.isSelected,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Duration pill
                    Positioned(
                      right: 56,
                      top: 0,
                      bottom: pillAndHandleBottomInset,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            bufferMinutes > 0
                                ? '計${block.effectiveDuration}分'
                                : '${block.duration}分',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Reorder handle
                    if (!widget.readOnly)
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: pillAndHandleBottomInset,
                        width: 52,
                        child: _QuickReorderListener(
                          index: widget.index,
                          onReorderIntentStart: () =>
                              widget.onReorderIntentStart?.call(block.id),
                          onReorderIntentEnd: () =>
                              widget.onReorderIntentEnd?.call(block.id),
                          child: Semantics(
                            key: ValueKey('reorder-handle:${block.id}'),
                            label: '並び替え',
                            child: SizedBox.expand(
                              child: Center(
                                child: _ReorderHandleIcon(
                                  color: AppColors.mutedInk.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Drag handle
                    if (!isOverview && !widget.readOnly)
                      Positioned(
                        top: -_DragHandle.overhang,
                        left: 0,
                        right: 0,
                        child: _DragHandle(
                          blockId: block.id,
                          initialDuration: block.duration,
                          onDrag: notifier.applyDurationDrag,
                          onPreciseChange: (id, precise) =>
                              notifier.setPreciseDragging(precise ? id : null),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoint(Block block, TimelineNotifier notifier) {
    final color =
        AppColors.blockColors[block.colorIndex % AppColors.blockColors.length];
    final startTime = widget.computedBlock.startTime;
    final currentMarkerOffset = currentTimelineMarkerOffsetForBlock(
      computedBlock: widget.computedBlock,
      currentTimelineMinute: widget.currentTimelineMinute,
      visualHeight: 52,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left sidebar
          _Sidebar(
            startTime: startTime,
            accentColor: color,
            lineColor: color,
            isPoint: true,
            sourceIndex: widget.sourceIndex,
            onInsert: _handleSidebarDoubleTap,
            isSearchHighlighted: widget.isSearchHighlighted,
            currentTimeMinute: widget.currentTimelineMinute,
            currentMarkerOffset: currentMarkerOffset,
            currentMarkerKey: ValueKey('current-time-rail-marker:${block.id}'),
          ),
          const SizedBox(width: 8),
          // Point block body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _wrapSwipeDelete(
                block: block,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.readOnly) return;
                    if (_dismissInlineEditorIfNeeded()) return;
                    notifier.selectBlock(block.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? AppColors.cardBackgroundSelected
                          : widget.isSearchHighlighted
                          ? AppColors.accentOlive.withValues(alpha: 0.08)
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: widget.isSelected
                          ? AppShadows.cardSelected
                          : AppShadows.card,
                    ),
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _isPreciseImpactTarget
                            ? AppColors.accentOlive.withValues(alpha: 0.70)
                            : (widget.isSearchHighlighted && !widget.isSelected
                                  ? AppColors.accentOlive.withValues(
                                      alpha: 0.25,
                                    )
                                  : Colors.transparent),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.78, 1.0],
                                colors: [Colors.white, Colors.transparent],
                              ).createShader(bounds),
                              blendMode: BlendMode.dstIn,
                              child: TextField(
                                controller: _titleCtrl,
                                focusNode: _titleFocusNode,
                                readOnly: widget.readOnly,
                                canRequestFocus: !widget.readOnly,
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                onChanged: widget.readOnly
                                    ? null
                                    : (v) => notifier.updateBlock(
                                        block.id,
                                        (b) => b.copyWith(title: v),
                                      ),
                                onTap: () {},
                                onTapOutside: (_) => FocusManager
                                    .instance
                                    .primaryFocus
                                    ?.unfocus(),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!widget.readOnly)
                          _QuickReorderListener(
                            index: widget.index,
                            onReorderIntentStart: () =>
                                widget.onReorderIntentStart?.call(block.id),
                            onReorderIntentEnd: () =>
                                widget.onReorderIntentEnd?.call(block.id),
                            child: Semantics(
                              key: ValueKey('reorder-handle:${block.id}'),
                              label: '並び替え',
                              child: SizedBox(
                                width: 52,
                                child: Center(
                                  child: _ReorderHandleIcon(
                                    color: AppColors.mutedInk.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BufferSegment extends StatelessWidget {
  const _BufferSegment({
    required this.minutes,
    required this.color,
    required this.isSelected,
  });

  final int minutes;
  final Color color;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 36;
        final isTight = constraints.maxHeight < 28;
        final outerPadding = isCompact
            ? const EdgeInsets.fromLTRB(16, 0, 16, 0)
            : const EdgeInsets.fromLTRB(16, 0, 16, 0);
        final contentPadding = isTight
            ? const EdgeInsets.symmetric(horizontal: 8)
            : isCompact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

        return Padding(
          padding: outerPadding,
          child: Container(
            padding: contentPadding,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.zero,
                topRight: Radius.zero,
                bottomLeft: Radius.circular(AppRadius.md),
                bottomRight: Radius.circular(AppRadius.md),
              ),
              boxShadow: isSelected ? AppShadows.cardSelected : AppShadows.card,
            ),
            child: isTight
                ? Center(child: _BufferSegmentLabel(minutes: minutes))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DottedDivider(
                        color: AppColors.timelineLine.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 4),
                      Center(child: _BufferSegmentLabel(minutes: minutes)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _BufferSegmentLabel extends StatelessWidget {
  const _BufferSegmentLabel({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '余裕 +$minutes分',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedInk.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// 擬似点線 — 本体ブロックとバッファセグメントの境目を「くっついている感じ」で示す
class _DottedDivider extends StatelessWidget {
  const _DottedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotWidth = 3.0;
        const gapWidth = 3.0;
        final count = (constraints.maxWidth / (dotWidth + gapWidth))
            .floor()
            .clamp(1, 200);
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Container(width: dotWidth, height: 1, color: color),
              if (i < count - 1) const SizedBox(width: gapWidth),
            ],
          ],
        );
      },
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground({required this.isPoint});

  final bool isPoint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Semantics(
            label: isPoint ? '行動ピンを削除' : '行動ブロックを削除',
            child: Icon(
              Icons.delete_outline,
              size: 22,
              color: AppColors.ink.withValues(alpha: 0.58),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.startTime,
    this.accentColor,
    this.lineColor,
    this.isPoint = false,
    this.sourceIndex,
    this.onInsert,
    this.isSearchHighlighted = false,
    this.currentTimeMinute,
    this.currentMarkerOffset,
    this.currentMarkerKey,
  });

  final int startTime;
  final Color? accentColor;
  final Color? lineColor;
  final bool isPoint;
  final int? sourceIndex;
  final void Function(int insertIndex)? onInsert;
  final bool isSearchHighlighted;
  final int? currentTimeMinute;
  final double? currentMarkerOffset;
  final Key? currentMarkerKey;

  @override
  Widget build(BuildContext context) {
    final effectiveLineColor = lineColor ?? AppColors.timelineLine;
    final showCurrentMarker =
        currentTimeMinute != null && currentMarkerOffset != null;
    final baseSidebar = SizedBox(
      width: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Vertical timeline line — tinted to block color, faded at ends
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      effectiveLineColor.withValues(alpha: 0.0),
                      effectiveLineColor,
                      effectiveLineColor,
                      effectiveLineColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.12, 0.88, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Action block: small rounded-rect at the start of the interval
          if (!isPoint && accentColor != null)
            Positioned(
              right: -2,
              top: 0,
              child: Container(
                width: isSearchHighlighted ? 8 : 6,
                height: isSearchHighlighted ? 8 : 6,
                decoration: BoxDecoration(
                  color: isSearchHighlighted
                      ? AppColors.accentOlive
                      : AppColors.mutedInk,
                  borderRadius: BorderRadius.all(
                    Radius.circular(isSearchHighlighted ? 3 : 2),
                  ),
                ),
              ),
            ),
          // Point block: larger centered dot
          if (isPoint && accentColor != null)
            Positioned(
              right: -3,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: isSearchHighlighted ? 12 : 8,
                  height: isSearchHighlighted ? 12 : 8,
                  decoration: BoxDecoration(
                    color: isSearchHighlighted
                        ? AppColors.accentOlive
                        : AppColors.mutedInk,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          // Time label
          Positioned(
            top: isPoint ? 0 : -10,
            right: 8,
            bottom: isPoint ? 0 : null,
            child: Align(
              alignment: isPoint ? Alignment.centerRight : Alignment.topRight,
              child: Container(
                color: AppColors.canvas,
                padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
                child: Text(
                  formatTime(startTime),
                  style: AppTextStyles.time(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedInk,
                  ),
                ),
              ),
            ),
          ),
          if (showCurrentMarker)
            Positioned(
              key: currentMarkerKey,
              top: (currentMarkerOffset! - 16).clamp(-12.0, double.infinity),
              right: -8,
              child: _RailCurrentTimeMarker(minutes: currentTimeMinute!),
            ),
        ],
      ),
    );

    if (onInsert != null && sourceIndex != null) {
      return Builder(
        builder: (context) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              final height = renderBox?.size.height ?? 0;
              final dy = details.localPosition.dy;
              final isUpperHalf = dy < height / 2;
              final insertIndex = isUpperHalf ? sourceIndex! : sourceIndex! + 1;
              onInsert!(insertIndex);
            },
            child: baseSidebar,
          );
        },
      );
    }

    return baseSidebar;
  }
}

// ---------------------------------------------------------------------------
// Reorder Handle Icon (visual affordance only)
// ---------------------------------------------------------------------------

class _ReorderHandleIcon extends StatelessWidget {
  const _ReorderHandleIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final dotColor = Color.lerp(
      color,
      AppColors.ink,
      0.60,
    )!.withValues(alpha: 0.80);

    return SizedBox(
      width: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 3),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RailCurrentTimeMarker extends StatelessWidget {
  const _RailCurrentTimeMarker({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 15,
            top: 0,
            child: Container(
              color: AppColors.canvas,
              padding: const EdgeInsets.only(left: 2, right: 3),
              child: SizedBox(
                width: 38,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'now',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentOlive,
                      ),
                    ),
                    Text(
                      formatTime(minutes),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.visible,
                      style: AppTextStyles.time(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOlive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 5,
            top: 19,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.accentOlive,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 22,
            child: Container(
              width: 6,
              height: 1.5,
              decoration: BoxDecoration(
                color: AppColors.accentOlive.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Drag Handle
// ---------------------------------------------------------------------------

class _DragHandle extends StatefulWidget {
  static const double hitHeight = 44.0;
  static const double overhang = 16.0;

  const _DragHandle({
    required this.blockId,
    required this.initialDuration,
    required this.onDrag,
    required this.onPreciseChange,
  });

  final String blockId;
  final int initialDuration;
  final void Function(
    String id,
    double deltaY,
    int startDuration,
    bool isPrecise,
  )
  onDrag;
  final void Function(String id, bool isPrecise) onPreciseChange;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  bool _isPrecise = false;
  int? _activePointer;
  double _startY = 0;
  int _startDuration = 0;
  bool _hasMoved = false;
  Timer? _longPressTimer;

  void _beginInteraction(Offset globalPosition, int pointer) {
    if (_activePointer != null) return;
    _activePointer = pointer;
    _startY = globalPosition.dy;
    _startDuration = widget.initialDuration;
    _hasMoved = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_hasMoved) {
        setState(() => _isPrecise = true);
        widget.onPreciseChange(widget.blockId, true);
        HapticFeedback.selectionClick();
      }
    });
  }

  void _updateMovement(Offset globalPosition) {
    final delta = globalPosition.dy - _startY;
    if (delta.abs() > 5) _hasMoved = true;
  }

  void _endInteraction() {
    _activePointer = null;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isPrecise) {
      widget.onPreciseChange(widget.blockId, false);
    }
    if (mounted && _isPrecise) {
      setState(() => _isPrecise = false);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _beginInteraction(event.position, event.pointer);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    _updateMovement(event.position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _endInteraction();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _endInteraction();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition.dy - _startY;
    _updateMovement(details.globalPosition);
    widget.onDrag(widget.blockId, delta, _startDuration, _isPrecise);
  }

  void _onDragEnd(DragEndDetails details) {
    _endInteraction();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DragHandle.hitHeight,
      child: Stack(
        children: [
          // ビジュアル — フル幅中央に固定
          Center(
            child: Container(
              width: _isPrecise ? 80.0 : 64.0,
              height: _isPrecise ? 8.0 : 6.0,
              decoration: BoxDecoration(
                color: _isPrecise
                    ? AppColors.mutedInk.withValues(alpha: 0.70)
                    : AppColors.mutedInk.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          // ヒット領域 — 右56px(ピル+移動ハンドル帯)を除外
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: 56,
            child: Semantics(
              label: '所要時間を調整',
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  onVerticalDragCancel: _endInteraction,
                  child: const SizedBox.expand(),
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
// Quick Reorder Listener (200ms delay)
// ---------------------------------------------------------------------------

class _QuickReorderListener extends StatefulWidget {
  const _QuickReorderListener({
    required this.index,
    required this.child,
    this.onReorderIntentStart,
    this.onReorderIntentEnd,
  });

  final int index;
  final Widget child;
  final VoidCallback? onReorderIntentStart;
  final VoidCallback? onReorderIntentEnd;

  @override
  State<_QuickReorderListener> createState() => _QuickReorderListenerState();
}

class _QuickReorderListenerState extends State<_QuickReorderListener> {
  int? _activePointer;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent event) =>
          _handlePointerDown(context, event),
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }

  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 200),
      debugOwner: this,
    );
  }

  void _handlePointerDown(BuildContext context, PointerDownEvent event) {
    _activePointer = event.pointer;
    widget.onReorderIntentStart?.call();

    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final list = SliverReorderableList.maybeOf(context);
    if (list == null) return;
    list.startItemDragReorder(
      index: widget.index,
      event: event,
      recognizer: createRecognizer()..gestureSettings = gestureSettings,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.onReorderIntentEnd?.call();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
  }
}
