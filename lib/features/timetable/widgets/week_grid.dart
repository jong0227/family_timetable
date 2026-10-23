import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../../../domain/timetable_logic.dart';

/// 주간 시간표 격자(간단히 보기). 종이 시간표처럼 두 부분으로 나눈다.
///
/// 1. 학교 교시 — 교시마다 한 줄로 **가로로 맞춘다**(월 3교시와 화 3교시가 같은 높이).
///    그 요일에 없는 교시는 빈칸.
/// 2. 방과 후 — 방과후·학원·활동·돌봄을 요일 열마다 시간순으로 쌓는다.
///
/// 칸 높이가 시간과 상관없어서 길이·간격은 안 보인다. 그건 [TimeScaleGrid](시간 비례)가 맡는다.
/// 칸 색은 일정 종류([AppPalette.kind]).
class WeekGrid extends StatelessWidget {
  final List<Entry> entries;
  final List<int> weekdays;

  /// null이면 읽기 전용.
  final ValueChanged<Entry>? onTapEntry;

  /// 요일 머리를 누르면(그 요일에 일정 추가). null이면 비활성.
  final ValueChanged<int>? onTapDay;

  const WeekGrid({
    super.key,
    required this.entries,
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
        row((d) => WeekdayHeader(weekday: d, isToday: d == today, onTap: onTapDay == null ? null : () => onTapDay!(d))),
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

/// 요일 머리(오늘은 검은 알약). 간단히/시간 비례 두 보기가 같이 쓴다.
class WeekdayHeader extends StatelessWidget {
  final int weekday;
  final bool isToday;
  final VoidCallback? onTap;

  const WeekdayHeader({super.key, required this.weekday, required this.isToday, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
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

/// 종류색 범례. 시간표에 실제로 있는 종류만, 정해진 순서(학교→방과후→학원…)로.
class KindLegend extends StatelessWidget {
  final Iterable<Entry> entries;
  const KindLegend({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final present = entries.map((e) => e.kind).toSet();
    final kinds = EntryKind.values.where(present.contains).toList();
    if (kinds.length < 2) return const SizedBox.shrink();
    return Wrap(
      spacing: AppGap.md,
      runSpacing: AppGap.xs,
      children: [
        for (final k in kinds)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: p.kind(k).accent, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: AppGap.xs),
              Text(
                k.label,
                style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
              ),
            ],
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final Entry entry;
  final String label;
  final bool school;
  final VoidCallback? onTap;

  const _Cell({required this.entry, required this.label, required this.school, this.onTap});

  /// "15:00–16:00"(Poppins 10)이 한 줄에 들어가는 칸 안쪽 폭. 이보다 좁으면 두 줄로 나눈다.
  static const _rangeOnOneLineWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    final tone = context.palette.kind(entry.kind);
    return Semantics(
      button: onTap != null,
      label: '${weekdayLabel(entry.weekday)} $label ${entry.kind.label} ${entry.title}',
      child: Material(
        color: tone.container,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 4, 5),
            // 방과 후 칸은 끝 시각도 보여준다. 칸이 넓으면 위에 "15:00–16:00" 한 줄,
            // 좁으면(플립) 위에 시작·아래에 "~16:00" — 달력의 일정 블록처럼 위 끝 = 시작, 아래 끝 = 끝.
            child: LayoutBuilder(
              builder: (context, c) {
                final timeStyle = AppFonts.numeric(
                  size: AppText.micro,
                  weight: FontWeight.w600,
                  color: tone.onContainer,
                );
                final wide = c.maxWidth >= _rangeOnOneLineWidth;
                final end = formatMinutes(entry.end);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(school || !wide ? label : '$label–$end', style: timeStyle),
                    Text(
                      shortTitle(entry.title),
                      maxLines: school ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.w700,
                        color: tone.onContainer,
                        height: 1.25,
                      ),
                    ),
                    if (!school && !wide) Text('~$end', style: timeStyle),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
