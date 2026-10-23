# 아키텍처

> 이 문서는 "어디에 무엇을 두는가"와 "왜 그렇게 했는가"를 정한다.
> 새 기능을 붙이기 전에 읽고, 규칙을 바꿔야 하면 코드보다 이 문서를 먼저 고친다.

## 1. 제품 원칙 (모든 결정의 기준)

1. **오늘이 먼저다.** 앱을 열면 3초 안에 "지금 누가 어디 있고 다음은 뭔지"가 보여야 한다.
   새 기능이 "오늘" 화면을 복잡하게 만들면 다른 탭으로 보낸다.
2. **자녀는 N명이다.** 코드 어디에도 "첫째/둘째"를 하드코딩하지 않는다. 자녀가 1명이든
   5명이든 같은 코드 경로를 탄다. 자녀가 1명일 때만 UI를 줄인다(선택 탭 숨김 등).
3. **고쳐도 안전하다.** 시간표를 바꾸는 모든 동작은 수정 기록을 남기고 되돌릴 수 있다.
   지우기는 표시(soft delete)가 기본이다.
4. **가족이 같이 쓴다.** 내가 바꾼 건 바로 가족 폰에 보인다. 그래서 바꾸기 전에 확인하고,
   누가 바꿨는지 남긴다.
5. **설정 없이도 켜진다.** 네트워크·Firebase가 없어도 앱은 로컬 모드로 동작한다.

## 2. 계층

```
lib/
├─ main.dart            시작점: Bootstrap → ProviderScope → App
├─ app/                 앱 조립(틀, 세션, Provider). 기능 간 연결은 여기서만.
│  ├─ app.dart          MaterialApp, 탭 틀(AppShell)
│  ├─ bootstrap.dart    시작할 때 한 번 준비(prefs, 로컬 저장소, Firebase)
│  ├─ session.dart      이 폰은 어느 가족의 누구인가(가족 코드, 회원 id)
│  └─ providers.dart    화면이 읽는 모든 상태
├─ core/design/         디자인 시스템(토큰·색·테마·공용 컴포넌트). → DESIGN_SYSTEM.md
├─ domain/              순수 Dart. Flutter·Firebase를 모른다.
│  ├─ models.dart       데이터 모델 + JSON
│  ├─ timetable_logic.dart  교시 시간, 빈 시간, 학기 이름 등 계산
│  ├─ day_summary.dart  "오늘" 화면 계산
│  └─ permissions.dart  권한 정책(누가 무엇을)
├─ data/                저장. domain만 안다.
│  ├─ family_store.dart     저장소 인터페이스 + 로컬/Firestore 구현
│  └─ timetable_repository.dart  데이터를 바꾸는 유일한 입구
└─ features/<기능>/     화면. 기능 하나 = 폴더 하나.
   ├─ today/  timetable/  family/  onboarding/
```

### 의존 방향 (한 방향만)

```
features ──▶ app/providers ──▶ data ──▶ domain
    │                                     ▲
    └──────────▶ core/design ─────────────┘ (모델 표시용)
```

- `domain/`은 아무것도 import 하지 않는다(모델끼리만). → 테스트가 쉽고, 나중에 웹·iOS로 가도 그대로.
- `features/`는 `data/`를 **직접 import 하지 않는다.** 읽기는 Provider, 쓰기는 `repositoryProvider`.
- 기능 폴더끼리는 서로 화면을 열 수 있지만(예: 오늘 → 아이 추가 시트), 상태를 공유하려면
  Provider로 올린다. 다른 기능 폴더의 private 위젯을 가져다 쓰지 않는다. 두 기능이 같이
  쓰게 되면 `core/design/components/`로 올린다.

## 3. 데이터

### 저장 위치
| 모드 | 저장소 | 언제 |
|---|---|---|
| 로컬 | `LocalFamilyStore` (앱 문서 폴더 `local_family.json`) | Firebase 설정 전, 공유 시작 전 |
| 공유 | `FirestoreFamilyStore` `timetable_families/{가족코드}/{컬렉션}/{id}` | 가족 코드 있음 |

"가족 공유 시작"을 누르면 로컬 데이터를 그대로 Firestore로 복사하고 저장소를 바꾼다.
화면은 저장소가 바뀐 걸 모른다(Provider가 다시 구독).

Moneycraft는 가족 데이터를 **문서 하나**에 통째로 넣었지만, 이 앱은 버전·수정 기록이 학기마다
쌓여 1MB 한도에 닿을 수 있어 **컬렉션으로 나눴다.**

### 컬렉션
| 컬렉션 | 문서 | 삭제 방식 |
|---|---|---|
| `members` | 가족 구성원(보호자/자녀) | 삭제 |
| `children` | 자녀 프로필, `currentVersionId` | 표시(`deleted`) |
| `versions` | 이름 붙은 시간표 한 벌(일정 목록 포함) | 표시(`deleted`) |
| `revisions` | 버전의 수정 기록(고친 뒤 상태 스냅샷) | 버전당 50개 넘으면 오래된 것부터 삭제 |
| (루트 문서) | `schemaVersion`, `createdAt` | — |

### 버전과 수정 기록 (이 앱의 핵심 규칙)
- **버전** = "2학년 1학기"처럼 이름 붙은 시간표. 학기가 바뀌면 새 버전을 만든다(보통 지난 것을 복제).
  지난 버전은 지우지 않고 남겨서 언제든 다시 본다. "현재"는 `Child.currentVersionId` 하나로 정한다.
  → **지난 학기로 돌아가기** = `currentVersionId`만 바꾸기.
- **수정 기록** = 한 버전 안에서 고칠 때마다 "고친 뒤 상태"를 통째로 한 장 찍는다.
  → **잘못 고친 걸 되돌리기** = 원하는 기록의 상태를 다시 저장(이것도 기록으로 남아 되돌림을 되돌릴 수 있다).
- 버전의 일정을 바꾸는 코드는 **반드시 `TimetableRepository.saveEntries`(또는 그걸 부르는 메서드)를 거친다.**
  `store.put(Collections.versions, …)`을 화면이나 다른 곳에서 직접 부르면 기록이 안 남는다.
- 같은 버전 안에서 수정 기록 시각은 항상 앞 기록보다 늦게 찍는다(같은 밀리초 충돌 방지 — 테스트 있음).

### 동시 수정
두 사람이 같은 버전을 동시에 고치면 버전 문서는 **나중에 저장한 쪽이 이긴다.** 진 쪽의 변경도
수정 기록에는 남아 있으므로 되돌리기로 되살릴 수 있다. 가족 규모에서는 이 정도면 충분하다고
판단했다. 충돌이 실제로 문제 되면 일정 단위 문서로 쪼개는 것을 검토한다(ROADMAP 참고).

### 데이터 마이그레이션
문서 모양을 바꿀 때:
1. `kSchemaVersion`(data/family_store.dart)을 1 올린다.
2. `fromJson`은 **옛 모양도 읽을 수 있게** 기본값을 둔다(필드 삭제 대신 무시).
3. 새 앱이 가족 데이터를 처음 열 때 루트 문서의 `schemaVersion`을 올린다.
4. 옛 앱은 자기보다 높은 버전을 보면 상단에 "업데이트해 주세요"를 띄운다(`AppShell`).
5. 모델 테스트에 "옛 JSON 읽기" 케이스를 추가한다.

## 4. 상태 관리 (Riverpod)

- 읽기: `childrenProvider`, `versionsProvider`, `currentVersionProvider(childId)`, `meProvider`,
  `permissionsProvider` 등. **화면에서 스트림을 직접 만들지 않는다.**
- 쓰기: `ref.read(repositoryProvider).<동작>()`. 수정 기록의 "누가"는 `meProvider`에서 자동으로 채워진다.
- 화면 안에서만 쓰는 상태(선택한 요일, 펼침 여부)는 `StatefulWidget`의 지역 상태로 둔다.
  다른 화면도 알아야 하면 그때 Provider로 올린다.

## 5. 권한
`domain/permissions.dart` 한 곳에서만 정한다. 화면에서 `me.isParent` 같은 조건을 쓰지 않고
`perms.canEditEntries(child)`처럼 **의도**로 묻는다. 지금 규칙:
- 보호자: 전부 / 자녀: 자기 시간표의 일정 추가·수정·되돌리기만 / 회원 선택 전: 보기만.

Firestore 보안 규칙(`firestore.rules`)은 "로그인한 사람이면 가족 코드를 아는 문서를 읽고 쓴다"까지만
보장한다(Moneycraft와 같은 수준). 앱 안 권한은 실수 방지용이고, 악의적 접근 차단은 가족 코드의
비밀성에 기댄다. 외부에 공개 배포할 때는 회원별 uid를 규칙에 넣는 작업이 필요하다(ROADMAP M4).

## 6. 테스트
| 대상 | 방식 | 위치 |
|---|---|---|
| domain 계산 | 순수 단위 테스트 | `test/timetable_logic_test.dart` |
| 저장 규칙(버전·기록·되돌리기) | `LocalFamilyStore.memory()`로 리포지토리 테스트 | `test/timetable_repository_test.dart` |
| 화면 | 필요할 때 위젯 테스트. 레이아웃은 실기기(플립·폴드)로 확인 | — |

규칙: **버그를 고치면 그 버그를 재현하는 테스트를 같이 넣는다.** 커밋 전 `flutter analyze` 0건,
`flutter test` 전부 통과.

## 7. 새 기능을 붙이는 순서
1. 모델이 바뀌면 `domain/models.dart` + 마이그레이션 절차(3장).
2. 계산은 `domain/`에 순수 함수로 + 테스트.
3. 저장 동작은 `TimetableRepository`에 메서드로 + 테스트.
4. 읽을 상태가 필요하면 `app/providers.dart`에 Provider.
5. 화면은 `features/<기능>/`에, `core/design`의 컴포넌트로 조립. 새 모양이 필요하면 컴포넌트부터.
6. 권한이 걸리면 `Permissions`에 메서드 추가.
7. `docs/ROADMAP.md` 체크, 필요하면 이 문서 갱신.
