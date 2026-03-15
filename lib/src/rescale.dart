part of 'floating_overlay.dart';

/// Scales the floating child widget by listening to the scale controller's
/// stream.
class _Rescale extends StatelessWidget {
  const _Rescale({
    required this.child,
    required this.scaleController,
    required this.data,
  });

  final Widget child;
  final _FloatingOverlayScale scaleController;
  final FloatingOverlayData data;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      initialData: scaleController.state,
      stream: scaleController.stream,
      builder: (context, snapshot) {
        final scale = snapshot.data!;
        final size =
            data.childSize != Size.zero ? data.childSize * scale : null;
        return SizedBox.fromSize(
          size: size,
          child: child,
        );
      },
    );
  }
}
