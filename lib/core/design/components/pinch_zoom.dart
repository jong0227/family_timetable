import 'package:flutter/widgets.dart';

/// 두 손가락으로 벌리면 [onZoom]에 더 큰 배율, 오므리면 더 작은 배율을 알려준다.
///
/// 손가락 하나는 건드리지 않는다 — 제스처 경쟁(arena)에 끼지 않는 [Listener]로 손가락 수만 세서,
/// 한 손가락 드래그는 바깥 스크롤이 그대로 받는다. Flutter의 ScaleGestureRecognizer를 쓰면
/// 한 손가락 드래그까지 가로채 화면 스크롤이 막힌다.
class PinchZoom extends StatefulWidget {
  final double zoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onZoomEnd;
  final Widget child;

  const PinchZoom({super.key, required this.zoom, required this.onZoom, required this.onZoomEnd, required this.child});

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  final _pointers = <int, Offset>{};
  double? _startDistance;
  double _startZoom = 1;

  double _distance() {
    final ps = _pointers.values.toList();
    return (ps[0] - ps[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _startDistance = _distance();
      _startZoom = widget.zoom;
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final start = _startDistance;
    if (_pointers.length == 2 && start != null && start > 20) {
      widget.onZoom(_startZoom * _distance() / start);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_startDistance != null && _pointers.length < 2) {
      _startDistance = null;
      widget.onZoomEnd();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    // translucent: 칸 사이 빈자리에 손가락을 대도 잡힌다(기본값이면 자식이 그린 곳만 받는다 — 테스트로 발견).
    behavior: HitTestBehavior.translucent,
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
