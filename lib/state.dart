import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'theme.dart';

const _uuid = Uuid();

@immutable
class TimelineState {
  const TimelineState({
    this.targetTime = 13 * 60,
    this.targetTimeTitle = '目標時刻',
    this.blocks = const [],
    this.selectedBlockId,
    this.preciseDraggingId,
  });

  final int targetTime; // minutes since midnight
  final String targetTimeTitle;
  final List<Block> blocks;
  final String? selectedBlockId; // null | 'target-time' | block.id
  final String? preciseDraggingId;

  TimelineState copyWith({
    int? targetTime,
    String? targetTimeTitle,
    List<Block>? blocks,
    Object? selectedBlockId = _sentinel,
    Object? preciseDraggingId = _sentinel,
  }) {
    return TimelineState(
      targetTime: targetTime ?? this.targetTime,
      targetTimeTitle: targetTimeTitle ?? this.targetTimeTitle,
      blocks: blocks ?? this.blocks,
      selectedBlockId: selectedBlockId == _sentinel
          ? this.selectedBlockId
          : selectedBlockId as String?,
      preciseDraggingId: preciseDraggingId == _sentinel
          ? this.preciseDraggingId
          : preciseDraggingId as String?,
    );
  }
}

const _sentinel = Object();

class TimelineNotifier extends Notifier<TimelineState> {
  @override
  TimelineState build() {
    return TimelineState(
      blocks: [
        Block(
          id: _uuid.v4(),
          type: BlockType.action,
          title: '移動',
          duration: 30,
          colorIndex: 0,
        ),
      ],
    );
  }

  void setTargetTime(int minutes) {
    state = state.copyWith(targetTime: minutes);
  }

  void setTargetTimeTitle(String title) {
    state = state.copyWith(targetTimeTitle: title);
  }

  void addBlock(int index, BlockType type) {
    final blocks = state.blocks;
    final prevColor = index > 0 ? blocks[index - 1].colorIndex : -1;
    final nextColor = index < blocks.length ? blocks[index].colorIndex : -1;
    final rng = Random();
    var newColorIndex = rng.nextInt(AppColors.blockColors.length);
    var tries = 0;
    while ((newColorIndex == prevColor || newColorIndex == nextColor) && tries < 20) {
      newColorIndex = rng.nextInt(AppColors.blockColors.length);
      tries++;
    }

    final newBlock = Block(
      id: _uuid.v4(),
      type: type,
      title: type == BlockType.action ? '新しい行動' : '新しい行動ポイント',
      duration: type == BlockType.action ? 15 : 0,
      colorIndex: newColorIndex,
    );

    final newBlocks = List<Block>.from(blocks)..insert(index, newBlock);
    state = state.copyWith(blocks: newBlocks);
  }

  void updateBlock(String id, Block Function(Block) updater) {
    state = state.copyWith(
      blocks: state.blocks.map((b) => b.id == id ? updater(b) : b).toList(),
    );
  }

  void deleteBlock(String id) {
    state = state.copyWith(
      blocks: state.blocks.where((b) => b.id != id).toList(),
      selectedBlockId: null,
    );
  }

  void moveBlock(String id, BlockMoveDirection direction) {
    final blocks = List<Block>.from(state.blocks);
    final index = blocks.indexWhere((b) => b.id == id);
    if (index < 0) return;
    final delta = direction == BlockMoveDirection.toPast ? -1 : 1;
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= blocks.length) return;
    final block = blocks.removeAt(index);
    blocks.insert(newIndex, block);
    state = state.copyWith(blocks: blocks);
  }

  void selectBlock(String? id) {
    state = state.copyWith(selectedBlockId: id);
  }


  void moveBlockByIndex(int fromIndex, int toIndex) {
    final blocks = List<Block>.from(state.blocks);
    if (fromIndex < 0 || fromIndex >= blocks.length) return;
    final block = blocks.removeAt(fromIndex);
    blocks.insert(toIndex.clamp(0, blocks.length), block);
    state = state.copyWith(blocks: blocks);
  }

  void reorderBlock(String id, int insertBefore) {
    final blocks = List<Block>.from(state.blocks);
    final fromIndex = blocks.indexWhere((b) => b.id == id);
    if (fromIndex < 0) return;
    final block = blocks.removeAt(fromIndex);
    var toIndex = fromIndex < insertBefore ? insertBefore - 1 : insertBefore;
    blocks.insert(toIndex.clamp(0, blocks.length), block);
    state = state.copyWith(blocks: blocks);
  }

  void setPreciseDragging(String? id) {
    state = state.copyWith(preciseDraggingId: id);
  }

  void applyDurationDrag(String id, double deltaY, int startDuration, bool isPrecise) {
    final snap = isPrecise ? 1 : kSnapMinutes;
    final deltaDuration = ((-deltaY / kPixelsPerMinute) / snap).round() * snap;
    var newDuration = startDuration + deltaDuration;
    if (newDuration < 5) newDuration = 5;
    updateBlock(id, (b) => b.copyWith(duration: newDuration));
  }

  /// 時刻フィールドへの入力を受け、該当ブロックまたは次ブロックの duration を調整する。
  void applyStartTimeEdit(String id, int newStartTimeMinutes) {
    final blocks = state.blocks;
    final computed = computeBlocks(blocks, state.targetTime);
    final index = blocks.indexWhere((b) => b.id == id);
    if (index < 0) return;
    final block = blocks[index];
    final cb = computed[index];

    if (block.type == BlockType.action) {
      var newDuration = cb.endTime - newStartTimeMinutes;
      while (newDuration < 0) { newDuration += 24 * 60; }
      if (newDuration < 5) newDuration = 5;
      updateBlock(id, (b) => b.copyWith(duration: newDuration));
    } else {
      // For point blocks: if it's the last, move target time;
      // otherwise adjust the next block's duration.
      if (index == blocks.length - 1) {
        setTargetTime(newStartTimeMinutes);
      } else {
        final nextBlock = blocks[index + 1];
        final nextCb = computed[index + 1];
        var newDuration = nextCb.endTime - newStartTimeMinutes;
        while (newDuration < 0) { newDuration += 24 * 60; }
        if (newDuration < 5) newDuration = 5;
        updateBlock(nextBlock.id, (b) => b.copyWith(duration: newDuration));
      }
    }
  }
}

final timelineProvider =
    NotifierProvider<TimelineNotifier, TimelineState>(TimelineNotifier.new);

final computedBlocksProvider = Provider<List<ComputedBlock>>((ref) {
  final s = ref.watch(timelineProvider);
  return computeBlocks(s.blocks, s.targetTime);
});
