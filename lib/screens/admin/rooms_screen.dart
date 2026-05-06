import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  String selectedFilter = 'ทั้งหมด';

  @override
  Widget build(BuildContext context) {
    final filteredRooms = MockData.rooms.where((room) {
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'มีคนอยู่') return room.status == RoomStatus.occupied;
      if (selectedFilter == 'ว่าง') return room.status == RoomStatus.vacant;
      if (selectedFilter == 'ซ่อมบำรุง') return room.status == RoomStatus.maintenance;
      return true;
    }).toList();

    return Scaffold(
      appBar: const MobileHeader(subtitle: 'ห้องพัก'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ห้องพักทั้งหมด (${MockData.rooms.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                PrimaryButton(
                  label: 'เพิ่มผู้พักอาศัย',
                  icon: Icons.add,
                  onPressed: () => _showAddTenantDialog(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['ทั้งหมด', 'มีคนอยู่', 'ว่าง', 'ซ่อมบำรุง'].map((filter) {
                final isActive = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (val) => setState(() => selectedFilter = filter),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.primary,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(color: isActive ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredRooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final room = filteredRooms[index];
                return _RoomCard(room: room);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTenantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มผู้พักอาศัยใหม่'),
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'เลือกห้องว่าง'),
              items: MockData.rooms
                  .where((r) => r.status == RoomStatus.vacant)
                  .map((r) => DropdownMenuItem(value: r.id, child: Text(r.id)))
                  .toList(),
              onChanged: (val) {},
            ),
            const TextField(decoration: InputDecoration(labelText: 'ชื่อผู้พักอาศัย')),
            const TextField(decoration: InputDecoration(labelText: 'เบอร์โทร')),
            const SizedBox(height: 24),
            PrimaryButton(label: 'บันทึก', fullWidth: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;

  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant;
    String statusText;

    switch (room.status) {
      case RoomStatus.occupied:
        variant = BadgeVariant.primary;
        statusText = 'มีคนอยู่';
        break;
      case RoomStatus.vacant:
        variant = BadgeVariant.success;
        statusText = 'ว่าง';
        break;
      case RoomStatus.maintenance:
        variant = BadgeVariant.destructive;
        statusText = 'ซ่อมบำรุง';
        break;
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ห้อง ${room.id}', style: Theme.of(context).textTheme.titleMedium),
              StatusBadge(label: statusText, variant: variant),
            ],
          ),
          const SizedBox(height: 8),
          if (room.status == RoomStatus.occupied) ...[
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(room.tenantName ?? '', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(room.phoneNumber ?? '', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ] else if (room.status == RoomStatus.maintenance) ...[
            const Row(
              children: [
                Icon(Icons.build_outlined, size: 16, color: AppColors.destructive),
                SizedBox(width: 8),
                Text('อยู่ระหว่างซ่อมบำรุง', style: TextStyle(color: AppColors.destructive, fontSize: 14)),
              ],
            ),
          ],
          const Align(
            alignment: Alignment.bottomRight,
            child: Text('฿3,500/เดือน', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
