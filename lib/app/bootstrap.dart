import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/family_store.dart';
import 'session.dart';

/// 앱이 켜질 때 한 번 준비하는 것들. runApp 전에 만들어서 Provider로 넣는다.
class Bootstrap {
  final SharedPreferences prefs;
  final LocalFamilyStore localStore;

  /// google-services.json이 없거나 초기화가 실패하면 false → 로컬 모드로만 동작.
  final bool firebaseReady;

  const Bootstrap({required this.prefs, required this.localStore, required this.firebaseReady});

  static Future<Bootstrap> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 웹은 디자인 미리보기 전용(브라우저에서 화면 확인). 파일 저장·Firebase 없이 메모리로만 돈다.
    if (kIsWeb) return Bootstrap(prefs: prefs, localStore: LocalFamilyStore.memory(), firebaseReady: false);
    final dir = await getApplicationDocumentsDirectory();
    final local = await LocalFamilyStore.open(File('${dir.path}/local_family.json'));

    var firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      // 가족 공유 중이었다면 익명 로그인을 미리 해 둔다(Firestore 규칙이 로그인을 요구).
      if (prefs.getString('familyCode') != null) await ensureSignedIn();
    } catch (_) {
      // Firebase가 없어도 앱은 로컬 모드로 써야 하므로 실패를 삼킨다.
    }
    return Bootstrap(prefs: prefs, localStore: local, firebaseReady: firebaseReady);
  }
}

final bootstrapProvider = Provider<Bootstrap>((_) => throw UnimplementedError('main()에서 override 한다'));
