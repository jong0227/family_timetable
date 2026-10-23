import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/timetable_logic.dart';
import 'family_store.dart';

/// 교시 입력 한 줄(과목, 시각).
typedef SchoolPeriodInput = ({String subject, int start, int end});

const _uuid = Uuid();
String newId() => _uuid.v4();

/// 버전마다 남겨 두는 수정 기록 최대 개수. 넘으면 오래된 것부터 지운다.
/// (학기 하나에 50번 넘게 고칠 일은 드물고, 문서 수가 끝없이 늘어나는 걸 막는다.)
const kMaxRevisionsPerVersion = 50;

/// 시간표 데이터를 바꾸는 일은 전부 여기를 거친다. 화면에서 store를 직접 만지지 않는다.
///
/// 핵심 규칙:
/// - **버전의 일정을 바꿀 때는 반드시 [saveEntries]를 거친다.** 그래야 수정 기록이 같이 남는다.
/// - **고치기 직전에 저장소의 지금 값을 다시 읽고**([_latest]) 그 위에 변경분만 얹는다. 화면이 시트를 연
///   시점의 목록으로 통째로 덮으면, 그사이 다른 가족이 추가한 일정이 기록도 없이 사라진다(코드 점검 H3).
/// - 이름·기간·삭제 표시·지금 쓰는 시간표처럼 **일부만 바꿀 땐 그 필드만 쓴다**([FamilyStore.update], H2).
class TimetableRepository {
  final FamilyStore store;

  /// 수정 기록의 "누가"에 들어갈 이름(아빠, 엄마, 첫째…).
  final String actorName;

  const TimetableRepository(this.store, {required this.actorName});

  static String _now() => DateTime.now().toIso8601String();

  // ── 가족 ───────────────────────────────────────────────

  /// 앱을 켤 때마다 부른다. 처음이면 만들고, 이 앱이 더 새 형식이면 버전을 올린다
  /// (옛 앱이 새 데이터를 덮어쓰지 않게 — ARCHITECTURE 3장 "데이터 마이그레이션").
  /// 더 새 앱이 이미 올려 놓은 버전은 절대 내리지 않는다.
  Future<void> initFamily() async {
    final meta = await store.readMeta();
    if (meta == null) {
      await store.writeMeta(FamilyMeta.current());
    } else if (meta.schemaVersion < kSchemaVersion) {
      await store.writeMeta(FamilyMeta(schemaVersion: kSchemaVersion, createdAt: meta.createdAt));
    }
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
    final versionName = firstVersionName ?? suggestVersionName(child, DateTime.now());
    // 1~2월에 처음 만들면 "○○ 겨울방학"이 추천되므로 이름으로 종류를 정한다.
    final v = await _createVersionDoc(child, versionName, const [], kind: VersionKind.parse(null, name: versionName));
    child = child.copyWith(currentVersionId: v.id);
    await store.put(Collections.children, child.id, child.toJson());
    return child;
  }

  /// 아이 정보 고치기. **바꾼 칸만** 쓴다(시트를 열어 둔 사이 다른 가족이 바꾼 "지금 쓰는 시간표" 등을
  /// 옛 값으로 되돌리지 않게 — 코드 점검 H2).
  Future<void> updateChildInfo(
    Child c, {
    required String name,
    required Institution institution,
    required int grade,
    required String schoolName,
    required int colorIndex,
  }) => store.update(Collections.children, c.id, {
    'name': name,
    'institution': institution.name,
    'grade': grade,
    'schoolName': schoolName,
    'colorIndex': colorIndex,
    'updatedAt': _now(),
  });

  /// 자녀 삭제는 표시만 한다(시간표 기록까지 날아가면 되살릴 방법이 없어서).
  Future<void> deleteChild(Child c) => store.update(Collections.children, c.id, {'deleted': true, 'updatedAt': _now()});

  Future<void> _setCurrentVersionId(String childId, String? versionId) =>
      store.update(Collections.children, childId, {'currentVersionId': versionId, 'updatedAt': _now()});

  // ── 버전 ───────────────────────────────────────────────

  /// 화면이 들고 있던 버전이 아니라 **저장소의 지금 버전**(없으면 받은 그대로).
  Future<TimetableVersion> _latest(TimetableVersion v) async {
    final j = await store.get(Collections.versions, v.id);
    return j == null ? v : TimetableVersion.fromJson(j);
  }

  /// 아이 한 명의 (지우지 않은) 버전들, 최신순.
  Future<List<TimetableVersion>> _versionsOf(String childId) async =>
      (await store.read(
          Collections.versions,
        )).values.map(TimetableVersion.fromJson).where((v) => v.childId == childId && !v.deleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 새 버전. [copyFrom]을 주면 그 일정을 복제해서 시작한다
  /// (새 학기 시간표는 대부분 지난 학기와 비슷하니까). 방학 시간표로 복제하면
  /// 학교 교시는 빼고 학원·방과후 등만 가져온다.
  ///
  /// 지금 쓰는 시간표로 바뀌는가:
  /// - 기간을 정한 방학 → 바꾸지 않는다. 그 기간이 되면 저절로 쓰이고, 끝나면 학기로 돌아온다.
  /// - 그 밖(학기, 기간 없는 방학) → [makeCurrent]면 바로 지금 쓰는 시간표가 된다.
  Future<TimetableVersion> createVersion(
    Child child,
    String name, {
    TimetableVersion? copyFrom,
    VersionKind kind = VersionKind.term,
    DateTime? startDate,
    DateTime? endDate,
    bool makeCurrent = true,
  }) async {
    var source = copyFrom == null ? const <Entry>[] : (await _latest(copyFrom)).entries;
    if (kind == VersionKind.vacation) source = entriesForVacation(source);
    final entries = [for (final e in source) e.copyWith(id: newId())];
    final v = await _createVersionDoc(
      child,
      name,
      entries,
      kind: kind,
      startDate: startDate,
      endDate: endDate,
      copiedFrom: copyFrom?.name,
    );
    final dated = startDate != null && endDate != null;
    if (makeCurrent && !(kind == VersionKind.vacation && dated)) {
      await _setCurrentVersionId(child.id, v.id);
    }
    return v;
  }

  /// 방학 기간 정하기/바꾸기. [start]·[end] 중 하나라도 null이면 기간을 지운다.
  ///
  /// 기간 없이 만들어 "지금 쓰는 시간표"가 된 방학에 기간을 정하면, 지금 쓰는 시간표를 가장 최근 학기로
  /// 돌려 둔다. 그래야 방학이 끝나면 학기로 돌아온다(예전엔 기간이 지나도 방학 시간표가 계속 쓰였다 — H5).
  Future<void> setVersionPeriod(TimetableVersion v, DateTime? start, DateTime? end) async {
    final clear = start == null || end == null;
    final j = (clear ? v.copyWith(clearPeriod: true) : v.copyWith(startDate: start, endDate: end)).toJson();
    await store.update(Collections.versions, v.id, {
      'startDate': j['startDate'],
      'endDate': j['endDate'],
      'updatedAt': j['updatedAt'],
    });
    if (clear || !v.isVacation) return;
    final childJson = await store.get(Collections.children, v.childId);
    if (childJson == null || childJson['currentVersionId'] != v.id) return;
    final term = (await _versionsOf(v.childId)).where((x) => x.kind == VersionKind.term).firstOrNull;
    if (term != null) await _setCurrentVersionId(v.childId, term.id);
  }

  Future<TimetableVersion> _createVersionDoc(
    Child child,
    String name,
    List<Entry> entries, {
    VersionKind kind = VersionKind.term,
    DateTime? startDate,
    DateTime? endDate,
    String? copiedFrom,
  }) async {
    final now = DateTime.now();
    final v = TimetableVersion(
      id: newId(),
      childId: child.id,
      name: name,
      kind: kind,
      startDate: startDate,
      endDate: endDate,
      entries: entries,
      createdAt: now,
      updatedAt: now,
    );
    await store.put(Collections.versions, v.id, v.toJson());
    await _addRevision(v, copiedFrom == null ? '"$name" 만듦' : '"$copiedFrom"에서 복제해 만듦');
    return v;
  }

  Future<void> renameVersion(TimetableVersion v, String name) =>
      store.update(Collections.versions, v.id, {'name': name, 'updatedAt': _now()});

  /// 이 버전을 지금 쓰는 시간표로. 지난 학기 시간표로 돌아가는 "버전 되돌리기".
  Future<void> setCurrent(Child child, TimetableVersion v) => _setCurrentVersionId(child.id, v.id);

  /// 버전 삭제(표시만). 지금 쓰는 버전을 지우면 남은 것 중 가장 최근 것을 현재로 바꾼다.
  Future<void> deleteVersion(Child child, TimetableVersion v) async {
    await store.update(Collections.versions, v.id, {'deleted': true, 'updatedAt': _now()});
    final childJson = await store.get(Collections.children, child.id);
    if (childJson == null || childJson['currentVersionId'] != v.id) return;
    final rest = (await _versionsOf(child.id)).where((s) => s.id != v.id).toList();
    await _setCurrentVersionId(child.id, rest.firstOrNull?.id);
  }

  // ── 댓글 ───────────────────────────────────────────────

  /// 일정에 댓글 달기. 빈 글은 무시한다(null).
  Future<Comment?> addComment({
    required TimetableVersion version,
    required Entry entry,
    required Member author,
    required String text,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return null;
    final c = Comment(
      id: newId(),
      entryId: entry.id,
      versionId: version.id,
      childId: version.childId,
      authorId: author.id,
      authorName: author.name,
      text: body,
      createdAt: DateTime.now(),
    );
    await store.put(Collections.comments, c.id, c.toJson());
    return c;
  }

  Future<void> deleteComment(Comment c) => store.remove(Collections.comments, c.id);

  // ── 일정 + 수정 기록 ────────────────────────────────────

  /// 버전의 일정을 바꾸고, 바뀐 뒤 상태를 수정 기록으로 남긴다. 일정 목록만 쓴다(이름·기간은 그대로).
  Future<TimetableVersion> saveEntries(TimetableVersion v, List<Entry> entries, String summary) async {
    final next = v.copyWith(entries: entries);
    final j = next.toJson();
    await store.update(Collections.versions, next.id, {'entries': j['entries'], 'updatedAt': j['updatedAt']});
    await _addRevision(next, summary);
    return next;
  }

  Future<TimetableVersion> upsertEntry(TimetableVersion v, Entry e) async {
    final latest = await _latest(v);
    final exists = latest.entries.any((x) => x.id == e.id);
    final entries = exists ? [for (final x in latest.entries) x.id == e.id ? e : x] : [...latest.entries, e];
    return saveEntries(latest, entries, '${describeEntry(e)} ${exists ? '수정' : '추가'}');
  }

  /// 새 일정 추가. id가 비어 있으면 여기서 붙인다(화면은 id를 만들지 않는다).
  Future<TimetableVersion> addEntries(TimetableVersion v, List<Entry> drafts) async {
    final es = [for (final e in drafts) e.id.isEmpty ? e.copyWith(id: newId()) : e];
    if (es.length == 1) return upsertEntry(v, es.first);
    final latest = await _latest(v);
    return saveEntries(latest, [...latest.entries, ...es], '${_describeBatch(es)} 추가');
  }

  /// 여러 일정을 한 줄로: 이름이 하나면 "월·수·금 피아노", 여럿이면 "피아노·태권도·영어".
  static String _describeBatch(List<Entry> es) {
    final titles = es.map((e) => e.title).toSet().toList();
    if (titles.length == 1) {
      final days = (es.map((e) => e.weekday).toSet().toList()..sort()).map(weekdayLabel).join('·');
      return '$days ${titles.single}';
    }
    return titles.length <= 3 ? titles.join('·') : '${titles.take(3).join('·')} 외 ${titles.length - 3}개';
  }

  Future<TimetableVersion> deleteEntry(TimetableVersion v, Entry e) async {
    final latest = await _latest(v);
    return saveEntries(latest, latest.entries.where((x) => x.id != e.id).toList(), '${describeEntry(e)} 삭제');
  }

  /// 한 요일의 학교 교시를 한꺼번에 바꾼다. [periods]는 1교시부터 순서대로, 과목이 비면 그 교시 없음.
  Future<TimetableVersion> replaceSchoolDay(TimetableVersion v, int weekday, List<SchoolPeriodInput> periods) =>
      replaceSchoolWeek(v, {weekday: periods});

  /// 여러 요일의 학교 교시를 한 번에 바꾼다. 수정 기록은 **한 장**만 남는다
  /// (교시 입력 화면에서 저장 한 번 = 되돌리기 한 번).
  /// 바뀐 게 없는 요일은 건드리지 않고, 아무것도 안 바뀌면 기록도 남기지 않는다.
  /// 같은 교시에 있던 일정은 **id를 그대로 쓴다** — 댓글이 일정 id에 붙어 있어서, 5교시만 고쳤는데
  /// 3교시 댓글까지 사라지던 문제를 막는다(코드 점검 M1).
  Future<TimetableVersion> replaceSchoolWeek(TimetableVersion v, Map<int, List<SchoolPeriodInput>> byDay) async {
    final latest = await _latest(v);
    var entries = latest.entries;
    final changedDays = <int>[];
    for (final MapEntry(key: weekday, value: periods) in byDay.entries) {
      bool isSchoolPeriod(Entry e) => e.weekday == weekday && e.kind == EntryKind.school && e.period != null;
      final before = entries.where(isSchoolPeriod).toList()..sort((a, b) => a.period!.compareTo(b.period!));
      final idByPeriod = {for (final e in before) e.period!: e.id};
      final after = <Entry>[
        for (var i = 0; i < periods.length; i++)
          if (periods[i].subject.trim().isNotEmpty)
            Entry(
              id: idByPeriod[i + 1] ?? newId(),
              weekday: weekday,
              start: periods[i].start,
              end: periods[i].end,
              title: periods[i].subject.trim(),
              kind: EntryKind.school,
              period: i + 1,
            ),
      ];
      String sig(List<Entry> es) => es.map((e) => '${e.period}|${e.title}|${e.start}|${e.end}').join(',');
      if (sig(before) == sig(after)) continue;
      changedDays.add(weekday);
      entries = [...entries.where((e) => !isSchoolPeriod(e)), ...after];
    }
    if (changedDays.isEmpty) return latest;
    changedDays.sort();
    return saveEntries(latest, entries, '${changedDays.map(weekdayLabel).join('·')} 학교 교시 입력');
  }

  /// 수정 기록 하나를 골라 그 상태로 되돌린다. 되돌린 것 자체도 기록으로 남는다.
  Future<TimetableVersion> restoreRevision(TimetableVersion v, Revision r) async {
    final t = r.createdAt;
    final when = '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    return saveEntries(await _latest(v), r.entries, '$when 상태로 되돌림');
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
