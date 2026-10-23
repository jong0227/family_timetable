import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models.dart';
import '../app_theme.dart';
import '../palette.dart';
import '../tokens.dart';

/// 시간 입력. 두 가지 방법을 같은 칸에서 다 된다.
///
/// 1. **타이핑** — 숫자만 치면 된다. "1530" → 15:30, "930" → 9:30.
///    네 자리를 다 치면(또는 세 자리 + 분이 확실하면) 저절로 다음 칸으로 넘어간다.
///    콜론(:)을 칠 필요가 없고, 시·분 칸을 따로 누를 필요도 없다.
/// 2. **드래그** — 오른쪽 시계 아이콘을 누르면 휠이 올라온다. 5분 단위로 굴려서 고른다.
///
/// 아이 일정에 새벽 1~6시는 없으므로 1~6시로 치면 오후(13~18시)로 읽는다. "330" → 15:30.
/// (Material 기본 시간 선택기는 시·분 칸을 따로 눌러야 하고 드래그가 안 돼서 불편하다는
///  실사용 피드백으로 만든 컴포넌트다. 시간 입력은 앱 전체에서 이것만 쓴다.)
class TimeInputField extends StatefulWidget {
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  /// 다 쳤을 때 넘어갈 다음 칸. null이면 키보드를 닫는다.
  final FocusNode? nextFocus;
  final FocusNode? focusNode;

  const TimeInputField({
    super.key,
    required this.label,
    required this.minutes,
    required this.onChanged,
    this.nextFocus,
    this.focusNode,
  });

  @override
  State<TimeInputField> createState() => _TimeInputFieldState();
}

class _TimeInputFieldState extends State<TimeInputField> {
  late final _controller = TextEditingController(text: formatMinutes(widget.minutes));
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _invalid = false;

  /// 이 칸에 들어온 뒤 사용자가 실제로 숫자를 쳤나. 안 쳤으면 이 칸의 글자는 "보여주기"일 뿐이다.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TimeInputField old) {
    super.didUpdateWidget(old);
    // 밖에서 값이 바뀌면(교시 선택, 시작을 옮겨 끝이 따라 옮겨짐, 길이 칩, 휠) 보이는 글자도 맞춘다.
    // 포커스 여부가 아니라 "사용자가 치는 중인가"로 판단한다: 시작을 다 치면 끝 칸으로 포커스가 먼저
    // 넘어온 뒤 끝 값이 바뀌므로, 포커스로 막으면 끝 칸에 옛 시각이 남는다(실기기 피드백 후 발견).
    if (old.minutes != widget.minutes && !_dirty) {
      _controller.text = formatMinutes(widget.minutes);
      if (_focus.hasFocus) _selectAll();
    }
  }

  void _selectAll() => _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      // 들어오면 전부 선택 → 바로 새 숫자를 치면 덮어써진다.
      _dirty = false;
      _selectAll();
    } else if (_dirty) {
      // 치다가 나가면 친 만큼으로 확정. 안 쳤으면 아무것도 바꾸지 않는다
      // (보이는 글자를 다시 저장하면 밖에서 바꾼 값을 옛 글자로 덮을 수 있다).
      _commit(_controller.text, moveOn: false);
    }
  }

  void _onTyped(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    _dirty = true;
    setState(() => _invalid = false);
    if (isTypedTimeComplete(digits)) _commit(digits, moveOn: true);
  }

  void _commit(String text, {required bool moveOn}) {
    _dirty = false;
    final m = parseTypedTime(text);
    if (m == null) {
      if (text.replaceAll(RegExp(r'\D'), '').isNotEmpty) setState(() => _invalid = true);
      _controller.text = formatMinutes(widget.minutes);
      return;
    }
    _controller.text = formatMinutes(m);
    widget.onChanged(m);
    if (moveOn) {
      final next = widget.nextFocus;
      next != null ? next.requestFocus() : _focus.unfocus();
    }
  }

  Future<void> _openWheel() async {
    _focus.unfocus();
    final m = await showTimeWheel(context, initial: widget.minutes, title: widget.label);
    if (m != null) {
      _controller.text = formatMinutes(m);
      widget.onChanged(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _invalid ? p.status.urgent : Colors.transparent, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _invalid ? '예: 1530, 930' : widget.label,
                  style: TextStyle(fontSize: AppText.caption, color: _invalid ? p.status.urgent : p.textMuted),
                ),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: widget.nextFocus != null ? TextInputAction.next : TextInputAction.done,
                  inputFormatters: [TypedTimeFormatter()],
                  onChanged: _onTyped,
                  onSubmitted: (t) => _commit(t, moveOn: true),
                  style: AppFonts.numeric(size: AppText.numSm, weight: FontWeight.w400),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '굴려서 고르기',
            onPressed: _openWheel,
            icon: Icon(Icons.schedule_rounded, color: p.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 휠로 시간 고르기(5분 단위, 24시간). 고르면 분, 취소하면 null.
Future<int?> showTimeWheel(BuildContext context, {required int initial, String? title}) {
  var picked = (initial ~/ 5) * 5; // 휠이 5분 단위라 시작값도 맞춰야 한다.
  return showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppGap.page, 0, AppGap.page, AppGap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w700),
              ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 5,
                initialDateTime: DateTime(2000, 1, 1, picked ~/ 60, picked % 60),
                onDateTimeChanged: (t) => picked = t.hour * 60 + t.minute,
              ),
            ),
            const SizedBox(height: AppGap.md),
            FilledButton(onPressed: () => Navigator.pop(ctx, picked), child: const Text('확인')),
          ],
        ),
      ),
    ),
  );
}

// ── 타이핑 규칙(순수 함수 — test/time_input_test.dart) ─────────────────────

/// 아이 일정에서 1~6시는 오후로 읽는다(새벽 일정은 없다).
int _assumeAfternoon(int h) => h >= 1 && h <= 6 ? h + 12 : h;

/// 숫자만 남긴 입력을 시각(분)으로. 안 되면 null.
/// - 1~2자리: 시만 ("9" → 9:00, "15" → 15:00, "3" → 15:00)
/// - 3자리: H:MM ("930" → 9:30, "330" → 15:30)
/// - 4자리: HH:MM ("1530" → 15:30, "0930" → 9:30)
int? parseTypedTime(String input) {
  final d = input.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty || d.length > 4) return null;
  final (hs, ms) = switch (d.length) {
    1 || 2 => (d, '0'),
    3 => (d.substring(0, 1), d.substring(1)),
    _ => (d.substring(0, 2), d.substring(2)),
  };
  final h = int.parse(hs);
  final m = int.parse(ms);
  if (h > 23 || m > 59) return null;
  // "0930"처럼 앞에 0을 붙여 친 건 그대로 오전으로 둔다.
  final hour = d.length == 4 && d.startsWith('0') ? h : _assumeAfternoon(h);
  return hour * 60 + m;
}

/// 다 쳤나? 다 쳤으면 다음 칸으로 넘어간다.
/// - 4자리면 끝.
/// - 3자리인데 앞 두 자리가 시가 될 수 없으면(예: "930"의 93) 끝. "153"은 15:3_일 수 있어 기다린다.
bool isTypedTimeComplete(String digits) {
  if (digits.length >= 4) return true;
  if (digits.length == 3) return int.parse(digits.substring(0, 2)) > 23 && parseTypedTime(digits) != null;
  return false;
}

/// 치는 동안 콜론을 알아서 넣어 보여준다. 보이는 모양 = 그 자리에서 멈췄을 때 저장될 값
/// ([parseTypedTime]과 같은 규칙). "1" → "1", "15" → "15", "130" → "1:30", "1530" → "15:30".
/// ("1530"을 치는 중간에 잠깐 "1:53"이 보이지만, 거기서 멈추면 실제로 1:53이 되므로 정직한 표시다.)
class TypedTimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(d.length - 4);
    final text = switch (d.length) {
      0 || 1 || 2 => d,
      3 => '${d.substring(0, 1)}:${d.substring(1)}',
      _ => '${d.substring(0, 2)}:${d.substring(2)}',
    };
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
