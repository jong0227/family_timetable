import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/design.dart';
import '../../../domain/models.dart';
import '../entry_detail_screen.dart';
import '../week_view_mode.dart';
import 'time_scale_grid.dart';

/// 아이들 시간표를 한 격자에(함께 보기). 아이마다 "지금 쓰는 시간표"(방학이면 방학 시간표)를 모아
/// 시간 비례로 겹쳐 그린다. 칸 색은 **자녀색**(종류색 대신) — 누구 일정인지가 먼저 보여야 해서.
/// 같은 시간에 겹치면 나란히 놓인다(누가 언제 어디 있는지, 픽업이 겹치는지 한눈에).
///
/// 보기 전용: 고치기는 아이 탭에서. 칸을 누르면 그 일정의 상세·댓글로 간다.
class FamilyBoard extends ConsumerStatefulWidget {
  final List<Child> children;
  const FamilyBoard({super.key, required this.children});

  @override
  ConsumerState<FamilyBoard> createState() => _FamilyBoardState();
}

class _FamilyBoardState extends ConsumerState<FamilyBoard> {
  bool? _showWeekendOverride;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // 일정 id → (아이, 버전 id). 일정 id는 버전마다 새로 만들어져 아이끼리 겹치지 않는다.
    final owner = <String, (Child, String)>{};
    final entries = <Entry>[];
    for (final c in widget.children) {
      final v = ref.watch(currentVersionProvider(c.id));
      if (v == null) continue;
      for (final e in v.entries) {
        owner[e.id] = (c, v.id);
        entries.add(e);
      }
    }
    final hasWeekend = entries.any((e) => e.weekday >= 6);
    final showWeekend = _showWeekendOverride ?? hasWeekend;
    final weekdays = showWeekend ? const [1, 2, 3, 4, 5, 6, 7] : const [1, 2, 3, 4, 5];
    final foldSchool = ref.watch(foldSchoolProvider);
    final zoom = ref.watch(timeScaleZoomProvider);
    final hasSchoolPeriods = entries.any((e) => e.kind == EntryKind.school && e.period != null);

    return DashCard(
      icon: Icons.groups_2_outlined,
      title: '함께 보기 · 아이 ${widget.children.length}명',
      linkLabel: showWeekend ? '주말 숨기기' : '주말 보기',
      onLink: () => setState(() => _showWeekendOverride = !showWeekend),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: entries.isEmpty
          ? const EmptyState(emoji: '🗓️', title: '아직 일정이 없어요')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // 범례 = 아이 이름(자녀색 점). 칸 색이 자녀색이라 이게 곧 읽는 법.
                    Expanded(
                      child: Wrap(
                        spacing: AppGap.md,
                        runSpacing: AppGap.xs,
                        children: [for (final c in widget.children) ChildBadge(c)],
                      ),
                    ),
                    if (hasSchoolPeriods)
                      ToggleChip(
                        label: '학교 교시',
                        selected: !foldSchool,
                        onChanged: (_) => ref.read(foldSchoolProvider.notifier).toggle(),
                      ),
                  ],
                ),
                const SizedBox(height: AppGap.md),
                PinchZoom(
                  zoom: zoom,
                  onZoom: (z) => ref.read(timeScaleZoomProvider.notifier).preview(z),
                  onZoomEnd: () => ref.read(timeScaleZoomProvider.notifier).commit(),
                  child: TimeScaleGrid(
                    entries: entries,
                    weekdays: weekdays,
                    commentCounts: ref.watch(commentCountsProvider),
                    foldSchool: foldSchool,
                    zoom: zoom,
                    onToggleSchool: () => ref.read(foldSchoolProvider.notifier).toggle(),
                    groupOf: (e) => owner[e.id]!.$1.id,
                    toneOf: (e) => p.child(owner[e.id]!.$1.colorIndex),
                    onTapEntry: (e) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EntryDetailScreen(versionId: owner[e.id]!.$2, entryId: e.id),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
