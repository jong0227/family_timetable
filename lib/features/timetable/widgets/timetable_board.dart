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

  /// "+ 추가" 줄 왼쪽에 놓을 것(시간표 탭의 아이 탭).
  final Widget? leading;

  /// 카드 머리 오른쪽 끝(시간표 탭의 "수정 기록" 단추). 지난 버전 화면은 앱바에 따로 있어 안 준다.
  final Widget? headerAction;

  const TimetableBoard({super.key, required this.child, required this.version, this.leading, this.headerAction});

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
    // 기본: 평일엔 월~금, 토·일엔 주말까지(실사용 요청). "주말 보기/숨기기"로 바꾼 건 이 화면에서 유지.
    final isWeekendToday = ref.watch(todayProvider).weekday >= 6;
    final showWeekend = _showWeekendOverride ?? isWeekendToday;
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

    // 한 줄 = [아이 탭 ……… + 추가]. 일정 추가·교시 입력 큰 버튼 두 개가 한 줄을 따로 차지하던 걸
    // "+ 추가" 하나로 합쳤다(누르면 둘 중 고른다). 빈칸 없이 줄을 줄여 달라는 실사용 피드백.
    final addButton = canEdit
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppGap.lg),
            ),
            onPressed: () =>
                canPeriods ? _pickAdd(context, v) : showEntryEditor(context, child: widget.child, version: v),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('추가'),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.leading != null || addButton != null) ...[
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: widget.leading ?? const SizedBox.shrink()),
              ),
              if (addButton != null) ...[const SizedBox(width: AppGap.sm), addButton],
            ],
          ),
          const SizedBox(height: AppGap.md),
        ],
        DashCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 카드 머리 = 보기 방식 + 학교 교시 + 수정 기록. 예전엔 "주간 시간표 · 일정 N개" 제목 줄이 따로 있었다.
              Row(
                children: [
                  // 보기 방식은 "간단히" 칩 하나: 켜면 간단히, 끄면 시간 비례(기본). 탭 두 개(간단히|시간 비례)는
                  // 자리만 차지했다(실사용 요청).
                  ToggleChip(
                    label: WeekViewMode.compact.label,
                    selected: mode == WeekViewMode.compact,
                    onChanged: (on) =>
                        ref.read(weekViewModeProvider.notifier).set(on ? WeekViewMode.compact : WeekViewMode.timeScale),
                  ),
                  const SizedBox(width: AppGap.sm),
                  // 학교 다니는 아이면 교시가 아직 없어도 칩을 둔다(없으면 누를 때 교시 입력으로 안내).
                  // 교시가 있을 때만 보였더니 "교시 보기가 어딨냐"는 질문이 나왔다(실사용).
                  if (isTimeScale && (hasSchoolPeriods || widget.child.institution.hasPeriods))
                    ToggleChip(
                      label: '학교 교시',
                      selected: hasSchoolPeriods && !foldSchool,
                      onChanged: (_) {
                        if (hasSchoolPeriods) {
                          ref.read(foldSchoolProvider.notifier).toggle();
                        } else if (canPeriods) {
                          showToast(context, '아직 교시가 없어요. 요일별 교시를 넣어 주세요');
                          showSchoolWeekSheet(context, child: widget.child, version: v);
                        } else {
                          showToast(context, '이 시간표엔 아직 교시가 없어요');
                        }
                      },
                    ),
                  const Spacer(),
                  ?widget.headerAction,
                ],
              ),
              const SizedBox(height: AppGap.md),
              if (v.entries.isEmpty)
                EmptyState(emoji: '🗓️', title: '아직 일정이 없어요', message: canEdit ? '"+ 추가"로 학교 교시나 학원 일정을 넣어 보세요.' : null)
              else if (isTimeScale)
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
              // 바닥 줄 = 범례 + 주말 보기/숨기기(제목 줄에 있던 것).
              Row(
                children: [
                  Expanded(child: KindLegend(entries: v.entries)),
                  TextButton(
                    onPressed: () => setState(() => _showWeekendOverride = !showWeekend),
                    child: Text(showWeekend ? '주말 숨기기' : '주말 보기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "+ 추가": 일정 하나 넣기 / 요일별 교시 넣기 중 고른다.
  Future<void> _pickAdd(BuildContext context, TimetableVersion v) async {
    final pick = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('일정 추가'),
              subtitle: const Text('학원·방과후·늘봄 같은 일정 하나'),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('교시 입력'),
              subtitle: const Text('요일별 학교 교시를 한 번에'),
              onTap: () => Navigator.pop(ctx, 1),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || pick == null) return;
    if (pick == 0) {
      await showEntryEditor(context, child: widget.child, version: v);
    } else {
      await showSchoolWeekSheet(context, child: widget.child, version: v);
    }
  }
}
