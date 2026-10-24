import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dev_tools.dart';
import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/day_summary.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';
import '../family/child_form_sheet.dart';

/// "오늘" 대시보드 — 앱을 열면 가장 먼저 보는 화면.
/// 레퍼런스의 Dashboard 구성을 그대로 옮겼다:
///   큰 제목 + 요약 / 날짜  →  KPI 줄  →  히어로 카드(지금·다음)  →  카드 격자(자녀별 하루)
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// 다른 요일을 골랐으면 그 요일과 고른 날. 날짜가 바뀌면 저절로 오늘로 돌아간다 — 탭이 계속 살아 있어서
  /// 어제 고른 요일이 다음 날 아침에도 "오늘"처럼 남던 문제(코드 점검 M5).
  int? _picked;
  DateTime? _pickedOn;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    ref.watch(todayProvider); // 앱이 다시 앞으로 나오면 새로 그린다
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final pickedToday = _pickedOn != null && DateUtils.isSameDay(_pickedOn, now);
    final weekday = pickedToday ? _picked! : now.weekday;
    final isToday = weekday == now.weekday;
    void pick(int d) => setState(() {
      _picked = d;
      _pickedOn = now;
    });
    final children = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final summary = buildDaySummary(
      weekday: weekday,
      children: children,
      versionOf: (id) => ref.watch(currentVersionProvider(id)),
      nowMinutes: isToday ? now.hour * 60 + now.minute : null,
    );
    // 오늘이면 "다음 일정", 다른 요일이면 그날 "첫 일정"(히어로 칩과 같은 말 — 디자인 점검).
    final next = isToday
        ? summary.nextUpcoming
        : summary.children
              .map((c) => c.focus)
              .nonNulls
              .fold<DayBlock?>(null, (best, b) => best == null || b.start < best.start ? b : best);

    final page = PageBody(
      children: [
        PageHeader(
          title: isToday ? '오늘' : '${weekdayLabel(weekday)}요일',
          subtitle: children.isEmpty ? '아이를 추가하면 하루 일정이 여기 모여요' : _subtitle(summary),
          asideTop: '${now.month}월 ${now.day}일',
          asideMain: '${weekdayLabel(now.weekday)}요일',
          // 다른 요일을 볼 때만 "오늘로". 예전엔 요일 띠 옆에 붙어 띠 폭이 줄었다 늘었다 했다(실사용 버그).
          asideAction: isToday
              ? null
              : ActionChip(
                  // 머리 줄 높이 안에 들어가게 납작하게(기본 48dp 터치 여백이면 머리가 커져 아래 띠가 3px 밀렸다 —
                  // 테스트로 발견). 요일은 띠·밀기로도 바꿀 수 있어 보조 버튼으로 충분하다.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('오늘로'),
                  onPressed: () => pick(now.weekday),
                ),
        ),
        // 아이가 없으면 안내만. (예전엔 개발용 버튼이 없는 릴리스에서 아래 KPI·빈 카드까지 같이 그려졌다)
        if (children.isEmpty) ...[
          DashCard(
            child: EmptyState(
              emoji: '🧒',
              title: '첫 번째 아이를 추가해 주세요',
              message: '아이마다 시간표를 따로 만들고, 가족이 함께 볼 수 있어요.',
              actionLabel: '아이 추가',
              onAction: () => showChildFormSheet(context),
            ),
          ),
          if (devToolsEnabled) TextButton(onPressed: () => seedSampleFamily(ref), child: const Text('개발용: 샘플 가족 채우기')),
        ] else ...[
          KpiRow([
            Kpi('일정', '${summary.blockCount}'),
            Kpi(isToday ? '다음 일정' : '첫 일정', next == null ? '—' : formatMinutes(next.start)),
            Kpi('빈 시간', '${summary.gapCount}', dot: summary.gapCount > 0 ? p.status.urgent : null),
          ]),
          WeekdayStrip(selected: weekday, today: now.weekday, onChanged: pick),
          const SizedBox(height: AppGap.lg),
          _HeroPager(days: summary.children, isToday: isToday),
          const SizedBox(height: AppGap.md),
          DashboardGrid(children: [for (final d in summary.children) _ChildDayCard(day: d)]),
        ],
      ],
    );

    // 좌우로 밀면 요일이 넘어간다(왼쪽으로 밀면 다음 날, 일요일 다음은 월요일 — 실사용 요청).
    // 위쪽 자녀 카드(PageView)는 자기 안에서 받은 가로 밀기를 먼저 가져가므로 자녀 넘기기와 겹치지 않는다.
    // 세로 스크롤은 가로 드래그만 듣는 이 감지기와 다투지 않는다.
    if (children.isEmpty) return page;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      // 빠르게 튕기거나(속도) 천천히 충분히 밀거나(거리) 둘 중 하나면 넘긴다.
      // 속도만 보면 천천히 민 손가락은 속도가 0에 가까워 넘어가지 않았다(미리보기에서 발견).
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final left = v <= -_swipeVelocity || _dragDx <= -_swipeDistance;
        final right = v >= _swipeVelocity || _dragDx >= _swipeDistance;
        if (left == right) return;
        pick(left ? weekday % 7 + 1 : (weekday + 5) % 7 + 1);
      },
      child: page,
    );
  }

  /// 이보다 느린 가로 움직임은 요일 넘기기로 보지 않는다(살짝 비스듬한 세로 스크롤을 오인하지 않게).
  static const _swipeVelocity = 300.0;
  static const _swipeDistance = 80.0;

  /// 지금 가로 밀기에서 손가락이 움직인 거리(+ 오른쪽).
  double _dragDx = 0;

  String _subtitle(DaySummary s) {
    if (s.blockCount == 0) return '이날은 일정이 없어요';
    final gap = s.gapCount > 0 ? ' · 빈 시간 ${s.gapCount}곳' : '';
    return '일정 ${s.blockCount}개$gap';
  }
}

/// 자녀별 "지금·다음" 히어로 카드. 자녀가 여럿이면 옆으로 넘긴다.
class _HeroPager extends StatefulWidget {
  final List<ChildDay> days;
  final bool isToday;
  const _HeroPager({required this.days, required this.isToday});

  @override
  State<_HeroPager> createState() => _HeroPagerState();
}

class _HeroPagerState extends State<_HeroPager> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.length == 1) {
      return SizedBox(
        height: 200,
        child: _HeroContent(day: days.first, isToday: widget.isToday),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            itemCount: days.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: AppGap.md),
              child: _HeroContent(day: days[i], isToday: widget.isToday),
            ),
          ),
        ),
        const SizedBox(height: AppGap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < days.length; i++)
              AnimatedContainer(
                duration: AppMotion.fast,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? context.palette.dock : context.palette.status.neutral,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  final ChildDay day;
  final bool isToday;
  const _HeroContent({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = p.child(day.child.colorIndex);
    final focus = day.focus;
    final (chipLabel, chipColor) = switch (day.state) {
      NowState.ongoing => ('지금', p.status.positive),
      NowState.upcoming => (isToday ? '다음' : '첫 일정', p.status.info),
      NowState.done => ('오늘 끝', p.textMuted),
      NowState.none => ('일정 없음', p.textMuted),
    };
    return HeroCard(
      gradient: tone.gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildBadge(day.child),
              const Spacer(),
              StatusChip(chipLabel, color: chipColor, dot: day.state == NowState.ongoing),
            ],
          ),
          const Spacer(),
          if (focus == null)
            Text(
              '쉬는 날이에요',
              style: TextStyle(fontSize: AppText.titleLg, color: tone.onContainer),
            )
          else ...[
            TimeText(
              '${formatMinutes(focus.start)} – ${formatMinutes(focus.end)}',
              size: AppText.hero,
              weight: FontWeight.w300,
              color: tone.onContainer,
            ),
            const SizedBox(height: AppGap.xs),
            Text(
              _focusTitle(focus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700, color: tone.onContainer),
            ),
            if (focus.first.place.isNotEmpty)
              Text(
                focus.first.place,
                style: TextStyle(fontSize: AppText.body, color: tone.onContainer),
              ),
          ],
        ],
      ),
    );
  }

  String _focusTitle(DayBlock b) =>
      b.isSchoolBlock ? '${b.first.kind.emoji} 학교 · ${b.entries.length}교시' : '${b.first.kind.emoji} ${b.first.title}';
}

/// 자녀 한 명의 하루 타임라인 카드. 일정 사이 빈 시간은 주황으로 끼워 넣는다.
class _ChildDayCard extends StatelessWidget {
  final ChildDay day;
  const _ChildDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <({int start, Widget widget})>[
      for (final b in day.blocks) (start: b.start, widget: _BlockRow(block: b, tone: p.kind(b.first.kind))),
      for (final g in day.gaps) (start: g.start, widget: _GapRow(gap: g)),
    ]..sort((a, b) => a.start.compareTo(b.start));

    return DashCard(
      icon: Icons.schedule_rounded,
      title: '${day.child.name} · ${day.versionName ?? '시간표 없음'}',
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppGap.md),
              child: Text(
                '이날은 일정이 없어요',
                style: TextStyle(fontSize: AppText.body, color: p.textMuted),
              ),
            )
          : Column(children: [for (final r in rows) r.widget]),
    );
  }
}

class _BlockRow extends StatelessWidget {
  final DayBlock block;
  final ChildTone tone;
  const _BlockRow({required this.block, required this.tone});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = block.first;
    final title = block.isSchoolBlock ? '학교 ${block.entries.length}교시' : e.title;
    final detail = block.isSchoolBlock ? block.entries.map((x) => x.title).join(' · ') : e.place;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: TimeText(formatMinutes(block.start), size: AppText.body, color: p.textMuted),
          ),
          Container(
            width: 3,
            height: 36,
            margin: const EdgeInsets.only(right: AppGap.cozy),
            decoration: BoxDecoration(color: tone.accent, borderRadius: BorderRadius.circular(AppRadius.pill)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.kind.emoji} $title',
                  style: const TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    '${formatMinutes(block.start)}–${formatMinutes(block.end)}',
                    if (detail.isNotEmpty) detail,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppText.label, color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  final Gap gap;
  const _GapRow({required this.gap});

  @override
  Widget build(BuildContext context) {
    final urgent = context.palette.status.urgent;
    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 2, bottom: 2),
      child: Row(
        children: [
          StatusDot(urgent, size: 6),
          const SizedBox(width: AppGap.sm),
          Text(
            '빈 시간 ${gap.minutes}분 (${formatMinutes(gap.start)}–${formatMinutes(gap.end)})',
            style: TextStyle(
              fontSize: AppText.label,
              fontWeight: FontWeight.w600,
              color: context.palette.status.urgentText,
            ),
          ),
        ],
      ),
    );
  }
}
