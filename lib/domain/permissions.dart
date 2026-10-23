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
  const Permissions(this.me);

  bool get isParent => me?.isParent ?? false;

  bool canView(Child child) => true;

  bool canEditEntries(Child child) => isParent || (me?.childId == child.id);

  bool canRestoreRevision(Child child) => canEditEntries(child);

  bool canManageVersions(Child child) => isParent;

  bool get canManageChildren => isParent;

  bool get canManageMembers => isParent;
}
