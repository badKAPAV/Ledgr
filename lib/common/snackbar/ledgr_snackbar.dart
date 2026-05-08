import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wallzy/main.dart';

class LedgrSnackbar {
  static OverlayEntry? _currentOverlay;

  /// Dismisses the currently showing snackbar.
  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Shows a custom top-aligned snackbar.
  static void show({
    BuildContext? context,
    required Widget content,
    Duration duration = const Duration(seconds: 4),
    Widget? action, // Accepts SnackBarAction or any custom Widget
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    bool showCloseIcon = false,
    Color? closeIconColor,
  }) {
    _currentOverlay?.remove();
    _currentOverlay = null;

    final targetContext = context ?? appNavigatorKey.currentContext;

    if (targetContext == null) {
      debugPrint("Ledgr SnackBar: No context found. Cannot show snackbar.");
      return;
    }

    final overlayState = Overlay.of(targetContext);
    late OverlayEntry overlayEntry;

    void onDismiss() {
      if (_currentOverlay == overlayEntry) {
        overlayEntry.remove();
        _currentOverlay = null;
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _LedgrSnackbarWidget(
          content: content,
          duration: duration,
          action: action,
          backgroundColor: backgroundColor,
          elevation: elevation ?? 6.0,
          shape: shape,
          padding: padding,
          margin: margin ?? const EdgeInsets.all(16.0),
          showCloseIcon: showCloseIcon,
          closeIconColor: closeIconColor,
          onDismissed: onDismiss,
        );
      },
    );

    _currentOverlay = overlayEntry;
    overlayState.insert(overlayEntry);
  }
}

class _LedgrSnackbarWidget extends StatefulWidget {
  final Widget content;
  final Duration duration;
  final Widget? action;
  final Color? backgroundColor;
  final double elevation;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry margin;
  final bool showCloseIcon;
  final Color? closeIconColor;
  final VoidCallback onDismissed;

  const _LedgrSnackbarWidget({
    required this.content,
    required this.duration,
    this.action,
    this.backgroundColor,
    required this.elevation,
    this.shape,
    this.padding,
    required this.margin,
    required this.showCloseIcon,
    this.closeIconColor,
    required this.onDismissed,
  });

  @override
  State<_LedgrSnackbarWidget> createState() => _LedgrSnackbarWidgetState();
}

class _LedgrSnackbarWidgetState extends State<_LedgrSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    _isDismissing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Intercepts a standard SnackBarAction to style it and ensure it dismisses the overlay.
  Widget _buildAction(BuildContext context, ColorScheme colorScheme) {
    if (widget.action == null) return const SizedBox.shrink();

    // If the user passed a SnackBarAction, extract its properties
    if (widget.action is SnackBarAction) {
      final action = widget.action as SnackBarAction;

      return TextButton(
        onPressed: () {
          action.onPressed(); // Run user's custom function
          _dismiss(); // Automatically dismiss our custom snackbar
        },
        style: TextButton.styleFrom(
          // Material 3 defaults to inversePrimary for snackbar actions
          foregroundColor: action.textColor ?? colorScheme.inversePrimary,
          backgroundColor: action.backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        child: Text(
          action.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    // If the user passed a completely custom widget (like an IconButton), render it as-is
    return widget.action!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snackBarTheme = theme.snackBarTheme;

    final bgColor =
        widget.backgroundColor?.withValues(alpha: 0.4) ??
        snackBarTheme.backgroundColor?.withValues(alpha: 0.4) ??
        colorScheme.inverseSurface.withValues(alpha: 0.4);

    final contentColor = colorScheme.onInverseSurface;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: widget.margin,
              child: Material(
                elevation: widget.elevation,
                color: Colors.transparent,
                shape:
                    widget.shape ??
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      side: BorderSide(
                        color: colorScheme.onSurface,
                        width: 0.5,
                      ),
                    ),
                child: ClipRRect(
                  borderRadius:
                      (widget.shape as RoundedRectangleBorder?)?.borderRadius ??
                      BorderRadius.circular(30.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding:
                          widget.padding ??
                          const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                      color: bgColor,
                      child: DefaultTextStyle(
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: widget.content),

                            // Render our intercepted action
                            if (widget.action != null) ...[
                              const SizedBox(width: 8),
                              _buildAction(context, colorScheme),
                            ],

                            if (widget.showCloseIcon) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close),
                                color: widget.closeIconColor ?? contentColor,
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _dismiss,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
