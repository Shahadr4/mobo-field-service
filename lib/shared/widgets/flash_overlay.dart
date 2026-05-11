import 'package:flutter/material.dart';

/// Flash overlay widget for visual feedback on successful barcode scan
/// Matches the white flash animation from Odoo OWL barcode interface
class FlashOverlay extends StatefulWidget {
  final Widget child;
  final bool shouldFlash;
  final VoidCallback? onFlashComplete;
  final Color flashColor;
  final Duration duration;

  const FlashOverlay({
    super.key,
    required this.child,
    this.shouldFlash = false,
    this.onFlashComplete,
    this.flashColor = Colors.white,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<FlashOverlay> createState() => _FlashOverlayState();
}

class _FlashOverlayState extends State<FlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        setState(() => _isFlashing = false);
        widget.onFlashComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(FlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldFlash && !oldWidget.shouldFlash && !_isFlashing) {
      _triggerFlash();
    }
  }

  void _triggerFlash() {
    setState(() => _isFlashing = true);
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isFlashing)
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: widget.flashColor.withOpacity(
                    0.7 * (1.0 - _animation.value),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
