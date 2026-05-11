import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'billing/gate_helper.dart';
import 'billing/paywall_screen.dart';
import 'models.dart';
import 'persistence/persistence_providers.dart';
import 'persistence/timeline_template_repository.dart';
import 'state.dart';
import 'theme.dart';

enum TemplateSheetPresentation { sheet, popover }

class TemplateSheet extends ConsumerStatefulWidget {
  const TemplateSheet({
    super.key,
    required this.onDismiss,
    this.presentation = TemplateSheetPresentation.sheet,
  });

  final VoidCallback onDismiss;
  final TemplateSheetPresentation presentation;

  @override
  ConsumerState<TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends ConsumerState<TemplateSheet> {
  List<TimelineTemplateSummary> _templates = [];
  bool _loading = true;
  bool _saving = false;
  String? _renamingId;
  final _renameCtrl = TextEditingController();
  final _renameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    _renameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(timelineTemplateRepositoryProvider);
      final templates = await repo.listTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('TemplateSheet load error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _guardTemplateAction() {
    final proAccess = ref.read(effectiveProAccessProvider);
    if (proAccess.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認しています。少し待ってから再試行してください。')),
      );
      return false;
    }
    if (proAccess.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認できませんでした。通信状態を確認してください。')),
      );
      return false;
    }
    if (proAccess.isFree) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const PaywallScreen(feature: PaywallFeature.templates),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _saveCurrent() async {
    if (!_guardTemplateAction()) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(timelineTemplateRepositoryProvider);
      final state = ref.read(timelineProvider);
      await repo.createTemplate(state: state);
      await _load();
    } catch (e, st) {
      debugPrint('TemplateSheet save error: $e\n$st');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _apply(String templateId) async {
    if (!_guardTemplateAction()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ApplyConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;

    try {
      final service = ref.read(timelineTemplateApplyServiceProvider);
      await service.applyTemplate(templateId);
      if (mounted) widget.onDismiss();
    } catch (e, st) {
      debugPrint('TemplateSheet apply error: $e\n$st');
    }
  }

  void _startRename(TimelineTemplateSummary template) {
    setState(() {
      _renamingId = template.id;
      _renameCtrl.text = template.title;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renameFocusNode.requestFocus();
    });
  }

  Future<void> _commitRename(String templateId) async {
    if (!_guardTemplateAction()) {
      setState(() => _renamingId = null);
      return;
    }

    final newTitle = _renameCtrl.text.trim();
    if (newTitle.isEmpty) {
      setState(() => _renamingId = null);
      return;
    }
    try {
      final repo = ref.read(timelineTemplateRepositoryProvider);
      await repo.renameTemplate(templateId, newTitle);
      await _load();
    } catch (e, st) {
      debugPrint('TemplateSheet rename error: $e\n$st');
    } finally {
      if (mounted) setState(() => _renamingId = null);
    }
  }

  Future<void> _delete(String templateId, String title) async {
    if (!_guardTemplateAction()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(title: title),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(timelineTemplateRepositoryProvider);
      await repo.deleteTemplate(templateId);
      await _load();
    } catch (e, st) {
      debugPrint('TemplateSheet delete error: $e\n$st');
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}/${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPopover = widget.presentation == TemplateSheetPresentation.popover;
    final contentBottomPadding = isPopover ? 18.0 : 20.0 + bottomPadding;
    final listMaxHeight = isPopover ? 300.0 : 360.0;
    final boxShadow = isPopover
        ? AppShadows.quickOverlay
        : AppShadows.workSurface;

    return Material(
      color: Colors.transparent,
      child: Container(
        key: isPopover ? const ValueKey('template-popover-surface') : null,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: isPopover
              ? BorderRadius.circular(AppRadius.xl)
              : const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xl),
                  topRight: Radius.circular(AppRadius.xl),
                ),
          border: isPopover
              ? Border.all(
                  color: AppColors.softGray.withValues(alpha: 0.55),
                  width: 0.6,
                )
              : null,
          boxShadow: boxShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isPopover)
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
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, contentBottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      const Text(
                        'テンプレート',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.darkSurface,
                        ),
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: widget.onDismiss,
                        scale: 0.88,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            PhosphorIcons.x(),
                            size: 16,
                            color: AppColors.accentOlive,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Save current timeline
                  Pressable(
                    onTap: _saving ? null : _saveCurrent,
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
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    PhosphorIcons.floppyDisk(),
                                    size: 18,
                                    color: AppColors.canvas,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '現在のタイムラインを保存',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.canvas,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Template list
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: listMaxHeight),
                    child: _buildList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentOlive,
          ),
        ),
      );
    }
    if (_templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.cards(),
              size: 32,
              color: AppColors.mutedInk.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '保存済みテンプレートはありません',
              style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final t in _templates) _buildTemplateRow(t)],
      ),
    );
  }

  Widget _buildTemplateRow(TimelineTemplateSummary t) {
    final isRenaming = _renamingId == t.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRenaming)
                    TextField(
                      controller: _renameCtrl,
                      focusNode: _renameFocusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commitRename(t.id),
                      onTapOutside: (_) => _commitRename(t.id),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'テンプレート名',
                        hintStyle: TextStyle(color: AppColors.mutedInk),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    )
                  else
                    Pressable(
                      onTap: () => _startRename(t),
                      scale: 0.98,
                      child: Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.targetTimeTitle.isEmpty ? '目標時刻' : t.targetTimeTitle} · ${formatTime(t.targetTime)} · ${t.blockCount}ブロック · ${_formatDate(t.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Apply
            Pressable(
              onTap: () => _apply(t.id),
              scale: 0.88,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  PhosphorIcons.arrowUUpLeft(),
                  size: 16,
                  color: AppColors.accentOlive,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Delete
            Pressable(
              onTap: () => _delete(t.id, t.title),
              scale: 0.88,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  PhosphorIcons.trash(),
                  size: 16,
                  color: AppColors.ink,
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
// Apply Confirm Dialog
// ---------------------------------------------------------------------------

class _ApplyConfirmDialog extends StatelessWidget {
  const _ApplyConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'テンプレートを適用しますか？',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '既存のタイムライン（目標時刻と全ての行動）がテンプレートの内容に置き換わります。適用前に自動的に snapshot が作成されます。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mutedInk,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(false),
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child: Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(true),
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentOlive,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child: Text(
                          '適用',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete Confirm Dialog
// ---------------------------------------------------------------------------

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.isEmpty ? 'このテンプレート' : '「$title」',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'を削除しますか？',
              style: TextStyle(fontSize: 14, color: AppColors.mutedInk),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(false),
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child: Text(
                          'キャンセル',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(true),
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child: Text(
                          '削除',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
