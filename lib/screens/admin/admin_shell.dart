import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import 'dashboard_screen.dart';
import 'rooms_screen.dart';
import 'meter_screen.dart';
import 'billing_screen.dart';
import 'chat_screen.dart';
import 'lease_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  List<Widget> _buildPages(BuildContext context) {
    final auth = AuthScope.of(context);
    final dormitoryId = auth.dormitoryId;
    if (dormitoryId == null) {
      return [const SizedBox.shrink()];
    }

    return [
      DashboardScreen(dormitoryId: dormitoryId),
      RoomsScreen(dormitoryId: dormitoryId),
      const MeterScreen(),
      const BillingScreen(),
      const ChatScreen(),
      const LeaseScreen(),
    ];
  }

  int _calculateSelectedIndex(String location) {
    if (location.endsWith('/rooms')) return 1;
    if (location.endsWith('/meter')) return 2;
    if (location.endsWith('/billing')) return 3;
    if (location.endsWith('/chat')) return 4;
    if (location.endsWith('/lease')) return 5;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/landlord');
        break;
      case 1:
        context.go('/landlord/rooms');
        break;
      case 2:
        context.go('/landlord/meter');
        break;
      case 3:
        context.go('/landlord/billing');
        break;
      case 4:
        context.go('/landlord/chat');
        break;
    }
  }

  String _getHeaderSubtitle(String location) {
    if (location.endsWith('/rooms')) return 'ห้องพัก';
    if (location.endsWith('/meter')) return 'บันทึกมิเตอร์';
    if (location.endsWith('/billing')) return 'จัดการบิล';
    if (location.endsWith('/chat')) return 'แชท';
    if (location.endsWith('/lease')) return 'สัญญาเช่า';
    return 'หน้าหลัก';
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);
    final location = GoRouterState.of(context).uri.path;
    final auth = AuthScope.of(context);
    final hasDormitoryContext = auth.dormitoryId != null;
    final desiredIndex = _calculateSelectedIndex(location);
    final activeIndex = pages.isEmpty
        ? 0
        : desiredIndex.clamp(0, pages.length - 1);
    final bottomNavIndex = activeIndex <= 4 ? activeIndex : 0;

    return Scaffold(
      appBar: MobileHeader(
        subtitle: auth.dormitoryName ?? _getHeaderSubtitle(location),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primary),
            onPressed: () async {
              await auth.signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: activeIndex,
        children: pages,
      ),
      bottomNavigationBar: hasDormitoryContext
          ? Container(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2)),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: bottomNavIndex,
                onTap: (index) => _onItemTapped(context, index),
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.card,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.mutedForeground,
                selectedLabelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                items: [
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'หน้าหลัก'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.meeting_room_outlined),
                      activeIcon: Icon(Icons.meeting_room),
                      label: 'ห้องพัก'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.speed_outlined),
                      activeIcon: Icon(Icons.speed),
                      label: 'มิเตอร์'),
                  const BottomNavigationBarItem(
                      icon: Icon(Icons.receipt_long_outlined),
                      activeIcon: Icon(Icons.receipt_long),
                      label: 'บิล'),
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
            )
          : null,
    );
  }
}
