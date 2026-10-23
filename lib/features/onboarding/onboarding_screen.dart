import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';
import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';

/// 처음 켰을 때: "새로 시작" 또는 "가족 코드로 참여" → 내가 누구인지 고르기.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  MemberRole _role = MemberRole.parent;
  bool _joining = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final session = ref.watch(sessionProvider);
    final firebaseReady = ref.watch(bootstrapProvider).firebaseReady;

    // 가족 코드로 들어왔는데 아직 회원을 안 골랐으면: 기존 회원 중 고르기.
    if (session.isShared && !session.isOnboarded) return _PickMember(onNew: () => setState(() {}));

    return Scaffold(
      body: PageBody(
        children: [
          const SizedBox(height: AppGap.xxl),
          const PageHeader(title: '가족 시간표', subtitle: '아이들 시간표를 가족이 함께 봐요'),
          PillTabs<bool>(
            items: const [(false, '새로 시작', null), (true, '가족 코드로 참여', null)],
            selected: _joining,
            onChanged: (v) => setState(() => _joining = v),
          ),
          const SizedBox(height: AppGap.lg),
          if (_joining) ...[
            if (!firebaseReady)
              InfoBanner(color: p.status.info, message: '가족 공유 설정(Firebase) 전이라 아직 참여할 수 없어요'),
            DashCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: '가족 코드 6자리'),
                  ),
                  const SizedBox(height: AppGap.lg),
                  FilledButton(onPressed: _busy || !firebaseReady ? null : _join, child: const Text('참여하기')),
                ],
              ),
            ),
          ] else
            DashCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: '내 호칭 (예: 아빠, 엄마)')),
                  const SizedBox(height: AppGap.lg),
                  PillTabs<MemberRole>(
                    items: [for (final r in MemberRole.values) (r, r.label, null)],
                    selected: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  const SizedBox(height: AppGap.xl),
                  FilledButton(onPressed: _busy ? null : _start, child: const Text('시작하기')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showToast(context, '호칭을 적어 주세요');
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.initFamily();
      final member = await repo.addMember(name, _role);
      await ref.read(sessionProvider.notifier).setMember(member.id);
      // Firebase가 준비돼 있으면 바로 가족 공유를 시작한다(코드는 가족 탭에서 확인).
      if (ref.read(bootstrapProvider).firebaseReady) {
        await ref.read(sessionProvider.notifier).startSharing();
      }
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).joinFamily(_code.text);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 가족에 참여한 직후: 이미 등록된 회원 중 "나"를 고르거나 새로 등록.
class _PickMember extends ConsumerStatefulWidget {
  final VoidCallback onNew;
  const _PickMember({required this.onNew});

  @override
  ConsumerState<_PickMember> createState() => _PickMemberState();
}

class _PickMemberState extends ConsumerState<_PickMember> {
  final _name = TextEditingController();
  MemberRole _role = MemberRole.parent;
  String? _childId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final children = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    return Scaffold(
      body: PageBody(
        children: [
          const SizedBox(height: AppGap.xxl),
          const PageHeader(title: '나는 누구예요?', subtitle: '이 폰을 쓰는 사람을 골라 주세요'),
          DashCard(
            title: '등록된 가족',
            icon: Icons.people_alt_outlined,
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(m.role.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => ref.read(sessionProvider.notifier).setMember(m.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppGap.md),
          DashCard(
            title: '새로 등록',
            icon: Icons.person_add_alt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: '내 호칭')),
                const SizedBox(height: AppGap.md),
                PillTabs<MemberRole>(
                  items: [for (final r in MemberRole.values) (r, r.label, null)],
                  selected: _role,
                  onChanged: (r) => setState(() => _role = r),
                ),
                if (_role == MemberRole.child && children.isNotEmpty) ...[
                  const SizedBox(height: AppGap.md),
                  PillTabs<String?>(
                    items: [for (final c in children) (c.id, c.name, context.palette.child(c.colorIndex).accent)],
                    selected: _childId,
                    onChanged: (id) => setState(() => _childId = id),
                  ),
                ],
                const SizedBox(height: AppGap.lg),
                FilledButton(onPressed: _register, child: const Text('등록')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showToast(context, '호칭을 적어 주세요');
    if (_role == MemberRole.child && _childId == null) return showToast(context, '어느 아이인지 골라 주세요');
    final m = await ref.read(repositoryProvider).addMember(name, _role, childId: _childId);
    await ref.read(sessionProvider.notifier).setMember(m.id);
  }
}
