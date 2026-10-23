import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';
import 'revisions_screen.dart';
import 'version_detail_screen.dart';

/// 학기(버전) 목록. "2학년 1학기", "2학년 여름방학", "2학년 2학기"…
/// 지난 학기는 지우지 않고 남겨서 언제든 열어 본다. 지금 쓰는 것 하나에 "사용 중".
class VersionsScreen extends ConsumerWidget {
  final String childId;
  const VersionsScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final child = ref.watch(childProvider(childId));
    if (child == null) return const Scaffold();
    final versions = ref.watch(childVersionsProvider(childId));
    final canManage = ref.watch(permissionsProvider).canManageVersions(child);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => showNewVersionDialog(context, ref, child: child),
              icon: const Icon(Icons.add_rounded),
              label: const Text('새 학기 시간표'),
              shape: const StadiumBorder(),
            )
          : null,
      body: PageBody(
        children: [
          PageHeader(title: '학기별 시간표', subtitle: '${child.name} · ${versions.length}개'),
          for (final v in versions) ...[
            _VersionTile(child: child, version: v, isCurrent: v.id == child.currentVersionId, canManage: canManage),
            const SizedBox(height: AppGap.md),
          ],
          if (versions.isEmpty)
            DashCard(
              child: EmptyState(
                emoji: '📒',
                title: '아직 시간표가 없어요',
                actionLabel: canManage ? '새 학기 시간표' : null,
                onAction: () => showNewVersionDialog(context, ref, child: child),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppGap.sm),
            child: Text(
              '학기가 바뀌면 "새 학기 시간표"를 만들어 주세요. 지난 학기 시간표는 그대로 남아요.',
              style: TextStyle(fontSize: AppText.label, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionTile extends ConsumerWidget {
  final Child child;
  final TimetableVersion version;
  final bool isCurrent;
  final bool canManage;

  const _VersionTile({required this.child, required this.version, required this.isCurrent, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final tone = p.child(child.colorIndex);
    return DashCard(
      onTap: () => _open(context),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrent ? tone.accent : p.status.neutral,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        version.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: AppGap.sm),
                      StatusChip('사용 중', color: p.status.positive, dot: true),
                    ],
                  ],
                ),
                const SizedBox(height: AppGap.xxs),
                Text(
                  '일정 ${version.entries.length}개 · ${formatRelative(version.updatedAt)} 수정',
                  style: TextStyle(fontSize: AppText.label, color: p.textMuted),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _menu(context, ref)),
        ],
      ),
    );
  }

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VersionDetailScreen(versionId: version.id)));

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('보기'),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('수정 기록'),
              onTap: () => Navigator.pop(ctx, 'history'),
            ),
            if (canManage && !isCurrent)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('이 시간표를 지금 쓰기'),
                onTap: () => Navigator.pop(ctx, 'current'),
              ),
            if (canManage) ...[
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('복제해서 새 학기 만들기'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('이름 바꾸기'),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: ctx.palette.status.urgent),
                title: Text('삭제', style: TextStyle(color: ctx.palette.status.urgent)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(repositoryProvider);
    switch (action) {
      case 'open':
        _open(context);
      case 'history':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => RevisionsScreen(versionId: version.id)));
      case 'current':
        await repo.setCurrent(child, version);
        if (context.mounted) showToast(context, '이제 "${version.name}" 시간표를 써요');
      case 'copy':
        await showNewVersionDialog(context, ref, child: child, copyFrom: version);
      case 'rename':
        final name = await _askName(context, '이름 바꾸기', version.name);
        if (name != null) await repo.renameVersion(version, name);
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: '"${version.name}" 시간표를 삭제할까요?',
          message: isCurrent ? '지금 쓰는 시간표예요. 지우면 남은 것 중 가장 최근 시간표를 쓰게 돼요.' : null,
          confirmLabel: '삭제',
          destructive: true,
        );
        if (ok) await repo.deleteVersion(child, version, ref.read(childVersionsProvider(child.id)));
    }
  }
}

/// 새 학기(버전) 만들기. 이름 후보를 고르거나 직접 적고, 빈 시간표로 시작할지
/// 지금 시간표를 복제할지 정한다. 만든 버전은 바로 "사용 중"이 된다.
Future<void> showNewVersionDialog(
  BuildContext context,
  WidgetRef ref, {
  required Child child,
  TimetableVersion? copyFrom,
}) async {
  final current = ref.read(currentVersionProvider(child.id));
  final source = copyFrom ?? current;
  final existing = ref.read(childVersionsProvider(child.id)).map((v) => v.name).toSet();
  final candidates = versionNameCandidates(child, DateTime.now(), existing: existing);
  final controller = TextEditingController(text: candidates.firstOrNull ?? '');
  var copy = source != null && source.entries.isNotEmpty;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('새 학기 시간표'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: '이름 (예: 3학년 1학기)'),
              ),
              const SizedBox(height: AppGap.sm),
              Wrap(
                spacing: AppGap.snug,
                runSpacing: AppGap.snug,
                children: [
                  for (final c in candidates)
                    ActionChip(label: Text(c), onPressed: () => setState(() => controller.text = c)),
                ],
              ),
              if (source != null && source.entries.isNotEmpty) ...[
                const SizedBox(height: AppGap.lg),
                PillTabs<bool>(
                  items: [(true, '"${source.name}" 복제', null), (false, '빈 시간표', null)],
                  selected: copy,
                  onChanged: (v) => setState(() => copy = v),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('만들기')),
        ],
      ),
    ),
  );
  final name = controller.text.trim();
  controller.dispose();
  if (result != true || name.isEmpty) return;
  await ref.read(repositoryProvider).createVersion(child, name, copyFrom: copy ? source : null);
  if (context.mounted) showToast(context, '"$name" 시간표를 만들었어요. 지난 시간표는 그대로 남아 있어요');
}

Future<String?> _askName(BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
      ],
    ),
  );
  final name = controller.text.trim();
  controller.dispose();
  return ok == true && name.isNotEmpty ? name : null;
}
