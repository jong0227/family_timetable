import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';

/// 일정 추가·수정 시트.
/// - 추가: 여러 요일을 한 번에 고를 수 있다(월·수·금 피아노).
/// - 수정: 그 일정 하나(요일 하나). 삭제도 여기서.
/// 저장하면 수정 기록이 남는다(되돌리기 가능).
Future<void> showEntryEditor(
  BuildContext context, {
  required Child child,
  required TimetableVersion version,
  Entry? entry,
  int? weekday,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _EntryEditor(child: child, version: version, entry: entry, weekday: weekday),
);

class _EntryEditor extends ConsumerStatefulWidget {
  final Child child;
  final TimetableVersion version;
  final Entry? entry;
  final int? weekday;

  const _EntryEditor({required this.child, required this.version, this.entry, this.weekday});

  @override
  ConsumerState<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<_EntryEditor> {
  late final Entry? _original = widget.entry;
  late EntryKind _kind = _original?.kind ?? EntryKind.academy;
  late final _title = TextEditingController(text: _original?.title ?? '');
  late final _place = TextEditingController(text: _original?.place ?? '');
  late final _memo = TextEditingController(text: _original?.memo ?? '');
  // 새 일정은 요일을 미리 고르지 않는다(오늘 요일이 미리 켜져 있으면 모르고 그대로 저장되기 쉽다 —
  // 실사용 피드백). 격자의 요일 머리를 눌러 들어온 경우에만 그 요일을 켜 둔다.
  late Set<int> _days = {if (_original != null) _original.weekday else if (widget.weekday != null) widget.weekday!};
  late int? _period = _original?.period;
  late int _start = _original?.start ?? 15 * 60;
  late int _end = _original?.end ?? 16 * 60;
  bool _saving = false;

  bool get _editing => _original != null;
  // 방학 시간표엔 교시가 없다(학교에 가도 돌봄·방과후처럼 시간으로 잡는다).
  bool get _usesPeriods =>
      _kind == EntryKind.school && widget.child.institution.hasPeriods && !widget.version.isVacation;

  /// 칩·교시로 시간을 정할 때마다 올려서, 입력 칸이 치다 만 글자를 버리고 새 값을 보이게 한다.
  int _timeRevision = 0;
  final _startFocus = FocusNode();
  final _endFocus = FocusNode();

  @override
  void dispose() {
    _startFocus.dispose();
    _endFocus.dispose();
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final overlaps = _overlaps();

    return Padding(
      padding: EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, MediaQuery.viewInsetsOf(context).bottom + AppGap.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? '일정 고치기' : '일정 추가',
                    style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
                  ),
                ),
                ChildBadge(widget.child),
              ],
            ),
            const SizedBox(height: AppGap.lg),
            _label('종류'),
            PillTabs<EntryKind>(
              items: [for (final k in EntryKind.values) (k, '${k.emoji} ${k.label}', null)],
              selected: _kind,
              onChanged: (k) => setState(() {
                _kind = k;
                if (!_usesPeriods) _period = null;
              }),
            ),
            const SizedBox(height: AppGap.lg),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: '이름 (예: 피아노, 수학)'),
            ),
            const SizedBox(height: AppGap.sm),
            Wrap(
              spacing: AppGap.snug,
              runSpacing: AppGap.snug,
              children: [
                for (final s in titleSuggestions(_kind, widget.child.institution))
                  ActionChip(label: Text(s), onPressed: () => setState(() => _title.text = s)),
              ],
            ),
            const SizedBox(height: AppGap.lg),
            _label(_editing ? '요일' : '요일 (여러 개 고를 수 있어요)'),
            _WeekdayPicker(selected: _days, multi: !_editing, onChanged: (d) => setState(() => _days = d)),
            if (_usesPeriods) ...[
              const SizedBox(height: AppGap.lg),
              _label('교시'),
              PillTabs<int?>(
                items: [(null, '교시 없음', null), for (var i = 1; i <= kMaxPeriods; i++) (i, '$i교시', null)],
                selected: _period,
                onChanged: (v) => setState(() {
                  _period = v;
                  if (v != null) {
                    final (s, e) = defaultPeriodTime(widget.child.institution, v);
                    _start = s;
                    _end = e;
                    _timeRevision++;
                  }
                }),
              ),
            ],
            const SizedBox(height: AppGap.lg),
            _label('시간'),
            Row(
              children: [
                Expanded(
                  child: TimeInputField(
                    label: '시작',
                    minutes: _start,
                    focusNode: _startFocus,
                    nextFocus: _endFocus,
                    externalRevision: _timeRevision,
                    onChanged: (m) => setState(() => _setStart(m)),
                  ),
                ),
                const SizedBox(width: AppGap.md),
                Expanded(
                  child: TimeInputField(
                    label: '끝',
                    minutes: _end,
                    focusNode: _endFocus,
                    externalRevision: _timeRevision,
                    onChanged: (m) => setState(() => _end = m),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppGap.sm),
            // 끝 시각은 대개 "몇 분짜리"로 정하는 게 빠르다(학원 50분, 태권도 1시간).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final len in const [30, 40, 50, 60, 90, 120])
                    Padding(
                      padding: const EdgeInsets.only(right: AppGap.snug),
                      child: ChoiceChip(
                        label: Text(
                          len < 60 ? '$len분' : (len % 60 == 0 ? '${len ~/ 60}시간' : '${len ~/ 60}시간 ${len % 60}분'),
                        ),
                        selected: _end - _start == len,
                        onSelected: (_) => setState(() {
                          _end = (_start + len).clamp(0, 24 * 60 - 1);
                          _timeRevision++;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            if (_end <= _start) ...[
              const SizedBox(height: AppGap.sm),
              Text(
                '끝 시간이 시작보다 늦어야 해요',
                style: TextStyle(fontSize: AppText.label, color: p.status.urgentText, fontWeight: FontWeight.w600),
              ),
            ],
            if (overlaps.isNotEmpty) ...[
              const SizedBox(height: AppGap.sm),
              Row(
                children: [
                  StatusDot(p.status.urgent, size: 6),
                  const SizedBox(width: AppGap.sm),
                  Expanded(
                    child: Text(
                      '겹치는 일정: ${overlaps.map(describeEntry).join(', ')}',
                      style: TextStyle(
                        fontSize: AppText.label,
                        color: p.status.urgentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppGap.lg),
            TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: '장소 (선택)'),
            ),
            const SizedBox(height: AppGap.md),
            TextField(
              controller: _memo,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
            ),
            const SizedBox(height: AppGap.xxl),
            Row(
              children: [
                if (_editing) ...[
                  OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(foregroundColor: p.status.urgent),
                    child: const Text('삭제'),
                  ),
                  const SizedBox(width: AppGap.md),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || _end <= _start || _days.isEmpty ? null : _save,
                    child: Text(
                      _editing
                          ? '저장'
                          : _days.isEmpty
                          ? '요일을 골라 주세요'
                          : (_days.length > 1 ? '${_days.length}개 요일에 추가' : '추가'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 시작을 옮기면 길이를 유지한 채 끝도 같이 옮긴다(1시간짜리 학원을 30분 늦출 때 편하게).
  void _setStart(int m) {
    final len = (_end - _start).clamp(10, 24 * 60);
    _start = m;
    _end = (m + len).clamp(0, 24 * 60 - 1);
  }

  List<Entry> _overlaps() {
    final others = widget.version.entries;
    return {for (final d in _days) ...findOverlaps(_draft(d, _original?.id ?? '__new__'), others)}.toList();
  }

  Entry _draft(int weekday, String id) => Entry(
    id: id,
    weekday: weekday,
    start: _start,
    end: _end,
    title: _title.text.trim(),
    kind: _kind,
    period: _usesPeriods ? _period : null,
    place: _place.text.trim(),
    memo: _memo.text.trim(),
    pickupMemberId: _original?.pickupMemberId,
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppGap.sm),
    child: Text(
      t,
      style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: context.palette.textMuted),
    ),
  );

  Future<void> _save() async {
    // 시간 칸에 "16"까지만 치고 바로 저장을 눌러도 친 값으로 저장되게, 먼저 입력을 끝내고(칸이 확정)
    // 한 박자 기다린 뒤 값을 읽는다. 안드로이드는 버튼을 눌러도 입력칸 포커스가 안 빠져서, 예전엔
    // 화면엔 16이 보이는데 15:00으로 저장됐다(코드 점검 M2).
    FocusScope.of(context).unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (_title.text.trim().isEmpty) return showToast(context, '이름을 적어 주세요');
    if (_end <= _start) return showToast(context, '끝 시간이 시작보다 늦어야 해요');
    await _run(() async {
      final repo = ref.read(repositoryProvider);
      final original = _original;
      if (original != null) {
        await repo.upsertEntry(widget.version, _draft(_days.first, original.id));
      } else {
        final days = _days.toList()..sort();
        // id는 비워 두면 리포지토리가 새로 붙인다.
        await repo.addEntries(widget.version, [for (final d in days) _draft(d, '')]);
      }
    });
  }

  /// 저장·삭제 공통: 실패해도 버튼이 "저장 중"에 갇히지 않고 이유를 알린다(코드 점검 M6).
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showToast(context, '저장하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final original = _original!;
    final ok = await confirmDialog(
      context,
      title: '${describeEntry(original)} 삭제할까요?',
      message: '수정 기록에서 언제든 되돌릴 수 있어요.',
      confirmLabel: '삭제',
      destructive: true,
    );
    if (!ok) return;
    await _run(() => ref.read(repositoryProvider).deleteEntry(widget.version, original));
  }
}

/// 요일 고르기. [multi]면 여러 개.
class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final bool multi;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({required this.selected, required this.multi, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var d = 1; d <= 7; d++) ...[
          if (d > 1) const SizedBox(width: AppGap.xs),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!multi) return onChanged({d});
                final next = {...selected};
                next.contains(d) ? next.remove(d) : next.add(d);
                onChanged(next);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected.contains(d) ? p.dock : p.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  weekdayLabel(d),
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w700,
                    color: selected.contains(d) ? p.onDock : (d >= 6 ? p.textMuted : null),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
