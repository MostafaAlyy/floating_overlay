part of 'floating_overlay.dart';

class FloatingOverlayData extends Equatable {
  const FloatingOverlayData({
    required this.childSize,
    required this.scale,
    required this.position,
  });

  final Size childSize;
  final double scale;
  final Offset position;

  Rect get childRect => position & (childSize * scale);

  @override
  String toString() {
    return 'FloatingOverlayData('
        'childSize: $childSize, '
        'scale: $scale, '
        'position: $position'
        ')';
  }

  FloatingOverlayData copyWith({
    Size? childSize,
    double? scale,
    Offset? position,
  }) {
    return FloatingOverlayData(
      // Only update childSize when the incoming value is non-null AND
      // non-zero. The original code had the null check in the wrong order
      // (`childSize != Size.zero && childSize != null`), which would throw a
      // Null check operator error if childSize was null.
      childSize: (childSize != null && childSize != Size.zero)
          ? childSize
          : this.childSize,
      position: position ?? this.position,
      scale: scale ?? this.scale,
    );
  }

  @override
  List<Object?> get props => [childSize, scale, position];
}
