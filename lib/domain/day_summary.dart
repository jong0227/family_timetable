import 'models.dart';
import 'timetable_logic.dart';

/// "오늘" 대시보드 한 장에 필요한 계산을 모은다. 화면은 이 결과를 그리기만 한다.

enum NowState {
  /// 지금 진행 중
  ongoing,

  /// 아직 시작 전인 다음 일정
  upcoming,

  /// 오늘 일정이 모두 끝남
  done,

  /// 이 요일엔 일정이 없음
  none,
}

class ChildDay {
  final Child child;
  final String? versionName;
  final List<DayBlock> blocks;
  final List<Gap> gaps;

  /// 히어로 카드에 보여줄 블록(진행 중이거나 다음). 오늘이 아니면 첫 일정.
  final DayBlock? focus;
  final NowState state;

  const ChildDay({
    required this.child,
    required this.versionName,
    required this.blocks,
    required this.gaps,
    required this.focus,
    required this.state,
  });
}

class DaySummary {
  final int weekday;
  final List<ChildDay> children;

  const DaySummary(this.weekday, this.children);

  int get blockCount => children.fold(0, (s, c) => s + c.blocks.length);
  int get gapCount => children.fold(0, (s, c) => s + c.gaps.length);

  /// 모든 자녀 중 가장 먼저 시작하는 다음 일정(오늘 화면일 때만 의미 있음).
  DayBlock? get nextUpcoming {
    final ups = children.where((c) => c.state == NowState.upcoming && c.focus != null).map((c) => c.focus!).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return ups.firstOrNull;
  }
}

/// [nowMinutes]가 null이면(오늘이 아닌 요일을 보는 중) 진행 중/다음 판단 없이 첫 일정을 focus로.
DaySummary buildDaySummary({
  required int weekday,
  required List<Child> children,
  required TimetableVersion? Function(String childId) versionOf,
  int? nowMinutes,
}) {
  final days = <ChildDay>[];
  for (final child in children) {
    final v = versionOf(child.id);
    final entries = v?.entriesOn(weekday) ?? const <Entry>[];
    final blocks = groupDay(entries);
    final gaps = findGaps(entries);

    DayBlock? focus;
    NowState state;
    if (blocks.isEmpty) {
      state = NowState.none;
    } else if (nowMinutes == null) {
      focus = blocks.first;
      state = NowState.upcoming;
    } else {
      final ongoing = blocks.where((b) => b.start <= nowMinutes && nowMinutes < b.end).firstOrNull;
      final upcoming = blocks.where((b) => b.start > nowMinutes).firstOrNull;
      if (ongoing != null) {
        focus = ongoing;
        state = NowState.ongoing;
      } else if (upcoming != null) {
        focus = upcoming;
        state = NowState.upcoming;
      } else {
        focus = blocks.last;
        state = NowState.done;
      }
    }
    days.add(ChildDay(
      child: child,
      versionName: v?.name,
      blocks: blocks,
      gaps: gaps,
      focus: focus,
      state: state,
    ));
  }
  return DaySummary(weekday, days);
}
