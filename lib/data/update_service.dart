import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/app_version.dart';

/// GitHub 릴리스에서 새 버전을 찾는다. 저장소가 공개라 로그인 없이 읽힌다
/// (Moneycraft의 UpdateService와 같은 방식. 단 /releases/latest는 pre-release를 빼므로 목록을 본다).
class UpdateService {
  static const repo = 'jong0227/family_timetable';
  static const releasesPage = 'https://github.com/$repo/releases';

  final http.Client _client;
  UpdateService([http.Client? client]) : _client = client ?? http.Client();

  /// 설치된 [current]보다 새 버전이 있으면 그것, 없거나 확인 못 하면 null.
  /// 네트워크가 안 돼도 앱 사용에 지장이 없어야 하므로 예외를 밖으로 던지지 않는다.
  Future<AvailableUpdate?> check(AppVersion current) async {
    final list = await _releases();
    final newest = list == null ? null : newestRelease(list);
    return newest != null && newest.version.isNewerThan(current) ? newest : null;
  }

  /// 업데이트 기록(패치노트), 새 버전부터. 확인 못 하면 null.
  Future<List<ReleaseNote>?> history() async {
    final list = await _releases();
    return list == null ? null : releaseHistory(list);
  }

  Future<List<dynamic>?> _releases() async {
    try {
      final res = await _client
          .get(
            Uri.parse('https://api.github.com/repos/$repo/releases?per_page=50'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      return list is List ? list : null;
    } catch (_) {
      return null;
    }
  }
}
