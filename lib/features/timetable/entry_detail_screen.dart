import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import 'entry_editor_sheet.dart';

/// 일정 상세 + 댓글. 시간표 칸을 누르면 먼저 여기로 온다(바로 편집 화면이 뜨지 않게).
/// 고치는 건 오른쪽 위 "편집"으로만 — 보러 들어왔다가 실수로 고치는 일을 막는다(실사용 피드백).
///
/// 댓글은 아이가 "오늘 피아노 늦게 끝나요" 같은 특별한 일을 남기는 곳이라, 권한이 있는
/// 가족이면 누구나 쓸 수 있다([Permissions.canComment]).
class EntryDetailScreen extends ConsumerWidget {
  final String versionId;
  final String entryId;

  const EntryDetailScreen({super.key, required this.versionId, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(versionProvider(versionId));
    final entry = version?.entries.where((e) => e.id == entryId).firstOrNull;
    final child = version == null ? null : ref.watch(childProvider(version.childId));
    if (version == null || entry == null || child == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(emoji: '🗂️', title: '이 일정은 지워졌어요'),
      );
    }
    final perms = ref.watch(permissionsProvider);
    final comments = ref.watch(entryCommentsProvider(entryId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (perms.canEditEntries(child))
            Padding(
              padding: const EdgeInsets.only(right: AppGap.md),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => showEntryEditor(context, child: child, version: version, entry: entry),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('편집'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, AppGap.xl),
                  children: [
                    _EntryHero(child: child, version: version, entry: entry),
                    if (entry.place.isNotEmpty || entry.memo.isNotEmpty) ...[
                      const SizedBox(height: AppGap.md),
                      _InfoCard(entry: entry),
                    ],
                    SectionHeader(
                      '댓글',
                      trailing: comments.isEmpty
                          ? null
                          : Text(
                              '${comments.length}',
                              style: AppFonts.numeric(size: AppText.titleLg, color: context.palette.textMuted),
                            ),
                    ),
                    if (comments.isEmpty)
                      DashCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppGap.md),
                          child: Column(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: AppEmoji.sm)),
                              const SizedBox(height: AppGap.sm),
                              Text(
                                '특별한 일이 있으면 남겨 주세요',
                                style: TextStyle(fontSize: AppText.body, color: context.palette.textMuted),
                              ),
                              Text(
                                '예: 오늘 30분 늦게 끝나요, 준비물 챙겨야 해요',
                                style: TextStyle(fontSize: AppText.label, color: context.palette.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      for (final c in comments) _CommentBubble(comment: c),
                  ],
                ),
              ),
            ),
          ),
          if (perms.canComment) _CommentInput(version: version, entry: entry),
        ],
      ),
    );
  }
}

/// 맨 위 카드: 종류색 바탕에 이름·시각·요일. 시간표 칸과 같은 색이라 어디서 눌러 왔는지 이어진다.
class _EntryHero extends StatelessWidget {
  final Child child;
  final TimetableVersion version;
  final Entry entry;

  const _EntryHero({required this.child, required this.version, required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tone = p.kind(entry.kind);
    final when = ['매주 ${weekdayLabel(entry.weekday)}요일', if (entry.period != null) '${entry.period}교시'].join(' · ');
    return HeroCard(
      gradient: [tone.container, Color.lerp(tone.container, p.surface, 0.55)!],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip('${entry.kind.emoji} ${entry.kind.label}', color: tone.onContainer),
              const Spacer(),
              ChildBadge(child),
            ],
          ),
          const SizedBox(height: AppGap.lg),
          Text(
            entry.title,
            style: TextStyle(
              fontSize: AppText.display,
              fontWeight: FontWeight.w700,
              color: tone.onContainer,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppGap.sm),
          TimeText(
            '${formatMinutes(entry.start)} – ${formatMinutes(entry.end)}',
            size: AppText.kpi,
            weight: FontWeight.w300,
            color: tone.onContainer,
          ),
          const SizedBox(height: AppGap.xs),
          Text(
            '$when · ${entry.end - entry.start}분 · ${version.name}',
            style: TextStyle(fontSize: AppText.label, color: tone.onContainer.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Entry entry;
  const _InfoCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppGap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.textMuted),
          const SizedBox(width: AppGap.cozy),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: AppText.bodyLg)),
          ),
        ],
      ),
    );
    return DashCard(
      child: Column(
        children: [
          if (entry.place.isNotEmpty) row(Icons.place_outlined, entry.place),
          if (entry.memo.isNotEmpty) row(Icons.sticky_note_2_outlined, entry.memo),
        ],
      ),
    );
  }
}

/// 댓글 한 개. 내 댓글은 오른쪽 검은 말풍선, 다른 가족은 왼쪽 흰 말풍선(+ 이름 동그라미).
/// 아이가 쓴 댓글의 동그라미는 그 아이 색 — 누가 남겼는지 한눈에.
class _CommentBubble extends ConsumerWidget {
  final Comment comment;
  const _CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final me = ref.watch(meProvider);
    final mine = me?.id == comment.authorId;
    final author = (ref.watch(membersProvider).valueOrNull ?? const <Member>[])
        .where((m) => m.id == comment.authorId)
        .firstOrNull;
    final authorChild = author?.childId == null ? null : ref.watch(childProvider(author!.childId!));
    final avatarTone = authorChild == null ? null : p.child(authorChild.colorIndex);
    final canDelete = ref.watch(permissionsProvider).canDeleteComment(comment);

    final bubble = GestureDetector(
      onLongPress: canDelete ? () => _confirmDelete(context, ref) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? p.dock : p.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(mine ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(mine ? AppRadius.xs : AppRadius.lg),
          ),
        ),
        child: Text(
          comment.text,
          style: TextStyle(fontSize: AppText.bodyLg, height: 1.4, color: mine ? p.onDock : null),
        ),
      ),
    );

    final meta = Text(
      mine ? formatRelative(comment.createdAt) : '${comment.authorName} · ${formatRelative(comment.createdAt)}',
      style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppGap.md),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: avatarTone?.container ?? p.surfaceMuted,
              child: Text(
                comment.authorName.isEmpty ? '?' : comment.authorName.characters.first,
                style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700, color: avatarTone?.onContainer),
              ),
            ),
            const SizedBox(width: AppGap.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                const SizedBox(height: AppGap.xs),
                meta,
              ],
            ),
          ),
          if (mine) const SizedBox(width: AppGap.xxs),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context, title: '댓글을 지울까요?', confirmLabel: '지우기', destructive: true);
    if (ok) await ref.read(repositoryProvider).deleteComment(comment);
  }
}

/// 아래 고정 입력줄: 흰 알약 입력칸 + 검은 동그라미 보내기. 키보드가 올라오면 같이 올라간다.
class _CommentInput extends ConsumerStatefulWidget {
  final TimetableVersion version;
  final Entry entry;
  const _CommentInput({required this.version, required this.entry});

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(meProvider);
    // 보낼 글을 먼저 잡고 칸부터 비운다. 기다리는 사이 이어서 친 글까지 지워지지 않게(코드 점검 M6).
    final text = _controller.text;
    if (me == null || text.trim().isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ref
          .read(repositoryProvider)
          .addComment(version: widget.version, entry: widget.entry, author: me, text: text);
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        showToast(context, '댓글을 남기지 못했어요');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      color: p.canvas,
      padding: const EdgeInsets.fromLTRB(AppGap.page, AppGap.sm, AppGap.page, AppGap.sm),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '특별한 일이 있으면 남겨 주세요',
                    filled: false,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: AppGap.xs),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: p.dock, foregroundColor: p.onDock),
                onPressed: _sending || _controller.text.trim().isEmpty ? null : _send,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                tooltip: '보내기',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
