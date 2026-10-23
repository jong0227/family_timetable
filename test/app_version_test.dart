import 'package:family_timetable/domain/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion', () {
    test('태그·설치 버전을 같은 잣대로 읽는다', () {
      expect(AppVersion.tryParse('v0.1.4'), const AppVersion(0, 1, 4));
      expect(AppVersion.tryParse('0.1.4+5'), const AppVersion(0, 1, 4));
      expect(AppVersion.tryParse('1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('nightly'), isNull);
    });

    test('자리별로 비교한다(문자열 비교 아님)', () {
      expect(const AppVersion(0, 1, 10).isNewerThan(const AppVersion(0, 1, 9)), isTrue);
      expect(const AppVersion(0, 2, 0).isNewerThan(const AppVersion(0, 1, 99)), isTrue);
      expect(const AppVersion(0, 1, 4).isNewerThan(const AppVersion(0, 1, 4)), isFalse);
    });
  });

  group('newestRelease', () {
    Map<String, Object?> release(String tag, {bool apk = true, bool draft = false}) => {
      'tag_name': tag,
      'draft': draft,
      'prerelease': true,
      'html_url': 'https://github.com/x/$tag',
      'body': '## 가족 시간표 $tag\n\n### 폰에 설치하기\n지우지 마세요\n\n### 고친 것\n- **요일** 문제\n\n🤖 Generated',
      'assets': [
        if (apk) {'name': 'FamilyTimetable-$tag.apk', 'browser_download_url': 'https://dl/$tag.apk'},
      ],
    };

    test('APK가 붙은 가장 높은 버전(테스트용 pre-release 포함, 초안 제외)', () {
      final u = newestRelease([
        release('v0.1.3'),
        release('v0.1.10'),
        release('v0.1.9'),
        release('v0.2.0', draft: true),
        release('v0.1.11', apk: false),
      ]);
      expect(u!.version, const AppVersion(0, 1, 10));
      expect(u.apkUrl, 'https://dl/v0.1.10.apk');
    });

    test('릴리스 노트에서 설치 안내·제목·마크다운 기호를 걷어낸다', () {
      expect(newestRelease([release('v0.1.4')])!.notes, '고친 것\n- 요일 문제');
    });

    test('릴리스가 없으면 null', () => expect(newestRelease([]), isNull));
  });
}
