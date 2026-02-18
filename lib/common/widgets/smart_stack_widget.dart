import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartStackWidget extends StatefulWidget {
  final List<Widget> children;
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const SmartStackWidget({
    super.key,
    required this.children,
    this.height = 200,
    this.width, // Null means full width
    this.borderRadius = 24,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<SmartStackWidget> createState() => _SmartStackWidgetState();
}

class _SmartStackWidgetState extends State<SmartStackWidget> {
  late final PageController _pageController;
  int _currentIndex = 0;

  // Interaction State for Indicators
  bool _isInteracting = false;
  Timer? _hideTimer;

  // Animation constants for that "iOS feel"
  static const double _scaleFactor = 0.9;
  static const double _fadeFactor = 0.3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    HapticFeedback.selectionClick();
  }

  // Wakes up the indicators and sets a timer to put them back to sleep
  void _wakeUpIndicators() {
    if (!_isInteracting) {
      setState(() => _isInteracting = true);
    }

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isInteracting = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: widget.height,
      width: widget.width ?? double.infinity,
      margin: widget.padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors
            .transparent, // or colorScheme.surface if you want a background
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Stack(
        children: [
          // 2. Interaction Listener: Detects swipes to wake up UI
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                _wakeUpIndicators();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.children.length,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double value = 0.0;
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - index;
                    } else {
                      value = (index == 0) ? 0.0 : 1.0;
                    }

                    // Smoother curve for depth effect
                    final dist = value.abs();
                    double scale = 1.0;
                    double opacity = 1.0;

                    if (dist > 0) {
                      scale = 1.0 - (dist * (1 - _scaleFactor)).clamp(0.0, 1.0);
                      opacity = 1.0 - (dist * _fadeFactor).clamp(0.0, 1.0);
                    }

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: widget.children[index],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 3. The "Alive" Indicators
          if (widget.children.length > 1)
            Positioned(
              right: 4, // Moved slightly in for better aesthetics
              top: 0,
              bottom: 0,
              child: Center(
                // AnimatedOpacity handles the overall visibility of the "pill"
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    // Background only visible when interacting
                    color: _isInteracting
                        ? colorScheme.onSurface.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.children.length, (index) {
                      final isSelected = _currentIndex == index;
                      return GestureDetector(
                        onTap: () {
                          _wakeUpIndicators();
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.fastOutSlowIn,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          width: 4,
                          // Dots get smaller when not interacting to be less intrusive
                          height: isSelected ? 12 : 6,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(
                                    alpha: _isInteracting ? 1 : 0.4,
                                  )
                                : colorScheme.onSurface.withValues(
                                    alpha: _isInteracting ? 0.4 : 0.1,
                                  ), // Dimmer when idle
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
