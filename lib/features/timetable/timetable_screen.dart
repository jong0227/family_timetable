import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import '../family/child_form_sheet.dart';
import 'revisions_screen.dart';
import 'versions_screen.dart';
import 'widgets/family_board.dart';
import 'widgets/timetable_board.dart';

/// 시간표 탭: 자녀를 고르면 그 아이의 "지금 쓰는 시간표"를 보여주고 고친다.
/// 학기 관리(버전)는 제목 오른쪽 학기 이름([_VersionAside]), 수정 기록은 버튼 줄 끝 단추에서 들어간다.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  String? _childId;

  /// 아이 탭 끝의 "함께"(아이가 둘 이상일 때). 아이들 시간표를 한 격자에 겹쳐 본다([FamilyBoard]).
  static const _together = '*together';

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

    if (_childId == _together && children.length > 1) {
      return PageBody(
        children: [
          PageHeader(title: '시간표', subtitle: '아이 ${children.length}명 함께 보기'),
          PillTabs<String>(
            items: [for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent), (_together, '함께', null)],
            selected: _together,
            onChanged: (id) => setState(() => _childId = id),
          ),
          const SizedBox(height: AppGap.lg),
          FamilyBoard(children: children),
        ],
      );
    }

    final version = ref.watch(currentVersionProvider(child.id));
    final perms = ref.watch(permissionsProvider);

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return PageBody(
      children: [
        // 학기 이름은 제목 오른쪽 빈자리로. 예전엔 따로 카드(이름 + "시간표 N개"·"수정 기록" 줄)가 있어
        // 시간표가 화면 아래로 밀렸다(실사용 피드백). 큰 제목·버튼·카드 모양은 그대로 둔다.
        PageHeader(
          title: '시간표',
          subtitle: '${child.name} · ${child.institutionText}',
          asideAction: version == null
              ? null
              : _VersionAside(
                  version: version,
                  onTap: () => open(VersionsScreen(childId: child.id)),
                ),
        ),
        if (version != null)
          TimetableBoard(
            child: child,
            version: version,
            // 아이 탭은 "+ 추가"와 한 줄에, 수정 기록은 카드 머리에(줄을 줄여 달라는 실사용 피드백).
            leading: children.length > 1
                ? PillTabs<String>(
                    items: [
                      for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent),
                      (_together, '함께', null),
                    ],
                    selected: child.id,
                    onChanged: (id) => setState(() => _childId = id),
                  )
                : null,
            headerAction: IconButton(
              tooltip: '수정 기록',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => open(RevisionsScreen(versionId: version.id)),
            ),
          )
        else ...[
          if (children.length > 1) ...[
            PillTabs<String>(
              items: [for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent), (_together, '함께', null)],
              selected: child.id,
              onChanged: (id) => setState(() => _childId = id),
            ),
            const SizedBox(height: AppGap.lg),
          ],
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
      ],
    );
  }
}

/// 제목 오른쪽: 위에 "● 사용 중"(방학이면 "● 방학 · 8월 31일까지"), 아래 굵게 "2학년 2학기 ›". 누르면 학기 관리.
class _VersionAside extends ConsumerWidget {
  final TimetableVersion version;
  final VoidCallback onTap;

  const _VersionAside({required this.version, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final today = ref.watch(todayProvider);
    final status = version.covers(today) ? '방학 · ${formatDateShort(version.endDate!)}까지' : '사용 중';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: ConstrainedBox(
        // 학기 이름이 길어도 왼쪽 제목을 밀어내지 않게
        constraints: const BoxConstraints(maxWidth: 170),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(p.status.positive),
                const SizedBox(width: AppGap.xs),
                Flexible(
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppText.caption, color: p.status.positiveText),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    version.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
