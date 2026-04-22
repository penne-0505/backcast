import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

/// 固定高さ row でタイムライン全体を一覧する compact overview view.
class CompactOverviewView extends ConsumerStatefulWidget {
  const CompactOverviewView({super.key});

  @override
  ConsumerState<CompactOverviewView> createState() =>
      _CompactOverviewViewState();
}

class _CompactOverviewViewState extends ConsumerState<CompactOverviewView> {
  String? _selectedId;

  void _select(String? id) {
    setState(() => _selectedId = id);
  }

  void _returnToEdit(String? id) {
    final notifier = ref.read(timelineProvider.notifier);
    notifier.selectBlock(id);
    notifier.setViewMode(TimelineViewMode.edit);
  }

  void _moveBlock(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= ref.read(timelineProvider).blocks.length) {
      return;
    }
    ref.read(timelineProvider.notifier).moveBlockByIndex(fromIndex, toIndex);
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    }
    return '$minutes分';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(timelineProvider);
    final computed = ref.watch(computedBlocksProvider);
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    // 現在時刻がタイムライン範囲内か判定
    final timelineStart = computed.isEmpty
        ? state.targetTime
        : computed.first.startTime;
    final timelineEnd = state.targetTime;
    final isNowInRange = nowMinutes >= timelineStart && nowMinutes <= timelineEnd;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 28, 16),
            itemCount: computed.length + 1, // +1 for target anchor
            itemBuilder: (context, index) {
              if (index < computed.length) {
                final cb = computed[index];
                final block = cb.block;
                final isSelected = _selectedId == block.id;
                final color = AppColors
                    .blockColors[block.colorIndex % AppColors.blockColors.length];
                return _CompactOverviewRow(
                  symbol: block.type == BlockType.action ? '┃' : '●',
                  timeRange: block.type == BlockType.action
                      ? '${formatTime(cb.startTime)}–${formatTime(cb.endTime)}'
                      : formatTime(cb.startTime),
                  title: block.title,
                  trailing: block.type == BlockType.action
                      ? _formatDuration(block.duration)
                      : 'point',
                  color: color,
                  isSelected: isSelected,
                  onTap: () => _select(isSelected ? null : block.id),
                  onDoubleTap: () => _returnToEdit(block.id),
                  onMoveUp: index > 0 ? () => _moveBlock(index, index - 1) : null,
                  onMoveDown: index < state.blocks.length - 1
                      ? () => _moveBlock(index, index + 1)
                      : null,
                  isNowIndicator: isNowInRange &&
                      nowMinutes >= cb.startTime &&
                      nowMinutes <= cb.endTime,
                );
              } else {
                // Target anchor (last row)
                final isSelected = _selectedId == kTargetTimeId;
                return _CompactOverviewRow(
                  symbol: '◆',
                  timeRange: formatTime(state.targetTime),
                  title: state.targetTimeTitle,
                  trailing: 'target',
                  color: AppColors.accentOlive,
                  isSelected: isSelected,
                  onTap: () => _select(isSelected ? null : kTargetTimeId),
                  onDoubleTap: () => _returnToEdit(kTargetTimeId),
                  onMoveUp: state.blocks.isNotEmpty
                      ? () {} // target anchor cannot move; button disabled visually
                      : null,
                  onMoveDown: null,
                  isNowIndicator: false,
                );
              }
            },
          ),
        ),
        // Bottom action bar when something is selected
        if (_selectedId != null)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 28, 16),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border(
                top: BorderSide(color: AppColors.softGray.withValues(alpha: 0.5)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => _returnToEdit(_selectedId),
                      scale: 0.97,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accentOlive,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit,
                              size: 18,
                              color: AppColors.canvas,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '編集ビューへ',
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
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactOverviewRow extends StatelessWidget {
  const _CompactOverviewRow({
    required this.symbol,
    required this.timeRange,
    required this.title,
    required this.trailing,
    required this.color,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onMoveUp,
    this.onMoveDown,
    this.isNowIndicator = false,
  });

  final String symbol;
  final String timeRange;
  final String title;
  final String trailing;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool isNowIndicator;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        height: 58,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cardBackgroundSelected
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isSelected ? AppShadows.cardSelected : AppShadows.card,
          border: isNowIndicator
              ? Border.all(color: AppColors.accentOlive, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              // Symbol or color stripe
              SizedBox(
                width: 20,
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Time range
              SizedBox(
                width: 96,
                child: Text(
                  timeRange,
                  style: AppTextStyles.time(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedInk,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Trailing (duration / point / target)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                // Move up
                if (onMoveUp != null)
                  _IconButton(
                    icon: PhosphorIcons.caretUp(),
                    onTap: onMoveUp!,
                  )
                else
                  const SizedBox(width: 32),
                // Move down
                if (onMoveDown != null)
                  _IconButton(
                    icon: PhosphorIcons.caretDown(),
                    onTap: onMoveDown!,
                  )
                else
                  const SizedBox(width: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.85,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: AppColors.mutedInk,
          ),
        ),
      ),
    );
  }
}
