import 'package:flutter/material.dart';

import 'theme.dart';
import 'timeline_image_export.dart';

/// タイムライン共有専用の画像カード Widget。
///
/// [RepaintBoundary] で囲んで [RenderRepaintBoundary.toImage] により
/// PNG としてキャプチャすることを想定している。
class TimelineImageShareCard extends StatelessWidget {
  const TimelineImageShareCard({super.key, required this.viewModel});

  final TimelineImageExportViewModel viewModel;

  static const double _cardWidth = 320;
  static const double _timeColumnWidth = 72;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      color: AppColors.canvas,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Medo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOlive,
                  letterSpacing: 0.4,
                ),
              ),
              const Text(
                ' // ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedInk,
                ),
              ),
              Expanded(
                child: Text(
                  viewModel.targetTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Metadata
          Text(
            viewModel.metadataText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 16),
          // Divider
          Container(height: 1, color: AppColors.softGray),
          const SizedBox(height: 16),
          // Events
          for (var i = 0; i < viewModel.events.length; i++) ...[
            _buildEvent(
              viewModel.events[i],
              isLast: i == viewModel.events.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvent(TimelineImageExportEvent event, {required bool isLast}) {
    switch (event.type) {
      case TimelineImageExportEventType.action:
        return _buildAction(event);
      case TimelineImageExportEventType.actionPoint:
        return _buildPoint(event, isLast: isLast);
      case TimelineImageExportEventType.targetAnchor:
        return _buildAnchor(event);
    }
  }

  Widget _buildAction(TimelineImageExportEvent event) {
    final color = event.colorIndex >= 0
        ? AppColors.blockColors[event.colorIndex % AppColors.blockColors.length]
        : AppColors.mutedInk;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _timeColumnWidth,
          child: Text(
            event.timeText,
            style: AppTextStyles.time(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                if (event.durationMinutes != null && event.durationMinutes! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${event.durationMinutes}分',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                if (event.bufferMinutes > 0) ...[
                  const SizedBox(height: 6),
                  _DottedDivider(
                    color: AppColors.timelineLine.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '余裕 +${event.bufferMinutes}分',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedInk.withValues(alpha: 0.7),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoint(TimelineImageExportEvent event, {required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _timeColumnWidth,
          child: Text(
            event.timeText,
            style: AppTextStyles.time(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.mutedInk,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            event.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnchor(TimelineImageExportEvent event) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _timeColumnWidth,
          child: Text(
            event.timeText,
            style: AppTextStyles.time(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accentOlive,
            ),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.accentOlive,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TARGET',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.accentOlive,
                ),
              ),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 擬似点線 — 本体とバッファセグメントの境目を「くっついている感じ」で示す
class _DottedDivider extends StatelessWidget {
  const _DottedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotWidth = 3.0;
        const gapWidth = 3.0;
        final count =
            (constraints.maxWidth / (dotWidth + gapWidth))
                .floor()
                .clamp(1, 200);
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Container(width: dotWidth, height: 1, color: color),
              if (i < count - 1) const SizedBox(width: gapWidth),
            ],
          ],
        );
      },
    );
  }
}
