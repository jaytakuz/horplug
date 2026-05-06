import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class DashboardScreen extends StatelessWidget {
  final String dormSlug;

  const DashboardScreen({super.key, required this.dormSlug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MobileHeader(subtitle: 'หน้าหลัก'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1.1 Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: const [
                StatCard(
                  title: 'รายได้เดือนนี้',
                  value: '฿85,500',
                  icon: Icons.account_balance_wallet,
                  variant: BadgeVariant.primary,
                ),
                StatCard(
                  title: 'อัตราเข้าพัก',
                  value: '90%',
                  subtitle: '18/20 ห้อง',
                  icon: Icons.home,
                  variant: BadgeVariant.success,
                ),
                StatCard(
                  title: 'ผู้พักอาศัยทั้งหมด',
                  value: '18',
                  icon: Icons.people,
                ),
                StatCard(
                  title: 'สลิปรอตรวจ',
                  value: '3',
                  icon: Icons.warning_amber,
                  variant: BadgeVariant.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 1.2 Floor Plan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('แผนผังห้องพัก', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.go('/$dormSlug/admin/rooms'),
                  child: const Text('จัดการห้อง →', style: TextStyle(color: AppColors.ring)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _LegendItem(label: 'มีคนอยู่', color: AppColors.primary),
                      SizedBox(width: 12),
                      _LegendItem(label: 'ว่าง', color: AppColors.success),
                      SizedBox(width: 12),
                      _LegendItem(label: 'ซ่อม', color: AppColors.destructive),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFloorSection(context, 'ชั้น 1', MockData.rooms.where((r) => r.floor == '1').toList()),
                  const SizedBox(height: 16),
                  _buildFloorSection(context, 'ชั้น 2', MockData.rooms.where((r) => r.floor == '2').toList()),
                  const SizedBox(height: 16),
                  _buildFloorSection(context, 'ชั้น 3', MockData.rooms.where((r) => r.floor == '3').toList()),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1.3 Quick Actions
            Text('เมนูด่วน', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _QuickActionItem(
                  icon: Icons.speed,
                  label: 'บันทึกมิเตอร์',
                  color: AppColors.primary,
                  onTap: () => context.go('/$dormSlug/admin/meter'),
                ),
                _QuickActionItem(
                  icon: Icons.receipt_long,
                  label: 'สร้างบิล',
                  color: AppColors.success,
                  badge: '5',
                  onTap: () => context.go('/$dormSlug/admin/billing'),
                ),
                _QuickActionItem(
                  icon: Icons.description,
                  label: 'สัญญาเช่า',
                  color: AppColors.warning,
                  onTap: () => context.go('/$dormSlug/admin/lease'),
                ),
                _QuickActionItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'แชท',
                  color: AppColors.ring,
                  badge: '2',
                  onTap: () => context.go('/$dormSlug/admin/chat'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorSection(BuildContext context, String floorTitle, List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(floorTitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms.map((room) => _RoomTile(room: room)).toList(),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;

  const _RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    switch (room.status) {
      case RoomStatus.occupied:
        bgColor = AppColors.primary;
        borderColor = AppColors.primary;
        textColor = Colors.white;
        break;
      case RoomStatus.vacant:
        bgColor = AppColors.successBg;
        borderColor = AppColors.success;
        textColor = AppColors.success;
        break;
      case RoomStatus.maintenance:
        bgColor = AppColors.destructiveBg;
        borderColor = AppColors.destructive;
        textColor = AppColors.destructive;
        break;
    }

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(room.id, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              room.status == RoomStatus.occupied ? (room.tenantName ?? '') : (room.status == RoomStatus.vacant ? 'ว่าง' : 'ซ่อม'),
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (badge != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.destructive, shape: BoxShape.circle),
                    child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
