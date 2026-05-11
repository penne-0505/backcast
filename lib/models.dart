import 'package:flutter/foundation.dart';

const double kPixelsPerMinute = 5.5;
const double kOverviewPixelsPerMinute = 3.0;
const int kSnapMinutes = 5;
const int kBufferStepMinutes = 5;
const int kMaxActionBufferMinutes = 60;
const double kOverviewThresholdPpm = 5.0;
const double kMinOverviewBlockHeight = 40.0;
const double kMinBufferedOverviewBlockHeight = 52.0;

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
    this.bufferMinutes = 0,
    required this.colorIndex,
  });

  final String id;
  final BlockType type;
  final String title;
  final int duration; // minutes; 0 for actionPoint
  final int bufferMinutes; // minutes; action only
  final int colorIndex;

  int get normalizedBufferMinutes =>
      normalizeActionBufferMinutesForDuration(type, duration, bufferMinutes);

  int get effectiveDuration =>
      type == BlockType.action ? duration + normalizedBufferMinutes : 0;

  Block copyWith({
    String? id,
    BlockType? type,
    String? title,
    int? duration,
    int? bufferMinutes,
    int? colorIndex,
  }) {
    final nextType = type ?? this.type;
    final nextDuration = duration ?? this.duration;
    return Block(
      id: id ?? this.id,
      type: nextType,
      title: title ?? this.title,
      duration: nextDuration,
      bufferMinutes: normalizeActionBufferMinutes(
        nextType,
        bufferMinutes ?? this.bufferMinutes,
      ),
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
          bufferMinutes == other.bufferMinutes &&
          colorIndex == other.colorIndex;

  @override
  int get hashCode =>
      Object.hash(id, type, title, duration, bufferMinutes, colorIndex);
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
    final startTime = currentEndTime - block.effectiveDuration;
    result.insert(
      0,
      ComputedBlock(
        block: block,
        startTime: startTime,
        endTime: currentEndTime,
      ),
    );
    currentEndTime = startTime;
  }
  return result;
}

int normalizeActionBufferMinutes(BlockType type, int minutes) {
  if (type != BlockType.action) return 0;
  final clamped = minutes.clamp(0, kMaxActionBufferMinutes);
  return (((clamped / kBufferStepMinutes).round() * kBufferStepMinutes).clamp(
    0,
    kMaxActionBufferMinutes,
  )).toInt();
}

int maxActionBufferMinutesForDuration(int duration) {
  return (duration - kBufferStepMinutes).clamp(0, kMaxActionBufferMinutes);
}

int normalizeActionBufferMinutesForDuration(
  BlockType type,
  int duration,
  int minutes,
) {
  final normalized = normalizeActionBufferMinutes(type, minutes);
  if (type != BlockType.action) return 0;
  return normalized.clamp(0, maxActionBufferMinutesForDuration(duration));
}

int totalTimelineDuration(List<Block> blocks) {
  return blocks.fold(0, (sum, block) => sum + block.effectiveDuration);
}

String formatTime(int minutes) {
  var m = minutes % (24 * 60);
  if (m < 0) m += 24 * 60;
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}
