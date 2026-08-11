import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_shell_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final dormitoryId = auth.dormitoryId ?? 0;

    return ChangeNotifierProvider(
      create: (_) => AdminShellViewModel(
        dormitoryId: dormitoryId,
      )..refreshUnreadCount(),
      child: const _AdminShellView(),
    );
  }
}

class _AdminShellView extends StatelessWidget {
  const _AdminShellView();

  List<Widget> _buildPages(BuildContext context, int? dormitoryId) {
    // Return all pages always with the dormitoryId (even if it's 0)
    // This ensures IndexedStack always has consistent indices
    final id = dormitoryId ?? 0;

    return [
      DashboardScreen(dormitoryId: id),
      RoomsScreen(dormitoryId: id),
      MeterScreen(dormitoryId: id),
      BillingScreen(dormitoryId: id),
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

  void _onItemTapped(
      BuildContext context, AdminShellViewModel viewModel, int index) {
    // IndexedStack ไม่ dispose TextField ของหน้าแชท ถ้าไม่ unfocus แป้นพิมพ์
    // จะค้างทับแท็บที่สลับไป
    FocusManager.instance.primaryFocus?.unfocus();

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
    viewModel.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final viewModel = context.watch<AdminShellViewModel>();
    final dormitoryId = auth.dormitoryId;
    final pages = _buildPages(context, dormitoryId);
    final location = GoRouterState.of(context).uri.path;
    final desiredIndex = _calculateSelectedIndex(location);
    final activeIndex = desiredIndex.clamp(0, pages.length - 1);
    final bottomNavIndex = activeIndex <= 4 ? activeIndex : 0;

    return Scaffold(
      appBar: MobileHeader(
        dormitoryName: auth.dormitoryName,
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
      body: dormitoryId == null && activeIndex == 0
          ? _buildNoDormitoryView(context)
          : IndexedStack(
              index: activeIndex,
              children: pages,
            ),
      bottomNavigationBar: dormitoryId != null
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
                onTap: (index) => _onItemTapped(context, viewModel, index),
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
                    icon: NavBadgeIcon(
                      count: viewModel.unreadMessageCount,
                      icon: Icons.chat_bubble_outline,
                    ),
                    activeIcon: NavBadgeIcon(
                      count: viewModel.unreadMessageCount,
                      icon: Icons.chat_bubble,
                    ),
                    label: 'แชท',
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildNoDormitoryView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.domain_disabled, size: 64, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text('ไม่พบข้อมูลหอพัก', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('บัญชีของคุณยังไม่ได้ผูกกับหอพักใดๆ กรุณาติดต่อผู้ดูแลระบบ', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
