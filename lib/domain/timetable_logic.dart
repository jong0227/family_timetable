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

/// 시간 비례 보기에서 "학교 시간 접기"로 접을 구간들.
///
/// 학교 교시가 있는 시간대(가장 이른 교시 시작 ~ 가장 늦은 교시 끝) 중에서, **어느 요일이든 학교 말고 다른
/// 일정이 있는 시간은 빼고** 남은 구간만 접는다. 그래야 일요일 10시 학원, 일찍 끝나는 날의 늘봄처럼
/// 학교 시간대에 걸친 다른 일정이 접힌 틈에 숨지 않는다. [minMinutes]보다 짧은 구간은 접어 봐야
/// 줄어드는 게 없어서 그대로 둔다.
List<(int start, int end)> schoolFolds(List<Entry> entries, {int minMinutes = 30}) {
  bool isPeriod(Entry e) => e.kind == EntryKind.school && e.period != null;
  final school = entries.where(isPeriod).toList();
  if (school.isEmpty) return const [];
  final spanStart = school.map((e) => e.start).reduce((a, b) => a < b ? a : b);
  final spanEnd = school.map((e) => e.end).reduce((a, b) => a > b ? a : b);

  final busy = entries.where((e) => !isPeriod(e) && e.end > spanStart && e.start < spanEnd).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final folds = <(int, int)>[];
  var cursor = spanStart;
  for (final b in busy) {
    if (b.start - cursor >= minMinutes) folds.add((cursor, b.start));
    if (b.end > cursor) cursor = b.end;
  }
  if (spanEnd - cursor >= minMinutes) folds.add((cursor, spanEnd));
  return folds;
}

/// 시간 비례 보기의 세로축. 접힌 구간([folds])은 실제 길이와 상관없이 [foldHeight]만 차지하고,
/// 나머지는 1분 = [pxPerMinute]픽셀이다.
class TimeAxis {
  final int start;
  final int end;
  final List<(int start, int end)> folds;
  final double pxPerMinute;
  final double foldHeight;

  const TimeAxis({
    required this.start,
    required this.end,
    this.folds = const [],
    required this.pxPerMinute,
    this.foldHeight = 0,
  });

  /// [minutes] 시각의 세로 위치(px).
  double y(int minutes) {
    var y = 0.0;
    var at = start;
    for (final (a, b) in folds) {
      if (minutes <= a) break;
      y += (a - at) * pxPerMinute;
      if (minutes < b) return y + (minutes - a) / (b - a) * foldHeight;
      y += foldHeight;
      at = b;
    }
    return y + (minutes - at) * pxPerMinute;
  }

  double get height => y(end);

  /// 접힌 구간 한가운데(양 끝 제외)인가 — 정시 눈금을 그리지 않을 자리.
  bool isFolded(int minutes) => folds.any((f) => minutes > f.$1 && minutes < f.$2);
}

/// 시간 비례 보기에서 같은 요일에 시간이 겹치는 일정(예: 학교가 끝나기 전에 시작하는 돌봄)을
/// 나란히 놓기 위한 자리 배정. id → (몇 번째 줄, 그 무리의 줄 수).
/// 겹치는 일정끼리 한 무리로 묶고, 무리 안에서만 폭을 나눈다(안 겹치는 일정은 폭을 다 쓴다).
Map<String, ({int lane, int lanes})> assignLanes(List<Entry> dayEntries) {
  final sorted = [...dayEntries]
    ..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  final result = <String, ({int lane, int lanes})>{};
  var cluster = <(Entry, int)>[];
  var laneEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    for (final (e, lane) in cluster) {
      result[e.id] = (lane: lane, lanes: laneEnds.length);
    }
    cluster = [];
    laneEnds = [];
  }

  for (final e in sorted) {
    if (cluster.isNotEmpty && e.start >= clusterEnd) flush();
    var lane = laneEnds.indexWhere((end) => end <= e.start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(e.end);
    } else {
      laneEnds[lane] = e.end;
    }
    cluster.add((e, lane));
    clusterEnd = cluster.length == 1 ? e.end : (e.end > clusterEnd ? e.end : clusterEnd);
  }
  flush();
  return result;
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

/// 오늘 실제로 쓰는 시간표.
///
/// 1. 기간이 오늘을 덮는 시간표가 있으면 그것(여러 개면 가장 최근에 만든 것).
///    → 여름방학 시간표에 7/21~8/18을 정해 두면 그 기간엔 저절로 방학 시간표가 된다.
/// 2. 없으면 사용자가 "지금 쓰기"로 고른 시간표([Child.currentVersionId]).
///    → 방학이 끝나면 따로 바꾸지 않아도 원래 학기 시간표로 돌아온다.
TimetableVersion? effectiveVersion(Child child, List<TimetableVersion> versions, DateTime today) {
  final mine = versions.where((v) => v.childId == child.id && !v.deleted).toList();
  final dated = mine.where((v) => v.covers(today)).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return dated.firstOrNull ?? mine.where((v) => v.id == child.currentVersionId).firstOrNull;
}

const _terms = ['1학기', '여름방학', '2학기', '겨울방학'];

VersionKind _kindOfTerm(String term) => term.contains('방학') ? VersionKind.vacation : VersionKind.term;

/// 새 버전 만들 때의 이름 후보. **첫 번째가 기본값**이다.
///
/// 학기는 1학기 → 여름방학 → 2학기 → 겨울방학 → 다음 학년 1학기 순서로 흐른다.
/// 이미 있는 이름 중 이 순서에서 가장 뒤에 있는 것의 **다음**을 기본으로 고른다
/// ("2학년 2학기"를 쓰는 중이면 "2학년 겨울방학"). 이미 있는 이름은 후보에서 뺀다.
/// 순서에 맞는 기존 이름이 없으면 오늘 날짜로 짐작한 학기([suggestVersionName])부터.
/// [kind]를 주면 그 종류(학기만 / 방학만) 이름만 낸다. 순서 판단은 두 종류를 합친 흐름으로 한다
/// ("2학년 1학기"까지 있으면 다음 방학은 "2학년 여름방학").
List<String> versionNameCandidates(Child child, DateTime now, {Set<String> existing = const {}, VersionKind? kind}) {
  final graded = child.institution.maxGrade > 0 && child.grade > 0;
  final schoolYear = now.month <= 2 ? now.year - 1 : now.year;
  final (thisLabel, nextLabel) = graded
      ? ('${child.grade}학년', child.grade < child.institution.maxGrade ? '${child.grade + 1}학년' : null)
      : ('$schoolYear년', '${schoolYear + 1}년');
  final sequence = [for (final t in _terms) '$thisLabel $t', if (nextLabel != null) '$nextLabel ${_terms.first}'];

  final lastExisting = sequence.lastIndexWhere(existing.contains);
  final startIndex = lastExisting >= 0
      ? lastExisting + 1
      : sequence.indexOf(suggestVersionName(child, now)).clamp(0, sequence.length - 1);
  final ordered = [...sequence.skip(startIndex), ...sequence.take(startIndex)];
  return ordered.where((n) => !existing.contains(n) && (kind == null || _kindOfTerm(n) == kind)).toList();
}

/// 방학 시간표를 학기 시간표에서 복제할 때: 학교 교시는 빼고(방학엔 수업이 없다)
/// 학원·방과후·활동·돌봄만 남긴다.
List<Entry> entriesForVacation(List<Entry> termEntries) =>
    termEntries.where((e) => !(e.kind == EntryKind.school && e.period != null)).toList();

/// [candidate]와 같은 요일에 시간이 겹치는 일정들(자기 자신 제외).
/// 끝 시각 = 다음 시작 시각은 겹침이 아니다(9:40에 끝나고 9:40에 시작).
List<Entry> findOverlaps(Entry candidate, List<Entry> all) => [
  for (final e in all)
    if (e.id != candidate.id && e.weekday == candidate.weekday && e.start < candidate.end && candidate.start < e.end) e,
];

/// 입력할 때 바로 고를 수 있는 이름 후보. 학교급·종류별로.
List<String> titleSuggestions(EntryKind kind, Institution inst) => switch (kind) {
  EntryKind.school => switch (inst) {
    Institution.elementary => [
      '국어',
      '수학',
      '바른생활',
      '슬기로운생활',
      '즐거운생활',
      '통합',
      '창체',
      '영어',
      '과학',
      '사회',
      '체육',
      '음악',
      '미술',
      '도덕',
      '실과',
    ],
    Institution.middle ||
    Institution.high => ['국어', '수학', '영어', '과학', '사회', '역사', '도덕', '체육', '음악', '미술', '기술가정', '정보', '창체'],
    _ => ['특별활동'],
  },
  EntryKind.academy => ['피아노', '영어', '수학', '미술', '논술', '코딩', '과학'],
  EntryKind.afterSchool => ['로봇', '코딩', '바이올린', '방송댄스', '주산', '과학실험', '바둑', '요리', '영어', '음악줄넘기'],
  EntryKind.activity => ['태권도', '수영', '축구', '줄넘기', '발레'],
  EntryKind.care => ['어린이집', '유치원', '돌봄교실', '지역아동센터'],
  EntryKind.etc => ['병원', '상담'],
};

/// 좁은 격자 칸에 넣을 짧은 이름. 학교 시간표에 실제로 쓰는 줄임말을 따른다.
/// 원래 이름은 그대로 저장하고, 화면에서만 줄인다.
const _shortTitles = {'즐거운생활': '즐생', '슬기로운생활': '슬생', '바른생활': '바생', '안전한생활': '안전', '창의적체험활동': '창체', '기술가정': '기가'};

String shortTitle(String title) => _shortTitles[title.replaceAll(' ', '')] ?? title;

/// 수정 기록 한 줄 요약에 쓰는 일정 설명. "월 3교시 수학", "수 피아노"
String describeEntry(Entry e) {
  final p = e.period != null ? ' ${e.period}교시' : '';
  return '${weekdayLabel(e.weekday)}$p ${e.title}'.trim();
}
