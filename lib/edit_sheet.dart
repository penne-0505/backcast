import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'billing/gate_helper.dart';
import 'billing/paywall_screen.dart';
import 'models.dart';
import 'platform_time_picker.dart';
import 'state.dart';
import 'theme.dart';

class EditSheet extends ConsumerStatefulWidget {
  const EditSheet({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  ConsumerState<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<EditSheet>
    with SingleTickerProviderStateMixin {
  static const double _dismissDragThreshold = 96;
  static const double _dismissVelocityThreshold = 700;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _bufferCtrl;
  late final TextEditingController _targetTimeCtrl;
  late final FocusNode _durationFocusNode;
  late final FocusNode _bufferFocusNode;
  late final AnimationController _dragAnimationController;
  String? _lastSyncedBlockId;
  double _dismissDragOffset = 0;
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _durationCtrl = TextEditingController();
    _bufferCtrl = TextEditingController();
    _targetTimeCtrl = TextEditingController();
    _durationFocusNode = FocusNode();
    _bufferFocusNode = FocusNode();
    _dragAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _durationFocusNode.addListener(_onDurationFocusLost);
    _bufferFocusNode.addListener(_onBufferFocusLost);
  }

  @override
  void dispose() {
    _durationFocusNode.removeListener(_onDurationFocusLost);
    _bufferFocusNode.removeListener(_onBufferFocusLost);
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _bufferCtrl.dispose();
    _targetTimeCtrl.dispose();
    _durationFocusNode.dispose();
    _bufferFocusNode.dispose();
    _dragAnimationController.dispose();
    super.dispose();
  }

  void _onDurationFocusLost() {
    if (!_durationFocusNode.hasFocus) {
      final state = ref.read(timelineProvider);
      final selected = state.selectedBlockId == kTargetTimeId
          ? null
          : state.blocks
                .where((b) => b.id == state.selectedBlockId)
                .firstOrNull;
      if (selected != null && selected.type == BlockType.action) {
        final ds = selected.duration.toString();
        if (_durationCtrl.text != ds) _durationCtrl.text = ds;
      }
    }
  }

  void _onBufferFocusLost() {
    if (!_bufferFocusNode.hasFocus) {
      final state = ref.read(timelineProvider);
      final selected = state.selectedBlockId == kTargetTimeId
          ? null
          : state.blocks
                .where((b) => b.id == state.selectedBlockId)
                .firstOrNull;
      if (selected != null && selected.type == BlockType.action) {
        final bs = selected.normalizedBufferMinutes.toString();
        if (_bufferCtrl.text != bs) _bufferCtrl.text = bs;
      }
    }
  }

  void _syncBlockControllers(Block selected) {
    if (_titleCtrl.text != selected.title) {
      _titleCtrl.text = selected.title;
    }
    if (selected.type == BlockType.action && !_durationFocusNode.hasFocus) {
      final ds = selected.duration.toString();
      if (_durationCtrl.text != ds) _durationCtrl.text = ds;
    }
    if (selected.type == BlockType.action && !_bufferFocusNode.hasFocus) {
      final bs = selected.normalizedBufferMinutes.toString();
      if (_bufferCtrl.text != bs) _bufferCtrl.text = bs;
    }
  }

  void _syncTargetControllers(String targetTitle, int targetTime) {
    if (_titleCtrl.text != targetTitle) {
      _titleCtrl.text = targetTitle;
    }
    final formatted = formatTime(targetTime);
    if (_targetTimeCtrl.text != formatted) {
      _targetTimeCtrl.text = formatted;
    }
  }

  bool _needsBlockControllerSync(Block selected) {
    if (_titleCtrl.text != selected.title) return true;
    if (selected.type == BlockType.action && !_durationFocusNode.hasFocus) {
      if (_durationCtrl.text != selected.duration.toString()) return true;
    }
    if (selected.type == BlockType.action && !_bufferFocusNode.hasFocus) {
      if (_bufferCtrl.text != selected.normalizedBufferMinutes.toString()) {
        return true;
      }
    }
    return false;
  }

  bool _needsTargetControllerSync(String targetTitle, int targetTime) {
    return _titleCtrl.text != targetTitle ||
        _targetTimeCtrl.text != formatTime(targetTime);
  }

  void _queueControllerSync({
    required bool isTarget,
    required TimelineState state,
    required Block? selected,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isTarget) {
        _syncTargetControllers(state.targetTimeTitle, state.targetTime);
      } else if (selected != null) {
        _syncBlockControllers(selected);
      }
    });
  }

  Future<void> _pickTargetTime(int currentTargetTime) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final pickedMinutes = await showPlatformTimePicker(
      context,
      initialMinutes: currentTargetTime,
    );
    if (!mounted || pickedMinutes == null) return;

    ref.read(timelineProvider.notifier).setTargetTime(pickedMinutes);
  }

  void _showActionBufferPaywall() {
    final proAccess = ref.read(effectiveProAccessProvider);
    if (proAccess.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認しています。少し待ってから再試行してください。')),
      );
      return;
    }
    if (proAccess.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('課金状態を確認できませんでした。通信状態を確認してください。')),
      );
      return;
    }
    if (!proAccess.isFree) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const PaywallScreen(feature: PaywallFeature.actionBuffer),
      ),
    );
  }

  void _handleDismissDragUpdate(DragUpdateDetails details) {
    if (_dismissScheduled) return;
    _dragAnimationController.stop();
    final nextOffset = _dismissDragOffset + (details.primaryDelta ?? 0);
    setState(() => _dismissDragOffset = nextOffset.clamp(0.0, double.infinity));
  }

  void _handleDismissDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dismissDragOffset >= _dismissDragThreshold ||
        velocity >= _dismissVelocityThreshold) {
      _animateDismiss();
      return;
    }
    _animateDragOffset(to: 0);
  }

  void _handleDismissDragCancel() {
    if (_dismissScheduled) return;
    _animateDragOffset(to: 0);
  }

  Future<void> _animateDragOffset({required double to}) async {
    final animation = Tween<double>(begin: _dismissDragOffset, end: to).animate(
      CurvedAnimation(parent: _dragAnimationController, curve: Curves.easeOut),
    );
    void updateOffset() {
      if (mounted) setState(() => _dismissDragOffset = animation.value);
    }

    _dragAnimationController
      ..stop()
      ..reset();
    animation.addListener(updateOffset);
    try {
      await _dragAnimationController.forward();
    } finally {
      animation.removeListener(updateOffset);
    }
  }

  Future<void> _animateDismiss() async {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    final height = MediaQuery.of(context).size.height;
    await _animateDragOffset(to: height);
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final notifier = ref.read(timelineProvider.notifier);
    final proAccess = ref.watch(effectiveProAccessProvider);
    final isPro = proAccess.isPro;
    final isTarget = state.selectedBlockId == kTargetTimeId;
    final selected = isTarget
        ? null
        : state.blocks.where((b) => b.id == state.selectedBlockId).firstOrNull;
    final maxSelectedBufferMinutes =
        selected != null && selected.type == BlockType.action
        ? maxActionBufferMinutesForDuration(selected.duration)
        : 0;

    if (state.selectedBlockId != _lastSyncedBlockId) {
      _lastSyncedBlockId = state.selectedBlockId;
      _queueControllerSync(
        isTarget: isTarget,
        state: state,
        selected: selected,
      );
    } else if (isTarget &&
        _needsTargetControllerSync(state.targetTimeTitle, state.targetTime)) {
      _queueControllerSync(
        isTarget: isTarget,
        state: state,
        selected: selected,
      );
    } else if (selected != null && _needsBlockControllerSync(selected)) {
      _queueControllerSync(
        isTarget: isTarget,
        state: state,
        selected: selected,
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Transform.translate(
      offset: Offset(0, _dismissDragOffset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppShadows.workSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ドラッグハンドル ──────────────────────────────────────────
            GestureDetector(
              key: const ValueKey('edit-sheet-drag-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _handleDismissDragUpdate,
              onVerticalDragEnd: _handleDismissDragEnd,
              onVerticalDragCancel: _handleDismissDragCancel,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 8),
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
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── ヘッダー ─────────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        isTarget ? '目標を編集' : '行動を編集',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.darkSurface,
                        ),
                      ),
                      const Spacer(),
                      if (!isTarget && selected != null) ...[
                        Pressable(
                          onTap: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) =>
                                  _DeleteConfirmDialog(title: selected.title),
                            );
                            if (confirmed == true) {
                              notifier.deleteBlock(selected.id);
                              widget.onDismiss();
                            }
                          },
                          scale: 0.88,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.softGray,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              PhosphorIcons.trash(),
                              size: 16,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 16,
                          color: AppColors.accentDivider,
                        ),
                        const SizedBox(width: 12),
                      ],
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
                  const SizedBox(height: 20),

                  // ── 名前フィールド ────────────────────────────────────────
                  _SectionLabel(isTarget ? '目標名' : '行動名'),
                  const SizedBox(height: 6),
                  _StyledField(
                    controller: _titleCtrl,
                    placeholder: isTarget ? '目標を入力...' : '行動を入力...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.ink,
                    ),
                    onChanged: (v) {
                      if (isTarget) {
                        notifier.setTargetTimeTitle(v);
                      } else if (selected != null) {
                        notifier.updateBlock(
                          selected.id,
                          (b) => b.copyWith(title: v),
                        );
                      }
                    },
                  ),

                  // ── 目標モード専用: 時刻 ──────────────────────────────────
                  if (isTarget) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('目標時刻'),
                    const SizedBox(height: 6),
                    _StyledField(
                      controller: _targetTimeCtrl,
                      placeholder: '13:00',
                      style: AppTextStyles.time(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.6,
                      ),
                      textAlign: TextAlign.center,
                      readOnly: true,
                      onTap: () => _pickTargetTime(state.targetTime),
                    ),
                  ],

                  // ── ブロックモード専用: 所要時間 ──────────────────────────
                  if (!isTarget &&
                      selected != null &&
                      selected.type == BlockType.action) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('所要時間'),
                    const SizedBox(height: 6),
                    _DurationStepper(
                      controller: _durationCtrl,
                      focusNode: _durationFocusNode,
                      unitLabel: '分',
                      canDecrement: selected.duration > 5,
                      canIncrement: true,
                      onDecrement: () => notifier.updateBlock(
                        selected.id,
                        (b) => b.copyWith(
                          duration: (b.duration - 5).clamp(5, 9999),
                        ),
                      ),
                      onIncrement: () => notifier.updateBlock(
                        selected.id,
                        (b) => b.copyWith(duration: b.duration + 5),
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 5) {
                          notifier.updateBlock(
                            selected.id,
                            (b) => b.copyWith(duration: n),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel('余裕時間'),
                    const SizedBox(height: 6),
                    if (isPro) ...[
                      _DurationStepper(
                        controller: _bufferCtrl,
                        focusNode: _bufferFocusNode,
                        canDecrement: selected.normalizedBufferMinutes > 0,
                        canIncrement:
                            selected.normalizedBufferMinutes <
                            maxSelectedBufferMinutes,
                        fillColor: AppColors
                            .blockColors[selected.colorIndex %
                                AppColors.blockColors.length]
                            .withValues(alpha: 0.08),
                        borderRadius: AppRadius.pill,
                        onDecrement: () => notifier.setActionBufferMinutes(
                          selected.id,
                          selected.normalizedBufferMinutes - kBufferStepMinutes,
                        ),
                        onIncrement: () => notifier.setActionBufferMinutes(
                          selected.id,
                          selected.normalizedBufferMinutes + kBufferStepMinutes,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) {
                            final clamped = n.clamp(
                              0,
                              maxSelectedBufferMinutes,
                            );
                            final normalized =
                                normalizeActionBufferMinutesForDuration(
                                  BlockType.action,
                                  selected.duration,
                                  clamped,
                                );
                            if (normalized != n) {
                              _bufferCtrl.text = normalized.toString();
                            }
                            notifier.setActionBufferMinutes(
                              selected.id,
                              normalized,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '0〜$maxSelectedBufferMinutes分の範囲で5分単位で設定できます',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedInk.withValues(alpha: 0.7),
                        ),
                      ),
                    ] else
                      _LockedBufferControl(
                        minutes: selected.normalizedBufferMinutes,
                        onTap: _showActionBufferPaywall,
                      ),
                  ],

                  // ── ブロックモード専用: カラー ────────────────────────────
                  if (!isTarget && selected != null) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('カラー'),
                    const SizedBox(height: 10),
                    _ColorPicker(
                      selectedIndex:
                          selected.colorIndex % AppColors.blockColors.length,
                      onSelect: (i) => notifier.updateBlock(
                        selected.id,
                        (b) => b.copyWith(colorIndex: i),
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
// リーフウィジェット
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.label);
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.style,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String placeholder;
  final void Function(String)? onChanged;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: !readOnly,
        onTap: onTap,
        onChanged: onChanged,
        textAlign: textAlign,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: placeholder,
          hintStyle: const TextStyle(color: AppColors.mutedInk),
        ),
        style: style,
      ),
    );
  }
}

/// 統合型所要時間ステッパー: [ − | value 分 | + ]
class _DurationStepper extends StatefulWidget {
  const _DurationStepper({
    required this.controller,
    required this.focusNode,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
    this.canDecrement = true,
    this.canIncrement = true,
    this.fillColor,
    this.borderRadius = AppRadius.sm,
    this.unitLabel = '分',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final void Function(String) onChanged;
  final bool canDecrement;
  final bool canIncrement;
  final Color? fillColor;
  final double borderRadius;
  final String unitLabel;

  @override
  State<_DurationStepper> createState() => _DurationStepperState();
}

class _DurationStepperState extends State<_DurationStepper> {
  Timer? _repeatTimer;
  bool _shakeLeft = false;
  bool _shakeRight = false;

  void _onTapDecrement() {
    if (widget.canDecrement) {
      widget.onDecrement();
    } else {
      _triggerShakeLeft();
    }
  }

  void _onTapIncrement() {
    if (widget.canIncrement) {
      widget.onIncrement();
    } else {
      _triggerShakeRight();
    }
  }

  void _startRepeatDecrement() {
    _onTapDecrement();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!widget.canDecrement) {
        _stopRepeat();
        return;
      }
      widget.onDecrement();
    });
  }

  void _startRepeatIncrement() {
    _onTapIncrement();
    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!widget.canIncrement) {
        _stopRepeat();
        return;
      }
      widget.onIncrement();
    });
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _triggerShakeLeft() {
    setState(() => _shakeLeft = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeLeft = false);
    });
  }

  void _triggerShakeRight() {
    setState(() => _shakeRight = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _shakeRight = false);
    });
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: widget.fillColor ?? AppColors.softGray,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Row(
        children: [
          ShakeWidget(
            shake: _shakeLeft,
            child: Pressable(
              behavior: HitTestBehavior.opaque,
              onTap: _onTapDecrement,
              onLongPressStart: widget.canDecrement
                  ? (_) => _startRepeatDecrement()
                  : null,
              onLongPressEnd: (_) => _stopRepeat(),
              scale: 0.85,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: Icon(
                    PhosphorIcons.minus(),
                    size: 20,
                    color: AppColors.accentOlive,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.accentDivider),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.focusNode.requestFocus(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onChanged: widget.onChanged,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    widget.unitLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.accentDivider),
          ShakeWidget(
            shake: _shakeRight,
            child: Pressable(
              behavior: HitTestBehavior.opaque,
              onTap: _onTapIncrement,
              onLongPressStart: widget.canIncrement
                  ? (_) => _startRepeatIncrement()
                  : null,
              onLongPressEnd: (_) => _stopRepeat(),
              scale: 0.85,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: Icon(
                    PhosphorIcons.plus(),
                    size: 20,
                    color: AppColors.accentOlive,
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

class _LockedBufferControl extends StatelessWidget {
  const _LockedBufferControl({required this.minutes, required this.onTap});

  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.softGray,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.accentDivider.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$minutes分',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
            ),
            Icon(PhosphorIcons.lockKey(), size: 18, color: AppColors.mutedInk),
            const SizedBox(width: 8),
            const Text(
              'Pro',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color Picker
// ---------------------------------------------------------------------------

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < AppColors.blockColors.length; i++)
          Pressable(
            onTap: () => onSelect(i),
            scale: 0.88,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.blockColors[i],
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: selectedIndex == i
                    ? Border.all(color: AppColors.ink, width: 2.5)
                    : Border.all(
                        color: AppColors.blockColors[i].withValues(alpha: 0.85),
                        width: 2,
                      ),
                boxShadow: selectedIndex == i ? AppShadows.cardSelected : null,
              ),
              child: selectedIndex == i
                  ? Icon(PhosphorIcons.check(), color: Colors.white, size: 16)
                  : null,
            ),
          ),
      ],
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
              title.isEmpty ? 'この行動' : '「$title」',
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
