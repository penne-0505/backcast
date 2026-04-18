import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

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
    final parts = value.split(':');
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
        onSubmitted: _commit,
        onEditingComplete: () => _commit(_ctrl.text),
        onTapOutside: (_) => _commit(_ctrl.text),
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
    required this.preciseDraggingId,
    required this.allBlocks,
  });

  final ComputedBlock computedBlock;
  final bool isSelected;
  final String? preciseDraggingId;
  final List<Block> allBlocks;

  @override
  ConsumerState<BlockItem> createState() => _BlockItemState();
}

class _BlockItemState extends ConsumerState<BlockItem> {
  late final TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.computedBlock.block.title);
  }

  @override
  void didUpdateWidget(BlockItem old) {
    super.didUpdateWidget(old);
    // Sync title from external changes (e.g., edit sheet)
    final newTitle = widget.computedBlock.block.title;
    if (newTitle != old.computedBlock.block.title &&
        _titleCtrl.text != newTitle) {
      _titleCtrl.value = _titleCtrl.value.copyWith(text: newTitle);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _isAffected {
    if (widget.preciseDraggingId == null) return false;
    final myIndex = widget.allBlocks
        .indexWhere((b) => b.id == widget.computedBlock.block.id);
    final dragIndex =
        widget.allBlocks.indexWhere((b) => b.id == widget.preciseDraggingId);
    return myIndex != -1 && dragIndex != -1 && myIndex <= dragIndex;
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
    final height = block.duration * kPixelsPerMinute;
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
                colorDot: null,
              ),
              const SizedBox(width: 8),
              // Block body
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Block container
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => notifier.selectBlock(block.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? AppColors.blue50
                                : Colors.white,
                            border: Border.all(
                              color: (widget.isSelected || _isAffected)
                                  ? AppColors.blue400
                                  : AppColors.stone200,
                              width: widget.isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [],
                          ),
                          child: Padding(
                            padding: isCompact
                                ? const EdgeInsets.fromLTRB(10, 2, 10, 2)
                                : const EdgeInsets.fromLTRB(10, 20, 10, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _titleCtrl,

                                  onChanged: (v) => notifier.updateBlock(
                                    block.id,
                                    (b) => b.copyWith(title: v),
                                  ),
                                  onTap: () {},
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.stone800,
                                  ),
                                ),
                                if (height >= 40.0) ...[
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 3,
                                    width: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                                if (height >= 80.0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${block.duration}分',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.stone400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Reorder handle icon (visual only, tap/drag handled by LongPressDraggable)
                    Positioned(
                      top: 0,
                      right: 14,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _ReorderHandleIcon(),
                        ),
                      ),
                    ),
                    // Drag handle (extends 16px above the block)
                    Positioned(
                      top: -16,
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
          // Left sidebar with colored dot
          _Sidebar(
            startTime: startTime,
            colorDot: color,
          ),
          const SizedBox(width: 8),
          // Point block body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () => notifier.selectBlock(block.id),
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                  color: widget.isSelected ? AppColors.blue50 : Colors.white,
                  border: Border.all(
                    color: (widget.isSelected || _isAffected)
                        ? AppColors.blue400
                        : AppColors.stone200,
                    width: widget.isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        onChanged: (v) => notifier.updateBlock(
                          block.id,
                          (b) => b.copyWith(title: v),
                        ),
                        onTap: () {},
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.stone800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _ReorderHandleIcon(),
                  ],
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

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.startTime,
    required this.colorDot,
  });

  final int startTime;
  final Color? colorDot; // non-null for point blocks

  @override
  Widget build(BuildContext context) {
    final isPoint = colorDot != null;
    return SizedBox(
      width: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Vertical border line
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 2, color: AppColors.stone200),
            ),
          ),
          // Colored dot for point blocks
          if (isPoint)
            Positioned(
              right: -3,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorDot,
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
                color: AppColors.appBackground,
                padding:
                    const EdgeInsets.only(left: 2, top: 2, bottom: 2),
                child: Text(
                  formatTime(startTime),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stone500,
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

// ---------------------------------------------------------------------------
// Reorder Handle Icon (visual affordance only)
// ---------------------------------------------------------------------------

class _ReorderHandleIcon extends StatelessWidget {
  const _ReorderHandleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Container(
              height: 2,
              width: 16,
              decoration: BoxDecoration(
                color: AppColors.stone200,
                borderRadius: BorderRadius.circular(1),
              ),
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
  const _DragHandle({
    required this.blockId,
    required this.initialDuration,
    required this.onDrag,
    required this.onPreciseChange,
  });

  final String blockId;
  final int initialDuration;
  final void Function(
      String id, double deltaY, int startDuration, bool isPrecise) onDrag;
  final void Function(String id, bool isPrecise) onPreciseChange;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  bool _isPrecise = false;
  double _startY = 0;
  int _startDuration = 0;
  bool _hasMoved = false;
  Timer? _longPressTimer;

  void _onDragStart(DragStartDetails details) {
    _startY = details.globalPosition.dy;
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

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.globalPosition.dy - _startY;
    if (delta.abs() > 5) _hasMoved = true;
    widget.onDrag(widget.blockId, delta, _startDuration, _isPrecise);
  }

  void _onDragEnd(DragEndDetails details) {
    _longPressTimer?.cancel();
    if (_isPrecise) {
      widget.onPreciseChange(widget.blockId, false);
    }
    setState(() => _isPrecise = false);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: SizedBox(
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isPrecise ? 64.0 : 48.0,
            height: _isPrecise ? 8.0 : 6.0,
            decoration: BoxDecoration(
              color: _isPrecise ? AppColors.blue500 : AppColors.stone200,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}
