import 'package:family_timetable/core/design/components/pinch_zoom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 두 손가락: 벌리면 확대·오므리면 축소. 한 손가락 드래그는 바깥 스크롤이 그대로 받아야 한다.
void main() {
  Future<({List<double> zooms, ScrollController scroll, int ends})> pump(WidgetTester tester) async {
    final zooms = <double>[];
    var ends = 0;
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            PinchZoom(
              zoom: 1,
              onZoom: zooms.add,
              onZoomEnd: () => ends++,
              child: Container(key: const Key('grid'), height: 2000, color: Colors.white),
            ),
          ],
        ),
      ),
    );
    return (zooms: zooms, scroll: scroll, ends: ends);
  }

  testWidgets('두 손가락을 벌리면 배율이 커진다', (tester) async {
    final zooms = <double>[];
    var ended = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PinchZoom(zoom: 1, onZoom: zooms.add, onZoomEnd: () => ended++, child: const SizedBox.expand()),
      ),
    );
    final a = await tester.startGesture(const Offset(200, 300), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 400), pointer: 2);
    await a.moveTo(const Offset(200, 250));
    await b.moveTo(const Offset(200, 450));
    await a.up();
    await b.up();
    expect(zooms.last, closeTo(2.0, 0.01), reason: '손가락 간격 100 → 200');
    expect(ended, 1);
  });

  testWidgets('한 손가락 드래그는 확대가 아니라 스크롤', (tester) async {
    final r = await pump(tester);
    await tester.dragFrom(const Offset(200, 400), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(r.zooms, isEmpty);
    expect(r.scroll.offset, greaterThan(0));
  });
}
