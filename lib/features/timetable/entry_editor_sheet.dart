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
  late Set<int> _days = {_original?.weekday ?? widget.weekday ?? DateTime.now().weekday.clamp(1, 5)};
  late int? _period = _original?.period;
  late int _start = _original?.start ?? 15 * 60;
  late int _end = _original?.end ?? 16 * 60;
  bool _saving = false;

  bool get _editing => _original != null;
  bool get _usesPeriods => _kind == EntryKind.school && widget.child.institution.hasPeriods;

  @override
  void dispose() {
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
                  }
                }),
              ),
            ],
            const SizedBox(height: AppGap.lg),
            _label('시간'),
            Row(
              children: [
                Expanded(
                  child: _TimeField(label: '시작', minutes: _start, onPick: (m) => setState(() => _setStart(m))),
                ),
                const SizedBox(width: AppGap.md),
                Expanded(
                  child: _TimeField(label: '끝', minutes: _end, onPick: (m) => setState(() => _end = m)),
                ),
              ],
            ),
            if (_end <= _start) ...[
              const SizedBox(height: AppGap.sm),
              Text(
                '끝 시간이 시작보다 늦어야 해요',
                style: TextStyle(fontSize: AppText.label, color: p.status.urgent, fontWeight: FontWeight.w600),
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
                      style: TextStyle(fontSize: AppText.label, color: p.status.urgent, fontWeight: FontWeight.w600),
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
                    child: Text(_editing ? '저장' : (_days.length > 1 ? '${_days.length}개 요일에 추가' : '추가')),
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
    if (_title.text.trim().isEmpty) return showToast(context, '이름을 적어 주세요');
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final original = _original;
    if (original != null) {
      await repo.upsertEntry(widget.version, _draft(_days.first, original.id));
    } else {
      final days = _days.toList()..sort();
      // id는 비워 두면 리포지토리가 새로 붙인다.
      await repo.addEntries(widget.version, [for (final d in days) _draft(d, '')]);
    }
    if (mounted) Navigator.pop(context);
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
    setState(() => _saving = true);
    await ref.read(repositoryProvider).deleteEntry(widget.version, original);
    if (mounted) Navigator.pop(context);
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

class _TimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onPick;

  const _TimeField({required this.label, required this.minutes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
            initialEntryMode: TimePickerEntryMode.input,
          );
          if (t != null) onPick(t.hour * 60 + t.minute);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: AppText.caption, color: p.textMuted),
              ),
              TimeText(formatMinutes(minutes), size: AppText.numSm, weight: FontWeight.w400),
            ],
          ),
        ),
      ),
    );
  }
}
