import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// A data model for the tab content to ensure type safety and easy usage.
class CustomTabItem {
  final String label;
  final dynamic icon;

  const CustomTabItem({required this.label, required this.icon});
}

class CustomTabBar extends StatefulWidget implements PreferredSizeWidget {
  final List<CustomTabItem> tabs;
  final TabController? controller;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final EdgeInsetsGeometry padding;

  const CustomTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.backgroundColor,
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.padding = const EdgeInsets.all(4),
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateController();
  }

  @override
  void didUpdateWidget(CustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _updateController();
    }
  }

  void _updateController() {
    final newController = widget.controller ?? DefaultTabController.of(context);
    assert(
      // ignore: unnecessary_null_comparison
      newController != null,
      'No TabController found. Either provide one or wrap in DefaultTabController.',
    );

    if (newController != _controller) {
      _controller?.removeListener(_handleTabSelection);
      _controller = newController;
      _controller?.addListener(_handleTabSelection);
    }
  }

  void _handleTabSelection() {
    // Only rebuild if the index actually changed (avoid redundant builds during swipe animation)
    if (_controller!.indexIsChanging ||
        _controller!.animation!.value == _controller!.index.toDouble()) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabSelection);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- COLORS ---
    // Outer Shell Background (Darker/Subtle)
    final bgColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest;
    // Selected Pill Color (High Contrast)
    final activeColor = widget.indicatorColor ?? colorScheme.surfaceContainer;
    // Selected Text Color
    final activeText = widget.labelColor ?? colorScheme.onSurface;
    // Unselected Text Color
    final inactiveText =
        widget.unselectedLabelColor ?? colorScheme.onSurfaceVariant;

    return Container(
      // width: double.infinity, // Takes full width as requested
      decoration: ShapeDecoration(
        color: bgColor,
        shape: const StadiumBorder(), // The "Pill" Shape
      ),
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          100,
        ), // Clips scrolling content to pill
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.tabs.length, (index) {
              final isSelected = _controller?.index == index;
              final item = widget.tabs[index];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller?.animateTo(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 12,
                    vertical: 10,
                  ),
                  decoration: ShapeDecoration(
                    color: isSelected ? activeColor : bgColor,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- ANIMATED ICON REVEAL ---
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: isSelected
                              ? null
                              : 0, // Collapses width when unselected
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: HugeIcon(
                              strokeWidth: 2,
                              icon: item.icon,
                              size: 18,
                              color: activeText,
                            ),
                          ),
                        ),
                      ),
                      // --- TEXT LABEL ---
                      Text(
                        item.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected ? activeText : inactiveText,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
