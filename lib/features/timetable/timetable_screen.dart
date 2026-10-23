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
/// 학기 관리(버전)와 수정 기록은 위쪽 카드에서 들어간다.
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
    final versions = ref.watch(childVersionsProvider(child.id));
    final perms = ref.watch(permissionsProvider);

    return PageBody(
      children: [
        PageHeader(title: '시간표', subtitle: '${child.name} · ${child.institutionText}'),
        if (children.length > 1) ...[
          PillTabs<String>(
            items: [for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent)],
            selected: child.id,
            onChanged: (id) => setState(() => _childId = id),
          ),
          const SizedBox(height: AppGap.lg),
        ],
        _VersionCard(child: child, version: version, versionCount: versions.length),
        const SizedBox(height: AppGap.md),
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

/// "지금: 2학년 2학기" + 학기 관리 / 수정 기록 바로가기.
class _VersionCard extends ConsumerWidget {
  final Child child;
  final TimetableVersion? version;
  final int versionCount;

  const _VersionCard({required this.child, required this.version, required this.versionCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final today = ref.watch(todayProvider);
    final tone = p.child(child.colorIndex);
    final v = version;
    return HeroCard(
      gradient: tone.gradient,
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VersionsScreen(childId: child.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildBadge(child),
              const Spacer(),
              if (v != null)
                v.covers(today)
                    ? StatusChip('방학 · ${formatDateShort(v.endDate!)}까지', color: p.status.positive, dot: true)
                    : StatusChip('사용 중', color: p.status.positive, dot: true),
            ],
          ),
          const SizedBox(height: AppGap.lg),
          Text(
            v?.name ?? '시간표 없음',
            style: TextStyle(fontSize: AppText.hero, fontWeight: FontWeight.w300, color: tone.onContainer, height: 1.1),
          ),
          const SizedBox(height: AppGap.md),
          Row(
            children: [
              _HeroLink(
                icon: Icons.layers_outlined,
                label: '시간표 $versionCount개',
                color: tone.onContainer,
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => VersionsScreen(childId: child.id))),
              ),
              if (v != null) ...[
                const SizedBox(width: AppGap.sm),
                _HeroLink(
                  icon: Icons.history_rounded,
                  label: '수정 기록',
                  color: tone.onContainer,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => RevisionsScreen(versionId: v.id))),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeroLink({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.palette.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppGap.xs),
              Text(
                label,
                style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
