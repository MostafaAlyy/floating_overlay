import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

part 'cursor_border_side.dart';
part 'cursor_resizing.dart';
part 'floating_overlay_controller.dart';
part 'floating_overlay_cursor.dart';
part 'floating_overlay_data.dart';
part 'floating_overlay_offset.dart';
part 'floating_overlay_scale.dart';
part 'reposition.dart';
part 'rescale.dart';
part 'size_extension.dart';

class FloatingOverlay extends StatefulWidget {
  const FloatingOverlay({
    super.key,

    /// The child underneath this widget inside the widget tree.
    this.child,

    /// Used to controll the visibility state of the [floatingChild].
    this.controller,

    /// Widget that will be floating around.
    this.floatingChild,

    /// When you push pages on top, the floating child will vanish and reappear
    /// when you return if you give it an RouteObserver linked to the main
    /// MaterialApp.
    this.routeObserver,
  });

  /// The child underneath this widget inside the widget tree.
  final Widget? child;

  /// Widget that will be floating around.
  final Widget? floatingChild;

  /// Used to controll the visibility state of the [floatingChild].
  final FloatingOverlayController? controller;

  /// When you push pages on top, the floating child will vanish and reappear
  /// when you return if you give it an RouteObserver linked to the main
  /// MaterialApp.
  final RouteObserver? routeObserver;

  @override
  State<FloatingOverlay> createState() => _FloatingOverlayState();
}

class _FloatingOverlayState extends State<FloatingOverlay> 
    with RouteAware, TickerProviderStateMixin {
  static const empty = SizedBox.shrink();

  late final FloatingOverlayController controller;
  final key = GlobalKey();
  final floatingWidgetKey = GlobalKey();
  bool floating = false;  void startController(BuildContext context, BoxConstraints constraints) {
    final offset = widgetOffset();
    final endOffsetValue = endOffset(offset, constraints.biggest);
    final limits = Rect.fromPoints(offset, endOffsetValue);
    final child = widget.floatingChild ?? empty;
    controller._initState(context, child, limits, vsync: this);
  }

  Offset widgetOffset() {
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero);
  }

  Offset endOffset(Offset start, Size maxSize) {
    final maxSizeOffset = Offset(maxSize.width, maxSize.height);
    return start + maxSizeOffset;
  }

  @override
  void initState() {
    controller = widget.controller ?? FloatingOverlayController.relativeSize();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.routeObserver?.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    if (floating) {
      controller.show();
    }
  }

  @override
  void didPushNext() {
    floating = controller.isFloating;
    if (floating) {
      controller.hide();
    }
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    controller._dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          key: key,
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => startController(context, constraints),
            );
            return widget.child ?? empty;
          },
        );
      },
    );
  }
}
