import 'package:family_timetable/data/family_store.dart';
import 'package:family_timetable/data/timetable_repository.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/domain/timetable_logic.dart';
import 'package:flutter_test/flutter_test.dart';

/// 버전·수정 기록·되돌리기 규칙. "잘못 고쳐도 되돌릴 수 있다"가 이 앱의 약속이라
/// 이 테스트가 깨지면 기능을 붙이기 전에 먼저 고친다.
void main() {
  late LocalFamilyStore store;
  late TimetableRepository repo;

  setUp(() {
    store = LocalFamilyStore.memory();
    repo = TimetableRepository(store, actorName: '아빠');
  });

  Future<List<Revision>> revisionsOf(String versionId) async {
    final all = (await store.read(Collections.revisions)).values.map(Revision.fromJson);
    return all.where((r) => r.versionId == versionId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<TimetableVersion> versionById(String id) async =>
      TimetableVersion.fromJson((await store.read(Collections.versions))[id]!);

  Entry piano() => const Entry(id: 'e1', weekday: 1, start: 900, end: 960, title: '피아노', kind: EntryKind.academy);

  test('자녀를 추가하면 첫 버전이 만들어지고 현재로 지정된다', () async {
    final child = await repo.addChild(
      name: '첫째',
      institution: Institution.elementary,
      grade: 2,
      colorIndex: 0,
      order: 0,
      firstVersionName: '2학년 2학기',
    );
    expect(child.currentVersionId, isNotNull);
    final v = await versionById(child.currentVersionId!);
    expect(v.name, '2학년 2학기');
    expect(await revisionsOf(v.id), hasLength(1));
  });

  test('일정을 고칠 때마다 수정 기록이 쌓이고, 기록으로 되돌릴 수 있다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    var v = await versionById(child.currentVersionId!);

    v = await repo.upsertEntry(v, piano());
    final afterAdd = (await revisionsOf(v.id)).first;
    v = await repo.upsertEntry(v, piano().copyWith(title: '피아노(잘못 고침)'));
    expect(v.entries.single.title, '피아노(잘못 고침)');

    v = await repo.restoreRevision(v, afterAdd);
    expect(v.entries.single.title, '피아노');

    final revs = await revisionsOf(v.id);
    expect(revs.first.summary, contains('되돌림'));
    expect(revs.first.by, '아빠');
  });

  test('새 학기 버전을 복제해 만들어도 지난 버전은 그대로 남는다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    final first = await repo.upsertEntry(await versionById(child.currentVersionId!), piano());

    final next = await repo.createVersion(child, '3학년 1학기', copyFrom: first);
    await repo.deleteEntry(next, next.entries.single);

    expect((await versionById(first.id)).entries, hasLength(1), reason: '지난 학기 시간표는 건드리지 않는다');
    expect(next.entries.single.id, isNot(first.entries.single.id), reason: '복제한 일정은 새 id를 받는다');
  });

  test('지금 쓰는 버전을 지우면 남은 최신 버전이 현재가 된다', () async {
    var child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    final older = await versionById(child.currentVersionId!);
    final newer = await repo.createVersion(child, '새 학기');
    child = Child.fromJson((await store.read(Collections.children))[child.id]!);
    expect(child.currentVersionId, newer.id);

    await repo.deleteVersion(child, newer, [older, newer]);
    child = Child.fromJson((await store.read(Collections.children))[child.id]!);
    expect(child.currentVersionId, older.id);
  });

  test('교시 한꺼번에 입력: 여러 요일을 저장해도 기록은 한 장, 안 바뀌면 기록 없음', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    var v = await versionById(child.currentVersionId!);
    final before = (await revisionsOf(v.id)).length;

    final week = {
      1: [(subject: '국어', start: 540, end: 580), (subject: '수학', start: 590, end: 630)],
      2: [(subject: '', start: 540, end: 580), (subject: '통합', start: 590, end: 630)],
      3: <({String subject, int start, int end})>[],
    };
    v = await repo.replaceSchoolWeek(v, week);
    expect(v.entries, hasLength(3));
    expect(v.entries.where((e) => e.weekday == 2).single.period, 2, reason: '빈 교시는 건너뛰어도 교시 번호는 유지');
    final revs = await revisionsOf(v.id);
    expect(revs, hasLength(before + 1));
    expect(revs.first.summary, '월·화 학교 교시 입력');

    await repo.replaceSchoolWeek(v, week);
    expect(await revisionsOf(v.id), hasLength(before + 1), reason: '같은 내용 다시 저장은 기록을 남기지 않는다');
  });

  test('교시 입력은 학원 일정을 건드리지 않는다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    var v = await repo.upsertEntry(await versionById(child.currentVersionId!), piano());
    v = await repo.replaceSchoolWeek(v, {
      1: [(subject: '국어', start: 540, end: 580)],
    });
    expect(v.entries.map((e) => e.title), containsAll(['피아노', '국어']));
  });

  test('id 없이 추가하면 리포지토리가 새 id를 붙인다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    final v = await repo.addEntries(await versionById(child.currentVersionId!), [
      piano().copyWith(id: '', weekday: 1),
      piano().copyWith(id: '', weekday: 3),
    ]);
    final ids = v.entries.map((e) => e.id).toSet();
    expect(ids, hasLength(2));
    expect(ids.contains(''), isFalse);
    expect((await revisionsOf(v.id)).first.summary, '월·수 피아노 추가');
  });

  test('이름이 다른 일정을 한꺼번에 추가하면 기록 요약에 이름을 모두 적는다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    final v = await repo.addEntries(await versionById(child.currentVersionId!), [
      piano().copyWith(id: '', weekday: 5),
      piano().copyWith(id: '', weekday: 1),
      piano().copyWith(id: '', weekday: 2, title: '태권도'),
    ]);
    expect((await revisionsOf(v.id)).first.summary, '피아노·태권도 추가');
  });

  test('스키마 버전: 옛 버전이면 올리고, 더 새 버전은 내리지 않는다', () async {
    await store.writeMeta(FamilyMeta(schemaVersion: 1, createdAt: DateTime(2026)));
    await repo.initFamily();
    final upgraded = (await store.readMeta())!;
    expect(upgraded.schemaVersion, kSchemaVersion);
    expect(upgraded.createdAt, DateTime(2026), reason: '만든 날은 유지');

    await store.writeMeta(FamilyMeta(schemaVersion: kSchemaVersion + 1, createdAt: DateTime(2026)));
    await repo.initFamily();
    expect((await store.readMeta())!.schemaVersion, kSchemaVersion + 1);
  });

  test('방과후 종류는 저장했다 읽어도 그대로, 모르는 종류는 기타', () {
    final e = piano().copyWith(kind: EntryKind.afterSchool, title: '로봇');
    expect(Entry.fromJson(e.toJson()).kind, EntryKind.afterSchool);
    expect(Entry.fromJson({...e.toJson(), 'kind': 'futureKind'}).kind, EntryKind.etc);
  });

  group('방학 시간표', () {
    Future<Child> childNow(String id) async => Child.fromJson((await store.read(Collections.children))[id]!);

    test('학기에서 복제하면 학교 교시는 빼고 학원·방과후만 가져온다', () async {
      final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
      var term = await versionById(child.currentVersionId!);
      term = await repo.replaceSchoolWeek(term, {
        1: [(subject: '국어', start: 540, end: 580)],
      });
      term = await repo.addEntries(term, [
        piano().copyWith(id: ''),
        piano().copyWith(id: '', kind: EntryKind.afterSchool),
      ]);

      final vac = await repo.createVersion(child, '2학년 겨울방학', copyFrom: term, kind: VersionKind.vacation);
      expect(vac.kind, VersionKind.vacation);
      expect(vac.entries.map((e) => e.kind), unorderedEquals([EntryKind.academy, EntryKind.afterSchool]));
    });

    test('기간을 정한 방학은 지금 쓰는 시간표를 바꾸지 않고, 그 기간에만 저절로 쓰인다', () async {
      final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
      final term = await versionById(child.currentVersionId!);
      final vac = await repo.createVersion(
        child,
        '2학년 겨울방학',
        kind: VersionKind.vacation,
        startDate: DateTime(2026, 12, 26),
        endDate: DateTime(2027, 2, 28),
      );
      final c = await childNow(child.id);
      expect(c.currentVersionId, term.id, reason: '골라 둔 학기 시간표는 그대로');

      final all = (await store.read(Collections.versions)).values.map(TimetableVersion.fromJson).toList();
      expect(effectiveVersion(c, all, DateTime(2026, 12, 25))!.id, term.id);
      expect(effectiveVersion(c, all, DateTime(2026, 12, 26))!.id, vac.id, reason: '시작일 포함');
      expect(effectiveVersion(c, all, DateTime(2027, 2, 28, 23, 59))!.id, vac.id, reason: '끝날 밤까지 포함');
      expect(effectiveVersion(c, all, DateTime(2027, 3, 2))!.id, term.id, reason: '방학 끝나면 학기로 돌아옴');
    });

    test('기간 없는 방학은 만들자마자 지금 쓰는 시간표가 된다', () async {
      final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
      final vac = await repo.createVersion(child, '2학년 여름방학', kind: VersionKind.vacation);
      expect((await childNow(child.id)).currentVersionId, vac.id);
    });

    test('기간을 나중에 정하거나 지울 수 있다', () async {
      final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
      final vac = await repo.createVersion(child, '2학년 여름방학', kind: VersionKind.vacation);
      await repo.setVersionPeriod(vac, DateTime(2027, 7, 21), DateTime(2027, 8, 18));
      var saved = await versionById(vac.id);
      expect(saved.covers(DateTime(2027, 8, 1)), isTrue);
      await repo.setVersionPeriod(saved, null, null);
      saved = await versionById(vac.id);
      expect(saved.hasPeriod, isFalse);
    });
  });

  test('시간표 종류: 저장값이 없던 옛 데이터는 이름으로 짐작한다', () {
    final base = {'id': 'v', 'childId': 'c', 'entries': <Object>[]};
    expect(TimetableVersion.fromJson({...base, 'name': '2학년 여름방학'}).kind, VersionKind.vacation);
    expect(TimetableVersion.fromJson({...base, 'name': '2학년 2학기'}).kind, VersionKind.term);
    expect(TimetableVersion.fromJson({...base, 'name': '방학', 'kind': 'term'}).kind, VersionKind.term, reason: '저장값 우선');
  });

  test('방학 기간은 날짜만 저장한다(시간대로 하루 밀리지 않게)', () {
    final v = TimetableVersion(
      id: 'v',
      childId: 'c',
      name: '여름방학',
      kind: VersionKind.vacation,
      startDate: DateTime(2027, 7, 21),
      endDate: DateTime(2027, 8, 18),
      entries: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final j = v.toJson();
    expect(j['startDate'], '2027-07-21');
    expect(TimetableVersion.fromJson(j).endDate, DateTime(2027, 8, 18));
  });

  test('수정 기록은 버전마다 최대 개수까지만 남는다', () async {
    final child = await repo.addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    var v = await versionById(child.currentVersionId!);
    for (var i = 0; i < kMaxRevisionsPerVersion + 5; i++) {
      v = await repo.upsertEntry(v, piano().copyWith(start: 900 + i));
    }
    expect(await revisionsOf(v.id), hasLength(kMaxRevisionsPerVersion));
  });
}
