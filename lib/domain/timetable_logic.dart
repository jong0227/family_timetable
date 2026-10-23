import 'models.dart';

/// 화면과 상관없는 계산(교시 시간, 빈 시간, 학기 이름 추천). 전부 순수 함수라
/// 테스트에서 그대로 부른다.

/// 학교급별 기본 교시 시간. 학교마다 조금씩 달라서 "미리 채워 주는 값"일 뿐이고,
/// 입력 화면에서 시간을 바꿀 수 있다.
/// - 초등 40분 수업, 중 45분, 고 50분, 쉬는 시간 10분.
/// - 4교시 뒤에 점심시간 50분.
(int start, int end) defaultPeriodTime(Institution inst, int period) {
  final (firstStart, lesson) = switch (inst) {
    Institution.middle => (9 * 60, 45),
    Institution.high => (8 * 60 + 40, 50),
    _ => (9 * 60, 40),
  };
  const breakMin = 10;
  const lunchMin = 50;
  var t = firstStart;
  for (var p = 1; p < period; p++) {
    t += lesson + (p == 4 ? lunchMin : breakMin);
  }
  return (t, t + lesson);
}

const kMaxPeriods = 7;

/// 하루 일정 사이의 빈 시간. 하교 13:40, 학원 15:00이면 80분 공백.
class Gap {
  final int start;
  final int end;
  const Gap(this.start, this.end);
  int get minutes => end - start;
}

/// 같은 요일 일정들 사이에서 [minMinutes] 이상 비는 구간을 찾는다.
/// 일정이 겹치면(예: 학교가 끝나기 전 돌봄 시작) 공백으로 치지 않는다.
/// 교시 사이 쉬는 시간(10분)은 기본값 [minMinutes]=20 아래라 걸러진다.
List<Gap> findGaps(List<Entry> dayEntries, {int minMinutes = 20}) {
  final sorted = [...dayEntries]..sort((a, b) => a.start.compareTo(b.start));
  final gaps = <Gap>[];
  int? coveredUntil;
  for (final e in sorted) {
    if (coveredUntil != null && e.start - coveredUntil >= minMinutes) {
      gaps.add(Gap(coveredUntil, e.start));
    }
    coveredUntil = coveredUntil == null || e.end > coveredUntil ? e.end : coveredUntil;
  }
  return gaps;
}

/// 학교 일정은 교시가 이어져 있어서 하루에 6~7칸이 된다. "오늘" 화면에서는
/// 한 덩어리("학교 9:00~14:30 · 6교시")로 접어서 보여준다.
class DayBlock {
  final List<Entry> entries;
  const DayBlock(this.entries);

  Entry get first => entries.first;
  int get start => entries.first.start;
  int get end => entries.map((e) => e.end).reduce((a, b) => a > b ? a : b);
  bool get isSchoolBlock => entries.length > 1;
}

List<DayBlock> groupDay(List<Entry> dayEntries) {
  final sorted = [...dayEntries]..sort((a, b) => a.start.compareTo(b.start));
  final blocks = <DayBlock>[];
  var school = <Entry>[];
  void flush() {
    if (school.isNotEmpty) blocks.add(DayBlock(school));
    school = [];
  }

  for (final e in sorted) {
    if (e.kind == EntryKind.school && e.period != null) {
      school.add(e);
    } else {
      flush();
      blocks.add(DayBlock([e]));
    }
  }
  flush();
  blocks.sort((a, b) => a.start.compareTo(b.start));
  return blocks;
}

/// 지금 날짜로 학기를 짐작해 새 버전 이름을 추천한다.
/// 3~7월 1학기, 8월 여름방학 끝무렵이라 2학기, 9~12월 2학기, 1~2월 겨울방학.
String suggestVersionName(Child child, DateTime now) {
  final m = now.month;
  final term = switch (m) {
    >= 3 && <= 7 => '1학기',
    >= 8 && <= 12 => '2학기',
    _ => '겨울방학',
  };
  if (child.institution.maxGrade == 0 || child.grade == 0) {
    // 1~2월은 아직 지난 학년도라 연도를 하나 빼서 "2026년 겨울방학"처럼 붙인다.
    final year = m <= 2 ? now.year - 1 : now.year;
    return '$year년 $term';
  }
  return '${child.grade}학년 $term';
}

/// 버전 만들 때 바로 고를 수 있는 이름 후보.
List<String> versionNameCandidates(Child child, DateTime now) {
  final suggested = suggestVersionName(child, now);
  final prefix = child.institution.maxGrade == 0 || child.grade == 0
      ? '${now.month <= 2 ? now.year - 1 : now.year}년'
      : '${child.grade}학년';
  return {
    suggested,
    for (final t in ['1학기', '여름방학', '2학기', '겨울방학']) '$prefix $t',
  }.toList();
}

/// 수정 기록 한 줄 요약에 쓰는 일정 설명. "월 3교시 수학", "수 피아노"
String describeEntry(Entry e) {
  final p = e.period != null ? ' ${e.period}교시' : '';
  return '${weekdayLabel(e.weekday)}$p ${e.title}'.trim();
}
