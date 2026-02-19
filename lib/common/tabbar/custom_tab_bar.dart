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
  late List<GlobalKey> _tabKeys;

  @override
  void initState() {
    super.initState();
    // Initialize a key for every tab to track their positions
    _tabKeys = List.generate(widget.tabs.length, (index) => GlobalKey());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateController();
  }

  @override
  void didUpdateWidget(CustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild keys if the number of tabs changes dynamically
    if (widget.tabs.length != oldWidget.tabs.length) {
      _tabKeys = List.generate(widget.tabs.length, (index) => GlobalKey());
    }
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
    // Only rebuild if the index actually changed
    if (_controller!.indexIsChanging ||
        _controller!.animation!.value == _controller!.index.toDouble()) {
      setState(() {});

      // Auto-scroll to the selected tab after the frame renders the expanded size
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentTab();
      });
    }
  }

  void _scrollToCurrentTab() {
    if (_controller == null || _tabKeys.isEmpty) return;
    final index = _controller!.index;
    if (index < 0 || index >= _tabKeys.length) return;

    final keyContext = _tabKeys[index].currentContext;
    if (keyContext != null) {
      // ensureVisible finds the nearest Scrollable and scrolls to this context
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.5, // 0.5 means it will attempt to center the tab
      );
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
    final bgColor =
        widget.backgroundColor ?? colorScheme.surfaceContainerHighest;
    final activeColor = widget.indicatorColor ?? colorScheme.surfaceContainer;
    final activeText = widget.labelColor ?? colorScheme.onSurface;
    final inactiveText =
        widget.unselectedLabelColor ?? colorScheme.onSurfaceVariant;

    return Container(
      decoration: ShapeDecoration(color: bgColor, shape: const StadiumBorder()),
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.tabs.length, (index) {
              final isSelected = _controller?.index == index;
              final item = widget.tabs[index];

              return GestureDetector(
                // Attach the unique GlobalKey to each tab item
                key: _tabKeys[index],
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
                          width: isSelected ? null : 0,
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
