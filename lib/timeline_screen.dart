import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'block_item.dart';
import 'compact_overview.dart';
import 'edit_sheet.dart';
import 'models.dart';
import 'persistence/persistence_providers.dart';
import 'plan_panel.dart';
import 'platform_time_picker.dart';
import 'billing/gate_helper.dart';
import 'billing/paywall_screen.dart';
import 'settings/settings_screen.dart';
import 'state.dart';
import 'template_sheet.dart';
import 'theme.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();
  bool _sheetVisible = false;
  bool _templateSheetVisible = false;
  final Map<int, Offset> _activePointers = {};
  double _basePixelsPerMinute = kPixelsPerMinute;
  double _initialPinchDistance = 0;
  double _pendingPixelsPerMinute = kPixelsPerMinute;
  bool _isPinching = false;
  DateTime _now = DateTime.now();
  late final Timer _clockTimer;
  Timer? _saveDebounce;

  // Search
  bool _isSearchActive = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchHighlightTimer;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _isPinching = true;
      _basePixelsPerMinute = ref.read(timelineProvider).pixelsPerMinute;
      _pendingPixelsPerMinute = _basePixelsPerMinute;
      final pts = _activePointers.values.toList();
      _initialPinchDistance = (pts[0] - pts[1]).distance;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length != 2 || _initialPinchDistance == 0) return;
    final pts = _activePointers.values.toList();
    final dist = (pts[0] - pts[1]).distance;
    final v = (_basePixelsPerMinute * dist / _initialPinchDistance).clamp(
      3.0,
      kPixelsPerMinute,
    );
    _pendingPixelsPerMinute = v;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isPinching) {
      _isPinching = false;
      ref
          .read(timelineProvider.notifier)
          .setPixelsPerMinute(_pendingPixelsPerMinute);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _isPinching) {
      _isPinching = false;
      ref
          .read(timelineProvider.notifier)
          .setPixelsPerMinute(_pendingPixelsPerMinute);
    }
  }

  bool _dismissInlineEditorIfNeeded() {
    if (ref.read(timelineProvider).activeInlineEditorId == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0); // reverse:true → 0.0 = visual bottom
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    ref.listenManual(timelineProvider, (prev, next) {
      if (_isPinching) return;
      _saveDebounce?.cancel();
      _saveIndicatorTimer?.cancel();
      if (mounted) setState(() => _saveIndicatorVisible = true);
      _saveIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _saveIndicatorVisible = false);
      });
      _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
        final planId = ref.read(currentPlanIdProvider);
        if (planId == null) return;
        try {
          await ref
              .read(planRepositoryProvider)
              .savePlan(planId: planId, state: next, createSnapshot: false);
        } catch (e, st) {
          debugPrint('Auto-save error: $e\n$st');
          if (mounted) setState(() => _saveIndicatorVisible = false);
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final repo = ref.read(planRepositoryProvider);
        final plans = await repo.listPlans();
        if (!mounted) return;
        if (plans.isNotEmpty) {
          final plan = await repo.loadPlan(plans.first.id);
          if (!mounted || plan == null) return;
          ref.read(currentPlanIdProvider.notifier).set(plan.id);
          ref.read(timelineProvider.notifier).loadState(plan.state);
        } else {
          final plan = await repo.createPlan(state: ref.read(timelineProvider));
          if (!mounted) return;
          ref.read(currentPlanIdProvider.notifier).set(plan.id);
        }
      } catch (e, st) {
        debugPrint('Timeline init error: $e\n$st');
      }
    });
  }

  int? _activePanel; // 0=save, 1=load, 2=history
  bool _saveIndicatorVisible = false;
  Timer? _saveIndicatorTimer;

  void _togglePanel(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activePanel = _activePanel == index ? null : index);
  }

  void _closePanel() => setState(() => _activePanel = null);

  void _showSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sheetVisible = true);
  }

  void _dismissSheet() {
    setState(() => _sheetVisible = false);
    ref.read(timelineProvider.notifier).selectBlock(null);
  }

  void _showTemplateSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    final isPro = ref.read(effectiveIsProProvider);
    if (!isPro) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PaywallScreen(feature: PaywallFeature.templates),
        ),
      );
      return;
    }
    setState(() => _templateSheetVisible = true);
  }

  void _dismissTemplateSheet() {
    setState(() => _templateSheetVisible = false);
  }

  // display list = computed.reversed → display[k] = computed[n-1-k] = blocks[n-1-k]
  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final n = ref.read(timelineProvider).blocks.length;
    ref
        .read(timelineProvider.notifier)
        .moveBlockByIndex(n - 1 - oldIndex, n - 1 - newIndex);
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return Material(color: Colors.transparent, child: child);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveIndicatorTimer?.cancel();
    _clockTimer.cancel();
    _searchHighlightTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _openSearch() {
    _dismissInlineEditorIfNeeded();
    if (_sheetVisible) _dismissSheet();
    if (_activePanel != null) _closePanel();
    setState(() => _isSearchActive = true);
  }

  void _closeSearch() {
    setState(() => _isSearchActive = false);
    _searchController.clear();
    ref.read(timelineProvider.notifier).clearSearch();
    _searchHighlightTimer?.cancel();
    _searchHighlightTimer = null;
  }

  void _onSearchChanged(String value) {
    ref.read(timelineProvider.notifier).setSearchQuery(value);
  }

  void _onSearchSubmit() => _jumpToActiveSearchMatch();
  void _onSearchNext() {
    ref.read(timelineProvider.notifier).nextSearchMatch();
    _jumpToActiveSearchMatch();
  }

  void _onSearchPrev() {
    ref.read(timelineProvider.notifier).prevSearchMatch();
    _jumpToActiveSearchMatch();
  }

  static const double _kSearchJumpTopMargin = 32.0;
  static const double _kTargetAnchorHeight = 64.0;
  static const double _kPointBlockApproxHeight = 52.0;

  void _jumpToActiveSearchMatch() {
    final timelineState = ref.read(timelineProvider);
    final index = timelineState.activeSearchMatchIndex;
    if (index < 0 || index >= timelineState.searchMatches.length) return;

    final blockId = timelineState.searchMatches[index];
    final computed = ref.read(computedBlocksProvider);
    final sourceIndex = computed.indexWhere((cb) => cb.block.id == blockId);
    if (sourceIndex < 0) return;

    final ppm = timelineState.pixelsPerMinute;
    final isOverview = ppm < kOverviewThresholdPpm;
    final bottomSpacer = MediaQuery.of(context).padding.bottom + 88;

    // Estimate scroll offset to the BOTTOM edge of the target block.
    // In reverse:true, larger offset = higher up (towards visual top).
    double estimatedOffset = bottomSpacer + _kTargetAnchorHeight;
    for (int i = sourceIndex + 1; i < computed.length; i++) {
      final cb = computed[i];
      if (cb.block.type == BlockType.action) {
        final h = cb.block.duration * ppm;
        estimatedOffset +=
            isOverview ? h.clamp(kMinOverviewBlockHeight, double.infinity) : h;
      } else {
        estimatedOffset += _kPointBlockApproxHeight;
      }
    }

    // Target block height
    final targetCb = computed[sourceIndex];
    final targetHeight = targetCb.block.type == BlockType.action
        ? (isOverview
            ? (targetCb.block.duration * ppm)
                .clamp(kMinOverviewBlockHeight, double.infinity)
            : targetCb.block.duration * ppm)
        : _kPointBlockApproxHeight;

    // Top edge of the target block
    final targetTop = estimatedOffset - targetHeight;
    final viewportHeight =
        MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top;
    var desiredOffset = targetTop - viewportHeight + _kSearchJumpTopMargin;

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      desiredOffset = desiredOffset.clamp(0.0, maxScroll);
      _scrollController.jumpTo(desiredOffset);
    }

    // Temporary highlight
    ref.read(timelineProvider.notifier).highlightSearchBlock(blockId);
    _searchHighlightTimer?.cancel();
    _searchHighlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(timelineProvider.notifier).highlightSearchBlock(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final computed = ref.watch(computedBlocksProvider);
    final notifier = ref.read(timelineProvider.notifier);

    // Show sheet when a block becomes selected (edit view only)
    ref.listen<String?>(timelineProvider.select((s) => s.selectedBlockId), (
      prev,
      next,
    ) {
      if (next != null && !_sheetVisible && state.viewMode == TimelineViewMode.edit) {
        _showSheet();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _PlanHeader(
              activePanel: _activePanel,
              onTab: _togglePanel,
              saveIndicatorVisible: _saveIndicatorVisible,
              viewMode: state.viewMode,
              onToggleViewMode: () {
                final next = state.viewMode == TimelineViewMode.edit
                    ? TimelineViewMode.compact
                    : TimelineViewMode.edit;
                notifier.setViewMode(next);
              },
              onSearchTap: _openSearch,
              isSearchActive: _isSearchActive,
              onTemplateTap: _showTemplateSheet,
            ),
            if (_isSearchActive)
              _SearchPopover(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onNext: _onSearchNext,
                onPrev: _onSearchPrev,
                onSubmit: _onSearchSubmit,
                onClose: _closeSearch,
                matchCount: state.searchMatches.length,
                activeMatchIndex: state.activeSearchMatchIndex,
              ),
            Expanded(
              child: Stack(
                children: [
                  // Edit view
                  if (state.viewMode == TimelineViewMode.edit)
                    Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: CustomScrollView(
                        controller: _scrollController,
                        reverse: true,
                        slivers: [
                          // Visual bottom spacer — toolbar (56) + margin (16) + safe area + extra
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 88,
                            ),
                          ),
                          // Target anchor — visual bottom
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20, right: 28),
                              child: _TargetTimeAnchor(
                                targetTime: state.targetTime,
                                targetTimeTitle: state.targetTimeTitle,
                                isSelected:
                                    state.selectedBlockId == kTargetTimeId,
                                onSelect: () =>
                                    notifier.selectBlock(kTargetTimeId),
                              ),
                            ),
                          ),
                          // Reorderable blocks or empty state
                          if (computed.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyState(),
                            )
                          else ...[
                            SliverPadding(
                              padding: const EdgeInsets.only(left: 20, right: 28),
                              sliver: SliverReorderableList(
                                itemCount: computed.length,
                                onReorder: _onReorder,
                                proxyDecorator: _proxyDecorator,
                                itemBuilder: (context, index) {
                                  final n = computed.length;
                                  final sourceIndex = n - 1 - index;
                                  final cb = computed[sourceIndex];
                                  return SizedBox(
                                    key: ValueKey(cb.block.id),
                                    child: BlockItem(
                                      computedBlock: cb,
                                      isSelected:
                                          state.selectedBlockId == cb.block.id,
                                      isSearchHighlighted:
                                          state.searchHighlightedBlockId ==
                                              cb.block.id,
                                      preciseDraggingId: state.preciseDraggingId,
                                      allBlocks: state.blocks,
                                      index: index,
                                      sourceIndex: sourceIndex,
                                      sheetVisible: _sheetVisible,
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Visual top spacer
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 120),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    const CompactOverviewView(),

                  // 現在時刻インジケーター（edit view only）
                  if (state.viewMode == TimelineViewMode.edit && !_sheetVisible)
                    AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, _) {
                        final ppm = state.pixelsPerMinute;
                        final targetTime = state.targetTime;
                        final nowMinutes = _now.hour * 60 + _now.minute;
                        const anchorAreaHeight = 64.0;
                        final bottomSpacer =
                            MediaQuery.of(context).padding.bottom + 88.0;
                        final scrollOffset = _scrollController.hasClients
                            ? _scrollController.offset
                            : 0.0;
                        final nowFromBottom =
                            bottomSpacer +
                            anchorAreaHeight +
                            (targetTime - nowMinutes) * ppm;
                        final viewportHeight =
                            MediaQuery.of(context).size.height -
                            MediaQuery.of(context).padding.top;
                        final top =
                            viewportHeight - nowFromBottom + scrollOffset;
                        if (top < -20 || top > viewportHeight + 20) {
                          return const SizedBox.shrink();
                        }
                        final isOverlapping = computed.any(
                          (cb) =>
                              cb.startTime <= nowMinutes &&
                              nowMinutes <= cb.endTime,
                        );
                        if (!isOverlapping) return const SizedBox.shrink();
                        return Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: _NowIndicator(nowMinutes: nowMinutes),
                        );
                      },
                    ),

                  // 上部フェードオーバーレイ
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 20,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.canvas.withValues(alpha: 0.7),
                              AppColors.canvas.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Backdrop (only when sheet is visible)
                  if (_sheetVisible)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _dismissSheet,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(color: AppColors.scrim),
                          ),
                        ),
                      ),
                    ),

                  // Edit sheet panel
                  if (_sheetVisible)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: EditSheet(onDismiss: _dismissSheet),
                    ),

                  // Template sheet
                  if (_templateSheetVisible) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissTemplateSheet,
                        child: Container(color: AppColors.scrim),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: TemplateSheet(onDismiss: _dismissTemplateSheet),
                    ),
                  ],

                  // 浮遊ツールバー（edit view only）
                  if (state.viewMode == TimelineViewMode.edit && !_sheetVisible)
                    Positioned(
                      left: 52,
                      right: 52,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      child: _FloatingToolbar(
                        onAdd: () {
                          if (_dismissInlineEditorIfNeeded()) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          notifier.addBlock(0, BlockType.action);
                        },
                        onAddPoint: () {
                          if (_dismissInlineEditorIfNeeded()) return;
                          FocusManager.instance.primaryFocus?.unfocus();
                          notifier.addBlock(0, BlockType.actionPoint);
                        },
                      ),
                    ),

                  if (state.activeInlineEditorId != null &&
                      !_sheetVisible &&
                      state.viewMode == TimelineViewMode.edit)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        child: const SizedBox.expand(),
                      ),
                    ),

                  // プランパネル（バックドロップ + パネル本体）
                  if (_activePanel != null) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _closePanel,
                        child: Container(color: AppColors.scrim),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: PlanPanel(
                        initialTab: _activePanel!,
                        onDismiss: _closePanel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Header
// ---------------------------------------------------------------------------

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({
    required this.onTab,
    this.activePanel,
    this.saveIndicatorVisible = false,
    this.viewMode = TimelineViewMode.edit,
    required this.onToggleViewMode,
    required this.onSearchTap,
    this.isSearchActive = false,
    required this.onTemplateTap,
  });

  final void Function(int) onTab;
  final int? activePanel;
  final bool saveIndicatorVisible;
  final TimelineViewMode viewMode;
  final VoidCallback onToggleViewMode;
  final VoidCallback onSearchTap;
  final bool isSearchActive;
  final VoidCallback onTemplateTap;

  static final _icons = [
    PhosphorIcons.floppyDisk(), // セーブ
    PhosphorIcons.folderOpen(), // ロード
    PhosphorIcons.calendarBlank(), // エクスポート
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        boxShadow: AppShadows.header,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Image.asset('assets/images/medo_icon.png', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text(
            'Medo',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.6,
              color: AppColors.darkSurface,
            ),
          ),
          const Spacer(),
          if (saveIndicatorVisible) const _SaveIndicatorDot(),
          // Search entrypoint
          Pressable(
            onTap: onSearchTap,
            scale: 0.88,
            child: Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSearchActive
                    ? AppColors.selectionFill
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                PhosphorIcons.magnifyingGlass(),
                size: 22,
                color: isSearchActive
                    ? AppColors.accentOlive
                    : AppColors.mutedInk,
              ),
            ),
          ),
          for (var i = 0; i < 3; i++)
            Pressable(
              onTap: () => onTab(i),
              scale: 0.88,
              child: Container(
                margin: const EdgeInsets.only(left: AppSpacing.sm),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activePanel == i
                      ? AppColors.selectionFill
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _icons[i],
                  size: 22,
                  color: activePanel == i
                      ? AppColors.accentOlive
                      : AppColors.mutedInk,
                ),
              ),
            ),
          // Template button
          Pressable(
            onTap: onTemplateTap,
            scale: 0.88,
            child: Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                PhosphorIcons.cards(),
                size: 22,
                color: AppColors.mutedInk,
              ),
            ),
          ),
          // View mode toggle
          Pressable(
            onTap: onToggleViewMode,
            scale: 0.88,
            child: Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: viewMode == TimelineViewMode.compact
                    ? AppColors.selectionFill
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                viewMode == TimelineViewMode.compact
                    ? PhosphorIcons.listDashes()
                    : PhosphorIcons.squaresFour(),
                size: 22,
                color: viewMode == TimelineViewMode.compact
                    ? AppColors.accentOlive
                    : AppColors.mutedInk,
              ),
            ),
          ),
          Pressable(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            scale: 0.88,
            child: Container(
              margin: const EdgeInsets.only(left: AppSpacing.sm),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                PhosphorIcons.gear(),
                size: 22,
                color: AppColors.mutedInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search Popover — appears below header with slightly narrower width
// ---------------------------------------------------------------------------

class _SearchPopover extends StatelessWidget {
  const _SearchPopover({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onSubmit,
    required this.onClose,
    required this.matchCount,
    required this.activeMatchIndex,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSubmit;
  final VoidCallback onClose;
  final int matchCount;
  final int activeMatchIndex;

  @override
  Widget build(BuildContext context) {
    final hasMatches = matchCount > 0;
    final countText = hasMatches ? '${activeMatchIndex + 1}/$matchCount' : '0/0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass(),
              size: 18,
              color: AppColors.mutedInk,
            ),
            const SizedBox(width: 8),
              Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                onTapOutside: (_) => onClose(),
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '行動タイトルを検索',
                  hintStyle: TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ),
            // Match count
            if (controller.text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasMatches ? AppColors.selectionFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasMatches ? AppColors.accentOlive : AppColors.mutedInk,
                  ),
                ),
              ),
            const SizedBox(width: 2),
            // Prev
            Pressable(
              onTap: onPrev,
              scale: 0.88,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  PhosphorIcons.caretUp(),
                  size: 16,
                  color: hasMatches ? AppColors.mutedInk : AppColors.mutedInk.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Next
            Pressable(
              onTap: onNext,
              scale: 0.88,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  PhosphorIcons.caretDown(),
                  size: 16,
                  color: hasMatches ? AppColors.mutedInk : AppColors.mutedInk.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Close
            Pressable(
              onTap: onClose,
              scale: 0.88,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  PhosphorIcons.x(),
                  size: 16,
                  color: AppColors.mutedInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Target Time Anchor
// ---------------------------------------------------------------------------

class _TargetTimeAnchor extends ConsumerStatefulWidget {
  const _TargetTimeAnchor({
    required this.targetTime,
    required this.targetTimeTitle,
    required this.isSelected,
    required this.onSelect,
  });

  final int targetTime;
  final String targetTimeTitle;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  ConsumerState<_TargetTimeAnchor> createState() => _TargetTimeAnchorState();
}

class _TargetTimeAnchorState extends ConsumerState<_TargetTimeAnchor> {
  static const _connectorGap = 8.0;
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocusNode;

  static const _inlineEditorId = 'target-title';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.targetTimeTitle);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_handleTitleFocusChange);
  }

  @override
  void didUpdateWidget(_TargetTimeAnchor old) {
    super.didUpdateWidget(old);
    if (widget.targetTimeTitle != old.targetTimeTitle &&
        _titleCtrl.text != widget.targetTimeTitle) {
      _titleCtrl.text = widget.targetTimeTitle;
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_handleTitleFocusChange);
    _titleFocusNode.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _handleTitleFocusChange() {
    final notifier = ref.read(timelineProvider.notifier);
    if (_titleFocusNode.hasFocus) {
      notifier.setActiveInlineEditor(_inlineEditorId);
      return;
    }

    final activeInlineEditorId = ref
        .read(timelineProvider)
        .activeInlineEditorId;
    if (activeInlineEditorId == _inlineEditorId) {
      notifier.setActiveInlineEditor(null);
    }
  }

  bool _dismissInlineEditorIfNeeded() {
    if (ref.read(timelineProvider).activeInlineEditorId == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  Future<void> _pickTargetTime() async {
    if (_dismissInlineEditorIfNeeded()) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final pickedMinutes = await showPlatformTimePicker(
      context,
      initialMinutes: widget.targetTime,
    );
    if (!mounted || pickedMinutes == null) return;

    ref.read(timelineProvider.notifier).setTargetTime(pickedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(timelineProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(top: _connectorGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent bar
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: AppColors.accentOlive,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(width: 4),
          // Left sidebar
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () {
              if (_dismissInlineEditorIfNeeded()) return;
              final insertIndex = ref.read(timelineProvider).blocks.length;
              HapticFeedback.selectionClick();
              ref
                  .read(timelineProvider.notifier)
                  .addBlock(insertIndex, BlockType.action);
            },
            child: SizedBox(
              width: 48,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -_connectorGap,
                    right: 0,
                    bottom: -_connectorGap,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 2,
                        color: AppColors.timelineLine,
                      ),
                    ),
                  ),
                  // L字の横棒（縦線右端からブロック方向へ）
                  Positioned(
                    left: 46,
                    bottom: -_connectorGap,
                    child: Container(
                      width: 20,
                      height: 2,
                      color: AppColors.accentOlive,
                    ),
                  ),
                  Positioned(
                    top: -8,
                    right: 8,
                    child: Container(
                      color: AppColors.canvas,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Text(
                        formatTime(widget.targetTime),
                        style: AppTextStyles.time(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right body — アンカー本体。ラベル「目標」+ タイトル + 大きな目標時刻
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_dismissInlineEditorIfNeeded()) return;
                widget.onSelect();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TARGET',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.accentOlive.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _titleCtrl,
                            focusNode: _titleFocusNode,
                            onChanged: (v) => notifier.setTargetTimeTitle(v),
                            onTap: () {},
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Pressable(
                      behavior: HitTestBehavior.opaque,
                      onTap: _pickTargetTime,
                      scale: 0.95,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          formatTime(widget.targetTime),
                          style: AppTextStyles.time(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentOlive,
                            letterSpacing: -0.6,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Button
// ---------------------------------------------------------------------------

class _FloatingToolbar extends StatelessWidget {
  const _FloatingToolbar({required this.onAdd, required this.onAddPoint});

  final VoidCallback onAdd;
  final VoidCallback onAddPoint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.accentOlive,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.floatingToolbar,
      ),
      child: Row(
        children: [
          // ポイント追加
          Pressable(
            behavior: HitTestBehavior.opaque,
            onTap: onAddPoint,
            scale: 0.88,
            child: SizedBox(
              width: 60,
              height: 56,
              child: Center(
                child: Icon(
                  PhosphorIcons.pushPin(),
                  size: 20,
                  color: AppColors.canvas,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.canvas.withValues(alpha: 0.25),
          ),
          // 行動追加
          Expanded(
            child: Pressable(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              scale: 0.97,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIcons.plus(),
                    size: 20,
                    color: AppColors.canvas,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '前の行動を追加',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.canvas,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final bottomCompensation = MediaQuery.of(context).padding.bottom + 88 + 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(48, bottomCompensation.toDouble(), 48, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.selectionFill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.accentDivider),
            ),
            child: Icon(
              PhosphorIcons.listChecks(),
              color: AppColors.accentOlive,
              size: 28,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '前の行動を追加しましょう',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.darkSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '下のツールバーから、目標時刻に間に合わせるための行動や通過点を積み上げられます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedInk,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save Indicator Dot
// ---------------------------------------------------------------------------

class _SaveIndicatorDot extends StatelessWidget {
  const _SaveIndicatorDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.accentOlive,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Now Indicator
// ---------------------------------------------------------------------------

class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.nowMinutes});

  final int nowMinutes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 28),
      child: SizedBox(
        height: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  color: AppColors.canvas,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    formatTime(nowMinutes),
                    style: AppTextStyles.time(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accentOlive,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                color: AppColors.accentOlive.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
