import 'package:flutter/widgets.dart';

/// ─────────────────────────────────────────────────────────────
/// 디자인 토큰 — 화면에서 숫자를 직접 쓰지 않는다.
///
/// 토큰 "이름"은 Moneycraft(`son_allowance_app/lib/theme/app_theme.dart`)와 같게 맞췄다
/// (두 프로젝트를 오가며 같은 단어로 이야기하려고). "값"은 이 앱의 레퍼런스
/// (FacilityFlow — 여백 넓고, 라운드 크고, 제목은 크고 가늘게)에 맞췄다.
/// 규칙 전체와 이유는 `docs/DESIGN_SYSTEM.md`.
/// ─────────────────────────────────────────────────────────────

/// 글씨 크기. 용도로 고르고, 애매하면 한 단계 작은 쪽(플립 좁은 화면에서 잘리지 않게).
class AppText {
  AppText._();

  static const micro = 10.0; // 시간표 격자 안 시간
  static const caption = 11.0; // KPI 라벨, 보조 설명
  static const label = 12.0; // 칩, 태그
  static const body = 14.0; // 본문 기본 (13→14: 30~40대 부모·아이에게 13px은 작다 — 디자인 점검)
  static const bodyLg = 14.0; // 강조 본문
  static const title = 15.0; // 카드 제목
  static const titleLg = 16.0; // 큰 카드 제목
  static const heading = 18.0; // 다이얼로그·시트 제목
  static const numSm = 20.0; // 입력 칸 안 시각("15:00")

  /// 화면 대제목("오늘", "시간표"). 레퍼런스의 "Dashboard"처럼 크고 **가늘게**(w300).
  static const display = 32.0;

  /// KPI 숫자(오늘 일정 4, 빈 시간 1). 크고 가늘게.
  static const kpi = 26.0;

  /// 히어로 카드 안 시각("15:00")
  static const hero = 30.0;
}

class AppEmoji {
  AppEmoji._();

  static const sm = 32.0;
  static const md = 40.0;
  static const lg = 48.0;
}

/// 라운드. 레퍼런스처럼 카드는 크게 둥글린다.
class AppRadius {
  AppRadius._();

  static const xs = 6.0; // 격자 칸, 작은 배지
  static const sm = 10.0; // 작은 칩
  static const md = 14.0; // 입력창, 버튼
  static const lg = 22.0; // 카드 기본
  static const xl = 28.0; // 히어로 카드, 시트
  static const pill = 999.0; // 알약(하단 내비, 세그먼트 탭, 상태 칩)
}

/// 간격. `SizedBox`와 `EdgeInsets.all`에 쓴다.
/// `EdgeInsets.symmetric`·`only`는 그 컴포넌트에서만 뜻이 있는 미세조정이라 숫자를 그대로 둔다.
class AppGap {
  AppGap._();

  static const xxs = 2.0;
  static const xs = 4.0;
  static const snug = 6.0;
  static const sm = 8.0;
  static const cozy = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// 화면 좌우 여백
  static const page = 20.0;
}

/// 글씨 굵기:
///   w300 — 대제목·KPI 숫자 전용(크게 쓸 때만 가늘게. 작은 글씨에 쓰면 안 읽힌다)
///   w400·w500 — Poppins 숫자 전용(입력 칸의 시각, 시각 눈금). 한글엔 쓰지 않는다
///   w600 — 라벨, 보조 강조
///   w700 — 제목, 버튼
///   w800 — 카드 제목, 강조 시각
///   w900 — 쓰지 않는 게 기본(특별 연출용)
/// `FontWeight.bold` 같은 별칭은 쓰지 않는다.

/// 화면 폭 구간. 대상 기기는 갤럭시 Z 플립(좁음)과 폴드(펼치면 태블릿급).
///
/// - compact  (< 600)  : 플립, 폴드 겉화면 — 한 열, 하단 알약 내비
/// - medium   (600~839): 폴드 펼침 세로 — 카드 2열
/// - expanded (≥ 840)  : 폴드 펼침 가로 — 카드 3열, 왼쪽 레일 내비
///
/// 폭으로 분기하는 코드는 반드시 [Breakpoint.of]를 거친다(숫자 600을 화면마다 쓰지 않는다).
enum Breakpoint {
  compact,
  medium,
  expanded;

  static Breakpoint of(BuildContext context) => fromWidth(MediaQuery.sizeOf(context).width);

  static Breakpoint fromWidth(double w) => w >= 840
      ? Breakpoint.expanded
      : w >= 600
      ? Breakpoint.medium
      : Breakpoint.compact;

  /// 대시보드 카드 열 수
  int get columns => switch (this) {
    Breakpoint.compact => 1,
    Breakpoint.medium => 2,
    Breakpoint.expanded => 3,
  };
}

/// 본문 최대 폭(폴드 가로에서 카드가 끝까지 늘어나지 않게).
const kMaxContentWidth = 1080.0;

/// 하단 알약 내비 높이 + 바닥 여백. 스크롤 본문 아래 여백을 이만큼 둬야 마지막 카드가 안 가린다.
const kDockClearance = 104.0;

/// 애니메이션 시간. 화면에서 Duration을 직접 쓰지 않는다.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}
