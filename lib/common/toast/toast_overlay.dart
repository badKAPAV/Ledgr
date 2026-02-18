import 'package:flutter/material.dart';
import 'package:wallzy/common/toast/toast_widget.dart';

class ToastOverlay {
  static OverlayEntry? _currentOverlay;

  static void showToast(
    BuildContext context, {
    required String msg,
    Icon? icon,
    Duration duration = const Duration(seconds: 3),
    ToastPosition position = ToastPosition.bottom,
    bool dismissible = true,
    OverlayState? overlayState,
  }) {
    // Remove any active overlay
    _currentOverlay?.remove();

    final overlay = overlayState ?? Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return ToastWidget(
          content: Row(
            children: [
              if (icon != null) Icon(icon.icon, size: 14, color: icon.color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg,
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          duration: duration,
          position: position,
          dismissible: dismissible,
          onDismissed: () {
            entry.remove();
            _currentOverlay = null;
          },
        );
      },
    );

    _currentOverlay = entry;
    overlay.insert(entry);
  }
}

enum ToastPosition { top, bottom }
