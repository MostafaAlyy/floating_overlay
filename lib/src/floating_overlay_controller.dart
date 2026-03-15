part of 'floating_overlay.dart';

class FloatingOverlayController extends Cubit<FloatingOverlayData> {
  /// The controller for the [FloatingOverlay].
  ///
  /// Be sure to initialize this only once (probably inside `initState` method)
  /// when inside a Stateful Widget that has an [AnimationController] inside.
  FloatingOverlayController.relativeSize({
    /// Minimum scale to resize the floating child.
    double? minScale,

    /// Maximum scale to resize the floating child.
    double? maxScale,

    /// Padding inside the constraints of the floating child's space to float.
    EdgeInsets? padding,

    /// Offset inside the constraints of the floating child's space to float.
    Offset? start,

    /// If the floating child's space to float will be limited by the maximum
    /// size that the FloatingOverlay can be.
    bool constrained = false,

    /// Cursor detection pixel area.
    double? cursorArea,
  })  : _cursorArea = cursorArea,
        _offset = _FloatingOverlayOffset(
          start: start,
          padding: padding,
          constrained: constrained,
        ),
        _scale = _FloatingOverlayScale.relative(
          minScale: minScale,
          maxScale: maxScale,
        ),
        super(
          FloatingOverlayData(
            childSize: Size.zero,
            scale: 1.0,
            position: _FloatingOverlayOffset(
              start: start,
              padding: padding,
            ).state,
          ),
        ) {
    _cursorController = _FloatingOverlayCursor(scale: _scale, offset: _offset);
    _streamProcess();
  }

  /// The controller for the [FloatingOverlay].
  ///
  /// Be sure to initialize this only once (probably inside `initState` method)
  /// when inside a Stateful Widget that has an [AnimationController] inside.
  FloatingOverlayController.absoluteSize({
    /// Minimum size to resize the floating child.
    Size? minSize,

    /// Maximum size to resize the floating child.
    Size? maxSize,

    /// Padding inside the constraints of the floating child's space to float.
    EdgeInsets? padding,

    /// Offset inside the constraints of the floating child's space to float.
    Offset? start,

    /// If the floating child's space to float will be limited by the maximum
    /// size that the FloatingOverlay can be.
    bool constrained = false,

    /// Cursor detection pixel area.
    double? cursorArea,
  })  : _cursorArea = cursorArea,
        _offset = _FloatingOverlayOffset(
          start: start,
          padding: padding,
          constrained: constrained,
        ),
        _scale = _FloatingOverlayScale.absolute(
          maxSize: maxSize,
          minSize: minSize,
        ),
        super(
          FloatingOverlayData(
            childSize: Size.zero,
            scale: 1.0,
            position: _FloatingOverlayOffset(
              start: start,
              padding: padding,
            ).state,
          ),
        ) {
    _cursorController = _FloatingOverlayCursor(scale: _scale, offset: _offset);
    _streamProcess();
  }

  void _streamProcess() {
    _offset.stream.listen((offset) {
      emit(state.copyWith(position: offset));
    });
    _scale.stream.listen((scale) {
      emit(state.copyWith(scale: scale));
    });
  }

  static final _logger = Logger('FloatingOverlayController');
  late final _FloatingOverlayCursor _cursorController;
  final _FloatingOverlayOffset _offset;
  final _FloatingOverlayScale _scale;
  final double? _cursorArea;

  /// Stable key used to measure the floating child's rendered size.
  ///
  /// Previously this was re-assigned inside the [_floatingChild] getter on
  /// every call, which caused Flutter to unmount/remount the child widget tree
  /// whenever the key was read (e.g. during gesture detection). The key is now
  /// a `final` field so it lives for the lifetime of the controller.
  final GlobalKey _key = GlobalKey();

  OverlayState? _overlay;
  OverlayEntry? _entry;
  Widget? _child;

  void _initState(
    BuildContext context,
    Widget floatingChild,
    Rect limits, {
    TickerProvider? vsync,
  }) {
    _logger.fine('Started');
    _child ??= floatingChild;
    _offset.init(limits, MediaQuery.of(context).size);
    _scale.init(floatingLimits!);

    // Initialize physics system if a ticker provider is available.
    if (vsync != null) {
      _offset.initPhysics(vsync);
    }

    _overlay = Overlay.of(context);
    if (!isFloating) _createInvisibleChild(_startChildSize);
    _offset.setGlobal(_offset.state, state);
  }

  void _dispose() {
    hide(true);
    _offset.disposePhysics();
    _offset.close();
    _scale.close();
    _overlay = null;
    _logger.fine('Disposed');
  }

  void _createInvisibleChild(VoidCallback postFrameCallback) {
    _logger.fine('Creating invisible entry');
    _entry = OverlayEntry(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          postFrameCallback();
          _logger.fine('Destroying invisible entry');
          hide();
        });
        return Offstage(
          offstage: true,
          child: SizedBox.shrink(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _floatingChild,
            ),
          ),
        );
      },
    );
    _overlay?.insert(_entry!);
  }

  void _startChildSize() {
    _logger.fine('Starting child size measurement');
    emit(state.copyWith(childSize: _childSize));
  }

  Size get _childSize {
    final box = _key.currentContext!.findRenderObject()! as RenderBox;
    return box.size;
  }

  /// Returns the current offset of the floating widget.
  ///
  /// If you are using the setter and looking for the same result, use the
  /// [stream] getter which gives a [FloatingOverlayData] and will update when
  /// the controller ends processing.
  Offset get offset => state.position;

  /// Update the offset of the floating widget.
  set offset(Offset global) {
    _offset.setGlobal(global, state);
  }

  /// Returns the current scale of the floating widget.
  ///
  /// If you are using the setter and looking for the same result, use the
  /// [stream] getter which gives a [FloatingOverlayData] and will update when
  /// the controller ends processing.
  double get scale => state.scale;

  /// Update the scale of the floating widget.
  set scale(double scale) {
    _scale.onUpdate(scale, state);
  }

  /// Programmatically throw the floating widget to a target position
  /// using the physics-based spring animation.
  void throwToPosition(Offset targetPosition, {double? velocity}) {
    _offset.throwToPosition(targetPosition, velocity: velocity);
  }

  /// Enable or disable snap-to-corner behavior on drag release.
  void setSnapToPositions(bool enabled) {
    _offset.setSnapToPositions(enabled);
  }

  /// Override the default corner snap positions with custom ones.
  void setCustomSnapPositions(List<Offset> positions) {
    _offset.setCustomSnapPositions(positions);
  }

  /// The current set of snap positions (read-only copy).
  List<Offset> get snapPositions => _offset.snapPositions;

  /// Returns the constrained `Rect` in which the widget can float.
  ///
  /// This value is null until the [FloatingOverlay] is initiated.
  Rect? get floatingLimits => _offset.floatingLimits;

  /// Toggles the floating child's visibility.
  void toggle() {
    _logger.fine('Toggled');
    if (isFloating) {
      hide();
    } else {
      show();
    }
  }

  /// Hides the floating child.
  ///
  /// Pass [dispose] = `true` when tearing down the overlay permanently
  /// (e.g. from [_dispose]).
  void hide([bool dispose = false]) {
    _entry?.remove();
    if (dispose) _entry?.dispose();
    _entry = null;
    _logger.fine('Entry removed');
  }

  /// Whether the floating child is currently visible.
  bool get isFloating => _entry != null;

  /// Shows the floating child.
  void show() {
    _logger.fine('Showing entry');
    _entry = OverlayEntry(
      builder: (context) {
        return _entryProcessWidgets;
      },
    );
    _overlay?.insert(_entry!);
  }

  Widget get _entryProcessWidgets {
    return _Reposition(
      offsetController: _offset,
      child: Stack(
        children: [
          _Rescale(
            data: state,
            scaleController: _scale,
            child: gestureDetector,
          ),
          _CursorResizing(
            side: _Side.left,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.top,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.right,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.bottom,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.topLeft,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.topRight,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.bottomLeft,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
          _CursorResizing(
            side: _Side.bottomRight,
            controller: _cursorController,
            data: () => state,
            area: _cursorArea,
          ),
        ],
      ),
    );
  }

  Widget get gestureDetector {
    return GestureDetector(
      onScaleStart: (details) {
        _scale.onStart();
        _offset.onStartEnhanced(details.focalPoint);
      },
      onScaleUpdate: (details) {
        // Single-finger drag (scale == 1.0) → use enhanced movement with
        // velocity tracking for the physics throw on release.
        if (details.scale == 1.0) {
          _offset.onUpdateEnhanced(details.focalPoint, state);
        } else {
          // Pinch/zoom → update scale and adjust offset to keep widget centred
          // under the focal point.
          _scale.onUpdate(details.scale, state);
          final previousScale = _scale._previousScale;
          _offset.onUpdate(details.focalPoint, state, previousScale);
        }
      },
      onScaleEnd: (details) {
        // Physics-based throw / snap-to-corner on release.
        _offset.onEndEnhanced(state);
      },
      child: _floatingChild,
    );
  }

  Widget get _floatingChild {
    // NOTE: _key is a stable `final` field on this controller. Do NOT create a
    // new GlobalKey here — doing so would cause Flutter to unmount and remount
    // the child widget tree on every gesture update, losing all widget state.
    return Container(
      key: _key,
      child: _child ?? const SizedBox.shrink(),
    );
  }
}
