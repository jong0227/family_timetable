import 'package:flutter/material.dart';

/// 색 체계.
///
/// 디자인 방향은 FacilityFlow 대시보드 레퍼런스(docs/DESIGN_SYSTEM.md 참고):
/// 밝은 무채색 바탕 + 흰 카드 + **뜻이 있는 색만** 쓴다. 색은 장식이 아니라 정보다.
///
/// 색이 하는 일은 딱 두 가지로 나눈다.
/// 1. 상태색([StatusColors]) — "지금 신경 써야 하나?"  작은 점·칩·숫자에만 쓴다.
///    urgent  주황  빈 시간(보호 공백), 겹치는 일정, 되돌릴 수 없는 동작
///    info    청록  동기화·안내·지난 시간표 보는 중
///    positive 초록 지금 쓰는 버전, 진행 중인 일정, 동기화 완료
///    neutral 회색  구분선, 비활성
/// 2. 자녀색([ChildTone]) — "누구의 일정인가". 칸 배경을 옅게, 히어로 카드 그라데이션.
///
/// 일정 종류(학교/학원…)는 색이 아니라 이모지+글자로 구분한다. 세 번째 색 체계를 만들면
/// "파란 칸이 첫째인지 학원인지" 헷갈리기 때문이다.
@immutable
class StatusColors {
  final Color urgent;
  final Color info;
  final Color positive;
  final Color neutral;

  const StatusColors({required this.urgent, required this.info, required this.positive, required this.neutral});
}

/// 자녀 한 명의 색 한 벌.
@immutable
class ChildTone {
  /// 칸 배경(옅게)
  final Color container;

  /// 칸 위 글자
  final Color onContainer;

  /// 점, 테두리, 선택 표시(진하게)
  final Color accent;

  /// 히어로 카드 그라데이션(두 색, 레퍼런스의 유리 같은 파스텔 카드)
  final List<Color> gradient;

  const ChildTone(this.container, this.onContainer, this.accent, this.gradient);
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final StatusColors status;
  final List<ChildTone> childTones;

  /// 바탕(카드 뒤)
  final Color canvas;

  /// 카드
  final Color surface;

  /// 카드 안 작은 칸(입력창, 격자 빈칸)
  final Color surfaceMuted;

  /// 라벨처럼 흐린 글자
  final Color textMuted;

  /// 하단 알약 내비게이션 바탕 / 그 위 글자
  final Color dock;
  final Color onDock;

  const AppPalette({
    required this.status,
    required this.childTones,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.textMuted,
    required this.dock,
    required this.onDock,
  });

  ChildTone child(int colorIndex) => childTones[colorIndex % childTones.length];

  /// 새 자녀에게 줄 색: 이미 쓰는 색을 피해 팔레트 순서대로.
  int nextFreeColor(Iterable<int> used) {
    final taken = used.map((i) => i % childTones.length).toSet();
    for (var i = 0; i < childTones.length; i++) {
      if (!taken.contains(i)) return i;
    }
    return used.length % childTones.length;
  }

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) => this;

  // 자녀색 순서: 하늘 → 복숭아 → 민트 → 라벤더 → 레몬 → 장미
  // 첫째·둘째가 서로 가장 멀리 떨어진 색을 받도록 섞어 두었다.
  // 상태색(주황·청록·초록)과 겹치지 않게 채도를 낮춘 파스텔로만 고른다.
  static const light = AppPalette(
    status: StatusColors(
      urgent: Color(0xFFED4714),
      info: Color(0xFF2BA2C3),
      positive: Color(0xFF0EBE82),
      neutral: Color(0xFFD9D9D9),
    ),
    childTones: [
      ChildTone(Color(0xFFE3EEFB), Color(0xFF1E4A7A), Color(0xFF5B9BE0), [Color(0xFFD6E9FF), Color(0xFFE6F7F4)]),
      ChildTone(Color(0xFFFCE9DF), Color(0xFF7A3B18), Color(0xFFF08A5D), [Color(0xFFFFE1D2), Color(0xFFFFF3E3)]),
      ChildTone(Color(0xFFDFF4EA), Color(0xFF1B5C40), Color(0xFF3FB383), [Color(0xFFD3F3E4), Color(0xFFEAF6FB)]),
      ChildTone(Color(0xFFEEE6FA), Color(0xFF4A2F7A), Color(0xFF9A7BD8), [Color(0xFFE7DCFA), Color(0xFFF7EAF6)]),
      ChildTone(Color(0xFFFAF2D6), Color(0xFF6A5410), Color(0xFFD9B23A), [Color(0xFFFAEFC8), Color(0xFFF3F8E1)]),
      ChildTone(Color(0xFFFBE3EA), Color(0xFF7A2141), Color(0xFFE0698F), [Color(0xFFFFDCE7), Color(0xFFF7EAF9)]),
    ],
    canvas: Color(0xFFF1F1EF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF6F6F4),
    textMuted: Color(0xFF8A8A8E),
    dock: Color(0xFF151517),
    onDock: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    status: StatusColors(
      urgent: Color(0xFFFF6A3D),
      info: Color(0xFF4CC0DF),
      positive: Color(0xFF2BD99C),
      neutral: Color(0xFF3A3A3E),
    ),
    childTones: [
      ChildTone(Color(0xFF1E2A3B), Color(0xFFC4DAF6), Color(0xFF7DB2EC), [Color(0xFF223450), Color(0xFF1D3A38)]),
      ChildTone(Color(0xFF3A2519), Color(0xFFF8D2BF), Color(0xFFF5A07A), [Color(0xFF4A2C1E), Color(0xFF3D3020)]),
      ChildTone(Color(0xFF1A3328), Color(0xFFBCE8D3), Color(0xFF5FCB9C), [Color(0xFF1C3D2E), Color(0xFF1E3340)]),
      ChildTone(Color(0xFF2B2340), Color(0xFFDCCDF7), Color(0xFFB59BEB), [Color(0xFF332850), Color(0xFF3B2640)]),
      ChildTone(Color(0xFF353016), Color(0xFFF1E2A8), Color(0xFFE6C55A), [Color(0xFF423A18), Color(0xFF2E3A1E)]),
      ChildTone(Color(0xFF3A1D29), Color(0xFFF6C4D5), Color(0xFFEE8BAB), [Color(0xFF4A2032), Color(0xFF3A2445)]),
    ],
    canvas: Color(0xFF111113),
    surface: Color(0xFF1C1C1F),
    surfaceMuted: Color(0xFF242428),
    textMuted: Color(0xFF8E8E94),
    dock: Color(0xFFF2F2F2),
    onDock: Color(0xFF111113),
  );
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
