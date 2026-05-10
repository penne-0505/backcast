import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/timeline_template_repository.dart';
import 'package:medo/state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  late AppDatabase db;
  late TimelineTemplateRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = TimelineTemplateRepository(
      db,
      now: () => DateTime.utc(2026, 4, 23, 12),
    );
  });

  tearDown(() async {
    await db.close();
  });

  TimelineState sampleState() {
    return TimelineState(
      targetTime: 9 * 60,
      targetTimeTitle: '会議開始',
      selectedBlockId: 'transient-selection',
      preciseDraggingId: 'transient-drag',
      activeInlineEditorId: 'transient-editor',
      blocks: [
        Block(
          id: _uuid.v4(),
          type: BlockType.action,
          title: '移動',
          duration: 30,
          bufferMinutes: 10,
          colorIndex: 1,
        ),
        Block(
          id: _uuid.v4(),
          type: BlockType.actionPoint,
          title: '受付',
          duration: 0,
          colorIndex: 2,
        ),
      ],
    );
  }

  test('creates, lists, and loads a template with ordered blocks', () async {
    final created = await repository.createTemplate(
      state: sampleState(),
      title: '朝の準備テンプレート',
    );

    final summaries = await repository.listTemplates();
    expect(summaries, hasLength(1));
    expect(summaries.single.id, created.id);
    expect(summaries.single.title, '朝の準備テンプレート');
    expect(summaries.single.blockCount, 2);
    expect(summaries.single.targetTime, 9 * 60);
    expect(summaries.single.targetTimeTitle, '会議開始');

    final loaded = await repository.loadTemplate(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.title, '朝の準備テンプレート');
    expect(loaded.state.targetTimeTitle, '会議開始');
    expect(loaded.state.targetTime, 9 * 60);
    expect(loaded.state.blocks, hasLength(2));
    expect(loaded.state.blocks.map((b) => b.type), [
      BlockType.action,
      BlockType.actionPoint,
    ]);
    expect(loaded.state.blocks.map((b) => b.title), ['移動', '受付']);
    expect(loaded.state.blocks.map((b) => b.duration), [30, 0]);
    expect(loaded.state.blocks.map((b) => b.normalizedBufferMinutes), [10, 0]);
    expect(loaded.state.blocks.map((b) => b.colorIndex), [1, 2]);
  });

  test('restores template state with fresh block IDs', () async {
    final created = await repository.createTemplate(
      state: sampleState(),
      title: 'テスト',
    );

    final restored = await repository.restoreTemplateState(created.id);
    expect(restored.targetTime, 9 * 60);
    expect(restored.targetTimeTitle, '会議開始');
    expect(restored.blocks, hasLength(2));
    expect(restored.blocks[0].id, isNot('block-1'));
    expect(restored.blocks[1].id, isNot('block-2'));
    expect(restored.blocks[0].title, '移動');
    expect(restored.blocks[1].title, '受付');
    expect(restored.blocks[0].type, BlockType.action);
    expect(restored.blocks[1].type, BlockType.actionPoint);
    expect(restored.blocks[0].bufferMinutes, 10);
    expect(restored.blocks[1].normalizedBufferMinutes, 0);
  });

  test('renames a template', () async {
    final created = await repository.createTemplate(
      state: sampleState(),
      title: '旧名前',
    );

    await repository.renameTemplate(created.id, '新しい名前');

    final loaded = await repository.loadTemplate(created.id);
    expect(loaded!.title, '新しい名前');
  });

  test('deletes a template and its blocks', () async {
    final created = await repository.createTemplate(
      state: sampleState(),
      title: '削除対象',
    );

    await repository.deleteTemplate(created.id);

    final summaries = await repository.listTemplates();
    expect(summaries, isEmpty);

    final loaded = await repository.loadTemplate(created.id);
    expect(loaded, isNull);
  });

  test(
    'normalizes empty or whitespace-only title to Untitled template',
    () async {
      final withEmpty = await repository.createTemplate(
        state: sampleState(),
        title: '',
      );
      expect(withEmpty.title, 'Untitled template');

      final withWhitespace = await repository.createTemplate(
        state: sampleState(),
        title: '   ',
      );
      expect(withWhitespace.title, 'Untitled template');
    },
  );

  test(
    'uses targetTimeTitle as default title when title is not provided',
    () async {
      final created = await repository.createTemplate(state: sampleState());
      expect(created.title, '会議開始');
    },
  );

  test(
    'falls back to Untitled template when targetTimeTitle is empty',
    () async {
      final state = sampleState().copyWith(targetTimeTitle: '');
      final created = await repository.createTemplate(state: state);
      expect(created.title, 'Untitled template');
    },
  );

  test('handles empty blocks template', () async {
    final state = sampleState().copyWith(blocks: const []);
    final created = await repository.createTemplate(
      state: state,
      title: '空テンプレート',
    );

    final summaries = await repository.listTemplates();
    expect(summaries.single.blockCount, 0);

    final loaded = await repository.loadTemplate(created.id);
    expect(loaded!.state.blocks, isEmpty);

    final restored = await repository.restoreTemplateState(created.id);
    expect(restored.blocks, isEmpty);
  });

  test('throws when restoring from non-existent template', () async {
    expect(
      () => repository.restoreTemplateState('non-existent-id'),
      throwsA(isA<StateError>()),
    );
  });

  test('throws when renaming non-existent template', () async {
    expect(
      () => repository.renameTemplate('non-existent-id', '新しい名前'),
      throwsA(isA<StateError>()),
    );
  });

  test('lists templates ordered by updatedAt desc', () async {
    final first = await repository.createTemplate(
      state: sampleState(),
      title: 'First',
    );
    final second = await repository.createTemplate(
      state: sampleState(),
      title: 'Second',
    );

    // Update first to make it the most recently updated
    await repository.renameTemplate(first.id, 'First Updated');

    final summaries = await repository.listTemplates();
    expect(summaries, hasLength(2));
    expect(summaries[0].id, first.id);
    expect(summaries[1].id, second.id);
  });
}
