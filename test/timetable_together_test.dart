import 'package:family_timetable/app/bootstrap.dart';
import 'package:family_timetable/core/design/app_theme.dart';
import 'package:family_timetable/core/design/palette.dart';
import 'package:family_timetable/data/family_store.dart';
import 'package:family_timetable/data/timetable_repository.dart';
import 'package:family_timetable/domain/models.dart';
import 'package:family_timetable/features/timetable/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 시간표 탭 "함께": 아이들 일정을 한 격자에 모아 본다(실사용 요청).
void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('"함께"를 고르면 두 아이 일정이 한 격자에 나온다', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalFamilyStore.memory();
    final repo = TimetableRepository(store, actorName: '아빠');
    Future<void> addKid(String name, int color, Entry e) async {
      final c = await repo.addChild(name: name, institution: Institution.elementary, colorIndex: color, order: color);
      final v = TimetableVersion.fromJson((await store.read(Collections.versions))[c.currentVersionId!]!);
      await repo.upsertEntry(v, e);
    }

    await addKid(
      '첫째',
      0,
      const Entry(id: 'p', weekday: 1, start: 900, end: 960, title: '피아노', kind: EntryKind.academy),
    );
    await addKid(
      '둘째',
      1,
      const Entry(id: 's', weekday: 1, start: 900, end: 960, title: '수영', kind: EntryKind.activity),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWithValue(Bootstrap(prefs: prefs, localStore: store, firebaseReady: false)),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const Scaffold(body: TimetableScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('피아노'), findsOneWidget);
    expect(find.text('수영'), findsNothing, reason: '아이 탭에선 그 아이 것만');

    await tester.tap(find.text('함께'));
    await tester.pumpAndSettle();
    expect(find.text('함께 보기 · 아이 2명'), findsOneWidget);
    expect(find.text('피아노'), findsOneWidget);
    expect(find.text('수영'), findsOneWidget);
  });
}
