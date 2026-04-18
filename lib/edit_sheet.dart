import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

class EditSheet extends ConsumerStatefulWidget {
  const EditSheet({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  ConsumerState<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<EditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _targetTimeCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _durationCtrl = TextEditingController();
    _targetTimeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _targetTimeCtrl.dispose();
    super.dispose();
  }

  void _syncBlockControllers(Block selected) {
    if (_titleCtrl.text != selected.title) {
      _titleCtrl.value = _titleCtrl.value.copyWith(text: selected.title);
    }
    if (selected.type == BlockType.action) {
      final ds = selected.duration.toString();
      if (_durationCtrl.text != ds) _durationCtrl.text = ds;
    }
  }

  void _syncTargetControllers(String targetTitle, int targetTime) {
    if (_titleCtrl.text != targetTitle) {
      _titleCtrl.value = _titleCtrl.value.copyWith(text: targetTitle);
    }
    final formatted = formatTime(targetTime);
    if (_targetTimeCtrl.text != formatted) {
      _targetTimeCtrl.value = _targetTimeCtrl.value.copyWith(text: formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final notifier = ref.read(timelineProvider.notifier);
    final isTarget = state.selectedBlockId == kTargetTimeId;
    final selected = isTarget
        ? null
        : state.blocks
            .where((b) => b.id == state.selectedBlockId)
            .firstOrNull;

    if (isTarget) {
      _syncTargetControllers(state.targetTimeTitle, state.targetTime);
    } else if (selected != null) {
      _syncBlockControllers(selected);
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ドラッグハンドル ──────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.stone300,
                  borderRadius: BorderRadius.circular(2),
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
                        color: AppColors.stone900,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.stone100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: AppColors.stone500),
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
                    color: AppColors.stone800,
                  ),
                  onChanged: (v) {
                    if (isTarget) {
                      notifier.setTargetTimeTitle(v);
                    } else if (selected != null) {
                      notifier.updateBlock(
                          selected.id, (b) => b.copyWith(title: v));
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: AppColors.stone800,
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.datetime,
                    onChanged: (v) {
                      final parts = v.split(':');
                      if (parts.length == 2) {
                        final h = int.tryParse(parts[0]);
                        final m = int.tryParse(parts[1]);
                        if (h != null &&
                            m != null &&
                            h >= 0 &&
                            h < 24 &&
                            m >= 0 &&
                            m < 60) {
                          notifier.setTargetTime(h * 60 + m);
                        }
                      }
                    },
                  ),
                ],

                // ── ブロックモード専用: 所要時間 ──────────────────────────
                if (!isTarget && selected != null &&
                    selected.type == BlockType.action) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel('所要時間'),
                  const SizedBox(height: 6),
                  _DurationStepper(
                    controller: _durationCtrl,
                    onDecrement: () => notifier.updateBlock(
                      selected.id,
                      (b) => b.copyWith(
                          duration: (b.duration - 5).clamp(5, 9999)),
                    ),
                    onIncrement: () => notifier.updateBlock(
                      selected.id,
                      (b) => b.copyWith(duration: b.duration + 5),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 5) {
                        notifier.updateBlock(
                            selected.id, (b) => b.copyWith(duration: n));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.stone400,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.style,
    this.textAlign = TextAlign.start,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String placeholder;
  final void Function(String) onChanged;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.stone100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: textAlign,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: placeholder,
          hintStyle: const TextStyle(color: AppColors.stone400),
        ),
        style: style,
      ),
    );
  }
}

/// 統合型所要時間ステッパー: [ − | value 分 | + ]
class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.controller,
    required this.onDecrement,
    required this.onIncrement,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.stone100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDecrement,
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Icon(Icons.remove_rounded,
                    size: 20, color: AppColors.stone500),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.stone300),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    onChanged: onChanged,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppColors.stone800,
                    ),
                  ),
                ),
                const Text(
                  '分',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.stone400,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.stone300),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onIncrement,
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: Icon(Icons.add_rounded, size: 20, color: AppColors.stone500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


