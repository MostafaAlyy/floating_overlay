part of 'floating_overlay.dart';

/// Professional physics-based offset controller with smooth animations
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
  bool _snapToPositions = true; // Enable snap-to-position behavior
  DateTime _lastUpdateTime = DateTime.now();
  Ticker? _ticker;

  // Snap positions (corners and center edges)
  List<Offset> _snapPositions = [];

  // Professional physics constants - tuned for smooth, natural feel
  static const double _naturalFrequency = 12.0; // Spring system frequency
  static const double _dampingRatio = 0.9; // Critical damping for smoothness
  static const double _friction = 0.012; // Air resistance coefficient
  static const double _minVelocity = 0.8; // Threshold to stop animation
  static const double _maxVelocity =
      2500.0; // Maximum velocity cap  /// Initialize the floating limits based on constraints
  void init(Rect limits, Size screenSize) {
    if (_constrained) {
      floatingLimits = Rect.fromLTRB(
        limits.left + _padding.left,
        limits.top + _padding.top,
        limits.right - _padding.right,
        limits.bottom - _padding.bottom,
      );
    } else {
      final rightPadding = screenSize.width - _padding.right;
      final bottomPadding = screenSize.height - _padding.bottom;
      floatingLimits = Rect.fromLTRB(
        _padding.left,
        _padding.top,
        rightPadding,
        bottomPadding,
      );
    }

    // Initialize snap positions (4 corners)
    _updateSnapPositions(Size(100, 100)); // Default size, will be updated
  }

  /// Update snap positions based on current child size
  void _updateSnapPositions(Size childSize) {
    if (floatingLimits == null) return;

    final limits = floatingLimits!;
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

  /// Initialize physics system with professional-grade ticker
  void initPhysics(TickerProvider vsync) {
    _ticker = vsync.createTicker(_physicsUpdate);
  }

  /// Set global position with smooth interpolation
  void setGlobal(Offset newOffset, FloatingOverlayData data) {
    final validOffset = _validValue(newOffset, data.childRect.size);
    emit(validOffset);
    _previousOffset = state;
  }

  /// Professional throw animation to target position
  void throwToPosition(Offset targetPosition, {double? velocity}) {
    if (floatingLimits == null || _data == null) return;

    _targetPosition = _validValue(targetPosition, _data!.childRect.size);
    _isProgrammaticThrow = true;

    // Calculate optimal velocity for smooth arrival
    final distance = (_targetPosition - state).distance;
    final optimalVelocity = velocity ?? math.min(distance * 2.5, _maxVelocity);
    final direction =
        distance > 0 ? (_targetPosition - state) / distance : Offset.zero;

    _velocity = direction * optimalVelocity;
    _ticker?.start();
  }

  /// Enhanced gesture start with velocity reset
  void onStartEnhanced(Offset newOffset) {
    _startOffset = newOffset;
    _velocity = Offset.zero;
    _lastUpdateTime = DateTime.now();
    _isProgrammaticThrow = false;
    _ticker?.stop();
  }

  void onStart(Offset newOffset) => _startOffset = newOffset;
  void onEnd() => _previousOffset = state;

  /// Standard update for scaling gestures
  void onUpdate(
    Offset newOffset,
    FloatingOverlayData data,
    double previousScale,
  ) {
    final scaleOffset = _scaleOffset(data, previousScale);
    final delta = newOffset - _startOffset - scaleOffset;
    onUpdateDelta(delta, data.childRect.size);
  }

  /// Enhanced smooth update with professional velocity tracking
  void onUpdateEnhanced(Offset newOffset, FloatingOverlayData data) {
    _data = data;
    _updateSnapPositions(data.childRect.size);

    final now = DateTime.now();
    final deltaTime = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;

    if (deltaTime > 0 && deltaTime < 0.1) {
      // Ignore large time gaps
      final positionDelta = newOffset - _startOffset;

      // Professional velocity calculation with smoothing
      _velocity = _velocity * 0.7 + (positionDelta / deltaTime) * 0.3;
      _velocity = _velocity.clampMagnitude(0, _maxVelocity);
    }

    final delta = newOffset - _startOffset;
    onUpdateDelta(delta, data.childRect.size);
    _lastUpdateTime = now;
  }

  /// Professional gesture end with snap-to-position behavior only
  void onEndEnhanced(FloatingOverlayData data) {
    _data = data;
    _previousOffset = state;

    if (_snapToPositions) {
      // Always snap to the nearest corner
      final nearestPosition =
          _findNearestSnapPosition() ?? _snapPositions.first;
      _animateToPosition(nearestPosition);
    }
  }

  /// Find the nearest snap position (always returns a position)
  Offset? _findNearestSnapPosition() {
    if (_snapPositions.isEmpty) return null;

    double minDistance = double.infinity;
    Offset? nearestPosition;

    for (final snapPos in _snapPositions) {
      final distance = (state - snapPos).distance;
      if (distance < minDistance) {
        minDistance = distance;
        nearestPosition = snapPos;
      }
    }

    return nearestPosition;
  }

  /// Animate smoothly to target position
  void _animateToPosition(Offset targetPosition) {
    _targetPosition = targetPosition;
    _isProgrammaticThrow = true;

    // Calculate optimal velocity for smooth arrival
    final distance = (_targetPosition - state).distance;
    final optimalVelocity = math.min(distance * 3.0, _maxVelocity);
    final direction =
        distance > 0 ? (_targetPosition - state) / distance : Offset.zero;

    _velocity = direction * optimalVelocity;
    _ticker?.start();
  }

  /// Professional physics update system (snap-to-corner only)
  void _physicsUpdate(Duration elapsed) {
    if (_data == null) return;

    final now = DateTime.now();
    final dt = math.min(
      now.difference(_lastUpdateTime).inMilliseconds / 1000.0,
      1 / 30,
    ); // Cap at 30fps
    _lastUpdateTime = now;

    if (dt <= 0) return;

    final childSize = _data!.childRect.size;
    var newPosition = state;

    // Only use spring-damper system for smooth snap animations
    if (_isProgrammaticThrow) {
      newPosition = _updateSpringDamper(dt, childSize);
    }

    // Apply position and check if animation should continue
    emit(_validValue(newPosition, childSize));

    if (_velocity.distance < _minVelocity &&
        (!_isProgrammaticThrow || (state - _targetPosition).distance < 1.0)) {
      _stopAnimation();
    }
  }

  /// Spring-damper system for smooth programmatic animations (no bouncing)
  Offset _updateSpringDamper(double dt, Size childSize) {
    final displacement = _targetPosition - state;
    final springForce = displacement * _naturalFrequency * _naturalFrequency;
    final dampingForce = _velocity * (2 * _dampingRatio * _naturalFrequency);

    final acceleration = springForce - dampingForce;
    _velocity += acceleration * dt;

    // Apply friction
    _velocity *= math.pow(1 - _friction, dt).toDouble();

    var newPosition = state + _velocity * dt;

    // Clamp to boundaries without bouncing
    newPosition = _validValue(newPosition, childSize);

    return newPosition;
  }

  /// Calculate scale offset for gesture handling
  Offset _scaleOffset(FloatingOverlayData data, double previousScale) {
    final previousSize = data.copyWith(scale: previousScale).childRect.size;
    final currentSize = data.childRect.size;
    final difference = Size(
      currentSize.width - previousSize.width,
      currentSize.height - previousSize.height,
    );
    return Offset(difference.width / 2, difference.height / 2);
  }

  /// Update position by delta
  void onUpdateDelta(Offset delta, Size size) {
    final offset = _previousOffset + delta;
    emit(_validValue(offset, size));
  }

  /// Validate and clamp position within boundaries
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

  /// Stop animation cleanly
  void _stopAnimation() {
    _isProgrammaticThrow = false;
    _velocity = Offset.zero;
    _ticker?.stop();
  }

  /// Enable or disable snap-to-position behavior
  void setSnapToPositions(bool enabled) {
    _snapToPositions = enabled;
  }

  /// Set custom snap positions
  void setCustomSnapPositions(List<Offset> positions) {
    _snapPositions = List.from(positions);
  }

  /// Get current snap positions
  List<Offset> get snapPositions => List.from(_snapPositions);

  /// Dispose resources
  void disposePhysics() {
    _ticker?.dispose();
    _ticker = null;
  }
}

/// Extension for clamping offset magnitude
extension OffsetExtensions on Offset {
  Offset clampMagnitude(double min, double max) {
    final magnitude = distance;
    if (magnitude < min) return this;
    if (magnitude > max) return this / magnitude * max;
    return this;
  }
}
