import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Adds an iOS-style edge-swipe-to-pop gesture to a screen.
///
/// The app's shared push transition (`_slideFadePage` in app.dart) is a
/// `CustomTransitionPage`, which — unlike `CupertinoPageRoute` — doesn't
/// come with the platform back-swipe gesture built in. Android's back
/// gesture/button already pops correctly regardless (handled by the
/// system and Navigator, independent of the page transition), so this
/// only needs to do something on iOS.
class EdgeSwipeBack extends StatefulWidget {
  final Widget child;
  const EdgeSwipeBack({super.key, required this.child});

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapBack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  double _dragExtent = 0;
  bool _dragging = false;

  static const _edgeWidth = 24.0;

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _dragging = details.globalPosition.dx <= _edgeWidth;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(0.0, width);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final width = MediaQuery.of(context).size.width;
    final fling = (details.primaryVelocity ?? 0) > 800;
    if ((fling || _dragExtent > width * 0.35) && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    final start = _dragExtent;
    _snapBack
      ..value = 0
      ..addListener(() {
        setState(() => _dragExtent = start * (1 - _snapBack.value));
      })
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Transform.translate(
        offset: Offset(_dragExtent, 0),
        child: widget.child,
      ),
    );
  }
}
