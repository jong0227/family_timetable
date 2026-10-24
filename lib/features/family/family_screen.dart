import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';
import '../update/release_notes_screen.dart';
import '../update/update_sheet.dart';
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
        DashboardGrid(
          children: [
            DashCard(
              icon: Icons.child_care_rounded,
              title: '아이들 ${children.length}명',
              linkLabel: perms.canManageChildren ? '+ 추가' : null,
              onLink: () => showChildFormSheet(context),
              child: children.isEmpty
                  ? Text(
                      '아직 아이가 없어요',
                      style: TextStyle(fontSize: AppText.body, color: p.textMuted),
                    )
                  : Column(
                      children: [
                        for (final c in children)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: p.child(c.colorIndex).container,
                              child: Text(
                                c.name.characters.first,
                                style: TextStyle(color: p.child(c.colorIndex).onContainer, fontWeight: FontWeight.w700),
                              ),
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
          ],
        ),
        const SizedBox(height: AppGap.md),
        const _AppInfoCard(),
      ],
    );
  }
}

/// 앱 정보: 지금 버전, 새 버전 확인·업데이트.
class _AppInfoCard extends ConsumerWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final current = ref.watch(appVersionProvider).valueOrNull;
    final check = ref.watch(availableUpdateProvider);
    final update = check.valueOrNull;

    final (String status, Color color) = switch (check) {
      AsyncLoading() => ('확인하는 중…', p.textMuted),
      _ when update != null => ('새 버전 v${update.version}이 있어요', p.status.info),
      _ => ('최신 버전이에요', p.status.positive),
    };

    return DashCard(
      icon: Icons.system_update_alt_rounded,
      title: '앱 정보',
      linkLabel: '업데이트 기록',
      onLink: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReleaseNotesScreen())),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimeText(current == null ? '—' : 'v$current', size: AppText.numSm, weight: FontWeight.w400),
                const SizedBox(height: AppGap.xxs),
                Row(
                  children: [
                    StatusDot(color, size: 6),
                    const SizedBox(width: AppGap.snug),
                    Text(
                      status,
                      style: TextStyle(fontSize: AppText.label, color: p.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (update != null && current != null)
            FilledButton(
              onPressed: () => showUpdateSheet(context, update, current: current),
              child: const Text('업데이트'),
            )
          else
            OutlinedButton(
              onPressed: check.isLoading ? null : () => ref.invalidate(availableUpdateProvider),
              child: const Text('업데이트 확인'),
            ),
        ],
      ),
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

    // 처음에 실수로 "새로 시작"을 눌러 혼자만의 가족이 생겨도, 언제든 다른 가족 코드로 옮길 수 있어야 한다
    // (예전엔 가족 코드 참여가 첫 화면에만 있어서 되돌릴 길이 없었다 — 실사용 피드백).
    final joinOther = firebaseReady
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _joinOtherFamily(context, ref, currentCode: code),
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('다른 가족 코드로 참여'),
            ),
          )
        : null;

    if (code != null) {
      // 한 줄로: 예전엔 제목 줄 + 큰 숫자 코드 + "다른 가족 코드로 참여" 줄까지 카드 하나가 너무 컸다(실사용 피드백).
      // 다른 가족으로 옮기기는 드물게 쓰니 ⋮ 메뉴 안으로.
      return DashCard(
        padding: const EdgeInsets.fromLTRB(AppGap.lg, AppGap.xs, AppGap.xs, AppGap.xs),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 18, color: p.status.positive),
            const SizedBox(width: AppGap.sm),
            Text(
              '가족 코드',
              style: TextStyle(fontSize: AppText.label, color: p.textMuted),
            ),
            const SizedBox(width: AppGap.sm),
            Expanded(
              child: TimeText(code, size: AppText.titleLg, weight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                showToast(context, '가족 코드를 복사했어요. 가족에게 보내 주세요');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('복사'),
            ),
            if (firebaseReady)
              PopupMenuButton<void>(
                tooltip: '더 보기',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => _joinOtherFamily(context, ref, currentCode: code),
                    child: const Text('다른 가족 코드로 참여'),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
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
        ),
        ?joinOther,
      ],
    );
  }

  /// 다른 가족 코드로 옮기기. 지금 가족의 데이터는 지우지 않는다(코드로 언제든 돌아올 수 있다).
  /// 옮긴 뒤엔 "나는 누구예요?"(회원 고르기)로 간다.
  Future<void> _joinOtherFamily(BuildContext context, WidgetRef ref, {required String? currentCode}) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('다른 가족 코드로 참여'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '가족 코드 6자리'),
            ),
            const SizedBox(height: AppGap.md),
            Text(
              currentCode != null
                  ? '지금 가족($currentCode)에서 나와 새 가족의 시간표를 봐요. 지금 가족의 시간표는 지워지지 않고, 코드로 다시 돌아올 수 있어요.'
                  : '이 폰에만 저장된 시간표는 새 가족으로 옮겨지지 않아요. 새 가족의 시간표를 보게 돼요.',
              style: TextStyle(fontSize: AppText.label, color: ctx.palette.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('참여')),
        ],
      ),
    );
    final code = controller.text.trim().toUpperCase();
    controller.dispose();
    if (ok != true || code.isEmpty || !context.mounted) return;
    if (code == currentCode) return showToast(context, '이미 이 가족이에요');
    try {
      await ref.read(sessionProvider.notifier).joinFamily(code);
    } catch (e) {
      if (context.mounted) showToast(context, '$e');
    }
  }
}
