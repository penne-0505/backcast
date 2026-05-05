import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'billing/gate_helper.dart';
import 'billing/paywall_screen.dart';
import 'calendar_export.dart';
import 'calendar_export_delivery.dart';
import 'calendar_export_request_builder.dart';
import 'image_export_delivery.dart';
import 'text_export_delivery.dart';
import 'timeline_image_export.dart';
import 'timeline_image_share_card.dart';
import 'timeline_text_export.dart';
import 'state.dart';
import 'theme.dart';

final _calendarExportDelivery = CalendarExportDelivery();
const _textExportDelivery = TextExportDelivery();
const _imageExportDelivery = ImageExportDelivery();

// ---------------------------------------------------------------------------
// Export panel
// ---------------------------------------------------------------------------

class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  bool _useToday = true;
  DateTime? _pickedDate;
  bool _exporting = false;

  Future<void> _export() async {
    final state = ref.read(timelineProvider);
    if (!_useToday && _pickedDate == null) {
      _showResultSnackBar('日付を選択してください', success: false);
      return;
    }
    final base = _useToday ? DateTime.now() : _pickedDate!;

    final request = buildCalendarExportRequest(
      state: state,
      baseDate: base,
      clock: DateTime.now,
    );
    final preview = CalendarExportPreview.fromRequest(request);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _CalendarExportPreviewDialog(
        preview: preview,
        targetTitle: state.targetTimeTitle,
      ),
    );

    if (confirmed != true || !mounted) return;
    await _executeExport(request);
  }

  Future<void> _executeExport(CalendarExportRequest request) async {
    setState(() => _exporting = true);
    try {
      final result = await _calendarExportDelivery.deliver(request: request);

      if (!mounted) return;
      final calendarLabel = result.calendarName != null
          ? '（${result.calendarName}）'
          : '';
      _showResultSnackBar('${result.savedCount}件をカレンダーに登録しました$calendarLabel');
    } on CalendarExportException catch (e) {
      if (!mounted) return;
      final message = switch (e.error) {
        CalendarExportError.permissionDenied =>
          'カレンダーへのアクセスが許可されていません。設定から権限を確認してください。',
        CalendarExportError.noWritableCalendar => '書き込み可能なカレンダーが見つかりません。',
        CalendarExportError.invalidPayload => '登録内容に問題があります。',
        CalendarExportError.unsupportedPlatform =>
          'このプラットフォームではカレンダー登録に対応していません。',
        CalendarExportError.saveFailed => 'カレンダー登録に失敗しました。',
      };
      _showResultSnackBar(message, success: false);
    } on Exception {
      if (!mounted) return;
      _showResultSnackBar('カレンダー登録に失敗しました', success: false);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showTextShareDialog() async {
    final state = ref.read(timelineProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _TextShareDialog(
          state: state,
          useToday: _useToday,
          pickedDate: _pickedDate,
        );
      },
    );
  }

  Future<void> _showImageShareDialog() async {
    // Free image export gate
    final isPro = ref.read(effectiveIsProProvider);
    if (!isPro) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const PaywallScreen(feature: PaywallFeature.imageExport),
        ),
      );
      return;
    }

    final state = ref.read(timelineProvider);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ImageShareDialog(
          state: state,
          useToday: _useToday,
          pickedDate: _pickedDate,
        );
      },
    );
  }

  String _fmtDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  void _showResultSnackBar(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? PhosphorIcons.checkCircle()
                  : PhosphorIcons.warningCircle(),
              color: AppColors.canvas,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.canvas,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: success
            ? AppColors.darkSurface
            : const Color(0xFFB54A4A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          border: const Border(bottom: BorderSide(color: AppColors.softGray)),
          boxShadow: AppShadows.panel,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー行
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                children: [
                  const Text(
                    'エクスポート',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkSurface,
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: widget.onDismiss,
                    scale: 0.88,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        PhosphorIcons.x(),
                        size: 14,
                        color: AppColors.accentOlive,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // コンテンツ
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildExport(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── カレンダーエクスポート ────────────────────────────────────────────

  Widget _buildExport() {
    final displayDate = _useToday ? DateTime.now() : _pickedDate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'エクスポート日',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ToggleChip(
                label: '今日',
                selected: _useToday,
                onTap: () => setState(() {
                  _useToday = true;
                  _pickedDate = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ToggleChip(
                label: '別の日付',
                selected: !_useToday,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _useToday = false;
                      _pickedDate = picked;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        if (displayDate != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.softGray,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              _fmtDate(displayDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Pressable(
          onTap: _exporting ? null : _export,
          scale: 0.97,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.canvas,
                      ),
                    )
                  : const Text(
                      'カレンダーにエクスポート',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.canvas,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: _showTextShareDialog,
          scale: 0.97,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.darkSurface),
            ),
            child: const Center(
              child: Text(
                'テキストで共有',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: _showImageShareDialog,
          scale: 0.97,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.darkSurface),
            ),
            child: const Center(
              child: Text(
                '画像で共有',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 小部品
// ---------------------------------------------------------------------------

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: selected ? AppColors.darkSurface : AppColors.softGray,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.canvas : AppColors.mutedInk,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text Share Dialog
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Calendar Export Preview Dialog
// ---------------------------------------------------------------------------

class _CalendarExportPreviewDialog extends StatelessWidget {
  const _CalendarExportPreviewDialog({
    required this.preview,
    required this.targetTitle,
  });

  final CalendarExportPreview preview;
  final String targetTitle;

  String _fmtDateTime(DateTime dt) {
    final l = dt.toLocal();
    final date =
        '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
    final time =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'カレンダー登録の確認',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkSurface,
                  ),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pop(false),
                  scale: 0.88,
                  child: Icon(
                    PhosphorIcons.x(),
                    size: 20,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PreviewRow(
              label: '開始',
              value: _fmtDateTime(preview.startDateTime),
            ),
            const SizedBox(height: 10),
            _PreviewRow(
              label: 'アンカー',
              value: '${_fmtDateTime(preview.anchorDateTime)} ・ $targetTitle',
            ),
            const SizedBox(height: 10),
            _PreviewRow(label: '件数', value: '${preview.eventCount}件'),
            if (preview.spansMultipleDays) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.info(),
                      size: 16,
                      color: AppColors.accentOlive,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '開始日とアンカー日が異なります。日付をまたいで登録されます。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
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
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkSurface,
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
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child: Text(
                          '登録する',
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Text Share Dialog
// ---------------------------------------------------------------------------

class _TextShareDialog extends StatefulWidget {
  const _TextShareDialog({
    required this.state,
    required this.useToday,
    this.pickedDate,
  });

  final TimelineState state;
  final bool useToday;
  final DateTime? pickedDate;

  @override
  State<_TextShareDialog> createState() => _TextShareDialogState();
}

class _TextShareDialogState extends State<_TextShareDialog> {
  TimelineTextExportMode _mode = TimelineTextExportMode.noDate;

  @override
  Widget build(BuildContext context) {
    final baseDate = widget.useToday ? DateTime.now() : widget.pickedDate;
    final needDate = _mode != TimelineTextExportMode.noDate;
    final dateReady = baseDate != null;

    final text = needDate && !dateReady
        ? null
        : generateTimelineText(
            TimelineTextExportRequest(
              state: widget.state,
              mode: _mode,
              baseDate: needDate ? baseDate : null,
            ),
          );

    return Dialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'テキストで共有',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkSurface,
                  ),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.88,
                  child: Icon(
                    PhosphorIcons.x(),
                    size: 20,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '形式',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: '日付なし',
                    selected: _mode == TimelineTextExportMode.noDate,
                    onTap: () =>
                        setState(() => _mode = TimelineTextExportMode.noDate),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleChip(
                    label: '日にちあり',
                    selected: _mode == TimelineTextExportMode.withDate,
                    onTap: () =>
                        setState(() => _mode = TimelineTextExportMode.withDate),
                  ),
                ),
              ],
            ),
            if (needDate && !dateReady) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  'エクスポート日を「今日」または「別の日付」で選択してください。',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.ink,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: text == null
                        ? null
                        : () async {
                            await _textExportDelivery.copyToClipboard(text);
                            if (!mounted) return;
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('コピーしました'),
                                backgroundColor: AppColors.darkSurface,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 2),
                                elevation: 0,
                              ),
                            );
                          },
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.copy(),
                              size: 16,
                              color: AppColors.darkSurface,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'コピー',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pressable(
                    onTap: text == null
                        ? null
                        : () async {
                            await _textExportDelivery.share(
                              text,
                              context: context,
                            );
                          },
                    scale: 0.97,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              PhosphorIcons.export(),
                              size: 16,
                              color: AppColors.canvas,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '共有',
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
// Image Share Dialog
// ---------------------------------------------------------------------------

class _ImageShareDialog extends StatefulWidget {
  const _ImageShareDialog({
    required this.state,
    required this.useToday,
    this.pickedDate,
  });

  final TimelineState state;
  final bool useToday;
  final DateTime? pickedDate;

  @override
  State<_ImageShareDialog> createState() => _ImageShareDialogState();
}

class _ImageShareDialogState extends State<_ImageShareDialog> {
  final GlobalKey _captureKey = GlobalKey();
  TimelineImageExportMode _mode = TimelineImageExportMode.noDate;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final baseDate = widget.useToday ? DateTime.now() : widget.pickedDate;
    final needDate = _mode != TimelineImageExportMode.noDate;
    final dateReady = baseDate != null;

    final viewModel = needDate && !dateReady
        ? null
        : buildTimelineImageExportViewModel(
            widget.state,
            mode: _mode,
            baseDate: needDate ? baseDate : null,
          );

    final eventCount = viewModel?.events.length ?? 0;
    final isLongTimeline = eventCount > 50;

    return Dialog(
      backgroundColor: AppColors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.90,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  '画像で共有',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkSurface,
                  ),
                ),
                const Spacer(),
                Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.88,
                  child: Icon(
                    PhosphorIcons.x(),
                    size: 20,
                    color: AppColors.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '形式',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: '日付なし',
                    selected: _mode == TimelineImageExportMode.noDate,
                    onTap: () =>
                        setState(() => _mode = TimelineImageExportMode.noDate),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleChip(
                    label: '日にちあり',
                    selected: _mode == TimelineImageExportMode.withDate,
                    onTap: () => setState(
                      () => _mode = TimelineImageExportMode.withDate,
                    ),
                  ),
                ),
              ],
            ),
            if (needDate && !dateReady) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softGray,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Text(
                  'エクスポート日を「今日」または「別の日付」で選択してください。',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedInk),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: TimelineImageShareCard(viewModel: viewModel!),
                        ),
                      ),
                      if (isLongTimeline) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.softGray,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.info(),
                                size: 16,
                                color: AppColors.accentOlive,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'タイムラインが長いため、画像サイズが大きくなる可能性があります。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.ink,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Pressable(
              onTap: _sharing || viewModel == null
                  ? null
                  : () async {
                      setState(() => _sharing = true);
                      try {
                        final bytes = await _imageExportDelivery.capturePng(
                          _captureKey,
                        );
                        if (!mounted) return;
                        await _imageExportDelivery.sharePng(
                          bytes,
                          // ignore: use_build_context_synchronously
                          context: context,
                        );
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                      } catch (e, st) {
                        debugPrint('Image share error: $e\n$st');
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('画像の共有に失敗しました'),
                            backgroundColor: Color(0xFFB54A4A),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                            elevation: 0,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _sharing = false);
                      }
                    },
              scale: 0.97,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: _sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.canvas,
                          ),
                        )
                      : const Text(
                          '共有',
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
        ),
      ),
    );
  }
}
