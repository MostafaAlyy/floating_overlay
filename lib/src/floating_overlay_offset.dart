part of 'floating_overlay.dart';

/// Physics-based offset controller with smooth spring animations and
/// snap-to-corner behaviour on drag release.
class _FloatingOverlayOffset extends Cubit<Offset> {
  _FloatingOverlayOffset({
    Offset? start,
    EdgeInsets? padding,
    bool constrained = false,
  })  : _constrained = constrained,
        _padding = padding ?? EdgeInsets.zero,
        _previousOffset = start ?? Offset.zero,
        _startOffset = start ?? Offset.zero,
        super(start ?? Offset.zero);

  final EdgeInsets _padding;
  final bool _constrained;
  Offset _previousOffset;
  Offset _startOffset;
  Rect? floatingLimits;
  FloatingOverlayData? _data;

  // Physics system state
  Offset _velocity = Offset.zero;
  Offset _targetPosition = Offset.zero;
  bool _isProgrammaticThrow = false;
  bool _snapToPositions = true;
  DateTime _lastUpdateTime = DateTime.now();
  Ticker? _ticker;

  // Snap positions (corners by default, configurable)
  List<Offset> _snapPositions = [];

  // ─── Physics constants ────────────────────────────────────────────────────
  static const double _naturalFrequency = 12.0; // Spring frequency
  static const double _dampingRatio = 0.9;      // Critical damping (no bounce)
  static const double _friction = 0.012;        // Air-resistance coefficient
  static const double _minVelocity = 0.8;       // Stop threshold (px/s)
  static const double _maxVelocity = 2500.0;    // Velocity cap (px/s)

  // ─── Initialisation ───────────────────────────────────────────────────────

  /// Recalculate floating limits based on [LayoutBuilder] constraints.
  void init(Rect limits, Size screenSize) {
    if (_constrained) {
      floatingLimits = Rect.fromLTRB(
        limits.left + _padding.left,
        limits.top + _padding.top,
        limits.right - _padding.right,
        limits.bottom - _padding.bottom,
      );
    } else {
      floatingLimits = Rect.fromLTRB(
        _padding.left,
        _padding.top,
        screenSize.width - _padding.right,
        screenSize.height - _padding.bottom,
      );
    }

    // Snap positions are lazily updated once child size is known.
    // Pass Size.zero here — they will be refreshed on the first gesture.
    _updateSnapPositions(Size.zero);
  }

  /// Rebuild snap positions (the four corners) based on the measured child size.
  void _updateSnapPositions(Size childSize) {
    if (floatingLimits == null) return;

    final limits = floatingLimits!;

    if (childSize == Size.zero) {
      // Child size not yet known — keep positions empty until first gesture.
      _snapPositions = [];
      return;
    }

    _snapPositions = [
      // Top-left corner
      Offset(limits.left, limits.top),
      // Top-right corner
      Offset(limits.right - childSize.width, limits.top),
      // Bottom-left corner
      Offset(limits.left, limits.bottom - childSize.height),
      // Bottom-right corner
      Offset(limits.right - childSize.width, limits.bottom - childSize.height),
    ];
  }

  /// Attach a [Ticker] for physics animations.
  ///
  /// Safe to call multiple times — disposes the previous ticker first to avoid
  /// leaking resources when the [FloatingOverlay] re-initialises.
  void initPhysics(TickerProvider vsync) {
    if (_ticker != null) {
      _ticker!.stop();
      _ticker!.dispose();
    }
    _ticker = vsync.createTicker(_physicsUpdate);
  }

  // ─── Position API ─────────────────────────────────────────────────────────

  /// Immediately move the widget to [newOffset], clamped to the floating limits.
  void setGlobal(Offset newOffset, FloatingOverlayData data) {
    final validOffset = _validValue(newOffset, data.childRect.size);
    emit(validOffset);
    _previousOffset = state;
  }

  /// Programmatically animate the widget to [targetPosition] via the
  /// spring-damper physics system.
  void throwToPosition(Offset targetPosition, {double? velocity}) {
    if (floatingLimits == null || _data == null) return;

    _targetPosition = _validValue(targetPosition, _data!.childRect.size);
    _isProgrammaticThrow = true;

    final distance = (_targetPosition - state).distance;
    final optimalVelocity = velocity ?? math.min(distance * 2.5, _maxVelocity);
    final direction =
        distance > 0 ? (_targetPosition - state) / distance : Offset.zero;

    _velocity = direction * optimalVelocity;
    _ticker?.start();
  }

  // ─── Gesture callbacks ────────────────────────────────────────────────────

  /// Enhanced drag start — resets velocity so the previous throw does not
  /// interfere with the new gesture.
  void onStartEnhanced(Offset newOffset) {
    _startOffset = newOffset;
    _velocity = Offset.zero;
    _lastUpdateTime = DateTime.now();
    _isProgrammaticThrow = false;
    _ticker?.stop();
  }

  void onStart(Offset newOffset) => _startOffset = newOffset;

  void onEnd() => _previousOffset = state;

  /// Standard update used during pinch/zoom scaling gestures.
  void onUpdate(
    Offset newOffset,
    FloatingOverlayData data,
    double previousScale,
  ) {
    final scaleOffset = _scaleOffset(data, previousScale);
    final delta = newOffset - _startOffset - scaleOffset;
    onUpdateDelta(delta, data.childRect.size);
  }

  /// Enhanced drag update with velocity tracking for the physics throw.
  void onUpdateEnhanced(Offset newOffset, FloatingOverlayData data) {
    _data = data;
    _updateSnapPositions(data.childRect.size);

    final now = DateTime.now();
    final deltaTime = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;

    if (deltaTime > 0 && deltaTime < 0.1) {
      // Ignore suspiciously large time gaps (e.g. after a frame drop).
      final positionDelta = newOffset - _startOffset;

      // Exponential moving average — smooth but responsive.
      _velocity = _velocity * 0.7 + (positionDelta / deltaTime) * 0.3;
      _velocity = _velocity.clampMagnitude(0, _maxVelocity);
    }

    final delta = newOffset - _startOffset;
    onUpdateDelta(delta, data.childRect.size);
    _lastUpdateTime = now;
  }

  /// Drag release — snap to the nearest corner using the spring system.
  void onEndEnhanced(FloatingOverlayData data) {
    _data = data;
    _previousOffset = state;

    if (_snapToPositions && _snapPositions.isNotEmpty) {
      final nearestPosition = _findNearestSnapPosition() ?? _snapPositions.first;
      _animateToPosition(nearestPosition);
    }
  }

  // ─── Snap helpers ─────────────────────────────────────────────────────────

  Offset? _findNearestSnapPosition() {
    if (_snapPositions.isEmpty) return null;

    double minDistance = double.infinity;
    Offset? nearest;

    for (final snapPos in _snapPositions) {
      final distance = (state - snapPos).distance;
      if (distance < minDistance) {
        minDistance = distance;
        nearest = snapPos;
      }
    }

    return nearest;
  }

  void _animateToPosition(Offset targetPosition) {
    _targetPosition = targetPosition;
    _isProgrammaticThrow = true;

    final distance = (_targetPosition - state).distance;
    final optimalVelocity = math.min(distance * 3.0, _maxVelocity);
    final direction =
        distance > 0 ? (_targetPosition - state) / distance : Offset.zero;

    _velocity = direction * optimalVelocity;
    _ticker?.start();
  }

  // ─── Physics update loop ──────────────────────────────────────────────────

  void _physicsUpdate(Duration elapsed) {
    if (_data == null) return;

    final now = DateTime.now();
    // Cap delta-time at ~30 fps to avoid huge jumps after frame drops.
    final dt = math.min(
      now.difference(_lastUpdateTime).inMilliseconds / 1000.0,
      1 / 30,
    );
    _lastUpdateTime = now;

    if (dt <= 0) return;

    final childSize = _data!.childRect.size;
    var newPosition = state;

    if (_isProgrammaticThrow) {
      newPosition = _updateSpringDamper(dt, childSize);
    }

    emit(_validValue(newPosition, childSize));

    // Stop the ticker once both velocity and positional error are negligible.
    final atTarget =
        !_isProgrammaticThrow || (state - _targetPosition).distance < 1.0;
    if (_velocity.distance < _minVelocity && atTarget) {
      _stopAnimation();
    }
  }

  /// Critically-damped spring — smooth arrival at target with no overshoot.
  Offset _updateSpringDamper(double dt, Size childSize) {
    final displacement = _targetPosition - state;
    final springForce = displacement * _naturalFrequency * _naturalFrequency;
    final dampingForce = _velocity * (2 * _dampingRatio * _naturalFrequency);

    final acceleration = springForce - dampingForce;
    _velocity += acceleration * dt;

    // Apply air resistance.
    _velocity *= math.pow(1 - _friction, dt).toDouble();

    final newPosition = state + _velocity * dt;

    // Clamp to boundaries (no bouncing — boundaries are hard walls).
    return _validValue(newPosition, childSize);
  }

  // ─── Scale-gesture helpers ────────────────────────────────────────────────

  Offset _scaleOffset(FloatingOverlayData data, double previousScale) {
    final previousSize = data.copyWith(scale: previousScale).childRect.size;
    final currentSize = data.childRect.size;
    final difference = Size(
      currentSize.width - previousSize.width,
      currentSize.height - previousSize.height,
    );
    return Offset(difference.width / 2, difference.height / 2);
  }

  void onUpdateDelta(Offset delta, Size size) {
    final offset = _previousOffset + delta;
    emit(_validValue(offset, size));
  }

  // ─── Boundary clamping ────────────────────────────────────────────────────

  Offset _validValue(Offset offset, Size childSize) {
    if (floatingLimits == null) return offset;

    final limits = floatingLimits!;
    final rect = offset & childSize;

    double dx = offset.dx;
    double dy = offset.dy;

    if (rect.right > limits.right) dx = limits.right - rect.width;
    if (dx < limits.left) dx = limits.left;
    if (rect.left < limits.left) dx = limits.left;

    if (rect.bottom > limits.bottom) dy = limits.bottom - rect.height;
    if (dy < limits.top) dy = limits.top;
    if (rect.top < limits.top) dy = limits.top;

    return Offset(dx, dy);
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  void _stopAnimation() {
    _isProgrammaticThrow = false;
    _velocity = Offset.zero;
    _ticker?.stop();
  }

  void setSnapToPositions(bool enabled) => _snapToPositions = enabled;

  void setCustomSnapPositions(List<Offset> positions) {
    _snapPositions = List.from(positions);
  }

  List<Offset> get snapPositions => List.from(_snapPositions);

  void disposePhysics() {
    _ticker?.dispose();
    _ticker = null;
  }
}

/// Extension for clamping an [Offset]'s magnitude to a [min]/[max] range.
extension OffsetExtensions on Offset {
  Offset clampMagnitude(double min, double max) {
    final magnitude = distance;
    if (magnitude < min) return this;
    if (magnitude > max) return this / magnitude * max;
    return this;
  }
}
