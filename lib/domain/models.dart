/// 앱 전체의 데이터 모델.
///
/// 저장소(로컬 파일 / Firestore)에는 모두 JSON으로 들어간다. 컬렉션 하나에 문서
/// 하나씩: members, children, versions, revisions.
///
/// 시간은 "자정부터 몇 분"(int)으로 저장한다. 9:40 → 580. 비교·정렬·빈 시간 계산이
/// 문자열보다 훨씬 단순해진다.
library;

/// 기관 유형. 자녀를 추가할 때 고르고, 시간표 입력 화면(교시 유무·기본 교시 시간)이
/// 여기에 따라 달라진다. 둘째가 어린이집 → 초등학교로 올라가면 이 값만 바꾸면 된다.
enum Institution {
  daycare('어린이집', hasPeriods: false, maxGrade: 0),
  kindergarten('유치원', hasPeriods: false, maxGrade: 0),
  elementary('초등학교', hasPeriods: true, maxGrade: 6),
  middle('중학교', hasPeriods: true, maxGrade: 3),
  high('고등학교', hasPeriods: true, maxGrade: 3);

  final String label;
  final bool hasPeriods;
  final int maxGrade;
  const Institution(this.label, {required this.hasPeriods, required this.maxGrade});

  static Institution parse(String? s) =>
      Institution.values.firstWhere((e) => e.name == s, orElse: () => Institution.elementary);
}

enum MemberRole {
  parent('보호자'),
  child('자녀');

  final String label;
  const MemberRole(this.label);

  static MemberRole parse(String? s) =>
      MemberRole.values.firstWhere((e) => e.name == s, orElse: () => MemberRole.parent);
}

enum EntryKind {
  school('학교', '🏫'),
  academy('학원', '📚'),
  activity('활동', '⚽'),
  care('돌봄', '🧸'),
  etc('기타', '📌');

  final String label;
  final String emoji;
  const EntryKind(this.label, this.emoji);

  static EntryKind parse(String? s) =>
      EntryKind.values.firstWhere((e) => e.name == s, orElse: () => EntryKind.etc);
}

const kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 1(월)~7(일) → "월"
String weekdayLabel(int weekday) => kWeekdayLabels[(weekday - 1) % 7];

/// 580 → "9:40"
String formatMinutes(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

DateTime _parseDate(dynamic v) =>
    v is String ? (DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0)) : DateTime.fromMillisecondsSinceEpoch(0);

int _int(dynamic v, [int fallback = 0]) => v is int ? v : (v is num ? v.toInt() : fallback);

/// 앱을 쓰는 사람. 아빠·엄마·아이(폰이 있는 경우)·할머니 등.
class Member {
  final String id;
  final String name;
  final MemberRole role;

  /// 자녀 회원이면 어느 자녀 프로필인지. 자기 시간표만 고칠 수 있게 하는 데 쓴다.
  final String? childId;
  final DateTime updatedAt;

  const Member({
    required this.id,
    required this.name,
    required this.role,
    this.childId,
    required this.updatedAt,
  });

  bool get isParent => role == MemberRole.parent;

  Member copyWith({String? name, MemberRole? role, String? childId, bool clearChild = false}) => Member(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        childId: clearChild ? null : (childId ?? this.childId),
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'childId': childId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        role: MemberRole.parse(j['role'] as String?),
        childId: j['childId'] as String?,
        updatedAt: _parseDate(j['updatedAt']),
      );
}

/// 자녀 프로필. 계정이 아니라 "프로필"이라 폰이 없는 아이(어린이집 둘째)도
/// 부모가 만들어 관리할 수 있다. 나중에 아이가 폰을 가지면 자녀 회원으로 연결한다.
class Child {
  final String id;
  final String name;
  final int colorIndex;
  final Institution institution;

  /// 학년(학교일 때만). 0이면 미지정.
  final int grade;
  final String schoolName;

  /// 화면에 보이는 순서(첫째, 둘째…).
  final int order;

  /// 지금 쓰는 시간표 버전. 옛 버전으로 "되돌리기"는 이 값만 바꾸면 된다.
  final String? currentVersionId;
  final bool deleted;
  final DateTime updatedAt;

  const Child({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.institution,
    this.grade = 0,
    this.schoolName = '',
    required this.order,
    this.currentVersionId,
    this.deleted = false,
    required this.updatedAt,
  });

  Child copyWith({
    String? name,
    int? colorIndex,
    Institution? institution,
    int? grade,
    String? schoolName,
    int? order,
    String? currentVersionId,
    bool clearCurrentVersion = false,
    bool? deleted,
  }) =>
      Child(
        id: id,
        name: name ?? this.name,
        colorIndex: colorIndex ?? this.colorIndex,
        institution: institution ?? this.institution,
        grade: grade ?? this.grade,
        schoolName: schoolName ?? this.schoolName,
        order: order ?? this.order,
        currentVersionId: clearCurrentVersion ? null : (currentVersionId ?? this.currentVersionId),
        deleted: deleted ?? this.deleted,
        updatedAt: DateTime.now(),
      );

  /// "초등학교 2학년" / "어린이집"
  String get institutionText {
    if (institution.maxGrade == 0 || grade == 0) return institution.label;
    return '${institution.label} $grade학년';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'institution': institution.name,
        'grade': grade,
        'schoolName': schoolName,
        'order': order,
        'currentVersionId': currentVersionId,
        'deleted': deleted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Child.fromJson(Map<String, dynamic> j) => Child(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        colorIndex: _int(j['colorIndex']),
        institution: Institution.parse(j['institution'] as String?),
        grade: _int(j['grade']),
        schoolName: (j['schoolName'] as String?) ?? '',
        order: _int(j['order']),
        currentVersionId: j['currentVersionId'] as String?,
        deleted: j['deleted'] == true,
        updatedAt: _parseDate(j['updatedAt']),
      );
}

/// 시간표 한 칸. 요일 하나, 시간 하나.
class Entry {
  final String id;

  /// 1(월) ~ 7(일)
  final int weekday;

  /// 자정부터 몇 분
  final int start;
  final int end;
  final String title;
  final EntryKind kind;

  /// 학교 교시(1~7). 교시가 없는 일정이면 null.
  final int? period;
  final String place;
  final String memo;

  /// 데려다주거나 데리러 가는 사람(회원 id).
  final String? pickupMemberId;

  const Entry({
    required this.id,
    required this.weekday,
    required this.start,
    required this.end,
    required this.title,
    required this.kind,
    this.period,
    this.place = '',
    this.memo = '',
    this.pickupMemberId,
  });

  Entry copyWith({
    int? weekday,
    int? start,
    int? end,
    String? title,
    EntryKind? kind,
    int? period,
    bool clearPeriod = false,
    String? place,
    String? memo,
    String? pickupMemberId,
    bool clearPickup = false,
    String? id,
  }) =>
      Entry(
        id: id ?? this.id,
        weekday: weekday ?? this.weekday,
        start: start ?? this.start,
        end: end ?? this.end,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        period: clearPeriod ? null : (period ?? this.period),
        place: place ?? this.place,
        memo: memo ?? this.memo,
        pickupMemberId: clearPickup ? null : (pickupMemberId ?? this.pickupMemberId),
      );

  String get timeText => '${formatMinutes(start)}~${formatMinutes(end)}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekday': weekday,
        'start': start,
        'end': end,
        'title': title,
        'kind': kind.name,
        'period': period,
        'place': place,
        'memo': memo,
        'pickupMemberId': pickupMemberId,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        weekday: _int(j['weekday'], 1),
        start: _int(j['start']),
        end: _int(j['end']),
        title: (j['title'] as String?) ?? '',
        kind: EntryKind.parse(j['kind'] as String?),
        period: j['period'] == null ? null : _int(j['period']),
        place: (j['place'] as String?) ?? '',
        memo: (j['memo'] as String?) ?? '',
        pickupMemberId: j['pickupMemberId'] as String?,
      );
}

/// 이름 붙은 시간표 한 벌. "2학년 1학기", "2학년 여름방학"처럼 학기마다 하나씩 만들고,
/// 지난 학기 것도 지우지 않고 남겨서 나중에 다시 볼 수 있다.
class TimetableVersion {
  final String id;
  final String childId;
  final String name;
  final List<Entry> entries;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TimetableVersion({
    required this.id,
    required this.childId,
    required this.name,
    required this.entries,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  TimetableVersion copyWith({String? name, List<Entry>? entries, bool? deleted}) => TimetableVersion(
        id: id,
        childId: childId,
        name: name ?? this.name,
        entries: entries ?? this.entries,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  List<Entry> entriesOn(int weekday) =>
      entries.where((e) => e.weekday == weekday).toList()..sort((a, b) => a.start.compareTo(b.start));

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'deleted': deleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TimetableVersion.fromJson(Map<String, dynamic> j) => TimetableVersion(
        id: j['id'] as String,
        childId: (j['childId'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        entries: entriesFromJson(j['entries']),
        deleted: j['deleted'] == true,
        createdAt: _parseDate(j['createdAt']),
        updatedAt: _parseDate(j['updatedAt']),
      );
}

/// 버전 안의 수정 기록. 시간표를 고칠 때마다 "고친 뒤 상태"를 통째로 한 장 찍어 둔다.
/// 잘못 고쳤으면 원하는 기록을 골라 그 상태로 되돌린다(되돌리는 것도 기록이 하나
/// 더 쌓이는 것이라, 되돌린 걸 다시 되돌릴 수도 있다).
class Revision {
  final String id;
  final String versionId;
  final String childId;
  final List<Entry> entries;
  final String summary;
  final String by;
  final DateTime createdAt;

  const Revision({
    required this.id,
    required this.versionId,
    required this.childId,
    required this.entries,
    required this.summary,
    required this.by,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionId': versionId,
        'childId': childId,
        'entries': entries.map((e) => e.toJson()).toList(),
        'summary': summary,
        'by': by,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Revision.fromJson(Map<String, dynamic> j) => Revision(
        id: j['id'] as String,
        versionId: (j['versionId'] as String?) ?? '',
        childId: (j['childId'] as String?) ?? '',
        entries: entriesFromJson(j['entries']),
        summary: (j['summary'] as String?) ?? '',
        by: (j['by'] as String?) ?? '',
        createdAt: _parseDate(j['createdAt']),
      );
}

List<Entry> entriesFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) Entry.fromJson(Map<String, dynamic>.from(e)),
  ];
}
