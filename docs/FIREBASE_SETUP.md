# Firebase 설정 (가족 공유 켜기)

Moneycraft가 쓰는 Firebase 프로젝트 **`kids-allowance-48c8e`** 를 같이 쓴다.
데이터는 `timetable_families` 컬렉션에 따로 들어가서 Moneycraft의 `families`와 섞이지 않는다.

이 설정 전에도 앱은 **로컬 모드**(이 폰에만 저장)로 빌드·실행된다.

## 1. 콘솔에서 Android 앱 등록 (직접 해야 함)
1. https://console.firebase.google.com → `kids-allowance-48c8e` → 프로젝트 설정 → **앱 추가 → Android**
2. Android 패키지 이름: **`com.family.timetable`** (`android/app/build.gradle.kts`의 applicationId와 같아야 함)
3. 앱 닉네임: 가족 시간표
4. `google-services.json` 다운로드 → **`android/app/google-services.json`** 에 넣기
5. 빌드하면 Firebase 플러그인이 자동으로 켜진다(파일이 있을 때만 켜지게 해 둠).

## 2. 익명 로그인
Moneycraft에서 이미 켜 두었으므로 할 일 없음. (Authentication → 로그인 방법 → 익명: 사용)

## 3. Firestore 보안 규칙
프로젝트 루트의 `firestore.rules` 내용을 콘솔 → Firestore → 규칙에 **기존 Moneycraft 규칙과 합쳐서**
넣는다. 기존 규칙을 통째로 덮어쓰면 Moneycraft 동기화가 멈출 수 있으니 반드시 합칠 것.
(기존 규칙이 `match /{document=**}`로 이미 로그인 사용자 전체 허용이라면 추가할 것이 없다.)

## 4. 확인
1. 폰 A: 새로 시작 → 가족 탭에 6자리 가족 코드가 보이면 성공
2. 폰 B: 가족 코드로 참여 → "나는 누구예요?"에서 등록
3. 폰 A에서 아이를 추가하면 폰 B의 오늘 화면에 바로 나타나야 한다
