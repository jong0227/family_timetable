import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/app_version.dart';

/// 업데이트 기록(패치노트): 버전마다 무엇이 바뀌었는지. GitHub 릴리스 노트를 그대로 읽는다.
/// 지금 설치된 버전에는 "지금 버전" 표시.
class ReleaseNotesScreen extends ConsumerWidget {
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final notes = ref.watch(releaseNotesProvider);
    final current = ref.watch(appVersionProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('업데이트 기록')),
      body: switch (notes) {
        AsyncData(value: final list?) when list.isNotEmpty => ListView.separated(
          padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.sm, AppGap.page, AppGap.xxl),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppGap.md),
          itemBuilder: (_, i) => ReleaseNoteCard(note: list[i], isCurrent: list[i].version == current),
        ),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        _ => EmptyState(
          emoji: '📡',
          title: '업데이트 기록을 불러오지 못했어요',
          message: '인터넷 연결을 확인해 주세요',
          actionLabel: '다시 시도',
          onAction: () => ref.invalidate(releaseNotesProvider),
        ),
      },
      backgroundColor: p.canvas,
    );
  }
}

/// 버전 하나의 패치노트 카드.
class ReleaseNoteCard extends StatelessWidget {
  final ReleaseNote note;
  final bool isCurrent;
  const ReleaseNoteCard({super.key, required this.note, this.isCurrent = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = note.date;
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TimeText('v${note.version}', size: AppText.titleLg, weight: FontWeight.w700),
              if (d != null) ...[
                const SizedBox(width: AppGap.sm),
                Text(
                  '${d.year}.${d.month}.${d.day}',
                  style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
                ),
              ],
              const Spacer(),
              if (isCurrent) StatusChip('지금 버전', color: p.status.positive, dot: true),
            ],
          ),
          if (note.notes.isNotEmpty) ...[
            const SizedBox(height: AppGap.sm),
            Text(note.notes, style: const TextStyle(fontSize: AppText.body, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// 업데이트하고 처음 켰을 때 한 번: "v0.1.15로 업데이트했어요" + 그 사이 바뀐 점.
/// [since]보다 새롭고 [current] 이하인 버전들의 노트를 보여준다.
Future<void> showWhatsNewSheet(BuildContext context, {required List<ReleaseNote> notes, required AppVersion current}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, AppGap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'v$current로 업데이트했어요 🎉',
                  style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppGap.xs),
                Text(
                  '이번에 바뀐 점이에요',
                  style: TextStyle(fontSize: AppText.body, color: ctx.palette.textMuted),
                ),
                const SizedBox(height: AppGap.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppGap.sm),
                    itemBuilder: (_, i) => ReleaseNoteCard(note: notes[i]),
                  ),
                ),
                const SizedBox(height: AppGap.md),
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
              ],
            ),
          ),
        ),
      ),
    );
