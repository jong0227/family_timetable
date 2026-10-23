import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../../../domain/timetable_logic.dart';
import 'week_grid.dart';

/// 주간 시간표(시간 비례 보기). 세로축이 실제 시각이라 칸 높이 = 수업 길이,
/// 칸 사이 빈칸 = 빈 시간이 그대로 보인다. 같은 시간에 겹치는 일정은 나란히 놓는다([assignLanes]).
///
/// 1분 = [_pxPerMinute]픽셀. 40분 수업이 44px 정도라 시작 시각 + 과목 두 줄이 들어간다.
/// 축은 일정이 있는 시간대만(가장 이른 시작 ~ 가장 늦은 끝, 정시로 반올림) 그린다.
class TimeScaleGrid extends StatelessWidget {
  final List<Entry> entries;
  final List<int> weekdays;
  final ValueChanged<Entry>? onTapEntry;
  final ValueChanged<int>? onTapDay;

  const TimeScaleGrid({
    super.key,
    required this.entries,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.onTapEntry,
    this.onTapDay,
  });

  static const _pxPerMinute = 1.1;
  static const _gutter = 30.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final shown = entries.where((e) => weekdays.contains(e.weekday)).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    final first = shown.map((e) => e.start).reduce((a, b) => a < b ? a : b);
    final last = shown.map((e) => e.end).reduce((a, b) => a > b ? a : b);
    final axisStart = (first ~/ 60) * 60;
    final axisEnd = ((last + 59) ~/ 60) * 60;
    final height = (axisEnd - axisStart) * _pxPerMinute;
    double y(int minutes) => (minutes - axisStart) * _pxPerMinute;
    final nowMinutes = now.hour * 60 + now.minute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: _gutter),
            for (var i = 0; i < weekdays.length; i++) ...[
              if (i > 0) const SizedBox(width: AppGap.xs),
              Expanded(
                child: WeekdayHeader(
                  weekday: weekdays[i],
                  isToday: weekdays[i] == now.weekday,
                  onTap: onTapDay == null ? null : () => onTapDay!(weekdays[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppGap.sm),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시각 눈금(정시마다)
              SizedBox(
                width: _gutter,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var m = axisStart; m <= axisEnd; m += 60)
                      Positioned(
                        top: y(m) - 6,
                        left: 0,
                        child: Text(
                          '${m ~/ 60}',
                          style: AppFonts.numeric(size: AppText.micro, weight: FontWeight.w500, color: p.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < weekdays.length; i++) ...[
                if (i > 0) const SizedBox(width: AppGap.xs),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final day = shown.where((e) => e.weekday == weekdays[i]).toList();
                      final lanes = assignLanes(day);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 정시 가로줄
                          for (var m = axisStart; m <= axisEnd; m += 60)
                            Positioned(
                              top: y(m),
                              left: 0,
                              right: 0,
                              child: Container(height: 1, color: p.status.neutral.withValues(alpha: 0.5)),
                            ),
                          for (final e in day)
                            () {
                              final slot = lanes[e.id]!;
                              final w = c.maxWidth / slot.lanes;
                              return Positioned(
                                top: y(e.start) + 1,
                                height: (e.end - e.start) * _pxPerMinute - 2,
                                left: w * slot.lane,
                                width: w - (slot.lanes > 1 ? 1 : 0),
                                child: _Block(entry: e, onTap: onTapEntry == null ? null : () => onTapEntry!(e)),
                              );
                            }(),
                          // 오늘 열에 지금 시각 선
                          if (weekdays[i] == now.weekday && nowMinutes > axisStart && nowMinutes < axisEnd)
                            Positioned(
                              top: y(nowMinutes) - 1,
                              left: 0,
                              right: 0,
                              child: Container(height: 2, color: p.status.urgent),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 시간 비례 칸. 높이가 정해져 있어서 들어가는 만큼만 보여준다:
/// 넉넉하면 시각 + 이름 + 끝 시각, 보통이면 시각 + 이름, 아주 얇으면 이름만.
class _Block extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;

  const _Block({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = context.palette.kind(entry.kind);
    final school = entry.kind == EntryKind.school && entry.period != null;
    final label = school ? '${entry.period}교시' : formatMinutes(entry.start);
    return Semantics(
      button: onTap != null,
      label: '${weekdayLabel(entry.weekday)} ${entry.timeText} ${entry.kind.label} ${entry.title}',
      child: Material(
        color: tone.container,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, c) {
              final timeStyle = AppFonts.numeric(size: AppText.micro, weight: FontWeight.w600, color: tone.onContainer);
              final titleStyle = TextStyle(
                fontSize: AppText.caption,
                fontWeight: FontWeight.w700,
                color: tone.onContainer,
                height: 1.2,
              );
              final h = c.maxHeight;
              return Padding(
                padding: EdgeInsets.fromLTRB(5, h < 24 ? 1 : 3, 3, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h >= 30) Text(label, style: timeStyle, maxLines: 1, overflow: TextOverflow.clip),
                    Flexible(
                      child: Text(
                        shortTitle(entry.title),
                        maxLines: h >= 56 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    if (!school && h >= 56) ...[
                      const Spacer(),
                      Text('~${formatMinutes(entry.end)}', style: timeStyle, maxLines: 1),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
