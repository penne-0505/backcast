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
    this.sheetVisible = false,
  });

  final ComputedBlock computedBlock;
  final bool isSelected;
  final bool isSearchHighlighted;
  final String? preciseDraggingId;
  final List<Block> allBlocks;
  final int index;
  final int sourceIndex;
  final bool sheetVisible;

  @override
  ConsumerState<BlockItem> createState() => _BlockItemState();
}

class _BlockItemState extends ConsumerState<BlockItem> {
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocusNode;
  Offset? _swipeStart;
  Offset _swipeDelta = Offset.zero;

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
    if (widget.sheetVisible) return;
    if (_dismissInlineEditorIfNeeded()) return;
    if (widget.preciseDraggingId != null) return;
    HapticFeedback.selectionClick();
    ref.read(timelineProvider.notifier).addBlock(insertIndex, BlockType.action);
  }

  Future<bool> _confirmSwipeDelete() async {
    if (widget.sheetVisible) return false;
    if (_dismissInlineEditorIfNeeded()) return false;
    if (widget.preciseDraggingId != null) return false;
    HapticFeedback.selectionClick();
    return true;
  }

  void _deleteBlockBySwipe(DismissDirection direction) {
    ref
        .read(timelineProvider.notifier)
        .deleteBlock(widget.computedBlock.block.id);
  }

  Widget _wrapSwipeDelete({required Block block, required Widget child}) {
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
    ref
        .read(timelineProvider.notifier)
        .deleteBlock(widget.computedBlock.block.id);
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
    final ppm = ref.watch(timelineProvider.select((s) => s.pixelsPerMinute));
    final isOverview = ppm < kOverviewThresholdPpm;
    final naturalHeight = block.duration * ppm;
    final height = isOverview
        ? naturalHeight.clamp(kMinOverviewBlockHeight, double.infinity)
        : naturalHeight;
    final isCompact = height < 56.0;
    final color =
        AppColors.blockColors[block.colorIndex % AppColors.blockColors.length];
    final startTime = widget.computedBlock.startTime;

    return SizedBox(
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
                          onTap: () {
                            if (_dismissInlineEditorIfNeeded()) return;
                            notifier.selectBlock(block.id);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.isSelected
                                  ? AppColors.cardBackgroundSelected
                                  : widget.isSearchHighlighted
                                  ? AppColors.accentOlive.withValues(
                                      alpha: 0.08,
                                    )
                                  : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: widget.isSelected
                                  ? AppShadows.cardSelected
                                  : AppShadows.card,
                              border: _isPreciseImpactTarget
                                  ? Border.all(
                                      color: AppColors.accentOlive.withValues(
                                        alpha: 0.70,
                                      ),
                                      width: 1.5,
                                    )
                                  : (widget.isSearchHighlighted &&
                                            !widget.isSelected
                                        ? Border.all(
                                            color: AppColors.accentOlive
                                                .withValues(alpha: 0.25),
                                            width: 1.5,
                                          )
                                        : null),
                            ),
                            child: Padding(
                              padding: isCompact
                                  ? const EdgeInsets.fromLTRB(12, 2, 10, 2)
                                  : const EdgeInsets.fromLTRB(16, 20, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: isCompact
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 60),
                                    child: Stack(
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                stops: [0.60, 1.0],
                                                colors: [
                                                  Colors.white,
                                                  Colors.transparent,
                                                ],
                                              ).createShader(bounds),
                                          blendMode: BlendMode.dstIn,
                                          child: TextField(
                                            controller: _titleCtrl,
                                            focusNode: _titleFocusNode,
                                            maxLines: 1,
                                            textInputAction:
                                                TextInputAction.done,
                                            onChanged: (v) =>
                                                notifier.updateBlock(
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
                                  if (height >= 80.0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatTime(startTime)} - ${formatTime(startTime + block.duration)}',
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
                          ),
                        ),
                      ),
                    ),
                    // Duration pill
                    Positioned(
                      right: 56,
                      top: 0,
                      bottom: 0,
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
                            '${block.duration}分',
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
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: 52,
                      child: _QuickReorderListener(
                        index: widget.index,
                        child: Semantics(
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
                    if (!isOverview)
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
          ),
          const SizedBox(width: 8),
          // Point block body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _wrapSwipeDelete(
                block: block,
                child: GestureDetector(
                  onTap: () {
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
                      border: _isPreciseImpactTarget
                          ? Border.all(
                              color: AppColors.accentOlive.withValues(
                                alpha: 0.70,
                              ),
                              width: 1.5,
                            )
                          : (widget.isSearchHighlighted && !widget.isSelected
                                ? Border.all(
                                    color: AppColors.accentOlive.withValues(
                                      alpha: 0.25,
                                    ),
                                    width: 1.5,
                                  )
                                : null),
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
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                onChanged: (v) => notifier.updateBlock(
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
                        _QuickReorderListener(
                          index: widget.index,
                          child: Semantics(
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
  });

  final int startTime;
  final Color? accentColor;
  final Color? lineColor;
  final bool isPoint;
  final int? sourceIndex;
  final void Function(int insertIndex)? onInsert;
  final bool isSearchHighlighted;

  @override
  Widget build(BuildContext context) {
    final effectiveLineColor = lineColor ?? AppColors.timelineLine;
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

class _QuickReorderListener extends StatelessWidget {
  const _QuickReorderListener({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent event) => _startDragging(context, event),
      child: child,
    );
  }

  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 200),
      debugOwner: this,
    );
  }

  void _startDragging(BuildContext context, PointerDownEvent event) {
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final list = SliverReorderableList.maybeOf(context);
    if (list == null) return;
    list.startItemDragReorder(
      index: index,
      event: event,
      recognizer: createRecognizer()..gestureSettings = gestureSettings,
    );
  }
}
