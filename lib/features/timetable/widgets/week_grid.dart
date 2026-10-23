import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../../../domain/timetable_logic.dart';

/// 주간 시간표 격자. 종이 시간표처럼 두 부분으로 나눈다.
///
/// 1. 학교 교시 — 교시마다 한 줄로 **가로로 맞춘다**(월 3교시와 화 3교시가 같은 높이).
///    그 요일에 없는 교시는 빈칸.
/// 2. 방과 후 — 학원·활동·돌봄을 요일 열마다 시간순으로 쌓는다.
///
/// 시간 축에 비례해 칸 높이를 정하는 방식은 플립 좁은 화면에서 40분 칸이 너무 얇아져
/// 글자가 안 들어가서 쓰지 않았다. 시각은 칸 안에 숫자로 보여준다.
class WeekGrid extends StatelessWidget {
  final List<Entry> entries;
  final ChildTone tone;
  final List<int> weekdays;

  /// null이면 읽기 전용.
  final ValueChanged<Entry>? onTapEntry;

  /// 요일 머리를 누르면(그 요일에 일정 추가). null이면 비활성.
  final ValueChanged<int>? onTapDay;

  const WeekGrid({
    super.key,
    required this.entries,
    required this.tone,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.onTapEntry,
    this.onTapDay,
  });

  static const _periodRowHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = DateTime.now().weekday;
    final shown = entries.where((e) => weekdays.contains(e.weekday)).toList();
    final periods = {
      for (final e in shown)
        if (_isPeriod(e)) (e.weekday, e.period!): e,
    };
    final maxPeriod = periods.keys.fold(0, (m, k) => k.$2 > m ? k.$2 : m);
    List<Entry> afterSchool(int d) =>
        shown.where((e) => e.weekday == d && !_isPeriod(e)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final hasAfterSchool = weekdays.any((d) => afterSchool(d).isNotEmpty);

    Widget row(Widget Function(int weekday) cell) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < weekdays.length; i++) ...[
          if (i > 0) const SizedBox(width: AppGap.xs),
          Expanded(child: cell(weekdays[i])),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row((d) => _DayHeader(weekday: d, isToday: d == today, onTap: onTapDay == null ? null : () => onTapDay!(d))),
        const SizedBox(height: AppGap.snug),
        for (var period = 1; period <= maxPeriod; period++) ...[
          SizedBox(
            height: _periodRowHeight,
            child: row((d) {
              final e = periods[(d, period)];
              return e == null
                  ? const SizedBox.expand()
                  : _Cell(
                      entry: e,
                      label: '$period교시',
                      school: true,
                      tone: tone,
                      onTap: onTapEntry == null ? null : () => onTapEntry!(e),
                    );
            }),
          ),
          const SizedBox(height: AppGap.xs),
        ],
        if (hasAfterSchool) ...[
          if (maxPeriod > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 0, 6),
              child: Text(
                '방과 후',
                style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
              ),
            ),
          row(
            (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final e in afterSchool(d))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppGap.xs),
                    child: _Cell(
                      entry: e,
                      label: formatMinutes(e.start),
                      school: false,
                      tone: tone,
                      onTap: onTapEntry == null ? null : () => onTapEntry!(e),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static bool _isPeriod(Entry e) => e.kind == EntryKind.school && e.period != null;
}

class _DayHeader extends StatelessWidget {
  final int weekday;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayHeader({required this.weekday, required this.isToday, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToday ? p.dock : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          weekdayLabel(weekday),
          style: TextStyle(
            fontSize: AppText.label,
            fontWeight: FontWeight.w700,
            color: isToday ? p.onDock : p.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Entry entry;
  final String label;
  final bool school;
  final ChildTone tone;
  final VoidCallback? onTap;

  const _Cell({required this.entry, required this.label, required this.school, required this.tone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 학교 교시는 옅은 회색 칸, 방과 후 일정은 자녀색 칸 — 한눈에 구분된다.
    final bg = school ? p.surfaceMuted : tone.container;
    final fg = school ? null : tone.onContainer;
    return Semantics(
      button: onTap != null,
      label: '${weekdayLabel(entry.weekday)} $label ${entry.title}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 4, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppFonts.numeric(size: AppText.micro, weight: FontWeight.w600, color: fg ?? p.textMuted),
                ),
                Text(
                  shortTitle(entry.title),
                  maxLines: school ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.w700, color: fg, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
