import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';

/// 학교 교시 한꺼번에 입력. 학교 시간표 종이를 보고 요일별로 과목만 쭉 적는다.
/// 시간은 학교급 기본 교시 시간으로 미리 채워지고, 시각을 누르면 바꿀 수 있다.
/// 월~금을 오가며 적은 뒤 저장 한 번 = 수정 기록 한 장.
Future<void> showSchoolWeekSheet(BuildContext context, {required Child child, required TimetableVersion version}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _SchoolWeekSheet(child: child, version: version),
      ),
    );

class _Row {
  final TextEditingController subject;
  int start;
  int end;
  _Row(String text, this.start, this.end) : subject = TextEditingController(text: text);
}

class _SchoolWeekSheet extends ConsumerStatefulWidget {
  final Child child;
  final TimetableVersion version;
  const _SchoolWeekSheet({required this.child, required this.version});

  @override
  ConsumerState<_SchoolWeekSheet> createState() => _SchoolWeekSheetState();
}

class _SchoolWeekSheetState extends ConsumerState<_SchoolWeekSheet> {
  int _weekday = DateTime.now().weekday.clamp(1, 5);
  late final Map<int, List<_Row>> _rows = {for (var d = 1; d <= 5; d++) d: _initialRows(d)};
  bool _saving = false;

  List<_Row> _initialRows(int weekday) {
    final existing = {
      for (final e in widget.version.entries)
        if (e.weekday == weekday && e.kind == EntryKind.school && e.period != null) e.period!: e,
    };
    return [
      for (var p = 1; p <= kMaxPeriods; p++)
        () {
          final e = existing[p];
          final (s, en) = defaultPeriodTime(widget.child.institution, p);
          return _Row(e?.title ?? '', e?.start ?? s, e?.end ?? en);
        }(),
    ];
  }

  @override
  void dispose() {
    for (final rows in _rows.values) {
      for (final r in rows) {
        r.subject.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = _rows[_weekday]!;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, MediaQuery.viewInsetsOf(context).bottom + AppGap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '학교 교시 입력',
                  style: TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
                ),
              ),
              ChildBadge(widget.child),
            ],
          ),
          const SizedBox(height: AppGap.xs),
          Text(
            '요일을 바꿔 가며 과목만 적어 주세요. 빈 칸은 그 교시가 없는 거예요.',
            style: TextStyle(fontSize: AppText.label, color: p.textMuted),
          ),
          const SizedBox(height: AppGap.md),
          PillTabs<int>(
            items: [
              for (var d = 1; d <= 5; d++)
                (d, '${weekdayLabel(d)} ${_filled(d)}', _filled(d) > 0 ? p.status.positive : null),
            ],
            selected: _weekday,
            onChanged: (d) => setState(() => _weekday = d),
          ),
          const SizedBox(height: AppGap.md),
          // 과목 칩은 한 줄 가로 스크롤: 여러 줄로 감싸면 플립 화면에서 교시 칸이 반쯤 밀려난다.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in titleSuggestions(EntryKind.school, widget.child.institution))
                  Padding(
                    padding: const EdgeInsets.only(right: AppGap.snug),
                    child: ActionChip(label: Text(s), onPressed: () => _fillNext(s)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppGap.md),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppGap.sm),
              itemBuilder: (_, i) => _PeriodRow(
                key: ValueKey('$_weekday-$i'),
                period: i + 1,
                row: rows[i],
                onTimeChanged: () => setState(() {}),
                onChanged: () => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: AppGap.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _saving ? null : _save, child: const Text('저장')),
          ),
        ],
      ),
    );
  }

  int _filled(int d) => _rows[d]!.where((r) => r.subject.text.trim().isNotEmpty).length;

  /// 과목 칩을 누르면 지금 요일의 첫 빈 교시에 넣는다(키보드 없이 빠르게 채우기).
  void _fillNext(String subject) {
    final empty = _rows[_weekday]!.where((r) => r.subject.text.trim().isEmpty).firstOrNull;
    if (empty == null) return showToast(context, '빈 교시가 없어요');
    setState(() => empty.subject.text = subject);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    await repo.replaceSchoolWeek(widget.version, {
      for (final MapEntry(key: d, value: rows) in _rows.entries)
        d: [for (final r in rows) (subject: r.subject.text, start: r.start, end: r.end)],
    });
    if (mounted) Navigator.pop(context);
  }
}

class _PeriodRow extends StatelessWidget {
  final int period;
  final _Row row;
  final VoidCallback onTimeChanged;
  final VoidCallback onChanged;

  const _PeriodRow({
    super.key,
    required this.period,
    required this.row,
    required this.onTimeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            '$period교시',
            style: const TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: TextField(
            controller: row.subject,
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '과목', isDense: true),
          ),
        ),
        const SizedBox(width: AppGap.sm),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: row.start ~/ 60, minute: row.start % 60),
              initialEntryMode: TimePickerEntryMode.input,
            );
            if (t == null) return;
            final len = row.end - row.start;
            row.start = t.hour * 60 + t.minute;
            row.end = row.start + len;
            onTimeChanged();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: TimeText(
              '${formatMinutes(row.start)}–${formatMinutes(row.end)}',
              size: AppText.label,
              weight: FontWeight.w500,
              color: p.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
