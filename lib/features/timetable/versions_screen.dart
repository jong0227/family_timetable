import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../core/format.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';
import 'revisions_screen.dart';
import 'version_detail_screen.dart';

/// 학기·방학 시간표 목록. "2학년 1학기", "2학년 여름방학", "2학년 2학기"…
/// 지난 것은 지우지 않고 남겨서 언제든 열어 본다.
///
/// 오늘 쓰는 시간표는 하나다([effectiveVersion]): 기간을 정한 방학이면 그 기간에 저절로,
/// 아니면 "지금 쓰기"로 고른 것.
class VersionsScreen extends ConsumerWidget {
  final String childId;
  const VersionsScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final child = ref.watch(childProvider(childId));
    if (child == null) return const Scaffold();
    final versions = ref.watch(childVersionsProvider(childId));
    final effective = ref.watch(currentVersionProvider(childId));
    final canManage = ref.watch(permissionsProvider).canManageVersions(child);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => showNewVersionDialog(context, ref, child: child),
              icon: const Icon(Icons.add_rounded),
              label: const Text('새 시간표'),
              shape: const StadiumBorder(),
            )
          : null,
      body: PageBody(
        children: [
          PageHeader(title: '학기·방학 시간표', subtitle: '${child.name} · ${versions.length}개'),
          for (final v in versions) ...[
            _VersionTile(child: child, version: v, effective: effective, canManage: canManage),
            const SizedBox(height: AppGap.md),
          ],
          if (versions.isEmpty)
            DashCard(
              child: EmptyState(
                emoji: '📒',
                title: '아직 시간표가 없어요',
                actionLabel: canManage ? '새 시간표' : null,
                onAction: () => showNewVersionDialog(context, ref, child: child),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppGap.sm),
            child: Text(
              '학기가 바뀌면 새 학기 시간표를, 방학엔 방학 시간표를 만들어 주세요. '
              '방학 시간표에 기간을 정해 두면 그 기간엔 저절로 방학 시간표를 쓰고, 끝나면 학기 시간표로 돌아와요.',
              style: TextStyle(fontSize: AppText.label, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 시간표 한 줄의 상태. 목록·상세 화면이 같은 말을 쓰도록 여기서 정한다.
enum _TileState {
  /// 기간이 오늘을 덮어 저절로 쓰는 중(방학)
  autoActive,

  /// "지금 쓰기"로 골라 쓰는 중
  active,

  /// 골라 둔 학기인데 지금은 방학 시간표가 대신 쓰이는 중 → 방학 끝나면 다시 쓰임
  resumesAfterVacation,

  /// 기간이 정해져 있고 아직 그때가 아님(앞으로 저절로 쓰임, 또는 지난 방학)
  scheduled,
  idle,
}

_TileState _stateOf(Child child, TimetableVersion v, TimetableVersion? effective, DateTime today) {
  if (effective?.id == v.id) return v.covers(today) ? _TileState.autoActive : _TileState.active;
  if (child.currentVersionId == v.id) return _TileState.resumesAfterVacation;
  if (v.hasPeriod) return _TileState.scheduled;
  return _TileState.idle;
}

class _VersionTile extends ConsumerWidget {
  final Child child;
  final TimetableVersion version;
  final TimetableVersion? effective;
  final bool canManage;

  const _VersionTile({required this.child, required this.version, required this.effective, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final tone = p.child(child.colorIndex);
    final today = ref.watch(todayProvider);
    final state = _stateOf(child, version, effective, today);
    final inUse = state == _TileState.active || state == _TileState.autoActive;
    final period = formatPeriod(version);
    final ended = version.hasPeriod && today.isAfter(version.endDate!);

    final chip = switch (state) {
      _TileState.autoActive => StatusChip('방학 중', color: p.status.positive, dot: true),
      _TileState.active => StatusChip('사용 중', color: p.status.positive, dot: true),
      _TileState.resumesAfterVacation => StatusChip('방학 끝나면 사용', color: p.textMuted),
      _TileState.scheduled when !ended => StatusChip('$period 자동', color: p.status.info),
      _ => null,
    };

    return DashCard(
      onTap: () => _open(context),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: inUse ? tone.accent : p.status.neutral,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppGap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        version.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: AppText.titleLg, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (chip != null) ...[const SizedBox(width: AppGap.sm), Flexible(child: chip)],
                  ],
                ),
                const SizedBox(height: AppGap.xxs),
                Text(
                  [version.kind.label, ?period, '일정 ${version.entries.length}개'].join(' · '),
                  style: TextStyle(fontSize: AppText.label, color: p.textMuted),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _menu(context, ref, inUse)),
        ],
      ),
    );
  }

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VersionDetailScreen(versionId: version.id)));

  Future<void> _menu(BuildContext context, WidgetRef ref, bool inUse) async {
    ListTile item(BuildContext ctx, IconData icon, String title, String action, {bool danger = false}) => ListTile(
      leading: Icon(icon, color: danger ? ctx.palette.status.urgent : null),
      title: Text(title, style: danger ? TextStyle(color: ctx.palette.status.urgent) : null),
      onTap: () => Navigator.pop(ctx, action),
    );
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(ctx, Icons.visibility_outlined, '보기', 'open'),
            item(ctx, Icons.history_rounded, '수정 기록', 'history'),
            if (canManage) ...[
              if (version.isVacation)
                item(ctx, Icons.date_range_rounded, version.hasPeriod ? '방학 기간 바꾸기' : '방학 기간 정하기', 'period'),
              if (!inUse) item(ctx, Icons.check_circle_outline_rounded, '이 시간표를 지금 쓰기', 'current'),
              item(ctx, Icons.copy_rounded, '복제해서 새 시간표 만들기', 'copy'),
              item(ctx, Icons.edit_outlined, '이름 바꾸기', 'rename'),
              item(ctx, Icons.delete_outline_rounded, '삭제', 'delete', danger: true),
            ],
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(repositoryProvider);
    switch (action) {
      case 'open':
        _open(context);
      case 'history':
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => RevisionsScreen(versionId: version.id)));
      case 'period':
        final range = await pickVacationRange(context, initial: version);
        if (range == null) return;
        await repo.setVersionPeriod(version, range.start, range.end);
        if (context.mounted) {
          showToast(context, '${formatDateShort(range.start)}~${formatDateShort(range.end)}엔 이 시간표를 저절로 써요');
        }
      case 'current':
        await repo.setCurrent(child, version);
        if (context.mounted) showToast(context, '이제 "${version.name}" 시간표를 써요');
      case 'copy':
        await showNewVersionDialog(context, ref, child: child, copyFrom: version);
      case 'rename':
        final name = await _askName(context, '이름 바꾸기', version.name);
        if (name != null) await repo.renameVersion(version, name);
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: '"${version.name}" 시간표를 삭제할까요?',
          message: inUse ? '지금 쓰는 시간표예요. 지우면 남은 것 중 가장 최근 시간표를 쓰게 돼요.' : null,
          confirmLabel: '삭제',
          destructive: true,
        );
        if (ok) await repo.deleteVersion(child, version);
    }
  }
}

/// 방학 기간 고르기(달력). 취소하면 null.
Future<DateTimeRange?> pickVacationRange(BuildContext context, {TimetableVersion? initial}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 2, 12, 31),
    initialDateRange: initial != null && initial.hasPeriod
        ? DateTimeRange(start: initial.startDate!, end: initial.endDate!)
        : null,
    helpText: '방학 기간',
    saveText: '저장',
  );
}

/// 새 시간표 만들기. 학기/방학을 고르고, 이름 후보를 고르거나 직접 적고,
/// 지금 시간표를 복제할지 정한다(방학으로 복제하면 학교 교시는 빼고 학원·방과후만).
/// 방학은 기간을 정할 수 있다 — 정하면 그 기간에 저절로 쓰이고, 안 정하면 바로 "사용 중"이 된다.
Future<void> showNewVersionDialog(
  BuildContext context,
  WidgetRef ref, {
  required Child child,
  TimetableVersion? copyFrom,
}) async {
  final source = copyFrom ?? ref.read(currentVersionProvider(child.id));
  final existing = ref.read(childVersionsProvider(child.id)).map((v) => v.name).toSet();
  final now = DateTime.now();
  List<String> candidatesFor(VersionKind k) => versionNameCandidates(child, now, existing: existing, kind: k);

  // 기본 종류: 순서상 다음에 올 시간표(학기 다음은 방학, 방학 다음은 학기)의 종류.
  final next = versionNameCandidates(child, now, existing: existing).firstOrNull;
  var kind = next != null && next.contains('방학') ? VersionKind.vacation : VersionKind.term;
  var candidates = candidatesFor(kind);
  final controller = TextEditingController(text: candidates.firstOrNull ?? '');
  var copy = source != null && source.entries.isNotEmpty;
  DateTimeRange? range;

  final result = await showDialog<bool>(
    context: context,
    // 이름·종류·기간까지 고른 뒤 바깥을 잘못 건드려 통째로 날아가지 않게, 취소/만들기로만 닫는다.
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final p = ctx.palette;
        final copyCount = source == null
            ? 0
            : (kind == VersionKind.vacation ? entriesForVacation(source.entries) : source.entries).length;
        return AlertDialog(
          title: const Text('새 시간표'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillTabs<VersionKind>(
                  items: [for (final k in VersionKind.values) (k, k.label, null)],
                  selected: kind,
                  onChanged: (k) => setState(() {
                    // 이름 칸이 아직 자동 추천값이면 새 종류의 추천으로 바꿔 준다(직접 친 이름은 그대로).
                    final wasSuggested = controller.text.isEmpty || candidates.contains(controller.text);
                    kind = k;
                    candidates = candidatesFor(k);
                    if (wasSuggested) controller.text = candidates.firstOrNull ?? '';
                  }),
                ),
                const SizedBox(height: AppGap.md),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: kind == VersionKind.vacation ? '이름 (예: 2학년 여름방학)' : '이름 (예: 3학년 1학기)',
                  ),
                ),
                const SizedBox(height: AppGap.sm),
                Wrap(
                  spacing: AppGap.snug,
                  runSpacing: AppGap.snug,
                  children: [
                    for (final c in candidates)
                      ActionChip(label: Text(c), onPressed: () => setState(() => controller.text = c)),
                  ],
                ),
                if (kind == VersionKind.vacation) ...[
                  const SizedBox(height: AppGap.lg),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final r = await pickVacationRange(ctx);
                      if (r != null) setState(() => range = r);
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      range == null
                          ? '방학 기간 정하기 (선택)'
                          : '${formatDateShort(range!.start)} ~ ${formatDateShort(range!.end)}',
                    ),
                  ),
                  const SizedBox(height: AppGap.xs),
                  Text(
                    range == null ? '기간을 정하면 그 기간에만 저절로 이 시간표를 써요.' : '이 기간엔 저절로 방학 시간표, 끝나면 학기 시간표로 돌아와요.',
                    style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
                  ),
                ],
                if (copyCount > 0) ...[
                  const SizedBox(height: AppGap.lg),
                  PillTabs<bool>(
                    items: [
                      (true, kind == VersionKind.vacation ? '학원·방과후 $copyCount개 가져오기' : '"${source!.name}" 복제', null),
                      (false, '빈 시간표', null),
                    ],
                    selected: copy,
                    onChanged: (v) => setState(() => copy = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('만들기')),
          ],
        );
      },
    ),
  );
  final name = controller.text.trim();
  controller.dispose();
  if (result != true || name.isEmpty) return;
  await ref
      .read(repositoryProvider)
      .createVersion(
        child,
        name,
        copyFrom: copy ? source : null,
        kind: kind,
        startDate: range?.start,
        endDate: range?.end,
      );
  if (!context.mounted) return;
  final r = range;
  showToast(
    context,
    kind == VersionKind.vacation && r != null
        ? (r.start.isAfter(DateTime.now())
              ? '"$name" 시간표를 만들었어요. ${formatDateShort(r.start)}부터 저절로 써요'
              : '"$name" 시간표를 만들었어요. 지금부터 ${formatDateShort(r.end)}까지 이 시간표를 써요')
        : '"$name" 시간표를 만들었어요. 지난 시간표는 그대로 남아 있어요',
  );
}

Future<String?> _askName(BuildContext context, String title, String initial) async {
  final controller = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
      ],
    ),
  );
  final name = controller.text.trim();
  controller.dispose();
  return ok == true && name.isNotEmpty ? name : null;
}
