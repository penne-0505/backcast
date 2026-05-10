import 'package:medo/billing/gate_helper.dart';
import 'package:medo/billing/paywall_screen.dart';
import 'package:medo/main.dart';
import 'package:medo/models.dart';
import 'package:medo/persistence/app_database.dart';
import 'package:medo/persistence/persistence_providers.dart';
import 'package:medo/persistence/plan_repository.dart';
import 'package:medo/persistence/timeline_template_repository.dart';
import 'package:medo/state.dart';
import 'package:medo/template_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

late AppDatabase db;

class _TestCurrentPlanIdNotifier extends CurrentPlanIdNotifier {
  final String? _value;
  _TestCurrentPlanIdNotifier(this._value);
  @override
  String? build() => _value;
}

Future<void> pumpMedoApp(WidgetTester tester, {bool isPro = true}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        effectiveIsProProvider.overrideWithValue(isPro),
      ],
      child: const MedoApp(),
    ),
  );
  await tester.pump();
}

ProviderContainer _containerFor(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

void main() {
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('TemplateSheet integration', () {
    Future<void> setLargeScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('shows empty state when no templates exist', (tester) async {
      await setLargeScreen(tester);
      await pumpMedoApp(tester);
      await tester.pumpAndSettle();

      final templateButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.cards(),
      );
      expect(templateButton, findsOneWidget);
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      expect(find.text('テンプレート'), findsOneWidget);
      expect(find.text('保存済みテンプレートはありません'), findsOneWidget);
    });

    testWidgets('Free user navigates to paywall from template button', (
      tester,
    ) async {
      await setLargeScreen(tester);
      await pumpMedoApp(tester, isPro: false);
      await tester.pumpAndSettle();

      final templateButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.cards(),
      );
      expect(templateButton, findsOneWidget);
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.textContaining('テンプレートはPro機能'), findsOneWidget);
    });

    testWidgets('saves current timeline as template', (tester) async {
      await setLargeScreen(tester);
      await pumpMedoApp(tester);
      await tester.pumpAndSettle();

      final templateButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.cards(),
      );
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('現在のタイムラインを保存'));
      await tester.pumpAndSettle();

      expect(find.text('保存済みテンプレートはありません'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TemplateSheet),
          matching: find.text('目標時刻'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('lists template metadata correctly', (tester) async {
      await setLargeScreen(tester);
      final repo = TimelineTemplateRepository(db);
      await repo.createTemplate(
        state: const TimelineState(
          targetTime: 900,
          targetTimeTitle: '会議',
          blocks: [
            Block(
              id: 'b1',
              type: BlockType.action,
              title: '資料準備',
              duration: 30,
              colorIndex: 0,
            ),
          ],
        ),
        title: '朝のルーティン',
      );

      await pumpMedoApp(tester);
      await tester.pumpAndSettle();

      final templateButton = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.cards(),
      );
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      expect(find.text('朝のルーティン'), findsOneWidget);
      expect(find.textContaining('会議'), findsOneWidget);
      expect(find.textContaining('15:00'), findsOneWidget);
      expect(find.textContaining('1ブロック'), findsOneWidget);
    });
  });

  group('TemplateSheet unit', () {
    Future<void> pumpSheet(WidgetTester tester, {bool isPro = true}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            effectiveIsProProvider.overrideWithValue(isPro),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: TemplateSheet(onDismiss: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows apply confirmation dialog', (tester) async {
      final repo = TimelineTemplateRepository(db);
      await repo.createTemplate(
        state: const TimelineState(
          targetTime: 900,
          targetTimeTitle: '会議',
          blocks: [],
        ),
        title: 'Empty Template',
      );

      await pumpSheet(tester);

      final applyIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.arrowUUpLeft(),
      );
      expect(applyIcon, findsOneWidget);
      await tester.tap(applyIcon);
      await tester.pumpAndSettle();

      expect(find.text('テンプレートを適用しますか？'), findsOneWidget);
      expect(find.text('適用'), findsOneWidget);
      expect(find.text('キャンセル'), findsOneWidget);

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('テンプレートを適用しますか？'), findsNothing);
    });

    testWidgets('renames a template', (tester) async {
      final repo = TimelineTemplateRepository(db);
      await repo.createTemplate(
        state: const TimelineState(
          targetTime: 900,
          targetTimeTitle: '会議',
          blocks: [],
        ),
        title: 'Old Name',
      );

      await pumpSheet(tester);

      expect(find.text('Old Name'), findsOneWidget);

      await tester.tap(find.text('Old Name'));
      await tester.pumpAndSettle();

      final textField = find.descendant(
        of: find.byType(TemplateSheet),
        matching: find.byType(TextField),
      );
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'New Name');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsOneWidget);
      expect(find.text('Old Name'), findsNothing);
    });

    testWidgets('deletes a template after confirmation', (tester) async {
      final repo = TimelineTemplateRepository(db);
      await repo.createTemplate(
        state: const TimelineState(
          targetTime: 900,
          targetTimeTitle: '会議',
          blocks: [],
        ),
        title: 'To Delete',
      );

      await pumpSheet(tester);

      expect(find.text('To Delete'), findsOneWidget);

      final deleteIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.trash(),
      );
      expect(deleteIcon, findsOneWidget);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('を削除しますか？'), findsOneWidget);
      await tester.tap(find.text('削除'));
      await tester.pumpAndSettle();

      expect(find.text('To Delete'), findsNothing);
      expect(find.text('保存済みテンプレートはありません'), findsOneWidget);
    });

    testWidgets('applies template and replaces timeline', (tester) async {
      final repo = TimelineTemplateRepository(db);
      final planRepo = PlanRepository(db);
      final plan = await planRepo.createPlan(
        state: const TimelineState(
          targetTime: 600,
          targetTimeTitle: 'Old Target',
          blocks: [
            Block(
              id: 'old1',
              type: BlockType.action,
              title: 'Old Action',
              duration: 15,
              colorIndex: 0,
            ),
          ],
        ),
      );

      await repo.createTemplate(
        state: const TimelineState(
          targetTime: 900,
          targetTimeTitle: 'New Target',
          blocks: [
            Block(
              id: 'new1',
              type: BlockType.action,
              title: 'New Action',
              duration: 30,
              colorIndex: 1,
            ),
          ],
        ),
        title: 'New Template',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            effectiveIsProProvider.overrideWithValue(true),
            currentPlanIdProvider.overrideWith(
              () => _TestCurrentPlanIdNotifier(plan.id),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: TemplateSheet(onDismiss: () {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final applyIcon = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == PhosphorIcons.arrowUUpLeft(),
      );
      await tester.tap(applyIcon);
      await tester.pumpAndSettle();

      await tester.tap(find.text('適用'));
      await tester.pumpAndSettle();

      // Verify through provider that timeline was replaced
      final container = _containerFor(tester);
      final state = container.read(timelineProvider);
      expect(state.targetTimeTitle, 'New Target');
      expect(state.targetTime, 900);
      expect(state.blocks.length, 1);
      expect(state.blocks.first.title, 'New Action');
      expect(state.selectedBlockId, isNull);
      expect(state.activeInlineEditorId, isNull);
      expect(state.preciseDraggingId, isNull);
    });

    testWidgets(
      'Free user is blocked from saving template and navigates to paywall',
      (tester) async {
        await pumpSheet(tester, isPro: false);

        await tester.tap(find.text('現在のタイムラインを保存'));
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.textContaining('テンプレートはPro機能'), findsOneWidget);
      },
    );

    testWidgets(
      'Free user is blocked from applying template and navigates to paywall',
      (tester) async {
        final repo = TimelineTemplateRepository(db);
        await repo.createTemplate(
          state: const TimelineState(
            targetTime: 900,
            targetTimeTitle: '会議',
            blocks: [],
          ),
          title: 'Blocked Apply',
        );

        await pumpSheet(tester, isPro: false);

        final applyIcon = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == PhosphorIcons.arrowUUpLeft(),
        );
        await tester.tap(applyIcon);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.textContaining('テンプレートはPro機能'), findsOneWidget);
      },
    );

    testWidgets(
      'Free user is blocked from renaming template and navigates to paywall',
      (tester) async {
        final repo = TimelineTemplateRepository(db);
        await repo.createTemplate(
          state: const TimelineState(
            targetTime: 900,
            targetTimeTitle: '会議',
            blocks: [],
          ),
          title: 'Blocked Rename',
        );

        await pumpSheet(tester, isPro: false);

        await tester.tap(find.text('Blocked Rename'));
        await tester.pumpAndSettle();

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.textContaining('テンプレートはPro機能'), findsOneWidget);
      },
    );

    testWidgets(
      'Free user is blocked from deleting template and navigates to paywall',
      (tester) async {
        final repo = TimelineTemplateRepository(db);
        await repo.createTemplate(
          state: const TimelineState(
            targetTime: 900,
            targetTimeTitle: '会議',
            blocks: [],
          ),
          title: 'Blocked Delete',
        );

        await pumpSheet(tester, isPro: false);

        final deleteIcon = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == PhosphorIcons.trash(),
        );
        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.textContaining('テンプレートはPro機能'), findsOneWidget);
      },
    );
  });
}
