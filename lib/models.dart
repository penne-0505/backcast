import 'package:flutter/foundation.dart';

const double kPixelsPerMinute = 6.0;
const int kSnapMinutes = 5;

/// 目標アンカーを識別する固定 ID（selectedBlockId に使用）
const String kTargetTimeId = 'target-time';

/// 行動ブロック（duration 型）か 行動ポイント（point 型）かを表す
enum BlockType { action, actionPoint }

/// moveBlock の方向を意味で表す
enum BlockMoveDirection { toPast, toFuture }

@immutable
class Block {
  const Block({
    required this.id,
    required this.type,
    required this.title,
    required this.duration,
    required this.colorIndex,
  });

  final String id;
  final BlockType type;
  final String title;
  final int duration; // minutes; 0 for actionPoint
  final int colorIndex;

  Block copyWith({
    String? id,
    BlockType? type,
    String? title,
    int? duration,
    int? colorIndex,
  }) {
    return Block(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Block &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          duration == other.duration &&
          colorIndex == other.colorIndex;

  @override
  int get hashCode =>
      Object.hash(id, type, title, duration, colorIndex);
}

@immutable
class ComputedBlock {
  const ComputedBlock({
    required this.block,
    required this.startTime,
    required this.endTime,
  });

  final Block block;
  final int startTime; // minutes since midnight
  final int endTime;
}

/// Compute start/end times for each block based on targetTime.
/// blocks[0] = earliest (past), blocks[last] = latest (just before target).
List<ComputedBlock> computeBlocks(List<Block> blocks, int targetTime) {
  var currentEndTime = targetTime;
  final result = <ComputedBlock>[];
  for (var i = blocks.length - 1; i >= 0; i--) {
    final block = blocks[i];
    final startTime = currentEndTime - block.duration;
    result.insert(0, ComputedBlock(
      block: block,
      startTime: startTime,
      endTime: currentEndTime,
    ));
    currentEndTime = startTime;
  }
  return result;
}

String formatTime(int minutes) {
  var m = minutes % (24 * 60);
  if (m < 0) m += 24 * 60;
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}
