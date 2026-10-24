// 앱 아이콘을 코드로 그려 안드로이드 런처 아이콘 PNG를 만든다(외부 그림 도구·패키지 없이).
//
//   flutter test tool/icon/icon_gen_test.dart --plain-name 후보     → tool/icon/candidates.png (후보 비교)
//   flutter test tool/icon/icon_gen_test.dart --plain-name 런처     → res/mipmap-* (지금 고른 [chosen])
//
// 좌표는 적응형 아이콘의 108×108 공간. 런처는 가운데 72×72만 보여주고(모양 마스크), 안전 영역은 가운데 지름 66 원.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 후보 하나: 바탕(108 전체를 채운다)과 앞 그림. [mono]는 테마 아이콘용 모양만.
class Design {
  final String name;
  final void Function(Canvas c) background;
  final void Function(Canvas c, {bool mono}) foreground;
  const Design(this.name, this.background, this.foreground);
}

const _full = Rect.fromLTWH(0, 0, 108, 108);

void _gradient(Canvas c, Color a, Color b) =>
    c.drawRect(_full, Paint()..shader = ui.Gradient.linear(const Offset(18, 18), const Offset(90, 90), [a, b]));

RRect _rr(double l, double t, double r, double b, double radius) =>
    RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

// A: 파란 바탕 + 흰 카드 안 "하루 일정" 세 줄(점 + 막대). 오늘 화면의 타임라인을 닮은 꼴.
final agenda = Design('agenda', (c) => _gradient(c, const Color(0xFF5B9BF0), const Color(0xFF2F62D6)), (
  c, {
  mono = false,
}) {
  c.saveLayer(_full, Paint());
  c.drawRRect(_rr(32, 34, 76, 74, 10), Paint()..color = Colors.white);
  final rows = [(44.0, 26.0, 1.0), (54.0, 18.0, 0.55), (64.0, 22.0, 0.3)];
  for (final (y, len, a) in rows) {
    final paint = mono
        ? (Paint()..blendMode = BlendMode.clear)
        : (Paint()..color = const Color(0xFF2F62D6).withValues(alpha: a));
    c.drawCircle(Offset(41, y), 2.6, paint);
    c.drawRRect(_rr(47, y - 2.6, 47 + len, y + 2.6, 2.6), paint);
  }
  c.restore();
});

// B: 파란 바탕 + 흰 선 아이콘(달력 테두리 + 그 안 시계). 선 굵기 하나로 깔끔하게.
final calendarClock = Design('calendar_clock', (c) => _gradient(c, const Color(0xFF5B9BF0), const Color(0xFF2F62D6)), (
  c, {
  mono = false,
}) {
  final stroke = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.2
    ..strokeCap = StrokeCap.round;
  c.drawRRect(_rr(33, 37, 75, 75, 9), stroke);
  c.drawLine(const Offset(44, 32), const Offset(44, 40), stroke);
  c.drawLine(const Offset(64, 32), const Offset(64, 40), stroke);
  const o = Offset(54, 57.5);
  c.drawCircle(o, 10.5, stroke..strokeWidth = 3.4);
  c.drawLine(o, o + const Offset(0, -6), stroke);
  c.drawLine(o, o + const Offset(4.5, 2.5), stroke);
});

// C: 흰 바탕 + 파란 알약 세 개가 시간 흐름처럼 엇갈려 놓인 꼴(시간표 칸). 지금 쓰는 아이콘(2026-10-24 v0.1.14).
// 예전 검은 바탕 + 달력 카드 + 색 칸 여섯 개는 "난잡하다"는 피드백으로 바꿨다.
final steps = Design('steps', (c) => c.drawRect(_full, Paint()..color = const Color(0xFFF4F7FD)), (c, {mono = false}) {
  Paint p(Color col) => Paint()..color = mono ? Colors.white : col;
  c.drawRRect(_rr(32, 34, 64, 45, 5.5), p(const Color(0xFF2F62D6)));
  c.drawRRect(_rr(42, 48.5, 76, 59.5, 5.5), p(const Color(0xFF5B9BF0)));
  c.drawRRect(_rr(32, 63, 58, 74, 5.5), p(const Color(0xFFA9C8F7)));
});

// D: 파란 바탕 + 흰 둥근 카드에 파란 시계 바늘 하나. 달력·시계를 한 덩어리로.
final cardClock = Design('card_clock', (c) => _gradient(c, const Color(0xFF3A74E8), const Color(0xFF1F45B5)), (
  c, {
  mono = false,
}) {
  c.saveLayer(_full, Paint());
  c.drawRRect(_rr(33, 33, 75, 75, 12), Paint()..color = Colors.white);
  final hand = Paint()
    ..color = const Color(0xFF2F62D6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (mono) hand.blendMode = BlendMode.clear;
  final path = Path()
    ..moveTo(54, 43)
    ..lineTo(54, 55)
    ..lineTo(62, 60);
  c.drawPath(path, hand);
  c.restore();
});

final designs = [agenda, calendarClock, steps, cardClock];

/// 지금 쓰는 아이콘.
final chosen = steps;

Future<void> _save(String path, int size, void Function(Canvas c, double s) paint) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  paint(c, size.toDouble());
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// 홈 화면에 보이는 모습(가운데 72를 [clip] 모양으로 자른 것). 예전 방식 아이콘과 미리보기에 쓴다.
void _launcher(Canvas c, double s, Design d, {bool circle = false}) {
  final box = Rect.fromLTWH(0, 0, s, s);
  c.save();
  c.clipPath(
    circle ? (Path()..addOval(box)) : (Path()..addRRect(RRect.fromRectAndRadius(box, Radius.circular(s * 0.23)))),
  );
  c.scale(s / 72);
  c.translate(-18, -18);
  d.background(c);
  d.foreground(c);
  c.restore();
}

void _layer(Canvas c, double s, void Function(Canvas c) paint) {
  c.save();
  c.scale(s / 108);
  paint(c);
  c.restore();
}

void main() {
  testWidgets('후보 미리보기', (tester) async {
    await tester.runAsync(() async {
      // 후보마다 세로로: 둥근 사각형(크게) · 원 마스크 · 실제 홈 화면 크기(48)
      const cell = 240.0;
      await _save('tool/icon/candidates.png', (cell * designs.length).toInt(), (c, s) {
        c.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = const Color(0xFF2A2A2E));
        for (var i = 0; i < designs.length; i++) {
          void at(double x, double y, void Function() draw) {
            c.save();
            c.translate(i * cell + x, y);
            draw();
            c.restore();
          }

          at(20, 20, () => _launcher(c, 200, designs[i]));
          at(20, 240, () => _launcher(c, 200, designs[i], circle: true));
          at(96, 470, () => _launcher(c, 48, designs[i]));
        }
      });
    });
  });

  testWidgets('런처 아이콘 PNG 만들기', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      for (final MapEntry(key: d, value: px) in legacy.entries) {
        await _save('$res/mipmap-$d/ic_launcher.png', px, (c, s) => _launcher(c, s, chosen));
        final layer = px * 108 ~/ 48;
        await _save('$res/mipmap-$d/ic_launcher_background.png', layer, (c, s) => _layer(c, s, chosen.background));
        await _save('$res/mipmap-$d/ic_launcher_foreground.png', layer, (c, s) => _layer(c, s, chosen.foreground));
        await _save(
          '$res/mipmap-$d/ic_launcher_monochrome.png',
          layer,
          (c, s) => _layer(c, s, (c) => chosen.foreground(c, mono: true)),
        );
      }
      await _save('tool/icon/icon_preview.png', 512, (c, s) => _launcher(c, s, chosen));
    });
  });
}
