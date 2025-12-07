import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: _FloatingBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          HapticFeedback.lightImpact();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _FloatingBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_FloatingBottomNavBar> createState() => _FloatingBottomNavBarState();
}

class _FloatingBottomNavBarState extends State<_FloatingBottomNavBar> {
  static const _items = [
    _NavItem(icon: Icons.map_outlined, selectedIcon: Icons.map_rounded, label: 'Mapa'),
    _NavItem(icon: Icons.shield_outlined, selectedIcon: Icons.shield_rounded, label: 'Zonas'),
    _NavItem(icon: Icons.notifications_outlined, selectedIcon: Icons.notifications_rounded, label: 'Alertas'),
    _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // Extra height to allow the floating bubble to overflow
      height: 100,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Main nav bar container
          Container(
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (index) {
                final isSelected = widget.currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 65,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon for non-selected items
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSelected ? 0.0 : 1.0,
                            child: Icon(
                              _items[index].icon,
                              color: Colors.grey.shade500,
                              size: 24,
                            ),
                          ),
                          // Label shown when not selected
                          if (!isSelected) ...[
                            const SizedBox(height: 4),
                            Text(
                              _items[index].label,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          // Spacer when selected (to avoid layout jump)
                          if (isSelected) const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Floating bubble indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: _getIndicatorPosition(context, widget.currentIndex),
            bottom: 40, // Position above the navbar
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _items[widget.currentIndex].selectedIcon,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          // Selected label below the bubble
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: _getIndicatorPosition(context, widget.currentIndex) - 7,
            bottom: 8,
            child: SizedBox(
              width: 70,
              child: Text(
                _items[widget.currentIndex].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getIndicatorPosition(BuildContext context, int index) {
    // Calculate position based on screen width and margins
    final screenWidth = MediaQuery.of(context).size.width;
    final navBarWidth = screenWidth - 32; // 16px margin on each side
    final itemWidth = navBarWidth / 4;
    // Center the 56px bubble within each item
    return (itemWidth * index) + (itemWidth / 2) - 28;
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

