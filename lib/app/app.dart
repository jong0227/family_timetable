import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/design.dart';
import '../features/family/family_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/today/today_screen.dart';
import '../features/update/update_sheet.dart';
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

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 가족 데이터의 저장 형식 버전을 이 앱 기준으로 맞춘다(처음이면 만들고, 옛 버전이면 올린다).
    Future.microtask(() => ref.read(repositoryProvider).initFamily());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱이 다시 앞으로 나오면 "오늘"을 새로 고친다. 방학 시작·끝날을 넘기며 켜 둔 앱도
  /// 맞는 시간표(방학/학기)를 보여주게.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(todayProvider.notifier).state = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final meta = ref.watch(familyMetaProvider).valueOrNull;
    final wide = Breakpoint.of(context) == Breakpoint.expanded;
    final update = ref.watch(availableUpdateProvider).valueOrNull;
    final current = ref.watch(appVersionProvider).valueOrNull;
    Widget topBanner(Widget banner) => SafeArea(
      bottom: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.sm, AppGap.page, 0), child: banner),
    );
    final body = Column(
      children: [
        // 가족 데이터가 이 앱보다 새 형식이면(가족 중 누가 먼저 업데이트) 업데이트를 강하게 권한다.
        if (meta?.isNewerThanApp ?? false)
          topBanner(
            InfoBanner(
              color: p.status.urgent,
              message: '가족 중 누군가 새 버전 앱을 쓰고 있어요. 앱을 업데이트해 주세요.',
              actionLabel: update != null && current != null ? '업데이트' : null,
              onAction: () => showUpdateSheet(context, update!, current: current!),
            ),
          )
        else if (update != null && current != null)
          topBanner(
            InfoBanner(
              color: p.status.info,
              message: '새 버전 v${update.version}이 나왔어요',
              actionLabel: '업데이트',
              onAction: () => showUpdateSheet(context, update, current: current),
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
