import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/timetable_logic.dart';
import 'family_store.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// 버전마다 남겨 두는 수정 기록 최대 개수. 넘으면 오래된 것부터 지운다.
/// (학기 하나에 50번 넘게 고칠 일은 드물고, 문서 수가 끝없이 늘어나는 걸 막는다.)
const kMaxRevisionsPerVersion = 50;

/// 시간표 데이터를 바꾸는 일은 전부 여기를 거친다. 화면에서 store를 직접 만지지 않는다.
///
/// 핵심 규칙: **버전의 일정을 바꿀 때는 반드시 [saveEntries]를 쓴다.**
/// 그래야 수정 기록이 같이 남아서 잘못 고친 걸 되돌릴 수 있다.
class TimetableRepository {
  final FamilyStore store;

  /// 수정 기록의 "누가"에 들어갈 이름(아빠, 엄마, 첫째…).
  final String actorName;

  const TimetableRepository(this.store, {required this.actorName});

  // ── 가족 ───────────────────────────────────────────────

  /// 새 가족 데이터의 첫 기록(스키마 버전). 이미 있으면 건드리지 않는다.
  Future<void> initFamily() async {
    if (await store.readMeta() == null) await store.writeMeta(FamilyMeta.current());
  }

  // ── 회원 ───────────────────────────────────────────────

  Future<Member> addMember(String name, MemberRole role, {String? childId}) async {
    final m = Member(id: newId(), name: name, role: role, childId: childId, updatedAt: DateTime.now());
    await store.put(Collections.members, m.id, m.toJson());
    return m;
  }

  Future<void> saveMember(Member m) => store.put(Collections.members, m.id, m.toJson());

  Future<void> removeMember(String id) => store.remove(Collections.members, id);

  // ── 자녀 ───────────────────────────────────────────────

  /// 자녀를 추가하고 첫 시간표 버전도 같이 만들어 "현재"로 지정한다.
  Future<Child> addChild({
    required String name,
    required Institution institution,
    int grade = 0,
    String schoolName = '',
    required int colorIndex,
    required int order,
    String? firstVersionName,
  }) async {
    var child = Child(
      id: newId(),
      name: name,
      colorIndex: colorIndex,
      institution: institution,
      grade: grade,
      schoolName: schoolName,
      order: order,
      updatedAt: DateTime.now(),
    );
    final v = await _createVersionDoc(child, firstVersionName ?? suggestVersionName(child, DateTime.now()), const []);
    child = child.copyWith(currentVersionId: v.id);
    await store.put(Collections.children, child.id, child.toJson());
    return child;
  }

  Future<void> saveChild(Child c) => store.put(Collections.children, c.id, c.toJson());

  /// 자녀 삭제는 표시만 한다(시간표 기록까지 날아가면 되살릴 방법이 없어서).
  Future<void> deleteChild(Child c) => saveChild(c.copyWith(deleted: true));

  // ── 버전 ───────────────────────────────────────────────

  /// 새 버전. [copyFrom]을 주면 그 일정을 그대로 복제해서 시작한다
  /// (새 학기 시간표는 대부분 지난 학기와 비슷하니까).
  /// [makeCurrent]면 바로 지금 쓰는 시간표로 바꾼다.
  Future<TimetableVersion> createVersion(
    Child child,
    String name, {
    TimetableVersion? copyFrom,
    bool makeCurrent = true,
  }) async {
    final entries = copyFrom == null ? const <Entry>[] : [for (final e in copyFrom.entries) e.copyWith(id: newId())];
    final v = await _createVersionDoc(child, name, entries, copiedFrom: copyFrom?.name);
    if (makeCurrent) await saveChild(child.copyWith(currentVersionId: v.id));
    return v;
  }

  Future<TimetableVersion> _createVersionDoc(Child child, String name, List<Entry> entries, {String? copiedFrom}) async {
    final now = DateTime.now();
    final v = TimetableVersion(
      id: newId(),
      childId: child.id,
      name: name,
      entries: entries,
      createdAt: now,
      updatedAt: now,
    );
    await store.put(Collections.versions, v.id, v.toJson());
    await _addRevision(v, copiedFrom == null ? '"$name" 만듦' : '"$copiedFrom"에서 복제해 만듦');
    return v;
  }

  Future<void> renameVersion(TimetableVersion v, String name) =>
      store.put(Collections.versions, v.id, v.copyWith(name: name).toJson());

  /// 이 버전을 지금 쓰는 시간표로. 지난 학기 시간표로 돌아가는 "버전 되돌리기".
  Future<void> setCurrent(Child child, TimetableVersion v) => saveChild(child.copyWith(currentVersionId: v.id));

  /// 버전 삭제(표시만). 지금 쓰는 버전을 지우면 남은 것 중 가장 최근 것을 현재로 바꾼다.
  Future<void> deleteVersion(Child child, TimetableVersion v, List<TimetableVersion> siblings) async {
    await store.put(Collections.versions, v.id, v.copyWith(deleted: true).toJson());
    if (child.currentVersionId == v.id) {
      final rest = siblings.where((s) => s.id != v.id && !s.deleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await saveChild(rest.isEmpty
          ? child.copyWith(clearCurrentVersion: true)
          : child.copyWith(currentVersionId: rest.first.id));
    }
  }

  // ── 일정 + 수정 기록 ────────────────────────────────────

  /// 버전의 일정을 통째로 바꾸고, 바뀐 뒤 상태를 수정 기록으로 남긴다.
  Future<TimetableVersion> saveEntries(TimetableVersion v, List<Entry> entries, String summary) async {
    final next = v.copyWith(entries: entries);
    await store.put(Collections.versions, next.id, next.toJson());
    await _addRevision(next, summary);
    return next;
  }

  Future<TimetableVersion> upsertEntry(TimetableVersion v, Entry e) {
    final exists = v.entries.any((x) => x.id == e.id);
    final entries = exists ? [for (final x in v.entries) x.id == e.id ? e : x] : [...v.entries, e];
    return saveEntries(v, entries, '${describeEntry(e)} ${exists ? '수정' : '추가'}');
  }

  Future<TimetableVersion> addEntries(TimetableVersion v, List<Entry> es) {
    if (es.length == 1) return upsertEntry(v, es.first);
    final days = es.map((e) => weekdayLabel(e.weekday)).toSet().join('·');
    return saveEntries(v, [...v.entries, ...es], '$days ${es.first.title} 추가');
  }

  Future<TimetableVersion> deleteEntry(TimetableVersion v, Entry e) =>
      saveEntries(v, v.entries.where((x) => x.id != e.id).toList(), '${describeEntry(e)} 삭제');

  /// 한 요일의 학교 교시를 한꺼번에 바꾼다. [subjects]는 1교시부터 순서대로, 빈 문자열이면 그 교시 없음.
  Future<TimetableVersion> replaceSchoolDay(
    TimetableVersion v,
    int weekday,
    List<({String subject, int start, int end})> periods,
  ) {
    final kept = v.entries.where((e) => !(e.weekday == weekday && e.kind == EntryKind.school && e.period != null));
    final added = <Entry>[
      for (var i = 0; i < periods.length; i++)
        if (periods[i].subject.trim().isNotEmpty)
          Entry(
            id: newId(),
            weekday: weekday,
            start: periods[i].start,
            end: periods[i].end,
            title: periods[i].subject.trim(),
            kind: EntryKind.school,
            period: i + 1,
          ),
    ];
    return saveEntries(v, [...kept, ...added], '${weekdayLabel(weekday)} 학교 교시 ${added.length}개 입력');
  }

  /// 수정 기록 하나를 골라 그 상태로 되돌린다. 되돌린 것 자체도 기록으로 남는다.
  Future<TimetableVersion> restoreRevision(TimetableVersion v, Revision r) {
    final t = r.createdAt;
    final when = '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    return saveEntries(v, r.entries, '$when 상태로 되돌림');
  }

  Future<void> _addRevision(TimetableVersion v, String summary) async {
    final existing = await _revisionsOf(v.id);
    // 같은 밀리초 안에 두 번 고치면 시각이 같아져 순서가 뒤섞이고, 정리할 때 새 기록이
    // 지워질 수 있다. 그래서 같은 버전 안에서는 시각이 반드시 앞 기록보다 늦게 찍히게 한다.
    var createdAt = DateTime.now();
    if (existing.isNotEmpty && !createdAt.isAfter(existing.first.createdAt)) {
      createdAt = existing.first.createdAt.add(const Duration(milliseconds: 1));
    }
    final r = Revision(
      id: newId(),
      versionId: v.id,
      childId: v.childId,
      entries: v.entries,
      summary: summary,
      by: actorName,
      createdAt: createdAt,
    );
    await store.put(Collections.revisions, r.id, r.toJson());
    for (final old in [r, ...existing].skip(kMaxRevisionsPerVersion)) {
      await store.remove(Collections.revisions, old.id);
    }
  }

  /// 한 버전의 수정 기록, 최신순.
  Future<List<Revision>> _revisionsOf(String versionId) async {
    final all = await store.read(Collections.revisions);
    return all.values.map(Revision.fromJson).where((r) => r.versionId == versionId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
