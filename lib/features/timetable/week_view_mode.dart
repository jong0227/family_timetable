import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap.dart';

/// 주간 시간표 보기 방식. 사용자가 고르고, 이 폰에 기억된다(가족과 공유하지 않는 개인 취향).
enum WeekViewMode {
  /// 간단히 — 교시는 줄을 맞추고 방과 후는 순서대로 쌓는다. 좁은 화면에서 글씨가 잘 보인다.
  compact('간단히'),

  /// 시간 비례 — 세로축이 실제 시각. 칸 높이가 수업 길이, 칸 사이 간격이 빈 시간이다.
  timeScale('시간 비례');

  final String label;
  const WeekViewMode(this.label);
}

class WeekViewModeController extends Notifier<WeekViewMode> {
  static const _key = 'weekViewMode';

  @override
  WeekViewMode build() {
    final saved = ref.read(bootstrapProvider).prefs.getString(_key);
    return WeekViewMode.values.where((m) => m.name == saved).firstOrNull ?? WeekViewMode.compact;
  }

  Future<void> set(WeekViewMode mode) async {
    state = mode;
    await ref.read(bootstrapProvider).prefs.setString(_key, mode.name);
  }
}

final weekViewModeProvider = NotifierProvider<WeekViewModeController, WeekViewMode>(WeekViewModeController.new);
