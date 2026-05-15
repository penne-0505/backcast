import 'dart:convert';

import '../models.dart';
import '../state.dart';

const int timelineStatePersistenceSchemaVersion = 2;
const int _oldestSupportedTimelineStateSchemaVersion = 1;

String encodeTimelineState(TimelineState state) {
  return jsonEncode(timelineStateToJson(state));
}

TimelineState decodeTimelineState(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Timeline state JSON must be an object.');
  }
  return timelineStateFromJson(decoded);
}

Map<String, Object?> timelineStateToJson(TimelineState state) {
  return {
    'schemaVersion': timelineStatePersistenceSchemaVersion,
    'targetTime': state.targetTime,
    'targetTimeTitle': state.targetTimeTitle,
    'blocks': state.blocks.map(blockToJson).toList(growable: false),
  };
}

TimelineState timelineStateFromJson(Map<String, Object?> json) {
  final schemaVersion = _readInt(json, 'schemaVersion');
  if (schemaVersion < _oldestSupportedTimelineStateSchemaVersion ||
      schemaVersion > timelineStatePersistenceSchemaVersion) {
    throw FormatException(
      'Unsupported timeline schema version: $schemaVersion',
    );
  }

  final blocksJson = json['blocks'];
  if (blocksJson is! List) {
    throw const FormatException('Timeline state blocks must be a list.');
  }

  return TimelineState(
    targetTime: _readInt(json, 'targetTime'),
    targetTimeTitle: _readString(json, 'targetTimeTitle'),
    blocks: blocksJson
        .map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('Block JSON must be an object.');
          }
          return blockFromJson(item);
        })
        .toList(growable: false),
  );
}

Map<String, Object?> blockToJson(Block block) {
  return {
    'id': block.id,
    'type': block.type.name,
    'title': block.title,
    'duration': block.duration,
    'bufferMinutes': block.bufferMinutes,
    'colorIndex': block.colorIndex,
  };
}

Block blockFromJson(Map<String, Object?> json) {
  final typeName = _readString(json, 'type');
  final type = BlockType.values
      .where((value) => value.name == typeName)
      .firstOrNull;
  if (type == null) {
    throw FormatException('Unsupported block type: $typeName');
  }

  final duration = _readInt(json, 'duration');
  return Block(
    id: _readString(json, 'id'),
    type: type,
    title: _readString(json, 'title'),
    duration: duration,
    bufferMinutes: normalizeRawActionBufferMinutes(
      _readOptionalInt(json, 'bufferMinutes') ?? 0,
    ),
    colorIndex: _readInt(json, 'colorIndex'),
  );
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer.');
}

int? _readOptionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('$key must be an integer.');
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}
