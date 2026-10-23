import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/design.dart';
import '../../domain/models.dart';
import '../../domain/timetable_logic.dart';

/// 자녀 추가/수정 시트. [child]가 null이면 추가.
/// 추가하면 첫 시간표 버전(학기 이름 자동 추천)도 같이 만들어진다.
Future<void> showChildFormSheet(BuildContext context, {Child? child}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ChildFormSheet(child: child),
);

class _ChildFormSheet extends ConsumerStatefulWidget {
  final Child? child;
  const _ChildFormSheet({this.child});

  @override
  ConsumerState<_ChildFormSheet> createState() => _ChildFormSheetState();
}

class _ChildFormSheetState extends ConsumerState<_ChildFormSheet> {
  late final _name = TextEditingController(text: widget.child?.name ?? '');
  late final _school = TextEditingController(text: widget.child?.schoolName ?? '');
  late Institution _inst = widget.child?.institution ?? Institution.elementary;
  late int _grade = widget.child?.grade ?? 1;
  int? _color;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final siblings = ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final color = _color ?? widget.child?.colorIndex ?? p.nextFreeColor(siblings.map((c) => c.colorIndex));
    final editing = widget.child != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, MediaQuery.viewInsetsOf(context).bottom + AppGap.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? '아이 정보' : '아이 추가',
              style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppGap.lg),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '이름 또는 호칭 (예: 첫째)'),
            ),
            const SizedBox(height: AppGap.lg),
            _label('다니는 곳'),
            PillTabs<Institution>(
              items: [for (final i in Institution.values) (i, i.label, null)],
              selected: _inst,
              onChanged: (i) => setState(() {
                _inst = i;
                if (_grade > i.maxGrade) _grade = i.maxGrade == 0 ? 0 : 1;
                if (i.maxGrade > 0 && _grade == 0) _grade = 1;
              }),
            ),
            if (_inst.maxGrade > 0) ...[
              const SizedBox(height: AppGap.lg),
              _label('학년'),
              PillTabs<int>(
                items: [for (var g = 1; g <= _inst.maxGrade; g++) (g, '$g학년', null)],
                selected: _grade,
                onChanged: (g) => setState(() => _grade = g),
              ),
              const SizedBox(height: AppGap.lg),
              TextField(
                controller: _school,
                decoration: const InputDecoration(labelText: '학교 이름 (선택)'),
              ),
            ],
            const SizedBox(height: AppGap.lg),
            _label('색'),
            Wrap(
              spacing: AppGap.md,
              children: [
                for (var i = 0; i < p.childTones.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: p.childTones[i].gradient),
                        border: Border.all(color: i == color ? p.childTones[i].accent : Colors.transparent, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppGap.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(color, siblings),
                child: Text(editing ? '저장' : '추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppGap.sm),
    child: Text(
      t,
      style: TextStyle(fontSize: AppText.label, fontWeight: FontWeight.w600, color: context.palette.textMuted),
    ),
  );

  Future<void> _save(int color, List<Child> siblings) async {
    final name = _name.text.trim();
    if (name.isEmpty) return showToast(context, '이름을 적어 주세요');
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final grade = _inst.maxGrade == 0 ? 0 : _grade;
    final existing = widget.child;
    if (existing == null) {
      final draft = Child(
        id: '',
        name: name,
        colorIndex: color,
        institution: _inst,
        grade: grade,
        order: siblings.length,
        updatedAt: DateTime.now(),
      );
      await repo.addChild(
        name: name,
        institution: _inst,
        grade: grade,
        schoolName: _school.text.trim(),
        colorIndex: color,
        order: siblings.length,
        firstVersionName: suggestVersionName(draft, DateTime.now()),
      );
    } else {
      await repo.updateChildInfo(
        existing,
        name: name,
        institution: _inst,
        grade: grade,
        schoolName: _school.text.trim(),
        colorIndex: color,
      );
    }
    if (mounted) Navigator.pop(context);
  }
}
