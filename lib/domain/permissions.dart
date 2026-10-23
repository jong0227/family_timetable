import 'models.dart';

/// 누가 무엇을 할 수 있는지는 **여기서만** 정한다.
///
/// 화면에서 `me.isParent` 같은 조건을 직접 쓰지 않는다. 권한 규칙이 화면마다
/// 흩어지면, 나중에 "할머니는 보기만"이나 "첫째는 둘째 것도 고칠 수 있게" 같은
/// 요구가 왔을 때 모든 화면을 다 뒤져야 한다. 여기 한 곳만 고치면 되도록 모은다.
///
/// 지금 규칙:
/// - 보호자: 모든 것
/// - 자녀: 자기 시간표 일정 추가·수정·되돌리기만. 버전 만들기/삭제, 자녀 프로필,
///   가족 구성원 관리는 못 한다.
/// - 아무도 아님(회원 선택 전): 보기만
class Permissions {
  final Member? me;

  /// 가족 데이터가 이 앱보다 새 형식이면 true — 보기만 된다. 옛 앱이 모르는 필드를 빼고 덮어써
  /// 데이터를 망가뜨리는 걸 막는다(kSchemaVersion). 예전엔 안내 띠만 띄우고 실제로는 다 고칠 수 있었다
  /// (코드 점검 H4).
  final bool readOnly;

  const Permissions(this.me, {this.readOnly = false});

  bool get isParent => me?.isParent ?? false;
  bool get _canWrite => !readOnly;

  bool canView(Child child) => true;

  bool canEditEntries(Child child) => _canWrite && (isParent || (me?.childId == child.id));

  bool canRestoreRevision(Child child) => canEditEntries(child);

  bool canManageVersions(Child child) => _canWrite && isParent;

  bool get canManageChildren => _canWrite && isParent;

  bool get canManageMembers => _canWrite && isParent;

  /// 댓글은 가족이면 누구나(아이도). "특별한 일"을 아이가 직접 남기는 게 목적이다.
  bool get canComment => _canWrite && me != null;

  /// 지우기는 쓴 사람 본인 또는 보호자.
  bool canDeleteComment(Comment c) => _canWrite && (isParent || (me != null && c.authorId == me!.id));
}
