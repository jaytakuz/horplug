import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/admin_shell_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_scaffold.dart';
import '../../widgets/reusable_widgets.dart';
import 'dashboard_screen.dart';
import 'rooms_screen.dart';
import 'meter_screen.dart';
import 'billing_screen.dart';
import 'chat_screen.dart';
import 'lease_screen.dart';
import 'maintenance_overview_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final dormitoryId = auth.dormitoryId ?? 0;

    return ChangeNotifierProvider(
      create: (_) => AdminShellViewModel(
        dormitoryId: dormitoryId,
      )
        ..refreshUnreadCount()
        ..startListeningForNewMessages(),
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
      MaintenanceOverviewScreen(dormitoryId: id),
    ];
  }

  /// หน้าที่เกินดัชนี 4 เข้าถึงได้จากทางลัดบนแดชบอร์ดเท่านั้น ไม่มีแท็บของตัวเอง
  /// — bottom navigation เต็มที่ห้าช่องแล้ว การยัดช่องที่หกทำให้ทุกแท็บแคบลงจน
  /// ป้ายอ่านไม่ออกบนจอ 360dp
  int _calculateSelectedIndex(String location) {
    if (location.endsWith('/rooms')) return 1;
    if (location.endsWith('/meter')) return 2;
    if (location.endsWith('/billing')) return 3;
    if (location.endsWith('/chat')) return 4;
    if (location.endsWith('/lease')) return 5;
    if (location.endsWith('/maintenance')) return 6;
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

    return AdaptiveNavigationScaffold(
      appBar: MobileHeader(
        dormitoryName: auth.dormitoryName,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primary),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              await auth.signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      showNavigation: dormitoryId != null,
      selectedIndex: bottomNavIndex,
      onDestinationSelected: (index) =>
          _onItemTapped(context, viewModel, index),
      destinations: [
        const NavDestination(
          label: 'หน้าหลัก',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
        ),
        const NavDestination(
          label: 'ห้องพัก',
          icon: Icons.meeting_room_outlined,
          activeIcon: Icons.meeting_room,
        ),
        const NavDestination(
          label: 'มิเตอร์',
          icon: Icons.speed_outlined,
          activeIcon: Icons.speed,
        ),
        const NavDestination(
          label: 'บิล',
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long,
        ),
        NavDestination(
          label: 'แชท',
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          badgeCount: viewModel.unreadMessageCount,
        ),
      ],
      body: dormitoryId == null && activeIndex == 0
          ? _buildNoDormitoryView(context)
          : IndexedStack(
              index: activeIndex,
              children: pages,
            ),
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
