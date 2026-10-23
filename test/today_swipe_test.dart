import 'package:family_timetable/app/bootstrap.dart';
import 'package:family_timetable/app/providers.dart';
import 'package:family_timetable/core/design/app_theme.dart';
import 'package:family_timetable/core/design/palette.dart';
import 'package:family_timetable/data/family_store.dart';
import 'package:family_timetable/data/timetable_repository.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 오늘 화면을 좌우로 밀면 요일이 넘어간다(실사용 요청). 빠르게 튕기든 천천히 밀든 넘어가야 한다.
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
    await tester.timedDrag(find.byType(TodayScreen), const Offset(-200, 0), const Duration(seconds: 1));
    await tester.pump();
    expect(find.text(dayTitle(next(today))), findsOneWidget);

    // 빠르게 튕긴 경우(속도로 판단), 두 번 → 어제
    await tester.fling(find.byType(TodayScreen), const Offset(150, 0), 1000);
    await tester.pump();
    await tester.fling(find.byType(TodayScreen), const Offset(150, 0), 1000);
    await tester.pump();
    expect(find.text(dayTitle(prev(today))), findsOneWidget);
  });

  testWidgets('조금만 움직인 건 넘기지 않는다', (tester) async {
    await pumpToday(tester);
    await tester.timedDrag(find.byType(TodayScreen), const Offset(-30, 0), const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('오늘'), findsOneWidget);
  });
}
