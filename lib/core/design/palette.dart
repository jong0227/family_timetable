import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// 색 체계.
///
/// 디자인 방향은 FacilityFlow 대시보드 레퍼런스(docs/DESIGN_SYSTEM.md 참고):
/// 밝은 무채색 바탕 + 흰 카드 + **뜻이 있는 색만** 쓴다. 색은 장식이 아니라 정보다.
///
/// 색이 하는 일은 세 가지로 나누고, **쓰는 자리를 겹치지 않게** 정한다.
/// 1. 상태색([StatusColors]) — "지금 신경 써야 하나?"  작은 점·칩·숫자에만 쓴다.
///    urgent  주황  빈 시간(보호 공백), 겹치는 일정, 되돌릴 수 없는 동작
///    info    청록  동기화·안내·지난 시간표 보는 중
///    positive 초록 지금 쓰는 버전, 진행 중인 일정, 동기화 완료
///    neutral 회색  구분선, 비활성
/// 2. 자녀색([ChildTone]) — "누구인가". 히어로 카드 그라데이션, 자녀 칩·점·배지에만.
/// 3. 종류색([kindTones]) — "무슨 일정인가". 시간표 칸(주간표)과 하루 타임라인의 막대에만.
///    학교 / 방과후 / 학원 / 활동 / 돌봄 / 기타.
///
/// 처음엔 칸도 자녀색으로 칠하고 종류는 이모지로만 나눴는데, 실사용에서 "학교·방과후·학원이
/// 색으로 구분돼야 한눈에 보인다"는 요청이 있었다. 시간표 화면은 이미 자녀 한 명 것만 보여주므로
/// 칸은 종류색으로 칠해도 "누구 것인지"가 헷갈리지 않는다. 종류색은 상태색(주황·청록·초록)과
/// 겹치지 않는 파스텔로만 고른다.
@immutable
class StatusColors {
  final Color urgent;
  final Color info;
  final Color positive;
  final Color neutral;

  /// 글자로 쓸 때의 진한 색. 점·선·막대는 위의 색 그대로, **글자·칩 글씨는 이 색**을 쓴다.
  /// (라이트에서 초록 #0EBE82 글자는 흰 바탕 대비 2.4:1이라 작은 글씨로는 안 읽힌다 — 디자인 점검.
  ///  아래 값은 흰 바탕에서 4.8~5.4:1. 다크는 원래 색이 이미 5.7~8.9:1이라 같은 값을 쓴다.)
  final Color urgentText;
  final Color infoText;
  final Color positiveText;

  const StatusColors({
    required this.urgent,
    required this.info,
    required this.positive,
    required this.neutral,
    required this.urgentText,
    required this.infoText,
    required this.positiveText,
  });

  /// 상태색 하나를 글자용으로. 상태색이 아니면 그대로.
  Color text(Color c) => c == urgent
      ? urgentText
      : c == info
      ? infoText
      : c == positive
      ? positiveText
      : c;
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
    required this.kindTones,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.textMuted,
    required this.dock,
    required this.onDock,
  });

  /// 일정 종류별 색. 칸 배경 container, 글자 onContainer, 막대·범례 점 accent.
  final Map<EntryKind, ChildTone> kindTones;

  ChildTone kind(EntryKind k) => kindTones[k] ?? kindTones[EntryKind.etc]!;

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

  // 자녀색 순서: 장미 → 레몬 → 하늘 → 복숭아 → 민트 → 라벤더
  // 앞의 둘(장미·레몬)은 어떤 종류색과도 겹치지 않는다. 자녀가 1~2명이면 "하늘색 = 첫째인지 학원인지"
  // 헷갈릴 일이 없다(디자인 점검: 예전엔 첫째가 하늘색 = 학원색이었다). 셋째부터는 겹칠 수 있다.
  // 상태색(주황·청록·초록)과 겹치지 않게 채도를 낮춘 파스텔로만 고른다.
  static const light = AppPalette(
    status: StatusColors(
      urgent: Color(0xFFED4714),
      info: Color(0xFF2BA2C3),
      positive: Color(0xFF0EBE82),
      neutral: Color(0xFFD9D9D9),
      urgentText: Color(0xFFD23C0C),
      infoText: Color(0xFF1A7590),
      positiveText: Color(0xFF087A55),
    ),
    childTones: [
      ChildTone(Color(0xFFFBE3EA), Color(0xFF7A2141), Color(0xFFE0698F), [Color(0xFFFFDCE7), Color(0xFFF7EAF9)]),
      ChildTone(Color(0xFFFAF2D6), Color(0xFF6A5410), Color(0xFFD9B23A), [Color(0xFFFAEFC8), Color(0xFFF3F8E1)]),
      ChildTone(Color(0xFFE3EEFB), Color(0xFF1E4A7A), Color(0xFF5B9BE0), [Color(0xFFD6E9FF), Color(0xFFE6F7F4)]),
      ChildTone(Color(0xFFFCE9DF), Color(0xFF7A3B18), Color(0xFFF08A5D), [Color(0xFFFFE1D2), Color(0xFFFFF3E3)]),
      ChildTone(Color(0xFFDFF4EA), Color(0xFF1B5C40), Color(0xFF3FB383), [Color(0xFFD3F3E4), Color(0xFFEAF6FB)]),
      ChildTone(Color(0xFFEEE6FA), Color(0xFF4A2F7A), Color(0xFF9A7BD8), [Color(0xFFE7DCFA), Color(0xFFF7EAF6)]),
    ],
    // 학교는 바탕에 가까운 차분한 회청색(하루의 기본), 그 밖은 서로 멀리 떨어진 파스텔.
    kindTones: {
      EntryKind.school: ChildTone(Color(0xFFE9ECF2), Color(0xFF3A4560), Color(0xFF7D8AA8), []),
      EntryKind.afterSchool: ChildTone(Color(0xFFEEE5FA), Color(0xFF4A2F7A), Color(0xFF9A7BD8), []),
      EntryKind.academy: ChildTone(Color(0xFFDDEBFB), Color(0xFF1E4A7A), Color(0xFF5B9BE0), []),
      EntryKind.activity: ChildTone(Color(0xFFDDF2E6), Color(0xFF1B5C40), Color(0xFF4FAE84), []),
      EntryKind.care: ChildTone(Color(0xFFFCE7DC), Color(0xFF7A3B18), Color(0xFFE8956A), []),
      // 기타는 무채색: 레몬을 자녀 전용으로 남기려고.
      EntryKind.etc: ChildTone(Color(0xFFEFEFF1), Color(0xFF4A4A50), Color(0xFFA0A0A6), []),
    },
    canvas: Color(0xFFF1F1EF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF6F6F4),
    // 8A8A8E는 흰 카드 3.4:1·바탕 3.0:1로 작은 글씨 기준(4.5:1) 미달 → 5.3:1 / 4.7:1 (디자인 점검)
    textMuted: Color(0xFF6B6B70),
    dock: Color(0xFF151517),
    onDock: Color(0xFFFFFFFF),
  );

  static const dark = AppPalette(
    status: StatusColors(
      urgent: Color(0xFFFF6A3D),
      info: Color(0xFF4CC0DF),
      positive: Color(0xFF2BD99C),
      // 3A3A3E였는데 다크 카드 위 정시 줄이 1.2:1로 거의 안 보였다(디자인 점검).
      neutral: Color(0xFF4E4E54),
      urgentText: Color(0xFFFF6A3D),
      infoText: Color(0xFF4CC0DF),
      positiveText: Color(0xFF2BD99C),
    ),
    // 다크모드 일정 칸이 칙칙하다는 실사용 피드백(디자인 점검): 예전 칸 색(262A33·2C2440 등)은 채도가 낮고
    // 카드 202024와 1.1~1.2:1이라 색이 아니라 "조금 밝은 회색"으로 보였다. 칸은 OKLCH 밝기 0.42 근처
    // (노랑·복숭아는 0.44~0.45)·채도 0.07~0.085로 올려 카드와 1.8~2.2:1, 글자는 같은 색조 0.95로
    // 칸 대비 6.4~7.5:1(시각 글자 0.8 투명도도 4.8:1 이상). 함께 보기는 자녀색으로 칸을 칠하므로 자녀색도 같은 기준.
    childTones: [
      ChildTone(Color(0xFF71384D), Color(0xFFFFE7EE), Color(0xFFF38CB1), [Color(0xFF603142), Color(0xFF452E4A)]),
      ChildTone(Color(0xFF645418), Color(0xFFF5EFD8), Color(0xFFCCAF42), [Color(0xFF4F410D), Color(0xFF313D1C)]),
      ChildTone(Color(0xFF1D5178), Color(0xFFDFF1FF), Color(0xFF72B8F2), [Color(0xFF1E4665), Color(0xFF064043)]),
      ChildTone(Color(0xFF784227), Color(0xFFFFE9DE), Color(0xFFF0986E), [Color(0xFF613520), Color(0xFF493314)]),
      ChildTone(Color(0xFF1E5A40), Color(0xFFDEF5E8), Color(0xFF60C99A), [Color(0xFF174E37), Color(0xFF0D3E4C)]),
      ChildTone(Color(0xFF534275), Color(0xFFF0EBFF), Color(0xFFBAA0F3), [Color(0xFF473A63), Color(0xFF4B2C41)]),
    ],
    kindTones: {
      EntryKind.school: ChildTone(Color(0xFF434D61), Color(0xFFE4EFFF), Color(0xFF9CB2D8), []),
      EntryKind.afterSchool: ChildTone(Color(0xFF534275), Color(0xFFF0EBFF), Color(0xFFBAA0F3), []),
      EntryKind.academy: ChildTone(Color(0xFF195277), Color(0xFFDEF2FF), Color(0xFF6EB9F1), []),
      EntryKind.activity: ChildTone(Color(0xFF23593D), Color(0xFFDFF5E7), Color(0xFF68C894), []),
      EntryKind.care: ChildTone(Color(0xFF784227), Color(0xFFFFE9DE), Color(0xFFF0986E), []),
      EntryKind.etc: ChildTone(Color(0xFF4C4D50), Color(0xFFEDEEF3), Color(0xFFAEB1B8), []),
    },
    canvas: Color(0xFF111113),
    // 바탕 111113과 카드 1C1C1F가 1.11:1로 카드 경계가 안 보였다 → 조금 밝게.
    surface: Color(0xFF202024),
    surfaceMuted: Color(0xFF2A2A2F),
    textMuted: Color(0xFF8E8E94),
    dock: Color(0xFFF2F2F2),
    onDock: Color(0xFF111113),
  );
}

extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
