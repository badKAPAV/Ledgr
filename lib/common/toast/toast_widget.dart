import 'package:flutter/material.dart';
import 'package:wallzy/common/toast/toast_overlay.dart';

class ToastWidget extends StatefulWidget {
  final Widget content;
  final Duration duration;
  final ToastPosition position;
  final bool dismissible;
  final VoidCallback onDismissed;

  const ToastWidget({
    super.key,
    required this.content,
    required this.duration,
    required this.position,
    required this.dismissible,
    required this.onDismissed,
  });

  @override
  State<ToastWidget> createState() => ToastWidgetState();
}

class ToastWidgetState extends State<ToastWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this
    );

    final beginOffset = widget.position == ToastPosition.top
        ? const Offset(0, -0.2)
        : const Offset(0, 5);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut
    );

    _slideController.forward();

    Future.delayed(widget.duration, () async {
      await _slideController.animateTo(
        0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      await _fadeController.forward();

      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.position == ToastPosition.top
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    final double bottomGap = widget.position == ToastPosition.top ? 16 : 30;

    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16,
            bottom: bottomGap,
          ),
          child: FadeTransition(
            opacity: ReverseAnimation(_fadeAnimation),
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: widget.dismissible
                      ? () async {
                          await _slideController.reverse();
                          widget.onDismissed();
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(75),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: widget.content,
                  ),
                ),
              ),
            ),
          ),
        ),
      )
    );
  }
}
