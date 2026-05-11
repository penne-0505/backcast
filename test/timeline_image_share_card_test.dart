import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:medo/theme.dart';
import 'package:medo/timeline_image_export.dart';
import 'package:medo/timeline_image_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimelineImageShareCard', () {
    testWidgets('renders target title, metadata, events and anchor', (
      tester,
    ) async {
      final vm = TimelineImageExportViewModel(
        targetTitle: '会議開始',
        metadataText: 'TOTAL 35m',
        events: [
          const TimelineImageExportEvent(
            timeText: '12:25-12:45',
            title: '移動',
            type: TimelineImageExportEventType.action,
            colorIndex: 0,
            durationMinutes: 20,
          ),
          const TimelineImageExportEvent(
            timeText: '12:45',
            title: 'コンビニ',
            type: TimelineImageExportEventType.actionPoint,
            colorIndex: 1,
          ),
          const TimelineImageExportEvent(
            timeText: '13:00',
            title: '会議開始',
            type: TimelineImageExportEventType.targetAnchor,
            colorIndex: -1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelineImageShareCard(viewModel: vm)),
        ),
      );

      expect(find.text('Medo'), findsOneWidget);
      expect(find.text('会議開始'), findsNWidgets(2));
      expect(find.text('TOTAL 35m'), findsOneWidget);
      expect(find.text('移動'), findsOneWidget);
      expect(find.text('コンビニ'), findsOneWidget);
      expect(find.text('TARGET'), findsOneWidget);
    });

    testWidgets('action event shows duration pill when > 0', (tester) async {
      final vm = TimelineImageExportViewModel(
        targetTitle: 'テスト',
        metadataText: 'TOTAL 20m',
        events: [
          const TimelineImageExportEvent(
            timeText: '12:40-13:00',
            title: '移動',
            type: TimelineImageExportEventType.action,
            colorIndex: 0,
            durationMinutes: 20,
          ),
          const TimelineImageExportEvent(
            timeText: '13:00',
            title: 'テスト',
            type: TimelineImageExportEventType.targetAnchor,
            colorIndex: -1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelineImageShareCard(viewModel: vm)),
        ),
      );

      expect(find.text('20分'), findsOneWidget);
    });

    testWidgets('action event shows バッファセグメント when buffer is set', (
      tester,
    ) async {
      final vm = TimelineImageExportViewModel(
        targetTitle: 'テスト',
        metadataText: 'TOTAL 30m',
        events: [
          const TimelineImageExportEvent(
            timeText: '12:30-13:00',
            title: '移動',
            type: TimelineImageExportEventType.action,
            colorIndex: 0,
            durationMinutes: 20,
            bufferMinutes: 10,
          ),
          const TimelineImageExportEvent(
            timeText: '13:00',
            title: 'テスト',
            type: TimelineImageExportEventType.targetAnchor,
            colorIndex: -1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelineImageShareCard(viewModel: vm)),
        ),
      );

      expect(find.text('20分'), findsOneWidget);
      expect(find.text('余裕 +10分'), findsOneWidget);
    });

    testWidgets('action event hides duration pill when 0', (tester) async {
      final vm = TimelineImageExportViewModel(
        targetTitle: 'テスト',
        metadataText: 'TOTAL 0m',
        events: [
          const TimelineImageExportEvent(
            timeText: '13:00-13:00',
            title: '移動',
            type: TimelineImageExportEventType.action,
            colorIndex: 0,
            durationMinutes: 0,
          ),
          const TimelineImageExportEvent(
            timeText: '13:00',
            title: 'テスト',
            type: TimelineImageExportEventType.targetAnchor,
            colorIndex: -1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelineImageShareCard(viewModel: vm)),
        ),
      );

      expect(find.text('0分'), findsNothing);
    });
  });

  group('PNG capture smoke test', () {
    testWidgets('produces non-empty PNG bytes', (tester) async {
      final vm = TimelineImageExportViewModel(
        targetTitle: 'キャプチャテスト',
        metadataText: 'TOTAL 10m',
        events: [
          const TimelineImageExportEvent(
            timeText: '12:50-13:00',
            title: '移動',
            type: TimelineImageExportEventType.action,
            colorIndex: 0,
            durationMinutes: 10,
          ),
          const TimelineImageExportEvent(
            timeText: '13:00',
            title: 'キャプチャテスト',
            type: TimelineImageExportEventType.targetAnchor,
            colorIndex: -1,
          ),
        ],
      );

      final captureKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.canvas,
            body: Center(
              child: RepaintBoundary(
                key: captureKey,
                child: TimelineImageShareCard(viewModel: vm),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary =
          captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      expect(boundary, isNotNull);

      await tester.runAsync(() async {
        final image = await boundary!.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(byteData, isNotNull);

        final bytes = byteData!.buffer.asUint8List();
        expect(bytes.isNotEmpty, isTrue);

        // PNG magic number
        expect(bytes.length, greaterThanOrEqualTo(8));
        expect(
          bytes.sublist(0, 8),
          equals(
            Uint8List.fromList([
              0x89,
              0x50,
              0x4E,
              0x47,
              0x0D,
              0x0A,
              0x1A,
              0x0A,
            ]),
          ),
        );
      });
    });
  });
}
