import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../entry_detail_screen.dart';
import '../entry_editor_sheet.dart';
import '../school_week_sheet.dart';
import '../week_view_mode.dart';
import 'time_scale_grid.dart';
import 'week_grid.dart';

/// 시간표 한 벌(버전 하나)을 보여주고 고치는 판. 시간표 탭(현재 버전)과
/// 지난 버전 보기 화면이 같은 판을 쓴다 — 보는 곳마다 모양·동작이 달라지지 않게.
/// 고칠 수 있는지는 권한([Permissions.canEditEntries])으로만 정한다.
class TimetableBoard extends ConsumerStatefulWidget {
  final Child child;
  final TimetableVersion version;

  const TimetableBoard({super.key, required this.child, required this.version});

  @override
  ConsumerState<TimetableBoard> createState() => _TimetableBoardState();
}

class _TimetableBoardState extends ConsumerState<TimetableBoard> {
  bool? _showWeekendOverride;

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(permissionsProvider).canEditEntries(widget.child);
    final mode = ref.watch(weekViewModeProvider);
    final v = widget.version;
    final hasWeekend = v.entries.any((e) => e.weekday >= 6);
    final showWeekend = _showWeekendOverride ?? hasWeekend;
    final weekdays = showWeekend ? const [1, 2, 3, 4, 5, 6, 7] : const [1, 2, 3, 4, 5];
    // 칸을 누르면 누구든(보기만 하는 가족·아이도) 상세 + 댓글로. 고치는 건 상세의 "편집"에서만.
    void onTapEntry(Entry e) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryDetailScreen(versionId: v.id, entryId: e.id),
      ),
    );
    final commentCounts = ref.watch(commentCountsProvider);
    final foldSchool = ref.watch(foldSchoolProvider);
    final zoom = ref.watch(timeScaleZoomProvider);
    final hasSchoolPeriods = v.entries.any((e) => e.kind == EntryKind.school && e.period != null);
    final ValueChanged<int>? onTapDay = canEdit
        ? (d) => showEntryEditor(context, child: widget.child, version: v, weekday: d)
        : null;

    final isTimeScale = mode == WeekViewMode.timeScale;
    final canPeriods = canEdit && widget.child.institution.hasPeriods && !v.isVacation;
    // 작은 단추 모양 하나로 통일(예전엔 큰 버튼 두 개 + 카드 제목 줄 + 보기 줄로 격자가 화면 아래로 밀렸다 — 실사용 피드백).
    const compact = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 38)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      textStyle: WidgetStatePropertyAll(TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700)),
      visualDensity: VisualDensity.compact,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1줄: 보기 방식 + (고칠 수 있으면) 교시 입력 · 일정 추가
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PillTabs<WeekViewMode>(
                  items: [for (final m in WeekViewMode.values) (m, m.label, null)],
                  selected: mode,
                  onChanged: (m) => ref.read(weekViewModeProvider.notifier).set(m),
                ),
              ),
            ),
            const SizedBox(width: AppGap.sm),
            if (canPeriods) ...[
              OutlinedButton.icon(
                style: compact,
                onPressed: () => showSchoolWeekSheet(context, child: widget.child, version: v),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('교시'),
              ),
              const SizedBox(width: AppGap.snug),
            ],
            if (canEdit)
              FilledButton.icon(
                style: compact,
                onPressed: () => showEntryEditor(context, child: widget.child, version: v),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('일정'),
              ),
          ],
        ),
        const SizedBox(height: AppGap.sm),
        // 2줄: 켜고 끄는 것들은 체크 표시가 있는 칩으로 — 켜졌는지 꺼졌는지가 보여야 한다.
        // "학교 교시 보기"를 끄면(기본) 학교에 있는 시간이 "학교" 칸 하나로 접힌다. 예전 "학교 펼치기" 단추와
        // 접힌 칸의 작은 화살표로는 어딜 눌러야 교시가 보이는지 몰랐다(실사용 피드백).
        Wrap(
          spacing: AppGap.sm,
          runSpacing: AppGap.xs,
          children: [
            if (isTimeScale && hasSchoolPeriods)
              ToggleChip(
                label: '학교 교시 보기',
                selected: !foldSchool,
                onChanged: (_) => ref.read(foldSchoolProvider.notifier).toggle(),
              ),
            ToggleChip(
              label: '주말',
              selected: showWeekend,
              onChanged: (on) => setState(() => _showWeekendOverride = on),
            ),
          ],
        ),
        const SizedBox(height: AppGap.sm),
        DashCard(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: v.entries.isEmpty
              ? EmptyState(
                  emoji: '🗓️',
                  title: '아직 일정이 없어요',
                  message: canEdit
                      ? (canPeriods ? '학교 시간표는 "교시"로, 학원은 "일정"으로 넣어 보세요.' : '"일정"으로 등원·하원 시간부터 넣어 보세요.')
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isTimeScale)
                      // 두 손가락으로 벌리면 세로로 늘고 오므리면 줄어든다(이 폰에 기억).
                      PinchZoom(
                        zoom: zoom,
                        onZoom: (z) => ref.read(timeScaleZoomProvider.notifier).preview(z),
                        onZoomEnd: () => ref.read(timeScaleZoomProvider.notifier).commit(),
                        child: TimeScaleGrid(
                          entries: v.entries,
                          weekdays: weekdays,
                          onTapEntry: onTapEntry,
                          onTapDay: onTapDay,
                          commentCounts: commentCounts,
                          foldSchool: foldSchool,
                          zoom: zoom,
                          onToggleSchool: () => ref.read(foldSchoolProvider.notifier).toggle(),
                        ),
                      )
                    else
                      WeekGrid(entries: v.entries, weekdays: weekdays, onTapEntry: onTapEntry, onTapDay: onTapDay),
                    const SizedBox(height: AppGap.md),
                    KindLegend(entries: v.entries),
                  ],
                ),
        ),
      ],
    );
  }
}
