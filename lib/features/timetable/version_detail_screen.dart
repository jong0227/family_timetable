import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import 'revisions_screen.dart';
import 'widgets/timetable_board.dart';

/// 버전 하나 보기. 지난 학기 시간표를 열면 위에 "지난 시간표를 보고 있어요" 띠가 뜨고,
/// 거기서 바로 "이걸로 쓰기"(지난 학기로 돌아가기)를 할 수 있다.
class VersionDetailScreen extends ConsumerWidget {
  final String versionId;
  const VersionDetailScreen({super.key, required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final version = ref.watch(versionProvider(versionId));
    final child = version == null ? null : ref.watch(childProvider(version.childId));
    if (version == null || child == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(emoji: '🗂️', title: '이 시간표는 지워졌어요'),
      );
    }
    final isCurrent = child.currentVersionId == version.id;
    final canManage = ref.watch(permissionsProvider).canManageVersions(child);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '수정 기록',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => RevisionsScreen(versionId: version.id))),
          ),
        ],
      ),
      body: PageBody(
        children: [
          PageHeader(title: version.name, subtitle: '${child.name} · ${child.institutionText}'),
          if (!isCurrent)
            InfoBanner(
              color: p.status.info,
              message: '지난 시간표를 보고 있어요',
              actionLabel: canManage ? '이걸로 쓰기' : null,
              onAction: () async {
                await ref.read(repositoryProvider).setCurrent(child, version);
                if (context.mounted) showToast(context, '이제 "${version.name}" 시간표를 써요');
              },
            ),
          TimetableBoard(child: child, version: version),
        ],
      ),
    );
  }
}
