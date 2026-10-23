import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';

/// 시간표 탭: 자녀별 주간 시간표 + 버전(학기) 관리.
///
/// 지금은 골격만 있다. 다음 단계(docs/ROADMAP.md M1)에서 주간 격자, 일정 입력 시트,
/// 버전 목록·수정 기록·되돌리기 화면을 이 폴더에 붙인다.
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
    final selected = children.where((c) => c.id == _childId).firstOrNull ?? children.firstOrNull;
    final version = selected == null ? null : ref.watch(currentVersionProvider(selected.id));
    final versions = selected == null ? const <TimetableVersion>[] : ref.watch(childVersionsProvider(selected.id));

    return PageBody(
      children: [
        PageHeader(title: '시간표', subtitle: version == null ? null : '${version.name} · 일정 ${version.entries.length}개'),
        if (children.length > 1) ...[
          PillTabs<String>(
            items: [for (final c in children) (c.id, c.name, p.child(c.colorIndex).accent)],
            selected: selected!.id,
            onChanged: (id) => setState(() => _childId = id),
          ),
          const SizedBox(height: AppGap.lg),
        ],
        DashCard(
          icon: Icons.layers_outlined,
          title: '시간표 버전 ${versions.length}개',
          child: Column(
            children: [
              for (final v in versions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('일정 ${v.entries.length}개', style: TextStyle(color: p.textMuted)),
                  trailing: v.id == selected?.currentVersionId ? StatusChip('사용 중', color: p.status.positive, dot: true) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppGap.md),
        const DashCard(
          child: EmptyState(
            emoji: '🗓️',
            title: '주간 시간표 입력은 다음 단계에서 붙여요',
            message: '교시 한꺼번에 입력, 학원 일정 추가, 수정 기록 되돌리기가 이 자리에 들어와요.',
          ),
        ),
      ],
    );
  }
}
