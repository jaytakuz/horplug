import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import 'dashboard_screen.dart';
import 'rooms_screen.dart';
import 'meter_screen.dart';
import 'billing_screen.dart';
import 'chat_screen.dart';
import 'lease_screen.dart';

class AdminShell extends StatefulWidget {
  final String dormSlug;

  const AdminShell({super.key, required this.dormSlug});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dormSlug != widget.dormSlug) {
      _buildPages();
    }
  }

  void _buildPages() {
    _pages = [
      DashboardScreen(dormSlug: widget.dormSlug),
      const RoomsScreen(),
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

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/${widget.dormSlug}/admin');
        break;
      case 1:
        context.go('/${widget.dormSlug}/admin/rooms');
        break;
      case 2:
        context.go('/${widget.dormSlug}/admin/meter');
        break;
      case 3:
        context.go('/${widget.dormSlug}/admin/billing');
        break;
      case 4:
        context.go('/${widget.dormSlug}/admin/chat');
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
    final location = GoRouterState.of(context).uri.path;
    final activeIndex = _calculateSelectedIndex(location);
    final bottomNavIndex = activeIndex <= 4 ? activeIndex : 0;

    return Scaffold(
      appBar: MobileHeader(subtitle: _getHeaderSubtitle(location)),
      body: IndexedStack(
        index: activeIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: bottomNavIndex,
          onTap: _onItemTapped,
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
      ),
    );
  }
}
