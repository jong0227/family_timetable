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
    return WeekViewMode.values.where((m) => m.name == saved).firstOrNull ?? WeekViewMode.timeScale;
  }

  Future<void> set(WeekViewMode mode) async {
    state = mode;
    await ref.read(bootstrapProvider).prefs.setString(_key, mode.name);
  }
}

final weekViewModeProvider = NotifierProvider<WeekViewModeController, WeekViewMode>(WeekViewModeController.new);

/// 시간 비례 보기에서 학교 시간대를 접을지. 기본은 접힘(학교에 있는 동안은 챙길 게 없어서).
/// 이 폰에 기억된다.
class FoldSchoolController extends Notifier<bool> {
  static const _key = 'foldSchool';

  @override
  bool build() => ref.read(bootstrapProvider).prefs.getBool(_key) ?? true;

  Future<void> toggle() async {
    state = !state;
    await ref.read(bootstrapProvider).prefs.setBool(_key, state);
  }
}

final foldSchoolProvider = NotifierProvider<FoldSchoolController, bool>(FoldSchoolController.new);

/// 시간 비례 보기의 세로 배율(두 손가락으로 벌리면 확대, 오므리면 축소). 이 폰에 기억된다.
class TimeScaleZoomController extends Notifier<double> {
  static const _key = 'timeScaleZoom';
  static const min = 0.5;
  static const max = 2.5;

  @override
  double build() => ref.read(bootstrapProvider).prefs.getDouble(_key) ?? 1.0;

  /// 손가락을 움직이는 동안(저장은 손을 뗄 때 [commit]).
  void preview(double zoom) => state = zoom.clamp(min, max);

  Future<void> commit() => ref.read(bootstrapProvider).prefs.setDouble(_key, state);
}

final timeScaleZoomProvider = NotifierProvider<TimeScaleZoomController, double>(TimeScaleZoomController.new);
