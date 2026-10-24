import 'package:family_timetable/core/design/app_theme.dart';
import 'package:family_timetable/core/design/palette.dart';
import 'package:family_timetable/domain/app_version.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/features/timetable/widgets/time_scale_grid.dart';
import 'package:family_timetable/features/timetable/widgets/week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _e(String id, int weekday, int start, int end, {EntryKind kind = EntryKind.academy, int? period}) =>
    Entry(id: id, weekday: weekday, start: start, end: end, title: id, kind: kind, period: period);

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(extensions: const [AppPalette.light]),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('보이는 요일에 일정이 없어도 요일 머리는 나온다(주말에만 일정 + 주말 끔)', (tester) async {
    await tester.pumpWidget(_wrap(TimeScaleGrid(entries: [_e('수영', 6, 600, 660)])));
    expect(find.byType(WeekdayHeader), findsNWidgets(5));
    expect(find.text('이 요일들엔 일정이 없어요'), findsOneWidget);
  });

  testWidgets('함께 보기: 두 아이 교시는 아이마다 따로 "학교" 칸으로 접힌다', (tester) async {
    final owner = {'a1': 'A', 'a2': 'A', 'b1': 'B', 'b2': 'B'};
    await tester.pumpWidget(
      _wrap(
        TimeScaleGrid(
          entries: [
            _e('a1', 1, 540, 580, kind: EntryKind.school, period: 1),
            _e('a2', 1, 590, 630, kind: EntryKind.school, period: 2),
            _e('b1', 1, 540, 580, kind: EntryKind.school, period: 1),
            _e('b2', 1, 590, 630, kind: EntryKind.school, period: 2),
          ],
          foldSchool: true,
          groupOf: (e) => owner[e.id]!,
        ),
      ),
    );
    expect(find.text('학교'), findsNWidgets(2));
  });

  group('업데이트 기록', () {
    Map<String, Object?> release(String tag, {bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'published_at': '2026-10-24T02:00:00Z',
      'body': '## 설치\n지우지 말고 덮어 설치\n\n## 바뀐 점\n- **아이콘** 변경\n\n🤖 Generated',
    };

    test('새 버전부터, 초안은 빼고, 설치 안내는 걷어낸다', () {
      final list = releaseHistory([release('v0.1.9'), release('v0.1.14'), release('v0.2.0', draft: true)]);
      expect(list.map((n) => '${n.version}'), ['0.1.14', '0.1.9']);
      expect(list.first.notes, '바뀐 점\n- 아이콘 변경');
      expect(list.first.date, isNotNull);
    });
  });

  group('함께 보기 색 계열', () {
    Child kid(String id, int color) => Child(
      id: id,
      name: id,
      institution: Institution.elementary,
      colorIndex: color,
      order: 0,
      updatedAt: DateTime(2026),
    );
    const p = AppPalette.light;

    test('라벤더 아이는 파랑, 장미 아이는 빨강', () {
      final f = p.familiesFor([kid('a', 5), kid('b', 0)]);
      expect(f['a'], same(p.familyTones[0]));
      expect(f['b'], same(p.familyTones[1]));
    });

    test('같은 계열을 고른 두 아이도 서로 다른 계열로 갈린다', () {
      final f = p.familiesFor([kid('a', 2), kid('b', 5)]); // 하늘·라벤더 = 둘 다 파랑
      expect(f['a'], same(p.familyTones[0]));
      expect(f['b'], same(p.familyTones[1]));
    });
  });
}
