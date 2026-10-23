import 'package:flutter/material.dart';

import '../../../domain/models.dart';
import '../palette.dart';
import '../tokens.dart';

/// 비어 있는 상태. 큰 이모지 + 한 줄 설명 + 다음 행동 버튼.
/// "아무것도 없어요"로 끝내지 말고, 사용자가 다음에 뭘 하면 되는지를 버튼으로 준다.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: AppEmoji.lg)),
          const SizedBox(height: AppGap.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: AppGap.snug),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: AppText.body, color: muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppGap.xl),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// 화면 위쪽 안내 띠(지난 시간표 보는 중, 로컬 모드, 읽기 전용 등). 상태색 점 + 문장 + 동작.
class InfoBanner extends StatelessWidget {
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const InfoBanner({super.key, required this.color, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppGap.md),
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppGap.cozy),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w600),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// 자녀 표시(색 점 + 이름). 자녀가 나오는 모든 곳에서 같은 모양으로 쓴다.
class ChildBadge extends StatelessWidget {
  final Child child;
  final bool large;

  const ChildBadge(this.child, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final tone = context.palette.child(child.colorIndex);
    final dot = large ? 12.0 : 8.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(color: tone.accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppGap.snug),
        Text(
          child.name,
          style: TextStyle(fontSize: large ? AppText.titleLg : AppText.body, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// 일정 종류 표시(이모지 + 글자). 색을 쓰지 않는다 — 색은 자녀·상태 몫(palette.dart).
class KindTag extends StatelessWidget {
  final EntryKind kind;
  const KindTag(this.kind, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    '${kind.emoji} ${kind.label}',
    style: TextStyle(fontSize: AppText.label, color: context.palette.textMuted),
  );
}

/// 확인 대화상자. 되돌릴 수 없는(또는 다른 가족에게 바로 보이는) 동작 전에 쓴다.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ctx.palette.status.urgent) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 짧은 결과 알림. 화면에서 ScaffoldMessenger를 직접 부르지 않고 이걸 쓴다.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, kDockClearance - 16),
      ),
    );
}
