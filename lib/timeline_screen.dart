import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'block_item.dart';
import 'edit_sheet.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _sheetCtrl;
  late final Animation<Offset> _sheetSlide;
  bool _sheetVisible = false;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _sheetSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _sheetCtrl,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0); // reverse:true → 0.0 = visual bottom
      }
    });
  }

  void _showSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sheetVisible = true);
    _sheetCtrl.forward(from: 0);
  }

  void _dismissSheet() {
    _sheetCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _sheetVisible = false);
      ref.read(timelineProvider.notifier).selectBlock(null);
    });
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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.0 + 0.02 * t, child: child),
        );
      },
      child: child,
    );
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final computed = ref.watch(computedBlocksProvider);
    final notifier = ref.read(timelineProvider.notifier);

    // Show sheet when a block becomes selected
    ref.listen<String?>(timelineProvider.select((s) => s.selectedBlockId), (
      prev,
      next,
    ) {
      if (next != null && !_sheetVisible) _showSheet();
    });

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: Column(
        children: [
          _Header(
            totalDuration: state.blocks.fold(0, (s, b) => s + b.duration),
          ),
          Expanded(
            child: Stack(
              children: [
                // Timeline list
                CustomScrollView(
                  controller: _scrollController,
                  reverse: true,
                  slivers: [
                    // Visual bottom spacer (matching original top: 32)
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    // Target anchor — visual bottom
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 28),
                        child: _TargetTimeAnchor(
                          targetTime: state.targetTime,
                          targetTimeTitle: state.targetTimeTitle,
                          isSelected: state.selectedBlockId == kTargetTimeId,
                          onSelect: () => notifier.selectBlock(kTargetTimeId),
                        ),
                      ),
                    ),
                    // Reorderable blocks
                    SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 28),
                      sliver: SliverReorderableList(
                        itemCount: computed.length,
                        onReorder: _onReorder,
                        proxyDecorator: _proxyDecorator,
                        itemBuilder: (context, index) {
                          // display[k] = computed[n-1-k]: most-future at bottom
                          final n = computed.length;
                          final cb = computed[n - 1 - index];
                          return _QuickReorderListener(
                            key: ValueKey(cb.block.id),
                            index: index,
                            child: BlockItem(
                              computedBlock: cb,
                              isSelected: state.selectedBlockId == cb.block.id,
                              preciseDraggingId: state.preciseDraggingId,
                              allBlocks: state.blocks,
                            ),
                          );
                        },
                      ),
                    ),
                    // Add button — visual top
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 28),
                        child: _AddButton(
                          onAdd: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            notifier.addBlock(0, BlockType.action);
                          },
                          onAddPoint: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            notifier.addBlock(0, BlockType.actionPoint);
                          },
                        ),
                      ),
                    ),
                    // Visual top spacer (matching original bottom: 96)
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),

                // Backdrop (only when sheet is visible)
                if (_sheetVisible)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _sheetCtrl,
                      builder: (context, child) =>
                          Opacity(opacity: _sheetCtrl.value, child: child),
                      child: GestureDetector(
                        onTap: _dismissSheet,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                            child: Container(color: Colors.black.withAlpha(51)),
                          ),
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
                    child: SlideTransition(
                      position: _sheetSlide,
                      child: EditSheet(onDismiss: _dismissSheet),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.totalDuration});

  final int totalDuration;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.stone200)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.blue500,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '逆算タイムライン',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.stone800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.stone100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '総所要時間: $totalDuration分',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stone500,
                  ),
                ),
              ),
            ],
          ),
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
  late final TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.targetTimeTitle);
  }

  @override
  void didUpdateWidget(_TargetTimeAnchor old) {
    super.didUpdateWidget(old);
    if (widget.targetTimeTitle != old.targetTimeTitle &&
        _titleCtrl.text != widget.targetTimeTitle) {
      _titleCtrl.value = _titleCtrl.value.copyWith(
        text: widget.targetTimeTitle,
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(timelineProvider.notifier);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left sidebar
          SizedBox(
            width: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(width: 2, color: AppColors.stone300),
                  ),
                ),
                Positioned(
                  top: -10,
                  right: 8,
                  child: Container(
                    color: AppColors.stone50,
                    padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                    child: Text(
                      formatTime(widget.targetTime),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.stone900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right body
          Expanded(
            child: GestureDetector(
              onTap: widget.onSelect,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.blue50
                      : AppColors.stone200,
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.blue400
                        : AppColors.stone300,
                    width: widget.isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        onChanged: (v) => notifier.setTargetTimeTitle(v),
                        onTap: () {},
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.stone800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.stone400,
                        shape: BoxShape.circle,
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onAdd, required this.onAddPoint});

  final VoidCallback onAdd;
  final VoidCallback onAddPoint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(width: 2, height: 56, color: AppColors.stone200),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: onAddPoint,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.stone100,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.push_pin_outlined,
                          size: 22,
                          color: AppColors.stone500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.stone100,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 22, color: AppColors.stone500),
                          SizedBox(width: 8),
                          Text(
                            '前の行動を追加',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                              color: AppColors.stone500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Reorder Listener (200ms delay, vs. default 500ms)
// ---------------------------------------------------------------------------

class _QuickReorderListener extends ReorderableDragStartListener {
  const _QuickReorderListener({
    super.key,
    required super.index,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer() {
    return DelayedMultiDragGestureRecognizer(
      delay: const Duration(milliseconds: 200),
      debugOwner: this,
    );
  }
}
