import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'persistence/persistence_providers.dart';
import 'persistence/plan_repository.dart';
import 'state.dart';
import 'theme.dart';

const _uuid = Uuid();

class PlanManagerSheet extends ConsumerStatefulWidget {
  const PlanManagerSheet({
    super.key,
    required this.onDismiss,
    this.initialTab = 0,
  });

  final VoidCallback onDismiss;
  final int initialTab;

  @override
  ConsumerState<PlanManagerSheet> createState() => _PlanManagerSheetState();
}

class _PlanManagerSheetState extends ConsumerState<PlanManagerSheet> {
  late int _tab;

  late final TextEditingController _nameCtrl;
  List<TimelinePlanSummary> _plans = [];
  List<TimelineSnapshotSummary> _snapshots = [];
  bool _loadingPlans = true;
  bool _loadingSnapshots = false;
  bool _saving = false;
  bool _userEditedName = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    final state = ref.read(timelineProvider);
    _nameCtrl = TextEditingController(text: state.targetTimeTitle);
    _nameCtrl.addListener(_onNameChanged);
    _initLoad();
    if (_tab == 2) _loadSnapshots();
  }

  void _onNameChanged() {
    _userEditedName = true;
  }

  Future<void> _initLoad() async {
    try {
      final repo = ref.read(planRepositoryProvider);
      final currentPlanId = ref.read(currentPlanIdProvider);
      final plans = await repo.listPlans();
      if (currentPlanId != null) {
        final current = plans.where((p) => p.id == currentPlanId).firstOrNull;
        if (current != null && mounted && !_userEditedName) {
          _nameCtrl.removeListener(_onNameChanged);
          _nameCtrl.text = current.title;
          _nameCtrl.addListener(_onNameChanged);
        }
      }
      if (mounted) {
        setState(() {
          _plans = plans;
          _loadingPlans = false;
        });
      }
    } catch (e, st) {
      debugPrint('PlanManager initLoad error: $e\n$st');
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _loadSnapshots() async {
    try {
      final currentPlanId = ref.read(currentPlanIdProvider);
      if (currentPlanId == null) {
        setState(() => _loadingSnapshots = false);
        return;
      }
      setState(() => _loadingSnapshots = true);
      final repo = ref.read(planRepositoryProvider);
      final snapshots = await repo.listSnapshots(currentPlanId);
      if (mounted) {
        setState(() {
          _snapshots = snapshots;
          _loadingSnapshots = false;
        });
      }
    } catch (e, st) {
      debugPrint('PlanManager loadSnapshots error: $e\n$st');
      if (mounted) setState(() => _loadingSnapshots = false);
    }
  }

  void _switchTab(int index) {
    setState(() => _tab = index);
    if (index == 2 && _snapshots.isEmpty && !_loadingSnapshots) {
      _loadSnapshots();
    }
  }

  TimelineState _withFreshBlockIds(TimelineState state) {
    return TimelineState(
      targetTime: state.targetTime,
      targetTimeTitle: state.targetTimeTitle,
      blocks: state.blocks
          .map((b) => b.copyWith(id: _uuid.v4()))
          .toList(growable: false),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(planRepositoryProvider);
      final fresh = _withFreshBlockIds(ref.read(timelineProvider));
      final plan = await repo.createPlan(state: fresh, title: name);
      if (!mounted) return;
      await repo.saveCurrentPlanId(plan.id);
      ref.read(timelineProvider.notifier).loadState(fresh);
      ref.read(currentPlanIdProvider.notifier).set(plan.id);
      widget.onDismiss();
    } catch (e, st) {
      debugPrint('PlanManager save error: $e\n$st');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadPlan(TimelinePlanSummary summary) async {
    final repo = ref.read(planRepositoryProvider);
    final plan = await repo.loadPlan(summary.id);
    if (!mounted || plan == null) return;
    await repo.saveCurrentPlanId(plan.id);
    ref.read(timelineProvider.notifier).loadState(plan.state);
    ref.read(currentPlanIdProvider.notifier).set(plan.id);
    widget.onDismiss();
  }

  Future<void> _restoreSnapshot(TimelineSnapshotSummary summary) async {
    final repo = ref.read(planRepositoryProvider);
    final currentPlanId = ref.read(currentPlanIdProvider);
    if (currentPlanId == null) return;
    await repo.restoreSnapshot(snapshotId: summary.id);
    final plan = await repo.loadPlan(currentPlanId);
    if (!mounted || plan == null) return;
    ref.read(timelineProvider.notifier).loadState(plan.state);
    widget.onDismiss();
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlanId = ref.watch(currentPlanIdProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
        boxShadow: AppShadows.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ドラッグハンドル
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // セグメントコントロール
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SegmentedControl(
              labels: const ['セーブ', 'ロード', '履歴'],
              selected: _tab,
              onChanged: _switchTab,
            ),
          ),
          const SizedBox(height: 16),

          // コンテンツエリア
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPadding),
              child: switch (_tab) {
                0 => _buildSaveTab(key: const ValueKey('save')),
                1 => _buildLoadTab(currentPlanId, key: const ValueKey('load')),
                _ => _buildHistoryTab(key: const ValueKey('history')),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── セーブタブ ──────────────────────────────────────────────────────────

  Widget _buildSaveTab({Key? key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('プラン名'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.softGray,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: TextField(
            controller: _nameCtrl,
            autofocus: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'プラン名を入力...',
              hintStyle: TextStyle(color: AppColors.mutedInk),
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Pressable(
          onTap: _saving ? null : _save,
          scale: 0.97,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.canvas,
                      ),
                    )
                  : const Text(
                      'この状態を保存する',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.canvas,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── ロードタブ ──────────────────────────────────────────────────────────

  Widget _buildLoadTab(String? currentPlanId, {Key? key}) {
    if (_loadingPlans) {
      return const Center(
        key: ValueKey('load'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentOlive,
          ),
        ),
      );
    }
    if (_plans.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: const Center(
          child: Text(
            '保存済みプランはありません',
            style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
          ),
        ),
      );
    }
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final summary in _plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pressable(
              onTap: () => _loadPlan(summary),
              scale: 0.98,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: currentPlanId == summary.id
                      ? AppColors.selectionFill
                      : AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: currentPlanId == summary.id
                      ? Border.all(color: AppColors.accentOlive, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${summary.blockCount}ブロック · ${formatTime(summary.targetTime)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentPlanId == summary.id)
                      Icon(
                        PhosphorIcons.check(),
                        size: 16,
                        color: AppColors.accentOlive,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── 履歴タブ ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab({Key? key}) {
    if (_loadingSnapshots) {
      return const Center(
        key: ValueKey('history'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentOlive,
          ),
        ),
      );
    }
    if (_snapshots.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: const Center(
          child: Text(
            '履歴はありません',
            style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
          ),
        ),
      );
    }
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final snapshot in _snapshots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Pressable(
              onTap: () => _restoreSnapshot(snapshot),
              scale: 0.98,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.label ?? '自動保存',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(snapshot.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.clockCounterClockwise(),
                      size: 16,
                      color: AppColors.accentOlive,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented Control
// ---------------------------------------------------------------------------

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                scale: 0.96,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected == i
                          ? AppColors.canvas
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: selected == i
                          ? [
                              const BoxShadow(
                                color: AppColors.softShadow,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected == i
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected == i
                              ? AppColors.darkSurface
                              : AppColors.mutedInk,
                        ),
                      ),
                    ),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.label);
  }
}
