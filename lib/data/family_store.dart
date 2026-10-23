import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

/// 컬렉션 이름. Firestore 하위 컬렉션 이름과 로컬 파일의 키로 똑같이 쓴다.
class Collections {
  Collections._();
  static const members = 'members';
  static const children = 'children';
  static const versions = 'versions';
  static const revisions = 'revisions';

  /// 일정 댓글(스키마 버전과 무관: 새 컬렉션이라 옛 앱은 그냥 못 볼 뿐 데이터를 망가뜨리지 않는다).
  static const comments = 'comments';
  static const all = [members, children, versions, revisions, comments];
}

/// 데이터를 어디에 두든(이 폰의 파일 / Firestore 가족 문서) 화면과 로직은 이
/// 인터페이스만 본다. 덕분에 Firebase 설정 전에도 앱을 혼자 써 볼 수 있고,
/// 나중에 "가족 공유 시작"을 누르면 로컬 데이터를 그대로 올리기만 하면 된다.
abstract class FamilyStore {
  /// 컬렉션 전체를 id → 문서 맵으로 계속 흘려준다(바뀔 때마다 새 값).
  Stream<Map<String, Map<String, dynamic>>> watch(String collection);

  /// 지금 값 한 번만.
  Future<Map<String, Map<String, dynamic>>> read(String collection);

  Future<void> put(String collection, String id, Map<String, dynamic> doc);

  Future<void> remove(String collection, String id);

  /// 가족 단위 정보(스키마 버전, 만든 날). 문서가 없으면 null.
  Future<FamilyMeta?> readMeta();

  Future<void> writeMeta(FamilyMeta meta);
}

/// 저장 형식 버전. 문서 모양을 바꾸면(필드 의미 변경·컬렉션 추가 등) 1 올리고
/// `docs/ARCHITECTURE.md`의 "데이터 마이그레이션" 절차를 따른다.
///
/// 가족 중 한 명만 앱을 업데이트한 상태에서, 옛 앱이 새 형식 데이터를 모르고 덮어써
/// 망가뜨리는 걸 막는 게 목적이다. 옛 앱은 자기보다 높은 버전을 보면 읽기 전용이 된다.
///
/// 이력:
/// - v1 (2026-10-23) 처음
/// - v2 (2026-10-23) 일정 종류에 `afterSchool`(학교 방과후) 추가. v1 앱은 이걸 '기타'로 읽고,
///   그 상태로 고쳐 저장하면 방과후가 기타로 바뀌어 버린다 → 그래서 버전을 올려 옛 앱에 업데이트 안내.
/// - v3 (2026-10-23) 시간표에 종류(`kind`: 학기/방학)와 방학 기간(`startDate`, `endDate`) 추가.
///   v2 앱은 이 필드를 몰라서, 그 시간표를 고쳐 저장하면 기간이 지워진다.
const kSchemaVersion = 3;

class FamilyMeta {
  final int schemaVersion;
  final DateTime createdAt;

  const FamilyMeta({required this.schemaVersion, required this.createdAt});

  factory FamilyMeta.current() => FamilyMeta(schemaVersion: kSchemaVersion, createdAt: DateTime.now());

  /// 이 앱보다 새 형식으로 저장된 가족 데이터인가.
  bool get isNewerThanApp => schemaVersion > kSchemaVersion;

  Map<String, dynamic> toJson() => {'schemaVersion': schemaVersion, 'createdAt': createdAt.toIso8601String()};

  static FamilyMeta? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['schemaVersion'] is! int) return null;
    return FamilyMeta(
      schemaVersion: j['schemaVersion'] as int,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 이 폰 안에만 저장. 앱 문서 폴더의 JSON 파일 하나에 통째로 쓴다.
/// (가족 데이터는 많아야 수백 KB라 파일 하나로 충분하다.)
/// [file]이 null이면 메모리에만 둔다(테스트용).
class LocalFamilyStore implements FamilyStore {
  final File? file;
  final Map<String, Map<String, Map<String, dynamic>>> _data = {for (final c in Collections.all) c: {}};
  final _controllers = <String, StreamController<Map<String, Map<String, dynamic>>>>{};
  Map<String, dynamic>? _meta;

  LocalFamilyStore._(this.file);

  factory LocalFamilyStore.memory() => LocalFamilyStore._(null);

  static Future<LocalFamilyStore> open(File file) async {
    final store = LocalFamilyStore._(file);
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          for (final c in Collections.all) {
            final col = raw[c];
            if (col is Map) {
              store._data[c] = {
                for (final e in col.entries)
                  if (e.value is Map) e.key as String: Map<String, dynamic>.from(e.value as Map),
              };
            }
          }
          if (raw['meta'] is Map) store._meta = Map<String, dynamic>.from(raw['meta'] as Map);
        }
      } catch (_) {
        // 파일이 깨졌으면 빈 상태로 시작한다. 앱이 아예 안 켜지는 것보다 낫다.
      }
    }
    return store;
  }

  /// 모든 컬렉션을 한 번에(가족 공유를 시작할 때 Firestore로 올리는 용도).
  Map<String, Map<String, Map<String, dynamic>>> snapshotAll() => {
    for (final c in Collections.all) c: Map.of(_data[c]!),
  };

  bool get isEmpty => _data.values.every((c) => c.isEmpty);

  StreamController<Map<String, Map<String, dynamic>>> _controller(String c) =>
      _controllers.putIfAbsent(c, () => StreamController.broadcast());

  @override
  Stream<Map<String, Map<String, dynamic>>> watch(String collection) async* {
    yield Map.of(_data[collection]!);
    yield* _controller(collection).stream;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> read(String collection) async => Map.of(_data[collection]!);

  @override
  Future<void> put(String collection, String id, Map<String, dynamic> doc) async {
    _data[collection]![id] = doc;
    await _changed(collection);
  }

  @override
  Future<void> remove(String collection, String id) async {
    _data[collection]!.remove(id);
    await _changed(collection);
  }

  @override
  Future<FamilyMeta?> readMeta() async => FamilyMeta.fromJson(_meta);

  @override
  Future<void> writeMeta(FamilyMeta meta) async {
    _meta = meta.toJson();
    await _persist();
  }

  Future<void> _changed(String collection) async {
    _controller(collection).add(Map.of(_data[collection]!));
    await _persist();
  }

  Future<void> _persist() async {
    final f = file;
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({..._data, 'meta': _meta}));
  }

  Future<void> clear() async {
    _meta = null;
    for (final c in Collections.all) {
      _data[c]!.clear();
      _controller(c).add(const {});
    }
    final f = file;
    if (f != null && await f.exists()) await f.delete();
  }
}

/// Firestore: `timetable_families/{가족코드}/{컬렉션}/{id}`.
///
/// Moneycraft는 가족 데이터를 문서 하나에 통째로 넣지만, 시간표는 버전·수정 기록이
/// 학기마다 계속 쌓여서 문서 한 개 한도(1MB)에 닿을 수 있다. 그래서 문서를 나눴다.
/// 오프라인일 때는 Firestore가 알아서 캐시에 쓰고 연결되면 올린다.
class FirestoreFamilyStore implements FamilyStore {
  static const rootCollection = 'timetable_families';

  final String familyCode;
  final FirebaseFirestore _db;

  FirestoreFamilyStore(this.familyCode, [FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get root => _db.collection(rootCollection).doc(familyCode);

  @override
  Stream<Map<String, Map<String, dynamic>>> watch(String collection) =>
      root.collection(collection).snapshots().map((s) => {for (final d in s.docs) d.id: d.data()});

  @override
  Future<Map<String, Map<String, dynamic>>> read(String collection) async {
    final s = await root.collection(collection).get();
    return {for (final d in s.docs) d.id: d.data()};
  }

  @override
  Future<void> put(String collection, String id, Map<String, dynamic> doc) =>
      root.collection(collection).doc(id).set(doc);

  @override
  Future<void> remove(String collection, String id) => root.collection(collection).doc(id).delete();

  @override
  Future<FamilyMeta?> readMeta() async => FamilyMeta.fromJson((await root.get()).data());

  @override
  Future<void> writeMeta(FamilyMeta meta) => root.set(meta.toJson(), SetOptions(merge: true));
}
