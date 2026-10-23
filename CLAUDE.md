# 가족 시간표 (family_timetable)

아빠·엄마·아이들이 각자 폰에 깔고, 자녀별 시간표를 가족이 함께 보고 고치는 Flutter 앱.
자녀는 N명(지금은 첫째 초등학생만, 둘째는 어린이집 → 나중에 추가).
시간표는 "2학년 1학기"처럼 이름 붙은 **버전**으로 남기고, 고칠 때마다 **수정 기록**이 쌓여 되돌릴 수 있다.
대상 기기: 갤럭시 Z 폴드 / 플립 (안드로이드). 자매 앱: `C:\dev\son_allowance_app` (Moneycraft).

## 📍 현재 상태 / 다음 할 일 (이어받기용)
- **M0 기반, M1 시간표 입력·학기·수정 기록 완료 (2026-10-23)**. 다음은 **M2 가족 운영**(픽업 담당·알림) → `docs/ROADMAP.md`
- 저장소: https://github.com/jong0227/family_timetable (private). M1은 브랜치 `m1-timetable-editing`
- 디자인 미리보기: `tool/preview_web.bat` → 브라우저 localhost:5173 (웹은 메모리 저장, 새로고침하면 초기화). 디버그 빌드 빈 화면의 "개발용: 샘플 가족 채우기"로 데이터 채우기
- Firebase 콘솔에 `com.family.timetable` 앱 등록 + `android/app/google-services.json` 아직 안 함
  → 그 전까지는 로컬 모드로만 동작. 절차: `docs/FIREBASE_SETUP.md`
- 실기기(플립·폴드) 확인 아직 못 함.

## 반드시 먼저 읽을 문서
- `docs/ARCHITECTURE.md` — 계층·의존 방향·데이터·버전/수정 기록 규칙·새 기능 붙이는 순서
- `docs/DESIGN_SYSTEM.md` — 레퍼런스(FacilityFlow), 색 체계, 토큰, 컴포넌트, 화면 패턴, 카피
- `docs/ROADMAP.md` — 단계별 할 일

## 지켜야 할 규칙 (요약 — 이유는 위 문서에)
1. 화면(`features/`)은 `data/`를 직접 import 하지 않는다. 읽기는 Provider, 쓰기는 `repositoryProvider`.
2. 버전의 일정을 바꾸는 건 **반드시 `TimetableRepository.saveEntries` 경유**(수정 기록이 남아야 함).
3. 권한 조건은 `Permissions`에만. 화면에서 `me.isParent` 직접 쓰지 않기.
4. 화면에서 숫자·색을 직접 쓰지 않는다. `AppText/AppGap/AppRadius/AppMotion`, `context.palette`.
   화면 파일은 `core/design/design.dart` 하나만 import.
5. 색은 정보다: 상태색(urgent/info/positive/neutral) + 자녀색만. 일정 종류는 이모지+글자.
6. 자녀를 "첫째/둘째"로 하드코딩하지 않는다. 1명이든 N명이든 같은 코드 경로.
7. 문서 모양을 바꾸면 `kSchemaVersion` + 마이그레이션 절차(ARCHITECTURE 3장).
8. 커밋 전 `flutter analyze` 0건, `flutter test` 전부 통과. 버그 고치면 재현 테스트 추가.

## 개발 환경 (Moneycraft와 같은 PC 설정)
```powershell
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"   # PC에 맞게
$env:Path = "C:\dev\flutter\bin;$env:JAVA_HOME\bin;C:\dev\android-sdk\platform-tools;$env:Path"
Set-Location "C:\dev\family_timetable"
```
- 분석/테스트: `flutter analyze` / `flutter test`
- 디버그 빌드: `flutter build apk --debug`
- 업데이트 설치(데이터 유지): `adb install -r <apk>` (`flutter install`은 데이터 지움)
- applicationId `com.family.timetable` — 스토어 게시 후 변경 불가.
- 릴리스 서명은 아직 디버그 키. 배포 전에 Moneycraft처럼 keystore + `android/key.properties` 구성.

## 테스트 배포 (사용자가 고른 방식: PC에서 빌드 → GitHub 릴리스, 2026-10-23)
폰에서 GitHub 저장소 Releases로 받아 설치한다. GitHub Actions 자동 빌드는 **하지 않기로 함**
(정식 서명 키가 없어 CI 빌드는 서명이 달라 업데이트 설치가 막힌다).
1. `pubspec.yaml` 버전 올리기(`0.1.x+N`, N은 매번 +1) → 커밋·푸시
2. **이 PC(남편 노트북)에서** 빌드 — 디버그 키가 이 PC의 것이라 다른 PC 빌드로는 업데이트 불가:
   `flutter build apk --release --split-per-abi --target-platform android-arm64`
   (갤럭시 전용 arm64 ~20MB. 전체 빌드는 54MB라 폰 전송 한도 30MB를 넘는다)
3. `C:\dev\share\FamilyTimetable-v<버전>.apk`로 복사
4. `gh release create v<버전> <apk> --repo jong0227/family_timetable --target <브랜치명 또는 전체 SHA>
   --title "가족 시간표 v<버전>" --notes-file <노트> --prerelease` (main에 합치기 전엔 pre-release.
   `--target`에 짧은 SHA를 주면 422 오류)
5. 노트에 설치법(지우지 말고 덮어 설치) + 바뀐 점. 저장소가 비공개라 폰 브라우저에 GitHub 로그인 필요.
