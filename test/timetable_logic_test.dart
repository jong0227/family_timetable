import 'package:family_timetable/domain/day_summary.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/domain/permissions.dart';
import 'package:family_timetable/domain/timetable_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e(int weekday, int start, int end, String title, {EntryKind kind = EntryKind.academy, int? period}) =>
    Entry(id: '$weekday-$start', weekday: weekday, start: start, end: end, title: title, kind: kind, period: period);

Child child(String id, {Institution inst = Institution.elementary, int grade = 2}) => Child(
    id: id, name: id, colorIndex: 0, institution: inst, grade: grade, order: 0, updatedAt: DateTime(2026));

void main() {
  group('교시 기본 시간', () {
    test('초등 40분 수업, 4교시 뒤 점심', () {
      expect(defaultPeriodTime(Institution.elementary, 1), (540, 580)); // 9:00~9:40
      expect(defaultPeriodTime(Institution.elementary, 4), (690, 730)); // 11:30~12:10
      expect(defaultPeriodTime(Institution.elementary, 5), (780, 820)); // 13:00~13:40
    });
  });

  group('빈 시간', () {
    test('하교와 학원 사이 공백을 찾는다', () {
      final gaps = findGaps([e(1, 540, 820, '학교'), e(1, 900, 960, '피아노')]);
      expect(gaps.single.minutes, 80);
    });

    test('쉬는 시간(10분)과 겹치는 일정은 공백이 아니다', () {
      expect(findGaps([e(1, 540, 580, '1교시'), e(1, 590, 630, '2교시')]), isEmpty);
      expect(findGaps([e(1, 540, 820, '학교'), e(1, 780, 1020, '돌봄')]), isEmpty);
    });
  });

  test('학교 교시는 한 덩어리로 묶는다', () {
    final blocks = groupDay([
      e(1, 540, 580, '국어', kind: EntryKind.school, period: 1),
      e(1, 590, 630, '수학', kind: EntryKind.school, period: 2),
      e(1, 900, 960, '피아노'),
    ]);
    expect(blocks, hasLength(2));
    expect(blocks.first.isSchoolBlock, isTrue);
    expect(blocks.first.end, 630);
  });

  group('학기 이름 추천', () {
    test('학교는 학년+학기', () {
      expect(suggestVersionName(child('a'), DateTime(2026, 10, 23)), '2학년 2학기');
      expect(suggestVersionName(child('a'), DateTime(2026, 3, 2)), '2학년 1학기');
    });
    test('어린이집은 연도+학기, 1~2월은 지난 학년도', () {
      final c = child('b', inst: Institution.daycare, grade: 0);
      expect(suggestVersionName(c, DateTime(2027, 1, 10)), '2026년 겨울방학');
    });
  });

  test('오늘 요약: 진행 중 / 다음 / 끝', () {
    final v = TimetableVersion(
      id: 'v',
      childId: 'a',
      name: '2학년 2학기',
      entries: [e(4, 540, 820, '학교'), e(4, 900, 960, '피아노')],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    DaySummary at(int now) =>
        buildDaySummary(weekday: 4, children: [child('a')], versionOf: (_) => v, nowMinutes: now);

    expect(at(600).children.single.state, NowState.ongoing);
    expect(at(850).children.single.state, NowState.upcoming);
    expect(at(850).nextUpcoming!.start, 900);
    expect(at(1000).children.single.state, NowState.done);
    expect(at(600).gapCount, 1);
  });

  test('권한: 자녀는 자기 시간표만 고친다', () {
    final kid = Member(id: 'm', name: '첫째', role: MemberRole.child, childId: 'a', updatedAt: DateTime(2026));
    final perms = Permissions(kid);
    expect(perms.canEditEntries(child('a')), isTrue);
    expect(perms.canEditEntries(child('b')), isFalse);
    expect(perms.canManageVersions(child('a')), isFalse);
    expect(const Permissions(null).canEditEntries(child('a')), isFalse);
  });
}
