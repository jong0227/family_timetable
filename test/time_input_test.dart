import 'package:family_timetable/core/design/components/time_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시간 타이핑 규칙. 실사용 피드백("숫자 치면 분으로 자연스럽게 넘어가야 한다")에서 나온 규칙이라
/// 바꾸면 손에 익은 입력 방식이 달라진다. 바꿀 땐 이 테스트부터.
void main() {
  int hm(int h, int m) => h * 60 + m;

  group('parseTypedTime', () {
    test('네 자리 = HH:MM', () {
      expect(parseTypedTime('1530'), hm(15, 30));
      expect(parseTypedTime('0930'), hm(9, 30), reason: '0을 붙이면 오전 그대로');
      expect(parseTypedTime('15:30'), hm(15, 30), reason: '콜론을 쳐도 된다');
    });

    test('세 자리 = H:MM', () {
      expect(parseTypedTime('930'), hm(9, 30));
      expect(parseTypedTime('130'), hm(13, 30), reason: '1시 반은 오후');
    });

    test('한두 자리 = 정시', () {
      expect(parseTypedTime('9'), hm(9, 0));
      expect(parseTypedTime('15'), hm(15, 0));
    });

    test('1~6시는 오후로 읽는다(아이 일정에 새벽은 없다)', () {
      expect(parseTypedTime('3'), hm(15, 0));
      expect(parseTypedTime('330'), hm(15, 30));
      expect(parseTypedTime('7'), hm(7, 0), reason: '7시부터는 그대로');
      expect(parseTypedTime('12'), hm(12, 0));
    });

    test('말이 안 되는 시각은 null', () {
      expect(parseTypedTime(''), isNull);
      expect(parseTypedTime('2460'), isNull);
      expect(parseTypedTime('975'), isNull);
      expect(parseTypedTime('12345'), isNull);
    });
  });

  group('다 쳤으면 다음 칸으로', () {
    test('네 자리면 끝', () => expect(isTypedTimeComplete('1530'), isTrue));
    test('930처럼 앞 두 자리가 시가 될 수 없으면 세 자리에서 끝', () => expect(isTypedTimeComplete('930'), isTrue));
    test('153은 15:3_일 수 있어 기다린다', () => expect(isTypedTimeComplete('153'), isFalse));
    test('두 자리 이하는 기다린다', () => expect(isTypedTimeComplete('15'), isFalse));
  });

  test('치는 동안 콜론 자동 표시', () {
    String fmt(String s) =>
        TypedTimeFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s)).text;
    expect(fmt('15'), '15');
    expect(fmt('130'), '1:30');
    expect(fmt('1530'), '15:30');
    expect(fmt('15:300'), '53:00', reason: '네 자리를 넘겨 치면 마지막 네 자리만 남는다(이어서 다시 치기)');
  });
}
