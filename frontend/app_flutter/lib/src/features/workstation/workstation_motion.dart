import 'package:flutter/material.dart';

/// Source mobile task buttons use active:scale-[.98]/.95 with CSS transitions.
/// Raw pointer observation leaves the button's gesture, focus and semantics in
/// charge; visual feedback never triggers an action or network operation.
class WorkstationPressFeedback extends StatefulWidget {
  const WorkstationPressFeedback({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = .98,
  });
  final Widget child;
  final bool enabled;
  final double scale;
  @override
  State<WorkstationPressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<WorkstationPressFeedback>
    with WidgetsBindingObserver {
  int? pointer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void clear() {
    if (pointer != null && mounted) setState(() => pointer = null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) clear();
  }

  @override
  void didUpdateWidget(WorkstationPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) pointer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (event) {
        if (widget.enabled && pointer == null) {
          setState(() => pointer = event.pointer);
        }
      },
      onPointerUp: (event) {
        if (event.pointer == pointer) clear();
      },
      onPointerCancel: (event) {
        if (event.pointer == pointer) clear();
      },
      child: AnimatedScale(
        scale: pointer != null && widget.enabled && !reduced ? widget.scale : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
