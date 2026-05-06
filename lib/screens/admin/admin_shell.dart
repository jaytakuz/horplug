import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  final String dormSlug;

  const AdminShell({super.key, required this.child, required this.dormSlug});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    int calculateSelectedIndex(String location) {
      if (location.endsWith('/rooms')) return 1;
      if (location.endsWith('/meter')) return 2;
      if (location.endsWith('/billing')) return 3;
      if (location.endsWith('/chat')) return 4;
      return 0;
    }

    void onItemTapped(int index, BuildContext context) {
      switch (index) {
        case 0:
          context.go('/$dormSlug/admin');
          break;
        case 1:
          context.go('/$dormSlug/admin/rooms');
          break;
        case 2:
          context.go('/$dormSlug/admin/meter');
          break;
        case 3:
          context.go('/$dormSlug/admin/billing');
          break;
        case 4:
          context.go('/$dormSlug/admin/chat');
          break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: calculateSelectedIndex(location),
          onTap: (index) => onItemTapped(index, context),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.mutedForeground,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'หน้าหลัก'),
            const BottomNavigationBarItem(icon: Icon(Icons.meeting_room_outlined), activeIcon: Icon(Icons.meeting_room), label: 'ห้องพัก'),
            const BottomNavigationBarItem(icon: Icon(Icons.speed_outlined), activeIcon: Icon(Icons.speed), label: 'มิเตอร์'),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'บิล'),
            BottomNavigationBarItem(
              icon: Badge(
                label: const Text('2'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              activeIcon: Badge(
                label: const Text('2'),
                child: const Icon(Icons.chat_bubble),
              ),
              label: 'แชท',
            ),
          ],
        ),
      ),
    );
  }
}
