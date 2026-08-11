import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// ปลายทางหนึ่งอันของแถบนำทาง
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// จำนวนที่ยังไม่อ่าน · 0 = ไม่ต้องแสดง badge
  final int badgeCount;
}

/// โครงหน้าจอที่ย้ายแถบนำทางตามความกว้างที่มี
///
/// จอแคบ — แถบล่าง ซึ่งเป็นระยะที่นิ้วโป้งเอื้อมถึงบนมือถือ
/// จอกว้าง — แถบข้างซ้าย เพราะแถบล่างที่ทอดยาวเต็มจอ 1,400px ทำให้ปุ่มห่างกัน
/// จนกวาดสายตาหาไม่เจอ และกินความสูงซึ่งเป็นมิติที่ขาดแคลนบนเดสก์ท็อป
///
/// ใช้ร่วมกันทั้งฝั่งเจ้าของหอและฝั่งผู้เช่า เพื่อไม่ให้สองฝั่งแตกต่างกันเอง
/// เวลาแก้อันหนึ่งแล้วลืมอีกอัน
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
    this.showNavigation = true,
  });

  final List<NavDestination> destinations;

  /// ดัชนีของแท็บที่เปิดอยู่ · ค่าที่เกินขอบเขตจะถูกหนีบให้อยู่ในช่วง เพราะ
  /// หน้าที่ไม่มีในแถบนำทาง (เช่น /landlord/lease) ก็ยังต้องวาดได้
  final int selectedIndex;

  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// false = ซ่อนแถบนำทางทั้งหมด (เช่นเจ้าของหอที่ยังไม่ได้ผูกกับหอไหน)
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    final index = destinations.isEmpty
        ? 0
        : selectedIndex.clamp(0, destinations.length - 1);

    if (!showNavigation) {
      return Scaffold(appBar: appBar, body: body);
    }

    if (context.isCompact) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: _BottomBar(
          destinations: destinations,
          selectedIndex: index,
          onDestinationSelected: onDestinationSelected,
        ),
      );
    }

    // ป้ายกำกับกางออกเฉพาะจอกว้างจริง · ที่ medium (แท็บเล็ต/ครึ่งจอ) แถบแบบ
    // กางกินความกว้างไป 250px ซึ่งเป็นสัดส่วนที่มากเกินไปของพื้นที่ทั้งหมด
    final extended = context.layoutSize == LayoutSize.expanded;

    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          _Rail(
            destinations: destinations,
            selectedIndex: index,
            onDestinationSelected: onDestinationSelected,
            extended: extended,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onDestinationSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedForeground,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        items: [
          for (final destination in destinations)
            BottomNavigationBarItem(
              icon: _NavIcon(
                  icon: destination.icon, count: destination.badgeCount),
              activeIcon: _NavIcon(
                  icon: destination.activeIcon, count: destination.badgeCount),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    // แถบต้องสูงเท่าจอเสมอ แต่จอเตี้ย (มือถือแนวนอน, หน้าต่างที่ลากให้เตี้ย)
    // มีที่ไม่พอสำหรับปลายทางทั้งห้า · ห่อด้วย SingleChildScrollView ที่บังคับ
    // ความสูงขั้นต่ำเท่าที่เหลืออยู่ เพื่อให้เลื่อนได้เมื่อไม่พอ และยังเต็มจอ
    // เมื่อพอ — IntrinsicHeight ตรงนี้แทนไม่ได้เพราะ NavigationRail ต้องการ
    // ความสูงที่แน่นอน
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: extended,
              backgroundColor: AppColors.card,
              indicatorColor: AppColors.primary.withValues(alpha: 0.12),
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              unselectedIconTheme:
                  const IconThemeData(color: AppColors.mutedForeground),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 13,
              ),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: _NavIcon(
                        icon: destination.icon, count: destination.badgeCount),
                    selectedIcon: _NavIcon(
                        icon: destination.activeIcon,
                        count: destination.badgeCount),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ไอคอนที่มี badge ตัวเลขเมื่อ [count] > 0 · ใช้ได้ทั้งแถบล่างและแถบข้าง
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon);
    if (count <= 0) return iconWidget;
    return Badge(label: Text('$count'), child: iconWidget);
  }
}
