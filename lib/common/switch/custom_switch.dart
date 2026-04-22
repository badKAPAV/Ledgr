import 'package:flutter/material.dart';

class LedgrSwitch extends StatelessWidget {
  /// Whether this switch is on or off.
  final bool value;

  /// Called when the user toggles the switch on or off.
  final ValueChanged<bool>? onChanged;

  /// The color to use on the track when this switch is on.
  /// Defaults to [ColorScheme.primary].
  final Color? activeTrackColor;

  /// The color to use on the track when this switch is off.
  /// Defaults to [ColorScheme.primaryContainer].
  final Color? inactiveTrackColor;

  /// The color to use on the thumb when this switch is on.
  /// Defaults to [ColorScheme.onPrimary].
  final Color? activeThumbColor;

  /// The color to use on the thumb when this switch is off.
  /// Defaults to [ColorScheme.onPrimary].
  final Color? inactiveThumbColor;

  /// An optional widget to use for the icon when the switch is on.
  final Widget? activeIcon;

  /// An optional widget to use for the icon when the switch is off.
  final Widget? inactiveIcon;

  /// The overall width of the switch.
  final double width;

  /// The overall height of the switch.
  final double height;

  /// The border radius of the background track.
  final double? trackRadius;

  /// The border radius of the sliding thumb (square by default).
  final double? thumbRadius;

  /// The duration of the toggle and color transition animations.
  final Duration animationDuration;

  /// The easing curve used for the sliding and color animations.
  final Curve animationCurve;

  const LedgrSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.activeThumbColor,
    this.inactiveThumbColor,
    this.activeIcon,
    this.inactiveIcon,
    this.width = 48.0,
    this.height = 32.0,
    this.trackRadius,
    this.thumbRadius,
    this.animationDuration = const Duration(milliseconds: 350),
    this.animationCurve = Curves.easeOutBack, // Gives a slight fluid bounce
  });

  @override
  Widget build(BuildContext context) {
    // Access the current theme
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve colors with theme fallbacks
    final actualActiveTrackColor = activeTrackColor ?? colorScheme.primary;
    final actualInactiveTrackColor =
        inactiveTrackColor ?? colorScheme.primaryContainer;
    final actualActiveThumbColor = activeThumbColor ?? colorScheme.onPrimary;
    final actualInactiveThumbColor =
        inactiveThumbColor ?? colorScheme.onPrimary;

    // Resolve dimensions and padding
    final padding = 4.0;
    final thumbSize = height - (padding * 2);
    final actualTrackRadius = trackRadius ?? height / 2.5;
    final actualThumbRadius = thumbRadius ?? 10.0; // Slightly rounded square

    // Default icons matching the user's images
    final defaultActiveIcon = Icon(
      Icons.check_rounded,
      color: actualActiveTrackColor,
      size: thumbSize * 0.75,
    );
    final defaultInactiveIcon = Icon(
      Icons.close_rounded,
      color: actualInactiveTrackColor,
      size: thumbSize * 0.75,
    );

    return GestureDetector(
      onTap: () {
        if (onChanged != null) {
          onChanged!(!value);
        }
      },
      // Adds a hit-test area slightly larger than the visual bounds
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value ? actualActiveTrackColor : actualInactiveTrackColor,
          borderRadius: BorderRadius.circular(actualTrackRadius),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The sliding thumb
            AnimatedPositioned(
              duration: animationDuration,
              curve: animationCurve,
              // Animate left/right padding to create the slide effect
              left: value ? width - thumbSize - padding : padding,
              right: value ? padding : width - thumbSize - padding,
              child: AnimatedContainer(
                duration: animationDuration,
                curve: animationCurve,
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  color: value
                      ? actualActiveThumbColor
                      : actualInactiveThumbColor,
                  borderRadius: BorderRadius.circular(actualThumbRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // The rotating/fading icon inside the thumb
                child: AnimatedSwitcher(
                  duration: animationDuration,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          // Add a slight spin to the icon transition
                          turns: Tween<double>(
                            begin: 0.75,
                            end: 1.0,
                          ).animate(animation),
                          child: ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                        );
                      },
                  child: KeyedSubtree(
                    key: ValueKey<bool>(value),
                    child: value
                        ? (activeIcon ?? defaultActiveIcon)
                        : (inactiveIcon ?? defaultInactiveIcon),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
