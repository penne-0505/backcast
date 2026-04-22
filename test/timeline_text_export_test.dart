import 'package:ato/models.dart';
import 'package:ato/state.dart';
import 'package:ato/timeline_text_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateTimelineText', () {
    test('日付なし・空のタイムライン', () {
      const state = TimelineState(
        targetTime: 13 * 60,
        targetTimeTitle: '会議開始',
        blocks: [],
      );
      final result = generateTimelineText(
        const TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.noDate,
        ),
      );
      expect(
        result,
        'Ato // 会議開始\n'
        'TOTAL 0m\n'
        '\n'
        '13:00       ◆ 会議開始',
      );
    });

    test('日付なし・単純なアクション列', () {
      final state = TimelineState(
        targetTime: 13 * 60,
        targetTimeTitle: '会議開始',
        blocks: [
          _action('b1', '移動', 20),
          _point('b2', 'コンビニ'),
          _action('b3', '資料確認', 15),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.noDate,
        ),
      );
      expect(
        result,
        'Ato // 会議開始\n'
        'TOTAL 35m\n'
        '\n'
        '12:25-12:45 ┃ 移動\n'
        '12:45       ● コンビニ\n'
        '12:45-13:00 ┃ 資料確認\n'
        '13:00       ◆ 会議開始',
      );
    });

    test('日にちあり・同日・空タイトルは「目標時刻」', () {
      const state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '',
        blocks: [],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 2),
        ),
      );
      expect(
        result,
        'Ato // 目標時刻\n'
        '2026-05-02 Sat  /  TOTAL 0m\n'
        '\n'
        '10:00       ◆ 目標時刻',
      );
    });

    test('日にちあり・同日・ブロックタイトル空は「無題」', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '', 30),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 2),
        ),
      );
      expect(
        result,
        'Ato // 到着\n'
        '2026-05-02 Sat  /  TOTAL 30m\n'
        '\n'
        '09:30-10:00 ┃ 無題\n'
        '10:00       ◆ 到着',
      );
    });

    test('改行タイトルは半角スペースに置換', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動\n駅前', 30),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.noDate,
        ),
      );
      expect(
        result,
        'Ato // 到着\n'
        'TOTAL 30m\n'
        '\n'
        '09:30-10:00 ┃ 移動 駅前\n'
        '10:00       ◆ 到着',
      );
    });

    test('0分要素（actionPoint）と target anchor は一点時刻', () {
      final state = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 30),
          _point('b2', '乗換'),
          _action('b3', '徒歩', 0),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.noDate,
        ),
      );
      expect(
        result,
        'Ato // 到着\n'
        'TOTAL 30m\n'
        '\n'
        '09:30-10:00 ┃ 移動\n'
        '10:00       ● 乗換\n'
        '10:00-10:00 ┃ 徒歩\n'
        '10:00       ◆ 到着',
      );
    });

    test('日にちあり・日跨ぎで divider とメタデータが正しい', () {
      // target=00:30, blocks=[60分移動, 60分待機]
      // timeline start = 00:30 - 120 = -90 = 前日 22:30
      final state = TimelineState(
        targetTime: 30,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 60),
          _action('b2', '待機', 60),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 3),
        ),
      );
      expect(
        result,
        'Ato // 到着\n'
        '2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 2h\n'
        '\n'
        '── 2026-05-02 Sat\n'
        '22:30-23:30 ┃ 移動\n'
        '23:30-00:30 ┃ 待機\n'
        '\n'
        '── 2026-05-03 Sun\n'
        '00:30       ◆ 到着',
      );
    });

    test('日にちあり・日跨ぎ・actionPoint 含む', () {
      // target=00:30, blocks=[30分移動, actionPoint, 30分徒歩]
      final state = TimelineState(
        targetTime: 30,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 30),
          _point('b2', '乗換'),
          _action('b3', '徒歩', 30),
        ],
      );
      final result = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 3),
        ),
      );
      expect(
        result,
        'Ato // 到着\n'
        '2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 1h\n'
        '\n'
        '── 2026-05-02 Sat\n'
        '23:30-00:00 ┃ 移動\n'
        '\n'
        '── 2026-05-03 Sun\n'
        '00:00       ● 乗換\n'
        '00:00-00:30 ┃ 徒歩\n'
        '00:30       ◆ 到着',
      );
    });

    test('日にちあり・同日でも日跨ぎがあっても divider は出ない', () {
      // target=00:30, blocks=[60分移動]
      // baseDate=2026-05-03（target日）
      // start=23:30（前日）なので日跨ぎ
      final state = TimelineState(
        targetTime: 30,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 60),
        ],
      );
      // 同日パターン: target=10:00, blocks=[30分]
      final sameDayState = TimelineState(
        targetTime: 10 * 60,
        targetTimeTitle: '到着',
        blocks: [
          _action('b1', '移動', 30),
        ],
      );
      final sameDayResult = generateTimelineText(
        TimelineTextExportRequest(
          state: sameDayState,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 3),
        ),
      );
      expect(
        sameDayResult,
        'Ato // 到着\n'
        '2026-05-03 Sun  /  TOTAL 30m\n'
        '\n'
        '09:30-10:00 ┃ 移動\n'
        '10:00       ◆ 到着',
      );

      final crossDayResult = generateTimelineText(
        TimelineTextExportRequest(
          state: state,
          mode: TimelineTextExportMode.withDate,
          baseDate: _date(2026, 5, 3),
        ),
      );
      expect(
        crossDayResult,
        'Ato // 到着\n'
        '2026-05-02 Sat -> 2026-05-03 Sun  /  TOTAL 1h\n'
        '\n'
        '── 2026-05-02 Sat\n'
        '23:30-00:30 ┃ 移動\n'
        '\n'
        '── 2026-05-03 Sun\n'
        '00:30       ◆ 到着',
      );
    });
  });
}

Block _action(String id, String title, int duration) => Block(
      id: id,
      type: BlockType.action,
      title: title,
      duration: duration,
      colorIndex: 0,
    );

Block _point(String id, String title) => Block(
      id: id,
      type: BlockType.actionPoint,
      title: title,
      duration: 0,
      colorIndex: 0,
    );

DateTime _date(int y, int m, int d) => DateTime(y, m, d);
