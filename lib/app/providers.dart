import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_store.dart';
import '../data/timetable_repository.dart';
import '../domain/models.dart';
import '../domain/permissions.dart';
import 'bootstrap.dart';
import 'session.dart';

/// 화면이 읽는 상태는 전부 여기 Provider로 나온다. 화면은 store/Firestore를 모른다.
///
/// 흐름: session(가족 코드) → store(로컬/Firestore) → 컬렉션 스트림 → 모델 목록
///       → 파생 상태(나, 권한, 자녀별 현재 시간표)

final storeProvider = Provider<FamilyStore>((ref) {
  final session = ref.watch(sessionProvider);
  final boot = ref.watch(bootstrapProvider);
  final code = session.familyCode;
  if (code != null && boot.firebaseReady) return FirestoreFamilyStore(code);
  return boot.localStore;
});

/// 가족 데이터의 스키마 버전 확인. 이 앱보다 새 형식이면 화면에서 읽기 전용 + 업데이트 안내.
final familyMetaProvider = FutureProvider<FamilyMeta?>((ref) => ref.watch(storeProvider).readMeta());

final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref
      .watch(storeProvider)
      .watch(Collections.members)
      .map((m) => m.values.map(Member.fromJson).toList()..sort((a, b) => a.role.index.compareTo(b.role.index))),
);

final childrenProvider = StreamProvider<List<Child>>(
  (ref) => ref
      .watch(storeProvider)
      .watch(Collections.children)
      .map(
        (m) =>
            m.values.map(Child.fromJson).where((c) => !c.deleted).toList()..sort((a, b) => a.order.compareTo(b.order)),
      ),
);

final versionsProvider = StreamProvider<List<TimetableVersion>>(
  (ref) => ref
      .watch(storeProvider)
      .watch(Collections.versions)
      .map(
        (m) =>
            m.values.map(TimetableVersion.fromJson).where((v) => !v.deleted).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
);

/// 한 버전의 수정 기록(최신순).
final revisionsProvider = StreamProvider.family<List<Revision>, String>(
  (ref, versionId) => ref
      .watch(storeProvider)
      .watch(Collections.revisions)
      .map(
        (m) =>
            m.values.map(Revision.fromJson).where((r) => r.versionId == versionId).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
);

final meProvider = Provider<Member?>((ref) {
  final id = ref.watch(sessionProvider).memberId;
  final members = ref.watch(membersProvider).valueOrNull ?? const [];
  for (final m in members) {
    if (m.id == id) return m;
  }
  return null;
});

final permissionsProvider = Provider<Permissions>((ref) => Permissions(ref.watch(meProvider)));

final repositoryProvider = Provider<TimetableRepository>(
  (ref) => TimetableRepository(ref.watch(storeProvider), actorName: ref.watch(meProvider)?.name ?? '알 수 없음'),
);

/// 자녀별 "지금 쓰는 시간표". 버전이 없으면 null.
final currentVersionProvider = Provider.family<TimetableVersion?, String>((ref, childId) {
  final children = ref.watch(childrenProvider).valueOrNull ?? const [];
  final versions = ref.watch(versionsProvider).valueOrNull ?? const [];
  final child = children.where((c) => c.id == childId).firstOrNull;
  if (child == null) return null;
  return versions.where((v) => v.id == child.currentVersionId).firstOrNull;
});

/// 버전 하나(지워졌거나 없으면 null). 지난 버전 보기·수정 기록 화면이 쓴다.
final versionProvider = Provider.family<TimetableVersion?, String>(
  (ref, versionId) => (ref.watch(versionsProvider).valueOrNull ?? const []).where((v) => v.id == versionId).firstOrNull,
);

final childProvider = Provider.family<Child?, String>(
  (ref, childId) => (ref.watch(childrenProvider).valueOrNull ?? const []).where((c) => c.id == childId).firstOrNull,
);

/// 자녀 한 명의 버전 목록(최신순).
final childVersionsProvider = Provider.family<List<TimetableVersion>, String>(
  (ref, childId) => (ref.watch(versionsProvider).valueOrNull ?? const []).where((v) => v.childId == childId).toList(),
);
