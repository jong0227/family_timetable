import 'package:family_timetable/app/bootstrap.dart';
import 'package:family_timetable/app/providers.dart';
import 'package:family_timetable/core/design/app_theme.dart';
import 'package:family_timetable/core/design/components/navigation.dart';
import 'package:family_timetable/core/design/palette.dart';
import 'package:family_timetable/data/family_store.dart';
import 'package:family_timetable/data/timetable_repository.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘 화면 위쪽(제목·숫자·요일 띠)을 좌우로 밀면 요일이 넘어간다(실사용 요청). 빠르게 튕기든 천천히 밀든.
/// 그 아래(카드)에서 민 건 요일이 아니라 앱 틀의 탭 넘기기로 간다.
void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  Future<void> pumpToday(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalFamilyStore.memory();
    await TimetableRepository(
      store,
      actorName: '아빠',
    ).addChild(name: '첫째', institution: Institution.elementary, colorIndex: 0, order: 0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(Bootstrap(prefs: prefs, localStore: store, firebaseReady: false)),
          // 30초 시계 대신 고정 시각(타이머가 테스트 끝까지 남지 않게)
          clockProvider.overrideWith((_) => Stream.value(DateTime.now())),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const Scaffold(body: TodayScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  String dayTitle(int weekday) => weekday == DateTime.now().weekday ? '오늘' : '${weekdayLabel(weekday)}요일';
  int next(int d) => d % 7 + 1;
  int prev(int d) => (d + 5) % 7 + 1;

  testWidgets('왼쪽으로 밀면 다음 날, 오른쪽으로 밀면 전날(일요일 다음은 월요일)', (tester) async {
    await pumpToday(tester);
    final today = DateTime.now().weekday;
    expect(find.text('오늘'), findsOneWidget);

    // 천천히 충분히 민 경우(거리로 판단)
    await tester.timedDrag(find.byType(WeekdayStrip), const Offset(-200, 0), const Duration(seconds: 1));
    await tester.pump();
    expect(find.text(dayTitle(next(today))), findsOneWidget);

    // 빠르게 튕긴 경우(속도로 판단), 두 번 → 어제
    await tester.fling(find.byType(WeekdayStrip), const Offset(150, 0), 1000);
    await tester.pump();
    await tester.fling(find.byType(WeekdayStrip), const Offset(150, 0), 1000);
    await tester.pump();
    expect(find.text(dayTitle(prev(today))), findsOneWidget);
  });

  testWidgets('좁은 폰(360px)에서 요일 띠가 화면 안에 다 들어가고, 넘겨도 크기가 안 변하며, 띠 위에서 밀어도 넘어간다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpToday(tester);
    final today = DateTime.now().weekday;
    final strip = find.byType(WeekdayStrip);
    final before = tester.getRect(strip);
    expect(before.right, lessThanOrEqualTo(360), reason: '7칸이 다 화면 안(가로 스크롤 없음)');

    // 띠 위에서 왼쪽으로 민다 → 다음 날 (예전엔 띠가 스크롤되며 요일이 안 넘어갔다)
    await tester.timedDrag(strip, const Offset(-200, 0), const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text(dayTitle(next(today))), findsOneWidget);
    expect(tester.getRect(strip), before, reason: '오늘에서 벗어나도 띠 크기·위치가 그대로("오늘로"가 띠 옆에 끼지 않는다)');

    // 한 바퀴(7번) 밀면 다시 오늘
    for (var i = 0; i < 6; i++) {
      await tester.fling(find.byType(WeekdayStrip), const Offset(-150, 0), 1000);
      await tester.pump();
    }
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('조금만 움직인 건 넘기지 않는다', (tester) async {
    await pumpToday(tester);
    await tester.timedDrag(find.byType(WeekdayStrip), const Offset(-30, 0), const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('카드 쪽(위쪽 영역 밖)에서 민 건 요일을 넘기지 않는다(탭 넘기기 몫)', (tester) async {
    await pumpToday(tester);
    final below = tester.getRect(find.byType(WeekdayStrip)).bottomCenter + const Offset(0, 160);
    await tester.timedDragFrom(below, const Offset(-200, 0), const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('제목 쪽에서 밀어도 요일이 넘어간다', (tester) async {
    await pumpToday(tester);
    await tester.timedDrag(find.text('오늘'), const Offset(-200, 0), const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text(dayTitle(next(DateTime.now().weekday))), findsOneWidget);
  });
}
