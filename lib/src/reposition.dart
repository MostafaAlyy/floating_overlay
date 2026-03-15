part of 'floating_overlay.dart';

/// Positions the floating child within the overlay [Stack] by listening to
/// the offset controller's stream.
class _Reposition extends StatelessWidget {
  const _Reposition({
    required this.child,
    required this.offsetController,
  });

  final Widget child;
  final _FloatingOverlayOffset offsetController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Offset>(
      initialData: offsetController.state,
      stream: offsetController.stream,
      builder: (context, snapshot) {
        final position = snapshot.data!;
        return Positioned(
          top: position.dy,
          left: position.dx,
          child: child,
        );
      },
    );
  }
}
