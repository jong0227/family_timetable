import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../../../domain/timetable_logic.dart';
import 'week_grid.dart';

/// 주간 시간표(시간 비례 보기). 세로축이 실제 시각이라 칸 높이 = 수업 길이,
/// 칸 사이 빈칸 = 빈 시간이 그대로 보인다. 같은 시간에 겹치는 일정은 나란히 놓는다([assignLanes]).
///
/// 1분 = [_pxPerMinute]픽셀. 40분 수업이 54px 정도라 시작 시각 + 과목 두 줄이 들어간다.
/// 축은 일정이 있는 시간대만(가장 이른 시작 ~ 가장 늦은 끝, 정시로 반올림) 그린다.
///
/// **학교 시간 접기**([foldSchool], 기본 켜짐): 학교에 있는 동안은 부모가 따로 챙길 게 없어서
/// 그 시간대를 눌러 담고([schoolFolds] · [TimeAxis]), 요일마다 교시들을 "학교" 칸 하나로 합친다.
/// 다른 일정이 걸친 시간은 접지 않으므로 학원·늘봄이 숨지 않는다. 학교 칸을 누르면 펼친다.
class TimeScaleGrid extends StatelessWidget {
  final List<Entry> entries;
  final List<int> weekdays;
  final ValueChanged<Entry>? onTapEntry;
  final ValueChanged<int>? onTapDay;

  /// 일정 id → 댓글 수. 댓글이 있는 칸 오른쪽 위에 점을 찍는다.
  final Map<String, int> commentCounts;

  final bool foldSchool;

  /// 세로 배율(두 손가락 확대·축소). 1이면 기본.
  final double zoom;

  /// 접힌 "학교" 칸을 눌렀을 때(펼치기).
  final VoidCallback? onToggleSchool;

  /// 여러 아이를 한 격자에(함께 보기): 일정이 누구 것인지([groupOf] — 학교 칸을 아이마다 따로 접는다)와
  /// 칸 색([toneOf] — 자녀색). 없으면 한 아이 시간표이고 칸 색은 종류색.
  final Object Function(Entry e)? groupOf;
  final ChildTone Function(Entry e)? toneOf;

  const TimeScaleGrid({
    super.key,
    required this.entries,
    this.weekdays = const [1, 2, 3, 4, 5],
    this.onTapEntry,
    this.onTapDay,
    this.commentCounts = const {},
    this.foldSchool = false,
    this.zoom = 1,
    this.onToggleSchool,
    this.groupOf,
    this.toneOf,
  });

  // 1.1에서 올림: 40분 칸에 시작 시각 + 이름 두 줄이 들어가야 읽힌다(실기기 피드백).
  static const _pxPerMinute = 1.35;
  static const _gutterWide = 30.0;
  // 주말까지 7칸이면 시각 눈금 칸과 열 사이를 줄여 열마다 몇 dp라도 더 준다(디자인 점검: 플립 7칸이면 글자 폭이 28dp).
  static const _gutterNarrow = 20.0;

  /// 접힌 구간 하나가 차지하는 높이. "학교 · 5교시"가 들어가는 만큼.
  static const _foldHeight = 44.0;

  static const _schoolPrefix = '__school_';
  static bool _isSchoolSummary(Entry e) => e.id.startsWith(_schoolPrefix);
  static bool _isPeriod(Entry e) => e.kind == EntryKind.school && e.period != null;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final shown = entries.where((e) => weekdays.contains(e.weekday)).toList();
    // 보이는 요일에 일정이 없어도(예: 일정이 주말에만 있는데 주말을 끈 경우) 요일 머리는 그린다.
    // 예전엔 격자 전체가 사라져 요일조차 안 보였다(실사용 버그). 요일을 눌러 일정을 넣을 수도 있어야 한다.
    if (shown.isEmpty) {
      final dense = weekdays.length >= 7;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: dense ? _gutterNarrow : _gutterWide),
              for (var i = 0; i < weekdays.length; i++) ...[
                if (i > 0) SizedBox(width: dense ? AppGap.xxs : AppGap.xs),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppGap.xxl),
            child: Text(
              '이 요일들엔 일정이 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.body, color: p.textMuted),
            ),
          ),
        ],
      );
    }

    final first = shown.map((e) => e.start).reduce((a, b) => a < b ? a : b);
    final last = shown.map((e) => e.end).reduce((a, b) => a > b ? a : b);
    final axisStart = (first ~/ 60) * 60;
    final axisEnd = ((last + 59) ~/ 60) * 60;
    final axis = TimeAxis(
      start: axisStart,
      end: axisEnd,
      folds: foldSchool ? schoolFolds(shown) : const [],
      pxPerMinute: _pxPerMinute * zoom,
      foldHeight: _foldHeight,
    );
    final nowMinutes = now.hour * 60 + now.minute;

    // 접을 땐 요일마다 교시들을 "학교" 칸 하나로 합친다(몇 교시까지인지는 칸 안에 적는다).
    // 함께 보기면 아이마다 따로 합친다(두 아이 교시가 한 칸으로 섞이지 않게).
    final periodsByDay = <int, Map<Object, List<Entry>>>{};
    if (foldSchool) {
      for (final e in shown.where(_isPeriod)) {
        periodsByDay.putIfAbsent(e.weekday, () => {}).putIfAbsent(groupOf?.call(e) ?? '', () => []).add(e);
      }
    }
    // 합친 "학교" 칸 id → 그 안의 교시들
    final summaries = <String, List<Entry>>{};
    List<Entry> dayEntries(int d) {
      final day = shown.where((e) => e.weekday == d).toList();
      final groups = periodsByDay[d];
      if (groups == null) return day;
      var n = 0;
      return [
        ...day.where((e) => !_isPeriod(e)),
        for (final periods in groups.values)
          () {
            final id = '$_schoolPrefix${d}_${n++}';
            summaries[id] = periods;
            return Entry(
              id: id,
              weekday: d,
              start: periods.map((e) => e.start).reduce((a, b) => a < b ? a : b),
              end: periods.map((e) => e.end).reduce((a, b) => a > b ? a : b),
              title: '학교',
              kind: EntryKind.school,
            );
          }(),
      ];
    }

    final dense = weekdays.length >= 7;
    final gutter = dense ? _gutterNarrow : _gutterWide;
    final colGap = dense ? AppGap.xxs : AppGap.xs;
    final hourMarks = [
      for (var m = axisStart; m <= axisEnd; m += 60)
        if (!axis.isFolded(m)) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(width: gutter),
            for (var i = 0; i < weekdays.length; i++) ...[
              if (i > 0) SizedBox(width: colGap),
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
          height: axis.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시각 눈금(정시마다, 접힌 구간 안은 빼고) + 접힌 자리 표시
              SizedBox(
                width: gutter,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final m in hourMarks)
                      Positioned(
                        top: axis.y(m) - 6,
                        left: 0,
                        child: Text(
                          '${m ~/ 60}',
                          style: AppFonts.numeric(size: AppText.micro, weight: FontWeight.w500, color: p.textMuted),
                        ),
                      ),
                    for (final (a, b) in axis.folds)
                      Positioned(
                        top: axis.y(a),
                        height: axis.y(b) - axis.y(a),
                        left: 0,
                        width: gutter - 4,
                        // 접힌 자리 표시도 누르면 펼친다(눌러 보고 싶게 생겼는데 아무 일 없던 것 — 디자인 점검).
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleSchool,
                          child: Center(child: Icon(Icons.unfold_more_rounded, size: 14, color: p.textMuted)),
                        ),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < weekdays.length; i++) ...[
                if (i > 0) SizedBox(width: colGap),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final day = dayEntries(weekdays[i]);
                      final lanes = assignLanes(day);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 정시 가로줄
                          for (final m in hourMarks)
                            Positioned(
                              top: axis.y(m),
                              left: 0,
                              right: 0,
                              child: Container(height: 1, color: p.status.neutral),
                            ),
                          for (final e in day)
                            () {
                              final slot = lanes[e.id]!;
                              final w = c.maxWidth / slot.lanes;
                              final summary = _isSchoolSummary(e);
                              return Positioned(
                                top: axis.y(e.start) + 1,
                                height: axis.y(e.end) - axis.y(e.start) - 2,
                                left: w * slot.lane,
                                width: w - (slot.lanes > 1 ? 1 : 0),
                                child: _Block(
                                  entry: e,
                                  schoolPeriods: summary ? summaries[e.id]!.length : null,
                                  tone: toneOf?.call(summary ? summaries[e.id]!.first : e),
                                  commentCount: commentCounts[e.id] ?? 0,
                                  onTap: summary ? onToggleSchool : (onTapEntry == null ? null : () => onTapEntry!(e)),
                                ),
                              );
                            }(),
                          // 오늘 열에 지금 시각 선
                          if (weekdays[i] == now.weekday && nowMinutes > axisStart && nowMinutes < axisEnd)
                            Positioned(
                              top: axis.y(nowMinutes) - 1,
                              left: 0,
                              right: 0,
                              // 주황(urgent)은 "빈 시간·겹침" 뜻이라 지금 선은 무채색 강조(라이트 검정/다크 흰색) — 디자인 점검
                              child: Container(height: 2, color: p.dock),
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

/// 시간 비례 칸. 위 끝 = 시작, 아래 끝 = 끝이라 **끝 시각은 칸에 쓰지 않는다**(눈금으로 보인다).
/// 좁은 열(주말까지 7칸 + 플립)에서 "~13:4"처럼 잘리고 글씨가 비좁다는 실사용 피드백으로,
/// 칸 안엔 시작(또는 교시)과 이름만 두고 이름에 남는 높이를 다 준다. 정확한 시각은 누르면 보이는 상세에서.
///
/// [schoolPeriods]가 있으면 접힌 "학교" 칸: 위에 "학교", 아래에 "5교시"를 적는다.
class _Block extends StatelessWidget {
  final Entry entry;
  final int? schoolPeriods;
  final int commentCount;
  final VoidCallback? onTap;

  /// 칸 색. 없으면 종류색(함께 보기에선 자녀색을 준다).
  final ChildTone? tone;

  const _Block({required this.entry, this.schoolPeriods, required this.commentCount, this.onTap, this.tone});

  static const _titleSize = AppText.caption;
  static const _titleLineHeight = _titleSize * 1.25;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = this.tone ?? p.kind(entry.kind);
    final summary = schoolPeriods != null;
    final label = summary
        ? '~${formatMinutes(entry.end)}'
        : (entry.period != null ? '${entry.period}교시' : formatMinutes(entry.start));
    final timeStyle = AppFonts.numeric(
      size: AppText.micro,
      weight: FontWeight.w600,
      color: tone.onContainer.withValues(alpha: 0.8),
    );
    return Semantics(
      button: onTap != null,
      label: summary
          ? '${weekdayLabel(entry.weekday)} 학교 $schoolPeriods교시, 눌러서 펼치기'
          : '${weekdayLabel(entry.weekday)} ${entry.timeText} ${entry.kind.label} ${entry.title}'
                '${commentCount > 0 ? ' 댓글 $commentCount개' : ''}',
      child: Material(
        color: tone.container,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final showTime = h >= 34;
              // 시각 한 줄(약 13px)과 위아래 여백을 빼고 남는 높이만큼 이름 줄 수를 정한다.
              final titleRoom = h - (showTime ? 13 : 0) - 6;
              final lines = (titleRoom / _titleLineHeight).floor().clamp(1, 4);
              final title = Text(
                summary ? '학교' : shortTitle(entry.title),
                maxLines: lines,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: _titleSize,
                  fontWeight: FontWeight.w700,
                  color: tone.onContainer,
                  height: 1.25,
                ),
              );
              // 좁은 칸에서도 시각이 잘리지 않게 줄여서라도 한 줄에 넣는다.
              Widget fit(String text) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text, style: timeStyle),
              );
              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, h < 24 ? 1 : 3, 2, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // 접힌 학교 칸: "학교" / "13:40"(끝 = 하원 시각) 두 줄. 예전엔 "5교시 ~13:40"을 한 줄에 줄여 넣어
                      // 4~6px로 작아졌다(디자인 점검). 교시 수는 칸이 넉넉할 때만.
                      // 일찍 끝나는 날은 접힌 칸이 낮아서 두 줄이 안 들어간다. 그땐 "학교"(색으로 이미 보임) 대신
                      // 끝 시각(= 하원·픽업 시각)만 남긴다.
                      children: summary && !showTime
                          ? [
                              Text(
                                formatMinutes(entry.end),
                                style: AppFonts.numeric(
                                  size: AppText.caption,
                                  weight: FontWeight.w600,
                                  color: tone.onContainer,
                                ),
                              ),
                            ]
                          : summary
                          ? [
                              title,
                              if (showTime)
                                Text(
                                  formatMinutes(entry.end),
                                  style: AppFonts.numeric(
                                    size: AppText.caption,
                                    weight: FontWeight.w600,
                                    color: tone.onContainer,
                                  ),
                                ),
                              if (showTime && c.maxWidth >= 48 && h >= 56)
                                Text(
                                  '$schoolPeriods교시',
                                  style: TextStyle(
                                    fontSize: AppText.caption,
                                    color: tone.onContainer.withValues(alpha: 0.8),
                                  ),
                                ),
                            ]
                          : [if (showTime) fit(label), title],
                    ),
                  ),
                  // 접힌 학교 칸은 "눌러서 펼친다"가 보여야 한다(어딜 눌러야 하냐는 실사용 질문).
                  if (summary)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(Icons.unfold_more_rounded, size: 14, color: tone.onContainer.withValues(alpha: 0.7)),
                    ),
                  if (commentCount > 0)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 9,
                        height: 9,
                        // 청록 점이 하늘색 학원 칸에 묻혀서 무채색 점 + 칸 색 테두리로(디자인 점검).
                        decoration: BoxDecoration(
                          color: p.dock,
                          shape: BoxShape.circle,
                          border: Border.all(color: tone.container, width: 1.5),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
