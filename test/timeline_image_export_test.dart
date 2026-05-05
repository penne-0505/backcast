import 'package:medo/models.dart';
import 'package:medo/state.dart';
import 'package:medo/timeline_image_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTimelineImageExportViewModel', () {
    test('日付なし・空のタイムライン', () {
      const state = TimelineState(
        targetTime: 13 * 60,
        targetTimeTitle: '会議開始',
        blocks: [],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.noDate,
      );
      expect(vm.targetTitle, '会議開始');
      expect(vm.metadataText, 'TOTAL 0m');
      expect(vm.events.length, 1);
      expect(vm.events.single.type, TimelineImageExportEventType.targetAnchor);
      expect(vm.events.single.timeText, '13:00');
      expect(vm.events.single.title, '会議開始');
    });

    test('日付なし・単純なアクション列', () {
      final state = TimelineState(
        targetTime: 13 * 60,
        targetTimeTitle: '会議開始',
        blocks: [
          _action('b1', '移動', 20, 0),
          _point('b2', 'コンビニ', 1),
          _action('b3', '資料確認', 15, 2),
        ],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.noDate,
      );
      expect(vm.metadataText, 'TOTAL 35m');
      expect(vm.events.length, 4);

      expect(vm.events[0].type, TimelineImageExportEventType.action);
      expect(vm.events[0].timeText, '12:25-12:45');
      expect(vm.events[0].title, '移動');
      expect(vm.events[0].durationMinutes, 20);

      expect(vm.events[1].type, TimelineImageExportEventType.actionPoint);
      expect(vm.events[1].timeText, '12:45');
      expect(vm.events[1].title, 'コンビニ');

      expect(vm.events[2].type, TimelineImageExportEventType.action);
      expect(vm.events[2].timeText, '12:45-13:00');
      expect(vm.events[2].title, '資料確認');

      expect(vm.events[3].type, TimelineImageExportEventType.targetAnchor);
      expect(vm.events[3].timeText, '13:00');
      expect(vm.events[3].title, '会議開始');
    });

    test('日にちあり・同日・空タイトルは「目標時刻」', () {
      const state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '',
        blocks: [],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.withDate,
        baseDate: _date(2026, 5, 2),
      );
      expect(vm.targetTitle, '目標時刻');
      expect(vm.metadataText, '2026-05-02 Sat  /  TOTAL 0m');
      expect(vm.events.single.title, '目標時刻');
    });

    test('日にちあり・同日・ブロックタイトル空は「無題」', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '', 30, 0),
        ],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.withDate,
        baseDate: _date(2026, 5, 2),
      );
      expect(vm.events[0].title, '無題');
      expect(vm.metadataText, '2026-05-02 Sat  /  TOTAL 30m');
    });

    test('0分要素（actionPoint）は durationMinutes が null', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 30, 0),
          _point('b2', '乗換', 1),
          _action('b3', '徒歩', 0, 2),
        ],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.noDate,
      );
      expect(vm.events[0].durationMinutes, 30);
      expect(vm.events[1].durationMinutes, isNull);
      expect(vm.events[2].durationMinutes, 0);
    });

    test('日にちあり・日跨ぎでメタデータが正しい', () {
      final state = TimelineState(
        targetTime: 30,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 60, 0),
          _action('b2', '待機', 60, 1),
        ],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.withDate,
        baseDate: _date(2026, 5, 3),
      );
      expect(vm.metadataText,
          '2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 2h');
    });

    test('改行タイトルは半角スペースに置換', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動\n駅前', 30, 0),
        ],
      );
      final vm = buildTimelineImageExportViewModel(
        state,
        mode: TimelineImageExportMode.noDate,
      );
      expect(vm.events[0].title, '移動 駅前');
    });

    test('withDate で baseDate が未指定の場合は ArgumentError', () {
      const state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [],
      );
      expect(
        () => buildTimelineImageExportViewModel(
          state,
          mode: TimelineImageExportMode.withDate,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

Block _action(String id, String title, int duration, int colorIndex) => Block(
      id: id,
      type: BlockType.action,
      title: title,
      duration: duration,
      colorIndex: colorIndex,
    );

Block _point(String id, String title, int colorIndex) => Block(
      id: id,
      type: BlockType.actionPoint,
      title: title,
      duration: 0,
      colorIndex: colorIndex,
    );

DateTime _date(int y, int m, int d) => DateTime(y, m, d);
