import 'package:family_timetable/core/design/app_theme.dart';
import 'package:family_timetable/core/design/components/time_input.dart';
import 'package:family_timetable/core/design/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실기기 버그 재현: 끝 칸에 커서를 둔 채 길이 칩(1시간)을 누르면 반영이 안 됐다.
/// 키보드가 포커스 때 글자를 다시 보내면 칸이 "치는 중"이 되어 밖에서 정한 값을 무시했기 때문.
void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  Future<void> pumpEditor(WidgetTester tester) async {
    const start = 15 * 60;
    var end = 16 * 60;
    var revision = 0;
    final endFocus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TimeInputField(
                  key: const Key('end'),
                  label: '끝',
                  minutes: end,
                  focusNode: endFocus,
                  externalRevision: revision,
                  onChanged: (m) => setState(() => end = m),
                ),
                for (final len in const [50, 60])
                  TextButton(
                    key: Key('chip$len'),
                    onPressed: () => setState(() {
                      end = start + len;
                      revision++;
                    }),
                    child: Text('$len'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String endText(WidgetTester tester) => tester
      .widget<EditableText>(find.descendant(of: find.byKey(const Key('end')), matching: find.byType(EditableText)))
      .controller
      .text;

  testWidgets('끝 칸에 커서를 둔 채(키보드가 글자를 다시 보내도) 길이 칩이 먹는다', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // 삼성 키보드처럼 포커스 때 같은 글자를 다시 보내는 상황
    await tester.enterText(find.byType(TextField), '16:0');
    await tester.pump();

    await tester.tap(find.byKey(const Key('chip50')));
    await tester.pump();
    expect(endText(tester), '15:50');
  });

  testWidgets('값이 같은 칩을 다시 눌러도 치다 만 숫자를 버리고 칩 값을 보여준다', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const Key('chip60'))); // 이미 16:00(1시간)
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();

    await tester.tap(find.byKey(const Key('chip60')));
    await tester.pump();
    expect(endText(tester), '16:00');
  });
}
