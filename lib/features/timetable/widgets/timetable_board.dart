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

  /// 버튼 줄 끝에 붙일 것(시간표 탭의 "수정 기록" 단추). 지난 버전 화면은 앱바에 따로 있어 안 준다.
  final Widget? trailing;

  const TimetableBoard({super.key, required this.child, required this.version, this.trailing});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEdit || widget.trailing != null) ...[
          Row(
            children: [
              if (canEdit)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showEntryEditor(context, child: widget.child, version: v),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('일정 추가'),
                  ),
                ),
              if (canPeriods) ...[
                const SizedBox(width: AppGap.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showSchoolWeekSheet(context, child: widget.child, version: v),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('교시 입력'),
                  ),
                ),
              ],
              if (widget.trailing != null) ...[
                if (canEdit) const SizedBox(width: AppGap.sm) else const Spacer(),
                widget.trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppGap.md),
        ],
        DashCard(
          icon: Icons.calendar_view_week_rounded,
          title: '주간 시간표 · 일정 ${v.entries.length}개',
          linkLabel: showWeekend ? '주말 숨기기' : '주말 보기',
          onLink: () => setState(() => _showWeekendOverride = !showWeekend),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: v.entries.isEmpty
              ? EmptyState(
                  emoji: '🗓️',
                  title: '아직 일정이 없어요',
                  message: canEdit
                      ? (canPeriods ? '학교 시간표는 "교시 입력"으로, 학원은 "일정 추가"로 넣어 보세요.' : '"일정 추가"로 등원·하원 시간부터 넣어 보세요.')
                      : null,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        PillTabs<WeekViewMode>(
                          items: [for (final m in WeekViewMode.values) (m, m.label, null)],
                          selected: mode,
                          onChanged: (m) => ref.read(weekViewModeProvider.notifier).set(m),
                        ),
                        const Spacer(),
                        // 켜짐/꺼짐이 체크로 보이는 칩. 켜면 교시가 다 보이고, 끄면(기본) 학교 시간이 한 칸으로 접힌다.
                        // 예전 "학교 펼치기" 단추로는 어딜 눌러야 교시가 보이는지 몰랐다(실사용 피드백).
                        if (isTimeScale && hasSchoolPeriods)
                          ToggleChip(
                            label: '학교 교시',
                            selected: !foldSchool,
                            onChanged: (_) => ref.read(foldSchoolProvider.notifier).toggle(),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppGap.md),
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
