part of 'floating_overlay.dart';

class _FloatingOverlayCursor {
  _FloatingOverlayCursor({
    required _FloatingOverlayScale scale,
    required _FloatingOverlayOffset offset,
  })  : _scale = scale,
        _offset = offset;

  final _FloatingOverlayScale _scale;
  final _FloatingOverlayOffset _offset;
  Rect _startRect = Rect.zero;

  /// Returns the primary axis delta for the given drag [side].
  ///
  /// For diagonal sides the axis with the larger absolute movement wins.
  Offset mainDirectionDelta(Offset newOffset, _Side side) {
    final delta = newOffset - _offset._startOffset;
    if (side.diagonal) {
      if (delta.dx.abs() > delta.dy.abs()) {
        return Offset(delta.dx, 0) * 2;
      } else {
        return Offset(0, delta.dy) * 2;
      }
    } else if (side.horizontal) {
      return Offset(delta.dx, 0) * 2;
    } else {
      return Offset(0, delta.dy) * 2;
    }
  }

  void onStart(Offset startOffset, FloatingOverlayData data) {
    _scale.onStart();
    _offset.onStart(startOffset);
    _startRect = data.childRect;
  }

  /// Updates scale and then adjusts the offset so the widget appears to
  /// resize around its centre point.
  void onUpdate(Offset delta, FloatingOverlayData data) {
    final size = data.childSize;
    final previousScale = _scale.state;
    _scale.onUpdateDelta(delta, data);
    final newScale = _scale.state;
    if (newScale != previousScale) {
      final newSize = size * newScale;
      final newRect = Alignment.center.inscribe(newSize, _startRect);
      _offset.onUpdateDelta(
        newRect.topLeft - _startRect.topLeft,
        data.childRect.size,
      );
    }
  }

  void onEnd() {
    _offset.onEnd();
  }
}
