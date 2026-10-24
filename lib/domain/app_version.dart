/// 앱 버전 비교. GitHub 릴리스 태그("v0.1.4")와 설치된 앱 버전("0.1.4")을 같은 잣대로 본다.
/// 빌드 번호(+5)는 비교하지 않는다 — 릴리스마다 0.1.x를 올리기로 했다(CLAUDE.md "테스트 배포").
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;

  const AppVersion(this.major, this.minor, this.patch);

  /// "v0.1.4", "0.1.4", "0.1.4+5", "0.1" 모두 받는다. 숫자가 없으면 null.
  static AppVersion? tryParse(String raw) {
    final m = RegExp(r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(raw.trim());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i) ?? '0');
    return AppVersion(g(1), g(2), g(3));
  }

  @override
  int compareTo(AppVersion o) => major != o.major
      ? major.compareTo(o.major)
      : (minor != o.minor ? minor.compareTo(o.minor) : patch.compareTo(o.patch));

  bool isNewerThan(AppVersion o) => compareTo(o) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// GitHub에 올라온 새 버전 하나.
class AvailableUpdate {
  final AppVersion version;
  final String apkUrl;
  final String releaseUrl;

  /// 릴리스 노트(마크다운 기호를 걷어낸 글).
  final String notes;

  const AvailableUpdate({required this.version, required this.apkUrl, required this.releaseUrl, required this.notes});
}

/// 릴리스 목록(GitHub API JSON) 중 APK가 붙은 가장 높은 버전. 초안은 빼고, 테스트용(pre-release)은 넣는다
/// (main에 합치기 전까지 릴리스를 pre-release로 올리기 때문).
AvailableUpdate? newestRelease(List<dynamic> releases) {
  AvailableUpdate? best;
  for (final r in releases) {
    if (r is! Map || r['draft'] == true) continue;
    final v = AppVersion.tryParse('${r['tag_name'] ?? ''}');
    if (v == null) continue;
    final assets = r['assets'];
    final apk = assets is List
        ? assets
              .whereType<Map<dynamic, dynamic>>()
              .where((a) => '${a['name']}'.toLowerCase().endsWith('.apk'))
              .firstOrNull
        : null;
    if (apk == null) continue;
    if (best == null || v.isNewerThan(best.version)) {
      best = AvailableUpdate(
        version: v,
        apkUrl: '${apk['browser_download_url']}',
        releaseUrl: '${r['html_url'] ?? ''}',
        notes: plainNotes('${r['body'] ?? ''}'),
      );
    }
  }
  return best;
}

/// 릴리스 노트를 앱 안에서 읽기 좋게: 설치 안내 절과 마크다운 기호를 걷어낸다.
String plainNotes(String markdown) {
  final lines = <String>[];
  var skip = false;
  for (final raw in markdown.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('#')) {
      // "폰에 설치하기"·"설치"는 앱 안에선 필요 없는 안내라 뺀다.
      skip = line.contains('설치');
      final title = line.replaceAll(RegExp(r'^#+\s*'), '');
      if (!skip && !title.startsWith('가족 시간표')) lines.add(title);
      continue;
    }
    if (skip || line.isEmpty || line.startsWith('🤖')) continue;
    lines.add(line.replaceAll('**', '').replaceAll('`', ''));
  }
  return lines.join('\n').trim();
}

/// 업데이트 기록(패치노트) 한 건.
class ReleaseNote {
  final AppVersion version;
  final DateTime? date;
  final String notes;
  const ReleaseNote({required this.version, required this.date, required this.notes});
}

/// 릴리스 목록(GitHub API JSON) → 새 버전부터 차례로. 초안·버전 태그가 아닌 건 뺀다.
List<ReleaseNote> releaseHistory(List<dynamic> releases) {
  final notes = <ReleaseNote>[
    for (final r in releases)
      if (r is Map && r['draft'] != true)
        if (AppVersion.tryParse('${r['tag_name'] ?? ''}') case final v?)
          ReleaseNote(
            version: v,
            date: DateTime.tryParse('${r['published_at'] ?? ''}')?.toLocal(),
            notes: plainNotes('${r['body'] ?? ''}'),
          ),
  ];
  return notes..sort((a, b) => a.version.isNewerThan(b.version) ? -1 : (b.version.isNewerThan(a.version) ? 1 : 0));
}
