import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/design.dart';
import '../features/family/family_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/today/today_screen.dart';
import 'providers.dart';
import 'session.dart';

class FamilyTimetableApp extends ConsumerWidget {
  const FamilyTimetableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    // 이 폰이 기억하는 회원이 가족 데이터에 없으면(다른 가족이 지웠거나 데이터가 초기화됨)
    // "아무도 아닌 사람"으로 앱을 쓰게 두지 않고 온보딩(회원 고르기)으로 돌려보낸다.
    final members = ref.watch(membersProvider);
    final memberMissing =
        session.isOnboarded && members.hasValue && !members.requireValue.any((m) => m.id == session.memberId);
    return MaterialApp(
      title: '가족 시간표',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: session.isOnboarded && !memberMissing ? const AppShell() : const OnboardingScreen(),
    );
  }
}

/// 탭 목록. 탭을 늘리거나 순서를 바꿀 때는 여기 한 곳만 고친다.
final _tabs = <(DockItem, Widget)>[
  (const DockItem(Icons.wb_sunny_outlined, '오늘'), const TodayScreen()),
  (const DockItem(Icons.calendar_view_week_rounded, '시간표'), const TimetableScreen()),
  (const DockItem(Icons.people_alt_outlined, '가족'), const FamilyScreen()),
];

/// 탭 틀. 좁은 화면은 떠 있는 알약 내비, 넓은 화면(폴드 가로)은 왼쪽 레일.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final meta = ref.watch(familyMetaProvider).valueOrNull;
    final wide = Breakpoint.of(context) == Breakpoint.expanded;
    final body = Column(
      children: [
        if (meta?.isNewerThanApp ?? false)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.sm, AppGap.page, 0),
              child: InfoBanner(color: p.status.urgent, message: '가족 중 누군가 새 버전 앱을 쓰고 있어요. 앱을 업데이트해 주세요.'),
            ),
          ),
        Expanded(
          child: IndexedStack(index: _index, children: [for (final t in _tabs) t.$2]),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: p.canvas,
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in _tabs) NavigationRailDestination(icon: Icon(t.$1.icon), label: Text(t.$1.label)),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: FloatingDock(
        items: [for (final t in _tabs) t.$1],
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
