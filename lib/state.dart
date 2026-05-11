import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'theme.dart';

const _uuid = Uuid();

enum TimelineViewMode { edit, compact }

@immutable
class TimelineState {
  const TimelineState({
    this.targetTime = 13 * 60,
    this.targetTimeTitle = '目標時刻',
    this.blocks = const [],
    this.selectedBlockId,
    this.preciseDraggingId,
    this.activeInlineEditorId,
    this.pixelsPerMinute = kPixelsPerMinute,
    this.viewMode = TimelineViewMode.edit,
    this.searchQuery = '',
    this.searchMatches = const [],
    this.activeSearchMatchIndex = -1,
    this.searchHighlightedBlockId,
    this.searchHighlightExpiresAt,
  });

  final int targetTime; // minutes since midnight
  final String targetTimeTitle;
  final List<Block> blocks;
  final String? selectedBlockId; // null | 'target-time' | block.id
  final String? preciseDraggingId;
  final String? activeInlineEditorId;
  final double pixelsPerMinute;
  final TimelineViewMode viewMode;

  // Search UI state — not persisted
  final String searchQuery;
  final List<String>
  searchMatches; // block ids in timeline order (past → target)
  final int activeSearchMatchIndex; // -1 when no match
  final String? searchHighlightedBlockId;
  final DateTime? searchHighlightExpiresAt;

  TimelineState copyWith({
    int? targetTime,
    String? targetTimeTitle,
    List<Block>? blocks,
    Object? selectedBlockId = _sentinel,
    Object? preciseDraggingId = _sentinel,
    Object? activeInlineEditorId = _sentinel,
    double? pixelsPerMinute,
    TimelineViewMode? viewMode,
    String? searchQuery,
    List<String>? searchMatches,
    int? activeSearchMatchIndex,
    Object? searchHighlightedBlockId = _sentinel,
    Object? searchHighlightExpiresAt = _sentinel,
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
      activeInlineEditorId: activeInlineEditorId == _sentinel
          ? this.activeInlineEditorId
          : activeInlineEditorId as String?,
      pixelsPerMinute: pixelsPerMinute ?? this.pixelsPerMinute,
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMatches: searchMatches ?? this.searchMatches,
      activeSearchMatchIndex:
          activeSearchMatchIndex ?? this.activeSearchMatchIndex,
      searchHighlightedBlockId: searchHighlightedBlockId == _sentinel
          ? this.searchHighlightedBlockId
          : searchHighlightedBlockId as String?,
      searchHighlightExpiresAt: searchHighlightExpiresAt == _sentinel
          ? this.searchHighlightExpiresAt
          : searchHighlightExpiresAt as DateTime?,
    );
  }
}

const _sentinel = Object();

class TimelineNotifier extends Notifier<TimelineState> {
  @override
  TimelineState build() {
    return const TimelineState();
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
    while ((newColorIndex == prevColor || newColorIndex == nextColor) &&
        tries < 20) {
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

  void incrementActionBuffer(String id) {
    final current = _blockById(id)?.normalizedBufferMinutes ?? 0;
    setActionBufferMinutes(id, current + kBufferStepMinutes);
  }

  void setActionBufferMinutes(String id, int minutes) {
    updateBlock(id, (block) {
      if (block.type != BlockType.action) return block;
      final normalized = normalizeActionBufferMinutesForDuration(
        block.type,
        block.duration,
        minutes,
      );
      return block.copyWith(bufferMinutes: normalized);
    });
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

  void setActiveInlineEditor(String? id) {
    state = state.copyWith(activeInlineEditorId: id);
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

  void loadState(TimelineState loaded) {
    state = loaded;
  }

  /// Applies a template [TimelineState] to the current timeline, clearing
  /// all transient UI state (selection, inline editor, precise dragging).
  void applyTemplateState(TimelineState loaded) {
    state = loaded.copyWith(
      selectedBlockId: null,
      preciseDraggingId: null,
      activeInlineEditorId: null,
    );
  }

  void setPreciseDragging(String? id) {
    state = state.copyWith(preciseDraggingId: id);
  }

  void setPixelsPerMinute(double value) {
    state = state.copyWith(
      pixelsPerMinute: value.clamp(kOverviewPixelsPerMinute, kPixelsPerMinute),
    );
  }

  void setViewMode(TimelineViewMode mode) {
    state = state.copyWith(
      viewMode: mode,
      pixelsPerMinute: mode == TimelineViewMode.compact
          ? kOverviewPixelsPerMinute
          : kPixelsPerMinute,
      selectedBlockId: null,
      preciseDraggingId: null,
      activeInlineEditorId: null,
    );
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchMatches: const [],
        activeSearchMatchIndex: -1,
        searchHighlightedBlockId: null,
        searchHighlightExpiresAt: null,
      );
      return;
    }

    final lowerQuery = trimmed.toLowerCase();
    final matches = state.blocks
        .where((b) => b.title.toLowerCase().contains(lowerQuery))
        .map((b) => b.id)
        .toList();

    final newIndex = matches.isEmpty ? -1 : 0;
    state = state.copyWith(
      searchQuery: trimmed,
      searchMatches: matches,
      activeSearchMatchIndex: newIndex,
    );
  }

  void clearSearch() {
    state = state.copyWith(
      searchQuery: '',
      searchMatches: const [],
      activeSearchMatchIndex: -1,
      searchHighlightedBlockId: null,
      searchHighlightExpiresAt: null,
    );
  }

  void _moveSearchMatch(int delta) {
    if (state.searchMatches.isEmpty) return;
    var next = state.activeSearchMatchIndex + delta;
    if (next < 0) next = state.searchMatches.length - 1;
    if (next >= state.searchMatches.length) next = 0;
    state = state.copyWith(activeSearchMatchIndex: next);
  }

  void nextSearchMatch() => _moveSearchMatch(1);
  void prevSearchMatch() => _moveSearchMatch(-1);

  void highlightSearchBlock(String? blockId) {
    state = state.copyWith(
      searchHighlightedBlockId: blockId,
      searchHighlightExpiresAt: blockId == null
          ? null
          : DateTime.now().add(const Duration(seconds: 3)),
    );
  }

  void expireSearchHighlightIfNeeded() {
    final expires = state.searchHighlightExpiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) {
      state = state.copyWith(
        searchHighlightedBlockId: null,
        searchHighlightExpiresAt: null,
      );
    }
  }

  void applyDurationDrag(
    String id,
    double deltaY,
    int startDuration,
    bool isPrecise,
  ) {
    final snap = isPrecise ? 1 : kSnapMinutes;
    final deltaDuration =
        ((-deltaY / state.pixelsPerMinute) / snap).round() * snap;
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
      var newDuration =
          cb.endTime - newStartTimeMinutes - block.normalizedBufferMinutes;
      while (newDuration < 0) {
        newDuration += 24 * 60;
      }
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
        var newDuration =
            nextCb.endTime -
            newStartTimeMinutes -
            nextBlock.normalizedBufferMinutes;
        while (newDuration < 0) {
          newDuration += 24 * 60;
        }
        if (newDuration < 5) newDuration = 5;
        updateBlock(nextBlock.id, (b) => b.copyWith(duration: newDuration));
      }
    }
  }

  Block? _blockById(String id) {
    return state.blocks.where((block) => block.id == id).firstOrNull;
  }
}

final timelineProvider = NotifierProvider<TimelineNotifier, TimelineState>(
  TimelineNotifier.new,
);

final computedBlocksProvider = Provider<List<ComputedBlock>>((ref) {
  final s = ref.watch(timelineProvider);
  return computeBlocks(s.blocks, s.targetTime);
});
