// 앱 아이콘을 코드로 그려 안드로이드 런처 아이콘 PNG를 만든다(외부 그림 도구·패키지 없이).
//
//   flutter test tool/icon/icon_gen_test.dart
//
// 모양: 앱 하단 내비와 같은 검은 바탕 위에 흰 시간표 카드. 머리띠는 첫째 자녀색(장미),
// 칸은 종류색(학원 하늘·학교 노랑·활동 민트·방과후 보라) — 앱 안 색 체계(DESIGN_SYSTEM 2장)를 그대로 쓴다.
// 좌표는 적응형 아이콘의 108×108 공간. 안전 영역(가운데 지름 66 원) 안에 내용을 둔다.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _background = Color(0xFF151517); // palette.dock
const _card = Color(0xFFFFFFFF);
const _header = Color(0xFFE0698F); // 자녀색 0(장미)
const _ring = Color(0xFF151517);
const _empty = Color(0xFFEFEFF1); // 종류색 기타(빈 칸)

/// (열, 시작 줄, 줄 수, 색). 3열 × 3줄 시간표.
const _blocks = [
  (0, 0, 2, Color(0xFF5B9BE0)),
  (0, 2, 1, _empty),
  (1, 0, 1, Color(0xFFD9B23A)),
  (1, 1, 2, Color(0xFF3FB383)),
  (2, 0, 1, _empty),
  (2, 1, 2, Color(0xFF9A7BD8)),
];

/// 108 공간의 카드와 칸을 그린다. [mono]면 모양만(테마 아이콘용: 카드는 채우고 칸은 뚫는다).
void _paintArtwork(Canvas c, {bool mono = false}) {
  final white = Paint()..color = mono ? Colors.white : _card;
  const card = Rect.fromLTRB(31, 34, 77, 78);
  c.saveLayer(const Rect.fromLTWH(0, 0, 108, 108), Paint());
  c.drawRRect(RRect.fromRectAndRadius(card, const Radius.circular(8)), white);
  if (!mono) {
    // 머리띠(위쪽 모서리만 둥글게)
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTRB(31, 34, 77, 45),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      Paint()..color = _header,
    );
  }
  // 칸
  const left = 35.0, top = 49.0, gap = 2.5, colW = (77 - 4 - left - 2 * gap) / 3, rowH = (78 - 4 - top - 2 * gap) / 3;
  for (final (col, row, span, color) in _blocks) {
    final r = Rect.fromLTWH(left + col * (colW + gap), top + row * (rowH + gap), colW, span * rowH + (span - 1) * gap);
    final paint = mono ? (Paint()..blendMode = BlendMode.clear) : (Paint()..color = color);
    if (mono && color == _empty) continue; // 빈 칸은 뚫지 않는다(모양이 덜 복잡하게)
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2.2)), paint);
  }
  c.restore();
  // 고리 두 개(카드 위로 살짝 나온 달력 고리)
  final ring = Paint()..color = mono ? Colors.white : _ring;
  final ringFill = Paint()..color = mono ? Colors.white : _card;
  for (final x in [44.0, 64.0]) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, 34), width: 5, height: 11),
      const Radius.circular(2.5),
    );
    if (!mono) c.drawRRect(r.inflate(1.6), ring);
    c.drawRRect(r, ringFill);
  }
}

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

/// 예전 방식(안드로이드 7 이하·미리보기용) 아이콘: 둥근 검은 사각형 + 그림. 108 공간의 18~90을 꽉 채운다.
void _legacy(Canvas c, double s) {
  final m = s * 0.04;
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTRB(m, m, s - m, s - m), Radius.circular(s * 0.22)),
    Paint()..color = _background,
  );
  c.save();
  c.scale(s / 72);
  c.translate(-18, -18);
  _paintArtwork(c);
  c.restore();
}

void _foreground(Canvas c, double s, {bool mono = false}) {
  c.save();
  c.scale(s / 108);
  _paintArtwork(c, mono: mono);
  c.restore();
}

void main() {
  testWidgets('런처 아이콘 PNG 만들기', (tester) async {
    await tester.runAsync(() async {
      const res = 'android/app/src/main/res';
      const legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      for (final MapEntry(key: d, value: px) in legacy.entries) {
        await _save('$res/mipmap-$d/ic_launcher.png', px, _legacy);
        final fg = px * 108 ~/ 48;
        await _save('$res/mipmap-$d/ic_launcher_foreground.png', fg, _foreground);
        await _save('$res/mipmap-$d/ic_launcher_monochrome.png', fg, (c, s) => _foreground(c, s, mono: true));
      }
      await _save('tool/icon/icon_preview.png', 512, _legacy);
    });
  });
}
