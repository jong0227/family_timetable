import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import '../family/child_form_sheet.dart';
import 'revisions_screen.dart';
import 'versions_screen.dart';
import 'widgets/timetable_board.dart';

/// 시간표 탭: 자녀를 고르면 그 아이의 "지금 쓰는 시간표"를 보여주고 고친다.
/// 학기 관리(버전)와 수정 기록은 위쪽 한 줄([_VersionBar])에서 들어간다.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  String? _childId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final children = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final child = children.where((c) => c.id == _childId).firstOrNull ?? children.firstOrNull;

    if (child == null) {
      return PageBody(
        children: [
          const PageHeader(title: '시간표'),
          DashCard(
            child: EmptyState(
              emoji: '🧒',
              title: '먼저 아이를 추가해 주세요',
              actionLabel: '아이 추가',
              onAction: () => showChildFormSheet(context),
            ),
          ),
        ],
      );
    }

    final version = ref.watch(currentVersionProvider(child.id));
    final perms = ref.watch(permissionsProvider);

    return PageBody(
      children: [
        // 큰 제목("시간표" + 아이·학년)과 학기 카드가 화면 위 1/3을 차지해 정작 시간표가 아래로 밀렸다(실사용 피드백).
        // 탭 이름은 아래 내비가 이미 말해 주므로, 위는 "누구의 · 어떤 시간표" 한 줄로 줄인다.
        if (children.length > 1) ...[
          PillTabs<String>(
            items: [for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent)],
            selected: child.id,
            onChanged: (id) => setState(() => _childId = id),
          ),
          const SizedBox(height: AppGap.xs),
        ],
        _VersionBar(child: child, version: version, showName: children.length == 1),
        const SizedBox(height: AppGap.sm),
        if (version != null)
          TimetableBoard(child: child, version: version)
        else
          DashCard(
            child: EmptyState(
              emoji: '📒',
              title: '쓰고 있는 시간표가 없어요',
              message: '학기 이름을 붙여 새 시간표를 만들어 주세요.',
              actionLabel: perms.canManageVersions(child) ? '새 시간표 만들기' : null,
              onAction: () => showNewVersionDialog(context, ref, child: child),
            ),
          ),
      ],
    );
  }
}

/// 지금 쓰는 시간표 한 줄: "2학년 2학기 ● 사용 중 ▸" + 수정 기록 단추.
///
/// 줄을 누르면 학기 관리(시간표 목록). 예전엔 이름 카드 + "시간표 N개"·"수정 기록" 글자 단추 줄이 따로 있었다.
class _VersionBar extends ConsumerWidget {
  final Child child;
  final TimetableVersion? version;

  /// 아이가 한 명이면 위에 아이 탭이 없으니 여기 이름을 붙인다.
  final bool showName;

  const _VersionBar({required this.child, required this.version, required this.showName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final today = ref.watch(todayProvider);
    final v = version;
    final status = v == null
        ? null
        : v.covers(today)
        ? '방학 · ${formatDateShort(v.endDate!)}까지'
        : '사용 중';
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => open(VersionsScreen(childId: child.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppGap.sm, horizontal: AppGap.xs),
              child: Row(
                children: [
                  if (showName) ...[ChildBadge(child, large: true), const SizedBox(width: AppGap.sm)],
                  Flexible(
                    child: Text(
                      v?.name ?? '시간표 없음',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: AppGap.sm),
                    StatusDot(p.status.positive),
                    const SizedBox(width: AppGap.xs),
                    Text(
                      status,
                      style: TextStyle(fontSize: AppText.label, color: p.status.positiveText),
                    ),
                  ],
                  Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
                ],
              ),
            ),
          ),
        ),
        if (v != null)
          IconButton(
            tooltip: '수정 기록',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => open(RevisionsScreen(versionId: v.id)),
          ),
      ],
    );
  }
}
