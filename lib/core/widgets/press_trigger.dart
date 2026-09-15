import 'package:flutter/widgets.dart';

/// Wraps any widget with a pointer-level press animation (scale + opacity).
/// Uses [Listener] so it fires before gesture competition — the inner widget
/// still receives its own tap/press callbacks normally.
class PressTrigger extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double scaleTo;
  final double opacityTo;
  final Duration duration;

  const PressTrigger({
    super.key,
    required this.child,
    this.enabled = true,
    this.scaleTo = 0.97,
    this.opacityTo = 0.88,
    this.duration = const Duration(milliseconds: 90),
  });

  @override
  State<PressTrigger> createState() => _PressTriggerState();
}

class _PressTriggerState extends State<PressTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _pressed && widget.enabled;
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: active ? widget.scaleTo : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: active ? widget.opacityTo : 1.0,
          duration: widget.duration,
          child: widget.child,
        ),
      ),
    );
  }
}
