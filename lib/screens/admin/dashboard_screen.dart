import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final String dormSlug;

  const DashboardScreen({super.key, required this.dormSlug});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _service = SupabaseService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Room> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _service.fetchRooms();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final occupiedRooms = _rooms.where((room) => room.status == RoomStatus.occupied).toList();
    final occupiedCount = occupiedRooms.length;
    final totalRooms = _rooms.length;
    final occupancyRate = totalRooms == 0 ? 0 : ((occupiedCount / totalRooms) * 100).round();
    final estimatedMonthlyRevenue = occupiedRooms.fold<double>(
      0,
      (sum, room) => sum + room.price,
    );
    final floorNumbers = _rooms
        .map((room) => room.floor)
        .toSet()
        .toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return Scaffold(
      appBar: const MobileHeader(subtitle: 'หน้าหลัก'),
      body: _buildBody(
        context,
        occupiedCount: occupiedCount,
        totalRooms: totalRooms,
        occupancyRate: occupancyRate,
        estimatedMonthlyRevenue: estimatedMonthlyRevenue,
        floorNumbers: floorNumbers,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required int occupiedCount,
    required int totalRooms,
    required int occupancyRate,
    required double estimatedMonthlyRevenue,
    required List<String> floorNumbers,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.destructive, size: 32),
              const SizedBox(height: 12),
              Text(
                'โหลดข้อมูลแดชบอร์ดไม่สำเร็จ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: _loadRooms,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  title: 'รายได้คาดการณ์',
                  value: '฿${estimatedMonthlyRevenue.toStringAsFixed(0)}',
                  subtitle: 'จากห้องที่มีผู้พักอาศัย',
                  icon: Icons.account_balance_wallet,
                  variant: BadgeVariant.primary,
                ),
                StatCard(
                  title: 'อัตราเข้าพัก',
                  value: '$occupancyRate%',
                  subtitle: '$occupiedCount/$totalRooms ห้อง',
                  icon: Icons.home,
                  variant: BadgeVariant.success,
                ),
                StatCard(
                  title: 'ผู้พักอาศัยทั้งหมด',
                  value: '$occupiedCount',
                  icon: Icons.people,
                ),
                StatCard(
                  title: 'ห้องว่าง',
                  value: '${_rooms.where((room) => room.status == RoomStatus.vacant).length}',
                  icon: Icons.meeting_room_outlined,
                  variant: BadgeVariant.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('แผนผังห้องพัก', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.go('/${widget.dormSlug}/admin/rooms'),
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
                  if (floorNumbers.isEmpty)
                    Text(
                      'ยังไม่มีข้อมูลห้องพัก',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    ...floorNumbers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final floor = entry.value;
                      final roomsOnFloor = _rooms.where((room) => room.floor == floor).toList();

                      return Column(
                        children: [
                          if (index > 0) const SizedBox(height: 16),
                          _buildFloorSection(context, 'ชั้น $floor', roomsOnFloor),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                  onTap: () => context.go('/${widget.dormSlug}/admin/meter'),
                ),
                _QuickActionItem(
                  icon: Icons.receipt_long,
                  label: 'สร้างบิล',
                  color: AppColors.success,
                  badge: '5',
                  onTap: () => context.go('/${widget.dormSlug}/admin/billing'),
                ),
                _QuickActionItem(
                  icon: Icons.description,
                  label: 'สัญญาเช่า',
                  color: AppColors.warning,
                  onTap: () => context.go('/${widget.dormSlug}/admin/lease'),
                ),
                _QuickActionItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'แชท',
                  color: AppColors.ring,
                  badge: '2',
                  onTap: () => context.go('/${widget.dormSlug}/admin/chat'),
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
              room.status == RoomStatus.occupied
                  ? (room.tenantFirstName ?? room.tenantName ?? '')
                  : (room.status == RoomStatus.vacant ? 'ว่าง' : 'ซ่อม'),
              style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 9),
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
                  color: color.withValues(alpha: 0.1),
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
