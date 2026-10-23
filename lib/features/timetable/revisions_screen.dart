import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import 'widgets/week_grid.dart';

/// 수정 기록: 이 시간표를 언제 누가 어떻게 고쳤는지. 기록을 누르면 그때 모습을 미리 보고,
/// "이 상태로 되돌리기"로 되돌린다. 되돌린 것도 새 기록으로 남아 다시 되돌릴 수 있다.
class RevisionsScreen extends ConsumerWidget {
  final String versionId;
  const RevisionsScreen({super.key, required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final version = ref.watch(versionProvider(versionId));
    final child = version == null ? null : ref.watch(childProvider(version.childId));
    final revisions = ref.watch(revisionsProvider(versionId)).valueOrNull ?? const <Revision>[];
    if (version == null || child == null) return Scaffold(appBar: AppBar());

    return Scaffold(
      appBar: AppBar(),
      body: PageBody(
        children: [
          PageHeader(title: '수정 기록', subtitle: '${child.name} · ${version.name} · ${revisions.length}개'),
          DashCard(
            child: Column(
              children: [
                for (var i = 0; i < revisions.length; i++)
                  _RevisionRow(
                    revision: revisions[i],
                    isLatest: i == 0,
                    isLast: i == revisions.length - 1,
                    onTap: () => _preview(context, ref, child, version, revisions[i], isLatest: i == 0),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppGap.sm),
            child: Text(
              '기록은 시간표마다 최근 50개까지 남아요.',
              style: TextStyle(fontSize: AppText.label, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _preview(
    BuildContext context,
    WidgetRef ref,
    Child child,
    TimetableVersion version,
    Revision r, {
    required bool isLatest,
  }) async {
    final canRestore = ref.read(permissionsProvider).canRestoreRevision(child);
    final restore = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, AppGap.xl),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                r.summary,
                style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppGap.xs),
              Text(
                '${r.by} · ${formatDateTime(r.createdAt)} · 일정 ${r.entries.length}개',
                style: TextStyle(fontSize: AppText.label, color: ctx.palette.textMuted),
              ),
              const SizedBox(height: AppGap.lg),
              WeekGrid(
                entries: r.entries,
                weekdays: r.entries.any((e) => e.weekday >= 6) ? const [1, 2, 3, 4, 5, 6, 7] : const [1, 2, 3, 4, 5],
              ),
              const SizedBox(height: AppGap.xl),
              if (isLatest)
                Text(
                  '지금 시간표가 이 상태예요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppText.body, color: ctx.palette.textMuted),
                )
              else if (canRestore)
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('이 상태로 되돌리기')),
            ],
          ),
        ),
      ),
    );
    if (restore != true || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: '${formatRelative(r.createdAt)} 상태로 되돌릴까요?',
      message: '가족 모두의 시간표가 바로 바뀌어요. 지금 상태도 기록에 남아서 다시 돌아올 수 있어요.',
      confirmLabel: '되돌리기',
    );
    if (!ok) return;
    await ref.read(repositoryProvider).restoreRevision(version, r);
    if (context.mounted) showToast(context, '되돌렸어요');
  }
}

/// 타임라인 한 줄: 점 + 세로선, 요약, 누가·언제.
class _RevisionRow extends StatelessWidget {
  final Revision revision;
  final bool isLatest;
  final bool isLast;
  final VoidCallback onTap;

  const _RevisionRow({required this.revision, required this.isLatest, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final restored = revision.summary.contains('되돌림');
    final dot = isLatest ? p.status.positive : (restored ? p.status.info : p.status.neutral);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  StatusDot(dot, size: 10),
                  if (!isLast) Expanded(child: Container(width: 2, color: p.status.neutral.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const SizedBox(width: AppGap.md),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppGap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            revision.summary,
                            style: const TextStyle(fontSize: AppText.bodyLg, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isLatest) ...[const SizedBox(width: AppGap.sm), StatusChip('지금', color: p.status.positive)],
                      ],
                    ),
                    const SizedBox(height: AppGap.xxs),
                    Text(
                      '${revision.by} · ${formatRelative(revision.createdAt)} · 일정 ${revision.entries.length}개',
                      style: TextStyle(fontSize: AppText.label, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textMuted),
          ],
        ),
      ),
    );
  }
}
