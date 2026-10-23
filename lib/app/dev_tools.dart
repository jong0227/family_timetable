import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/timetable_repository.dart';
import '../domain/models.dart';
import '../domain/timetable_logic.dart';
import 'providers.dart';

/// 개발용 도구. 디버그 빌드에서만 화면에 노출한다(`kDebugMode`).
/// 디자인 확인할 때 빈 화면 대신 그럴듯한 가족 데이터를 한 번에 채운다.
const devToolsEnabled = kDebugMode;

Future<void> seedSampleFamily(WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final first = await repo.addChild(
    name: '첫째',
    institution: Institution.elementary,
    grade: 2,
    schoolName: '햇살초등학교',
    colorIndex: 0,
    order: 0,
    firstVersionName: '2학년 2학기',
  );
  var v = ref.read(currentVersionProvider(first.id)) ?? await _waitVersion(ref, first.id);
  const subjects = [
    ['국어', '수학', '바른생활', '즐거운생활', '국어'],
    ['수학', '국어', '슬기로운생활', '창체'],
    ['국어', '즐거운생활', '수학', '안전한생활', '국어'],
    ['수학', '국어', '바른생활', '즐거운생활', '창체'],
    ['국어', '수학', '슬기로운생활', '즐거운생활'],
  ];
  for (var d = 1; d <= 5; d++) {
    v = await repo.replaceSchoolDay(v, d, [
      for (var p = 0; p < subjects[d - 1].length; p++)
        (
          subject: subjects[d - 1][p],
          start: defaultPeriodTime(Institution.elementary, p + 1).$1,
          end: defaultPeriodTime(Institution.elementary, p + 1).$2,
        ),
    ]);
  }
  v = await repo.addEntries(v, [
    for (final d in [1, 3, 5])
      Entry(id: newId(), weekday: d, start: 15 * 60, end: 16 * 60, title: '피아노', kind: EntryKind.academy, place: '도레미 피아노'),
    for (final d in [2, 4])
      Entry(id: newId(), weekday: d, start: 14 * 60 + 30, end: 15 * 60 + 30, title: '태권도', kind: EntryKind.activity, place: '용인 태권도'),
    for (final d in [2, 4])
      Entry(id: newId(), weekday: d, start: 16 * 60 + 30, end: 17 * 60 + 20, title: '영어', kind: EntryKind.academy, place: '키즈 영어'),
  ]);

  final second = await repo.addChild(
    name: '둘째',
    institution: Institution.daycare,
    colorIndex: 1,
    order: 1,
    firstVersionName: '2026년 2학기',
  );
  final v2 = ref.read(currentVersionProvider(second.id)) ?? await _waitVersion(ref, second.id);
  await repo.addEntries(v2, [
    for (var d = 1; d <= 5; d++)
      Entry(id: newId(), weekday: d, start: 9 * 60, end: 16 * 60 + 30, title: '어린이집', kind: EntryKind.care, place: '해님 어린이집'),
  ]);
}

/// 방금 만든 버전이 스트림에 반영되기 전이면 잠깐 기다린다.
Future<TimetableVersion> _waitVersion(WidgetRef ref, String childId) async {
  for (var i = 0; i < 50; i++) {
    final v = ref.read(currentVersionProvider(childId));
    if (v != null) return v;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('버전을 찾지 못했어요');
}
