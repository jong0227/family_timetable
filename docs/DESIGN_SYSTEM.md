# 디자인 시스템

> 레퍼런스: [FacilityFlow – Facility SaaS & UX UI Dashboard](https://dribbble.com/shots/27684067-FacilityFlow-Facility-SaaS-UX-UI-Dashboard-Design) (Yehor Mushka)
> 가져온 것은 **분위기와 구조**다. 화면을 그대로 베끼지 않는다.

## 1. 레퍼런스에서 가져온 것 → 이 앱에서의 의미

| 레퍼런스 | 이 앱 |
|---|---|
| 밝은 회색 바탕 + 테두리·그림자 없는 흰 카드, 큰 라운드 | `canvas` 위 `DashCard` (라운드 22) |
| 크고 가는 대제목 "Dashboard" + 한 줄 요약, 오른쪽 날짜·요일 | `PageHeader` — "오늘 / 일정 5개 · 빈 시간 1곳 / 10월 23일 목요일" |
| 라벨 위 큰 가는 숫자 KPI 줄 (Open tasks 24 …) | `KpiRow` — 일정 수 · 다음 일정 시각 · 빈 시간 |
| 유리 같은 파스텔 그라데이션 히어로 카드 + 상태 칩 | `HeroCard` — 자녀색 그라데이션, "지금/다음" 칩 |
| 카드 머리: 작은 아이콘 + 흐린 제목 + "View all" | `DashCard(icon, title, linkLabel)` |
| 상단 알약 세그먼트(검은 알약 = 선택) | `PillTabs` — 요일, 자녀, 학년 고르기 |
| 떠 있는 검은 알약 하단 내비 | `FloatingDock` (폴드 가로에선 왼쪽 레일) |
| 기능적 색 체계(주황/청록/초록/회색) | `StatusColors` (아래 2장) |
| Poppins 숫자 | 시각·KPI 숫자에만 Poppins, 한글은 Noto Sans KR |

## 2. 색 — "색은 정보다"

색이 하는 일은 두 가지뿐이다. 세 번째 색 체계를 만들지 않는다.

**상태색** — "지금 신경 써야 하나?" 작은 점·칩·숫자에만 쓴다. 면을 칠하지 않는다.

| 이름 | 값(라이트) | 뜻 | 예 |
|---|---|---|---|
| `urgent` | `#ED4714` | 주의 필요 | 빈 시간(보호 공백), 겹친 일정, 삭제 버튼 |
| `info` | `#2BA2C3` | 알림·시스템 | 다음 일정, 동기화 안내, 지난 시간표 보는 중 |
| `positive` | `#0EBE82` | 정상·완료 | 지금 진행 중, 사용 중인 버전, "나" |
| `neutral` | `#D9D9D9` | 비활성 | 구분선, 꺼진 점 |

**자녀색** — "누구의 일정인가". 6가지 파스텔(하늘·복숭아·민트·라벤더·레몬·장미).
각 색은 `container`(옅은 면) / `onContainer`(글자) / `accent`(점·선) / `gradient`(히어로) 한 벌.
상태색과 헷갈리지 않게 채도를 낮췄다. 새 자녀는 안 쓰는 색을 순서대로 받는다(`nextFreeColor`).

**일정 종류**(학교/학원/활동/돌봄)는 색이 아니라 **이모지 + 글자**(`KindTag`)로 구분한다.

다크 모드: 같은 이름, 다른 값(`AppPalette.dark`). 하단 내비는 다크에서 흰 알약으로 뒤집힌다.

## 3. 토큰 (`core/design/tokens.dart`)

이름은 Moneycraft와 같게 맞췄다(두 앱을 오가며 같은 말로 이야기하려고). 값은 레퍼런스에 맞췄다.

- **글씨** `AppText`: micro 10 · caption 11 · label 12 · body 13 · bodyLg 14 · title 15 · titleLg 16 · heading 18 · **kpi 26 · hero 30 · display 32**
- **굵기**: w300(대제목·KPI 숫자 전용) · w600 · w700 · w800. `FontWeight.bold` 금지. 작은 글씨에 w300 금지.
- **라운드** `AppRadius`: xs 6 · sm 10 · md 14 · lg 22(카드) · xl 28(히어로·시트) · pill
- **간격** `AppGap`: 2 · 4 · 6 · 8 · 10 · 12 · 16 · 20 · 24, 화면 좌우 `page` 20
- **움직임** `AppMotion`: fast 150ms · normal 250ms · easeOutCubic
- **폭 구간** `Breakpoint`: compact <600(플립, 1열, 하단 알약) · medium 600–839(폴드 세로, 2열) · expanded ≥840(폴드 가로, 3열, 왼쪽 레일)

규칙: 화면에서 숫자를 직접 쓰지 않는다. 예외는 `EdgeInsets.symmetric/only`의 컴포넌트 안쪽 미세조정과
고정 크기(히어로 높이 등). 애매하면 **한 단계 작은 쪽**.

## 4. 컴포넌트 (`core/design/components/`)

화면 파일은 `import '../../core/design/design.dart';` 하나만 쓴다.

| 컴포넌트 | 쓰임 |
|---|---|
| `PageBody` | 모든 탭 본문 틀(최대 폭, 좌우 여백, 하단 내비 여백) |
| `PageHeader` | 화면 대제목 + 요약 + 오른쪽 날짜 |
| `KpiRow` / `Kpi` | 숫자 요약 줄 |
| `DashboardGrid` | 폭에 따라 1~3열 카드 격자 |
| `DashCard` | 거의 모든 묶음의 그릇 |
| `HeroCard` | 화면당 하나, 자녀색 그라데이션 |
| `StatusChip` / `StatusDot` | 상태색 표시 |
| `TimeText` | 시각(Poppins) |
| `PillTabs` | 같은 화면 안 전환(요일·자녀·학년) |
| `FloatingDock` | 하단 탭 |
| `EmptyState` | 빈 상태 + **다음 행동 버튼** |
| `InfoBanner` | 화면 위 상태 알림 띠 |
| `ChildBadge` | 자녀 표시(점 + 이름) — 자녀가 나오는 모든 곳 |
| `KindTag` | 일정 종류(이모지 + 글자) |
| `TimeInputField` / `showTimeWheel` | 시간 입력 — 숫자만 치면 콜론 자동·다음 칸 자동, 시계 아이콘으로 5분 단위 휠. **시간 입력은 이것만 쓴다** (Material 시간 선택기 금지: 시·분 칸을 따로 눌러야 하고 드래그가 안 된다는 실사용 피드백) |
| `confirmDialog` / `showToast` | 확인 / 결과 알림 |

기능 안에서만 쓰는 조립 위젯은 그 기능 폴더의 `widgets/`에 둔다. 예: `features/timetable/widgets/` 의
`WeekGrid`(주간 격자 — 교시 줄 맞춤 + 방과 후) · `TimetableBoard`(버튼 + 격자, 시간표 탭과 지난 학기 보기가 같이 씀).
날짜·시각 글자는 `core/format.dart`(`formatDateTime`, `formatRelative`)로만 만든다.

같은 모양을 두 화면에서 직접 그리게 되면 컴포넌트로 올리고 이 표에 한 줄 추가한다.

## 5. 화면 구성 패턴

모든 탭은 같은 리듬을 따른다:
```
PageHeader (대제목 · 요약 · 날짜)
KpiRow (있으면)
PillTabs (화면 안 전환이 있으면)
HeroCard (화면의 주인공이 있으면, 하나만)
DashboardGrid [DashCard, DashCard, …]
```

## 6. 글(카피)

- 해요체, 짧게. "~합니다" 쓰지 않는다.
- 빈 상태는 이유 + 다음 행동: "첫 번째 아이를 추가해 주세요" + [아이 추가].
- 오류는 사용자가 할 일을 말한다: "없는 가족 코드예요. 코드를 다시 확인해 주세요."
- 아이도 읽는다. 어려운 단어(동기화, 버전) 대신 쉬운 말(가족 공유, 시간표 이름)을 먼저 쓴다.

## 7. 접근성
- 터치 영역 48px 이상(버튼 높이 52, 내비 버튼 48).
- 상태를 색만으로 전하지 않는다: 점 옆에 항상 글자("빈 시간 80분", "지금").
- 글씨 크기 설정을 키워도 깨지지 않게 고정 높이 카드 안 글은 한 줄 + 말줄임.
