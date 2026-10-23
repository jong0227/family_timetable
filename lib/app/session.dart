import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/family_store.dart';
import 'bootstrap.dart';

/// "이 폰은 어느 가족의 누구인가". 이 폰에만 저장되고 동기화되지 않는다.
///
/// - familyCode == null: 로컬 모드(이 폰에만 저장). Firebase 설정 전이거나 혼자 써 볼 때.
/// - memberId == null: 아직 온보딩 전.
class Session {
  final String? familyCode;
  final String? memberId;

  const Session({this.familyCode, this.memberId});

  bool get isShared => familyCode != null;
  bool get isOnboarded => memberId != null;
}

class SessionController extends Notifier<Session> {
  static const _kFamilyCode = 'familyCode';
  static const _kMemberId = 'memberId';

  SharedPreferences get _prefs => ref.read(bootstrapProvider).prefs;

  @override
  Session build() => Session(familyCode: _prefs.getString(_kFamilyCode), memberId: _prefs.getString(_kMemberId));

  Future<void> setMember(String memberId) async {
    await _prefs.setString(_kMemberId, memberId);
    state = Session(familyCode: state.familyCode, memberId: memberId);
  }

  /// 새 가족 코드를 발급하고, 지금까지 이 폰에 쌓인 로컬 데이터를 통째로 올린다.
  Future<String> startSharing() async {
    _requireFirebase();
    await ensureSignedIn();
    final db = FirebaseFirestore.instance;
    String code;
    do {
      code = _generateCode();
    } while ((await db.collection(FirestoreFamilyStore.rootCollection).doc(code).get()).exists);

    final remote = FirestoreFamilyStore(code);
    await remote.writeMeta(FamilyMeta.current());
    final local = ref.read(bootstrapProvider).localStore;
    for (final MapEntry(key: collection, value: docs) in local.snapshotAll().entries) {
      for (final MapEntry(key: id, value: doc) in docs.entries) {
        await remote.put(collection, id, doc);
      }
    }
    // 올렸으면 이 폰의 로컬 사본은 비운다. 남겨 두면 나중에 가족에서 나와 "새로 시작"할 때 옛 회원·아이가
    // 새 가족 데이터에 섞여 올라간다(코드 점검 M4). Firestore가 이 폰 캐시에 이미 갖고 있어 화면은 그대로다.
    await local.clear();
    await _setFamily(code);
    return code;
  }

  /// 다른 가족이 준 코드로 참여. 회원 선택은 그다음 화면에서 한다(memberId를 비운다).
  Future<void> joinFamily(String rawCode) async {
    _requireFirebase();
    await ensureSignedIn();
    final code = rawCode.trim().toUpperCase();
    final meta = await FirestoreFamilyStore(code).readMeta();
    if (meta == null) throw const SessionException('없는 가족 코드예요. 코드를 다시 확인해 주세요.');
    await _prefs.remove(_kMemberId);
    await _setFamily(code, memberId: null);
  }

  /// 가족 공유를 끊는다. Firestore의 가족 데이터는 지우지 않는다(다른 가족은 계속 쓴다).
  Future<void> leaveFamily() async {
    await _prefs.remove(_kFamilyCode);
    await _prefs.remove(_kMemberId);
    state = const Session();
  }

  Future<void> _setFamily(String code, {String? memberId = '__keep__'}) async {
    await _prefs.setString(_kFamilyCode, code);
    final keepMember = memberId == '__keep__';
    state = Session(familyCode: code, memberId: keepMember ? state.memberId : memberId);
  }

  void _requireFirebase() {
    if (!ref.read(bootstrapProvider).firebaseReady) {
      throw const SessionException('가족 공유 설정(Firebase)이 아직 안 돼 있어요. docs/FIREBASE_SETUP.md를 확인해 주세요.');
    }
  }

  String _generateCode() {
    // 0/O, 1/I/L처럼 헷갈리는 글자는 뺀다(Moneycraft와 같은 규칙).
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}

Future<void> ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) await auth.signInAnonymously();
}

class SessionException implements Exception {
  final String message;
  const SessionException(this.message);
  @override
  String toString() => message;
}

final sessionProvider = NotifierProvider<SessionController, Session>(SessionController.new);
