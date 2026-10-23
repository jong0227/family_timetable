import 'package:family_timetable/domain/day_summary.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/domain/permissions.dart';
import 'package:family_timetable/domain/timetable_logic.dart';
import 'package:flutter_test/flutter_test.dart';

Entry e(int weekday, int start, int end, String title, {EntryKind kind = EntryKind.academy, int? period}) =>
    Entry(id: '$weekday-$start', weekday: weekday, start: start, end: end, title: title, kind: kind, period: period);

Child child(String id, {Institution inst = Institution.elementary, int grade = 2}) =>
    Child(id: id, name: id, colorIndex: 0, institution: inst, grade: grade, order: 0, updatedAt: DateTime(2026));

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

  test('겹치는 일정 찾기: 맞닿는 건 겹침이 아니다', () {
    final all = [e(1, 540, 820, '학교'), e(1, 900, 960, '피아노'), e(2, 900, 960, '태권도')];
    expect(findOverlaps(e(1, 930, 1000, '영어'), all).single.title, '피아노');
    expect(findOverlaps(e(1, 960, 1000, '영어'), all), isEmpty);
    expect(findOverlaps(all[1], all), isEmpty, reason: '자기 자신은 제외');
  });

  test('격자용 짧은 과목 이름', () {
    expect(shortTitle('즐거운생활'), '즐생');
    expect(shortTitle('슬기로운 생활'), '슬생');
    expect(shortTitle('수학'), '수학');
  });

  group('시간 비례 보기 자리 배정', () {
    test('안 겹치면 각자 폭을 다 쓴다', () {
      final lanes = assignLanes([e(1, 540, 580, '국어'), e(1, 590, 630, '수학'), e(1, 900, 960, '피아노')]);
      expect(lanes.values.every((s) => s.lanes == 1 && s.lane == 0), isTrue);
    });

    test('겹치는 것끼리만 나란히(학교 끝나기 전 시작하는 돌봄)', () {
      final school = e(1, 540, 820, '학교');
      final care = e(1, 780, 1020, '돌봄');
      final piano = e(1, 1080, 1140, '피아노');
      final lanes = assignLanes([care, school, piano]);
      expect(lanes[school.id], (lane: 0, lanes: 2));
      expect(lanes[care.id], (lane: 1, lanes: 2));
      expect(lanes[piano.id], (lane: 0, lanes: 1), reason: '뒤에 안 겹치는 일정은 다시 폭 전체');
    });

    test('앞 줄이 비면 그 줄을 다시 쓴다', () {
      final a = e(1, 540, 600, 'A');
      final b = e(1, 550, 700, 'B');
      final c = e(1, 610, 650, 'C'); // A가 끝난 뒤, B와는 겹침 → A 자리(0번 줄)
      final lanes = assignLanes([a, b, c]);
      expect(lanes[c.id], (lane: 0, lanes: 2));
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
    test('새 학기 기본값은 이미 있는 학기의 다음', () {
      final c = child('a');
      final oct = DateTime(2026, 10, 23);
      expect(versionNameCandidates(c, oct).first, '2학년 2학기', reason: '아무것도 없으면 오늘 날짜 기준');
      expect(versionNameCandidates(c, oct, existing: {'2학년 2학기'}).first, '2학년 겨울방학');
      expect(versionNameCandidates(c, oct, existing: {'2학년 2학기', '2학년 겨울방학'}).first, '3학년 1학기');
      expect(versionNameCandidates(c, oct, existing: {'2학년 2학기'}), isNot(contains('2학년 2학기')));
    });

    test('종류를 고르면 그 종류 이름만, 순서는 학기·방학을 이어서 판단', () {
      final c = child('a');
      final oct = DateTime(2026, 10, 23);
      final existing = {'2학년 1학기', '2학년 여름방학', '2학년 2학기'};
      expect(versionNameCandidates(c, oct, existing: existing, kind: VersionKind.vacation).first, '2학년 겨울방학');
      expect(versionNameCandidates(c, oct, existing: existing, kind: VersionKind.term).first, '3학년 1학기');
      expect(
        versionNameCandidates(c, oct, existing: existing, kind: VersionKind.term).any((n) => n.contains('방학')),
        isFalse,
      );
    });

    test('마지막 학년은 다음 학년으로 넘기지 않는다', () {
      final c = child('a', grade: 6);
      expect(versionNameCandidates(c, DateTime(2026, 10, 1), existing: {'6학년 겨울방학'}), isNot(contains('7학년 1학기')));
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
    DaySummary at(int now) => buildDaySummary(weekday: 4, children: [child('a')], versionOf: (_) => v, nowMinutes: now);

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
