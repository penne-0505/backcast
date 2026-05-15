import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import '../state.dart';
import 'app_database.dart';

const _uuid = Uuid();

class TimelineTemplateSummary {
  const TimelineTemplateSummary({
    required this.id,
    required this.title,
    required this.targetTime,
    required this.targetTimeTitle,
    required this.blockCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final int targetTime;
  final String targetTimeTitle;
  final int blockCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TimelineTemplate {
  const TimelineTemplate({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TimelineState state;
}

class TimelineTemplateRepository {
  TimelineTemplateRepository(this._db, {DateTime Function()? now}) : _now = now;

  final AppDatabase _db;
  final DateTime Function()? _now;

  Future<TimelineTemplate> createTemplate({
    required TimelineState state,
    String? title,
  }) async {
    final templateId = _uuid.v4();
    final templateTitle = _normalizeTitle(
      title ?? _defaultTemplateTitle(state),
    );
    final now = _clock();

    return _db.transaction(() async {
      await _db
          .into(_db.timelineTemplates)
          .insert(
            TimelineTemplatesCompanion.insert(
              id: templateId,
              title: templateTitle,
              targetTime: state.targetTime,
              targetTimeTitle: state.targetTimeTitle,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceBlocks(templateId, state.blocks);

      return TimelineTemplate(
        id: templateId,
        title: templateTitle,
        createdAt: now,
        updatedAt: now,
        state: TimelineState(
          targetTime: state.targetTime,
          targetTimeTitle: state.targetTimeTitle,
          blocks: List<Block>.unmodifiable(state.blocks),
        ),
      );
    });
  }

  Future<List<TimelineTemplateSummary>> listTemplates() async {
    final rows = await (_db.select(
      _db.timelineTemplates,
    )..orderBy([(table) => OrderingTerm.desc(table.updatedAt)])).get();

    final summaries = <TimelineTemplateSummary>[];
    for (final row in rows) {
      summaries.add(
        TimelineTemplateSummary(
          id: row.id,
          title: row.title,
          targetTime: row.targetTime,
          targetTimeTitle: row.targetTimeTitle,
          blockCount: await _countBlocks(row.id),
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      );
    }
    return summaries;
  }

  Future<TimelineTemplate?> loadTemplate(String templateId) async {
    final template = await (_db.select(
      _db.timelineTemplates,
    )..where((row) => row.id.equals(templateId))).getSingleOrNull();
    if (template == null) return null;

    final blocks =
        await (_db.select(_db.timelineTemplateBlocks)
              ..where((row) => row.templateId.equals(templateId))
              ..orderBy([(row) => OrderingTerm.asc(row.position)]))
            .get();

    return TimelineTemplate(
      id: template.id,
      title: template.title,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
      state: TimelineState(
        targetTime: template.targetTime,
        targetTimeTitle: template.targetTimeTitle,
        blocks: blocks.map(_blockFromRow).toList(growable: false),
      ),
    );
  }

  /// Restores a [TimelineState] from the given template with fresh block IDs.
  Future<TimelineState> restoreTemplateState(String templateId) async {
    final template = await loadTemplate(templateId);
    if (template == null) {
      throw StateError('Template not found: $templateId');
    }

    return TimelineState(
      targetTime: template.state.targetTime,
      targetTimeTitle: template.state.targetTimeTitle,
      blocks: template.state.blocks
          .map((block) => block.copyWith(id: _uuid.v4()))
          .toList(growable: false),
    );
  }

  Future<void> renameTemplate(String templateId, String newTitle) async {
    final existing = await (_db.select(
      _db.timelineTemplates,
    )..where((row) => row.id.equals(templateId))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Template not found: $templateId');
    }

    final normalized = _normalizeTitle(newTitle);
    await (_db.update(
      _db.timelineTemplates,
    )..where((row) => row.id.equals(templateId))).write(
      TimelineTemplatesCompanion(
        title: Value(normalized),
        updatedAt: Value(_clock()),
      ),
    );
  }

  Future<void> deleteTemplate(String templateId) async {
    await (_db.delete(
      _db.timelineTemplates,
    )..where((row) => row.id.equals(templateId))).go();
  }

  DateTime _clock() => (_now ?? DateTime.now)().toUtc();

  String _defaultTemplateTitle(TimelineState state) {
    final title = state.targetTimeTitle.trim();
    return title.isEmpty ? '無題のテンプレート' : title;
  }

  String _normalizeTitle(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ? '無題のテンプレート' : trimmed;
  }

  Future<int> _countBlocks(String templateId) async {
    final count = _db.timelineTemplateBlocks.id.count();
    final query = _db.selectOnly(_db.timelineTemplateBlocks)
      ..addColumns([count])
      ..where(_db.timelineTemplateBlocks.templateId.equals(templateId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _replaceBlocks(String templateId, List<Block> blocks) async {
    await (_db.delete(
      _db.timelineTemplateBlocks,
    )..where((row) => row.templateId.equals(templateId))).go();

    await _db.batch((batch) {
      final companions = <TimelineTemplateBlocksCompanion>[];
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        companions.add(
          TimelineTemplateBlocksCompanion.insert(
            id: block.id,
            templateId: templateId,
            type: block.type.name,
            title: block.title,
            duration: block.duration,
            bufferMinutes: Value(block.bufferMinutes),
            colorIndex: block.colorIndex,
            position: i,
          ),
        );
      }
      batch.insertAll(_db.timelineTemplateBlocks, companions);
    });
  }

  Block _blockFromRow(TimelineTemplateBlock row) {
    final type = BlockType.values
        .where((value) => value.name == row.type)
        .firstOrNull;
    if (type == null) {
      throw FormatException('Unsupported persisted block type: ${row.type}');
    }

    return Block(
      id: row.id,
      type: type,
      title: row.title,
      duration: row.duration,
      bufferMinutes: normalizeRawActionBufferMinutes(row.bufferMinutes),
      colorIndex: row.colorIndex,
    );
  }
}
