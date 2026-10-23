import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';
import 'child_form_sheet.dart';

/// 가족 탭: 공유 상태, 아이들, 가족 구성원.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permissionsProvider);
    final children = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final me = ref.watch(meProvider);

    return PageBody(
      children: [
        PageHeader(title: '가족', subtitle: me == null ? null : '${me.name}(으)로 쓰는 중'),
        _SharingCard(session: session),
        const SizedBox(height: AppGap.md),
        DashboardGrid(children: [
          DashCard(
            icon: Icons.child_care_rounded,
            title: '아이들 ${children.length}명',
            linkLabel: perms.canManageChildren ? '+ 추가' : null,
            onLink: () => showChildFormSheet(context),
            child: children.isEmpty
                ? Text('아직 아이가 없어요', style: TextStyle(fontSize: AppText.body, color: p.textMuted))
                : Column(
                    children: [
                      for (final c in children)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: p.child(c.colorIndex).container,
                            child: Text(c.name.characters.first,
                                style: TextStyle(color: p.child(c.colorIndex).onContainer, fontWeight: FontWeight.w700)),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(c.institutionText, style: TextStyle(color: p.textMuted)),
                          trailing: perms.canManageChildren ? const Icon(Icons.chevron_right_rounded) : null,
                          onTap: perms.canManageChildren ? () => showChildFormSheet(context, child: c) : null,
                        ),
                    ],
                  ),
          ),
          DashCard(
            icon: Icons.people_alt_outlined,
            title: '가족 구성원 ${members.length}명',
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.role.label, style: TextStyle(color: p.textMuted)),
                    trailing: m.id == me?.id ? StatusChip('나', color: p.status.positive) : null,
                  ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

class _SharingCard extends ConsumerWidget {
  final Session session;
  const _SharingCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final firebaseReady = ref.watch(bootstrapProvider).firebaseReady;
    final code = session.familyCode;

    if (code != null) {
      return DashCard(
        icon: Icons.sync_rounded,
        title: '가족 공유 중',
        child: Row(
          children: [
            Expanded(child: TimeText(code, size: AppText.kpi, weight: FontWeight.w300)),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                showToast(context, '가족 코드를 복사했어요. 가족에게 보내 주세요');
              },
              child: const Text('코드 복사'),
            ),
          ],
        ),
      );
    }
    return InfoBanner(
      color: firebaseReady ? p.status.info : p.status.neutral,
      message: firebaseReady ? '이 폰에만 저장 중이에요' : '이 폰에만 저장 중 · 가족 공유 설정 전',
      actionLabel: firebaseReady ? '공유 시작' : null,
      onAction: () async {
        try {
          final c = await ref.read(sessionProvider.notifier).startSharing();
          if (context.mounted) showToast(context, '가족 코드 $c 가 만들어졌어요');
        } catch (e) {
          if (context.mounted) showToast(context, '$e');
        }
      },
    );
  }
}
