import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/tenant_shell_view_model.dart';
import '../../widgets/reusable_widgets.dart';
import 'tenant_bills_screen.dart';
import 'tenant_chat_screen.dart';
import 'tenant_dashboard_screen.dart';
import 'tenant_maintenance_screen.dart';
import 'tenant_profile_screen.dart';

/// เปลือกนอกของฝั่งผู้เช่า — โครงเดียวกับ AdminShell:
/// ShellRoute ทิ้ง `child` ไป แล้วให้ shell ถือ IndexedStack ของทุกแท็บเอง
/// โดยอ่าน index จาก URL
class TenantShell extends StatelessWidget {
  const TenantShell({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return ChangeNotifierProvider(
      // key ตาม roomId เพื่อให้ ViewModel ถูกสร้างใหม่เมื่อผู้เช่าเพิ่งตอบรับคำขอ
      // เข้าหอ (roomId เปลี่ยนจาก null เป็นค่าจริง)
      key: ValueKey(profile?.roomId),
      create: (_) => TenantShellViewModel(
        roomId: profile?.roomId,
        tenantId: profile?.id,
      )..refreshUnreadCount(),
      child: const _TenantShellView(),
    );
  }
}

class _TenantShellView extends StatefulWidget {
  const _TenantShellView();

  @override
  State<_TenantShellView> createState() => _TenantShellViewState();
}

class _TenantShellViewState extends State<_TenantShellView> {
  int? _lastIndex;

  static const _paths = [
    '/tenant',
    '/tenant/bills',
    '/tenant/maintenance',
    '/tenant/chat',
    '/tenant/profile',
  ];

  static const _sectionTitles = [
    'หน้าหลัก',
    'บิล',
    'แจ้งซ่อม',
    'แชท',
    'โปรไฟล์',
  ];

  static const _chatIndex = 3;

  int _calculateSelectedIndex(String location) {
    if (location.endsWith('/bills')) return 1;
    if (location.endsWith('/maintenance')) return 2;
    if (location.endsWith('/chat')) return 3;
    if (location.endsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    // IndexedStack ไม่ dispose TextField ของแท็บแชท ถ้าไม่ unfocus แป้นพิมพ์
    // จะค้างทับแท็บที่สลับไป
    FocusManager.instance.primaryFocus?.unfocus();

    context.go(_paths[index]);
  }

  /// เคลียร์ badge ตาม "ตำแหน่งที่อยู่จริง" ไม่ใช่ตามการแตะ nav bar —
  /// เข้าแท็บแชทได้อีกสามทาง (การ์ดข้อความบนแดชบอร์ด / ทางลัด / ปุ่มในโปรไฟล์)
  /// ซึ่งไม่ผ่าน _onItemTapped เลย
  void _syncUnreadForIndex(int activeIndex) {
    if (activeIndex == _lastIndex) return;
    _lastIndex = activeIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<TenantShellViewModel>();
      if (activeIndex == _chatIndex) {
        viewModel.markChatRead();
      } else {
        viewModel.refreshUnreadCount();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final viewModel = context.watch<TenantShellViewModel>();
    final location = GoRouterState.of(context).uri.path;
    final activeIndex = _calculateSelectedIndex(location);

    _syncUnreadForIndex(activeIndex);

    final dormName = auth.dormitoryName;
    final headerSubtitle = dormName != null
        ? '$dormName • ${_sectionTitles[activeIndex]}'
        : _sectionTitles[activeIndex];

    return Scaffold(
      appBar: MobileHeader(
        subtitle: headerSubtitle,
        // ไม่ใส่ action ที่นี่ — ปุ่มออกจากระบบอยู่ในแท็บโปรไฟล์ เพื่อลด chrome
        // ที่ต้องแบกไปทุกหน้า
        actions: const [SizedBox.shrink()],
      ),
      body: IndexedStack(
        index: activeIndex,
        children: const [
          TenantDashboardScreen(),
          TenantBillsScreen(),
          TenantMaintenanceScreen(),
          TenantChatScreen(embedded: true),
          TenantProfileScreen(),
        ],
      ),
      // ต่างจาก AdminShell ตรงที่แสดง nav เสมอ แม้ผู้เช่ายังไม่มีห้อง —
      // แท็บโปรไฟล์คือที่ที่ผู้เช่าจะเห็นคำขอเข้าหอของตัวเอง
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: activeIndex,
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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หน้าหลัก',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'บิล',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.build_outlined),
              activeIcon: Icon(Icons.build),
              label: 'แจ้งซ่อม',
            ),
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
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'โปรไฟล์',
            ),
          ],
        ),
      ),
    );
  }
}
