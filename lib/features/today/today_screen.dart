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
  late int _weekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final isToday = _weekday == now.weekday;
    final children = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final summary = buildDaySummary(
      weekday: _weekday,
      children: children,
      versionOf: (id) => ref.watch(currentVersionProvider(id)),
      nowMinutes: isToday ? now.hour * 60 + now.minute : null,
    );
    final next = isToday ? summary.nextUpcoming : null;

    return PageBody(
      children: [
        PageHeader(
          title: isToday ? '오늘' : '${weekdayLabel(_weekday)}요일',
          subtitle: children.isEmpty ? '아이를 추가하면 하루 일정이 여기 모여요' : _subtitle(summary),
          asideTop: '${now.month}월 ${now.day}일',
          asideMain: '${weekdayLabel(now.weekday)}요일',
        ),
        if (children.isEmpty)
          DashCard(
            child: EmptyState(
              emoji: '🧒',
              title: '첫 번째 아이를 추가해 주세요',
              message: '아이마다 시간표를 따로 만들고, 가족이 함께 볼 수 있어요.',
              actionLabel: '아이 추가',
              onAction: () => showChildFormSheet(context),
            ),
          ),
        if (children.isEmpty && devToolsEnabled)
          TextButton(onPressed: () => seedSampleFamily(ref), child: const Text('개발용: 샘플 가족 채우기'))
        else ...[
          KpiRow([
            Kpi('일정', '${summary.blockCount}'),
            Kpi('다음 일정', next == null ? '—' : formatMinutes(next.start)),
            Kpi('빈 시간', '${summary.gapCount}', dot: summary.gapCount > 0 ? p.status.urgent : null),
          ]),
          PillTabs<int>(
            items: [
              for (var d = 1; d <= 7; d++) (d, d == now.weekday ? '${weekdayLabel(d)} · 오늘' : weekdayLabel(d), null),
            ],
            selected: _weekday,
            onChanged: (d) => setState(() => _weekday = d),
          ),
          const SizedBox(height: AppGap.lg),
          _HeroPager(days: summary.children, isToday: isToday),
          const SizedBox(height: AppGap.md),
          DashboardGrid(children: [for (final d in summary.children) _ChildDayCard(day: d)]),
        ],
      ],
    );
  }

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
    if (days.length == 1) return SizedBox(height: 200, child: _HeroContent(day: days.first, isToday: widget.isToday));
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
            Text('쉬는 날이에요', style: TextStyle(fontSize: AppText.titleLg, color: tone.onContainer))
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
              Text(focus.first.place, style: TextStyle(fontSize: AppText.body, color: tone.onContainer)),
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
      for (final b in day.blocks) (start: b.start, widget: _BlockRow(block: b, tone: p.child(day.child.colorIndex))),
      for (final g in day.gaps) (start: g.start, widget: _GapRow(gap: g)),
    ]..sort((a, b) => a.start.compareTo(b.start));

    return DashCard(
      icon: Icons.schedule_rounded,
      title: '${day.child.name} · ${day.versionName ?? '시간표 없음'}',
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppGap.md),
              child: Text('이날은 일정이 없어요', style: TextStyle(fontSize: AppText.body, color: p.textMuted)),
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
                Text('${e.kind.emoji} $title',
                    style: const TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700)),
                Text(
                  ['${formatMinutes(block.start)}–${formatMinutes(block.end)}', if (detail.isNotEmpty) detail].join(' · '),
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
            style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: urgent),
          ),
        ],
      ),
    );
  }
}
