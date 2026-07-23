import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/dashboard_view_model.dart';
import '../../widgets/reusable_widgets.dart';

class DashboardScreen extends StatelessWidget {
  final int dormitoryId;

  const DashboardScreen({super.key, required this.dormitoryId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel(dormitoryId: dormitoryId)..loadRooms(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DashboardViewModel>();
    return _buildBody(context, viewModel);
  }

  Widget _buildBody(BuildContext context, DashboardViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.destructive, size: 32),
              const SizedBox(height: 12),
              Text(
                'โหลดข้อมูลแดชบอร์ดไม่สำเร็จ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.loadRooms,
              ),
            ],
          ),
        ),
      );
    }

    final floorNumbers = viewModel.floorNumbers;

    return RefreshIndicator(
      onRefresh: viewModel.loadRooms,
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
                  value: '฿${viewModel.estimatedMonthlyRevenue.toStringAsFixed(0)}',
                  subtitle: 'จากห้องที่มีผู้พักอาศัย',
                  icon: Icons.account_balance_wallet,
                  variant: BadgeVariant.primary,
                ),
                StatCard(
                  title: 'อัตราเข้าพัก',
                  value: '${viewModel.occupancyRate}%',
                  subtitle: '${viewModel.occupiedCount}/${viewModel.totalRooms} ห้อง',
                  icon: Icons.home,
                  variant: BadgeVariant.success,
                ),
                StatCard(
                  title: 'ผู้พักอาศัยทั้งหมด',
                  value: '${viewModel.occupiedCount}',
                  icon: Icons.people,
                ),
                StatCard(
                  title: 'ห้องว่าง',
                  value: '${viewModel.vacantCount}',
                  icon: Icons.meeting_room_outlined,
                  variant: BadgeVariant.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('แผนผังห้องพัก',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () =>
                      context.go('/landlord/rooms'),
                  child: const Text('จัดการห้อง →',
                      style: TextStyle(color: AppColors.ring)),
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
                      final roomsOnFloor = viewModel.roomsOnFloor(floor);

                      return Column(
                        children: [
                          if (index > 0) const SizedBox(height: 16),
                          _buildFloorSection(
                              context, viewModel, 'ชั้น $floor', roomsOnFloor),
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
                  onTap: () => context.go('/landlord/meter'),
                ),
                _QuickActionItem(
                  icon: Icons.receipt_long,
                  label: 'สร้างบิล',
                  color: AppColors.success,
                  badge: '5',
                  onTap: () => context.go('/landlord/billing'),
                ),
                _QuickActionItem(
                  icon: Icons.description,
                  label: 'สัญญาเช่า',
                  color: AppColors.warning,
                  onTap: () => context.go('/landlord/lease'),
                ),
                _QuickActionItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'แชท',
                  color: AppColors.ring,
                  badge: viewModel.unreadMessageCount > 0
                      ? '${viewModel.unreadMessageCount}'
                      : null,
                  onTap: () => context.go('/landlord/chat'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorSection(BuildContext context, DashboardViewModel viewModel,
      String floorTitle, List<Room> rooms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(floorTitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms
              .map((room) => _RoomTile(
                    room: room,
                    onTap: () =>
                        _showRoomDetailDialog(context, viewModel, room),
                  ))
              .toList(),
        ),
      ],
    );
  }

  void _showRoomDetailDialog(
      BuildContext context, DashboardViewModel viewModel, Room room) {
    String statusText;

    switch (room.status) {
      case RoomStatus.occupied:
        statusText = 'มีคนอยู่';
        break;
      case RoomStatus.vacant:
        statusText = 'ว่าง';
        break;
      case RoomStatus.maintenance:
        statusText = 'ซ่อมบำรุง';
        break;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'รายละเอียดห้อง ${room.id}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: AppColors.primary),
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TenantDetailRow(label: 'ห้อง', value: room.id),
              _TenantDetailRow(label: 'ชั้น', value: room.floor),
              _TenantDetailRow(label: 'สถานะ', value: statusText),
              _TenantDetailRow(
                  label: 'ราคา',
                  value: '฿${room.price.toStringAsFixed(0)}/เดือน'),
              if (room.status == RoomStatus.occupied) ...[
                const SizedBox(height: 12),
                Text(
                  'รายละเอียดผู้พักอาศัย',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TenantDetailRow(
                          label: 'ชื่อ', value: room.tenantName ?? '-'),
                      _TenantDetailRow(
                          label: 'เบอร์โทร', value: room.phoneNumber ?? '-'),
                      _TenantDetailRow(
                          label: 'อีเมล', value: room.tenantEmail ?? '-'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'เพิ่มผู้พักอาศัย',
                      icon: Icons.person_add_alt_1,
                      onPressed: room.status == RoomStatus.vacant &&
                              viewModel.availableTenants.isNotEmpty
                          ? () {
                              Navigator.of(dialogContext).pop();
                              _showAssignTenantDialog(context, viewModel, room);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: room.status == RoomStatus.occupied
                          ? () {
                              Navigator.of(dialogContext).pop();
                              _showRemoveTenantDialog(context, viewModel, room);
                            }
                          : null,
                      icon: const Icon(Icons.person_remove_alt_1),
                      label: const Text('ลบผู้พักอาศัย'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignTenantDialog(
      BuildContext context, DashboardViewModel viewModel, Room room) {
    if (room.status != RoomStatus.vacant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีห้องว่างสำหรับเพิ่มผู้พักอาศัย')),
      );
      return;
    }

    if (viewModel.availableTenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบผู้พักอาศัย')),
      );
      return;
    }

    Tenant? selectedTenant;
    final searchController = TextEditingController();
    var filteredTenants = <Tenant>[];
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'เพิ่มผู้พักอาศัย',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close, color: AppColors.primary),
                        splashRadius: 20,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TenantDetailRow(label: 'ห้อง', value: room.id),
                  _TenantDetailRow(label: 'ชั้น', value: room.floor),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppColors.primary),
                    decoration: const InputDecoration(
                      labelText: 'ค้นหาผู้พักอาศัยด้วยชื่อ',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        final keyword = value.trim().toLowerCase();
                        if (keyword.isEmpty) {
                          filteredTenants = [];
                        } else {
                          filteredTenants =
                              viewModel.availableTenants.where((tenant) {
                            return tenant.name.toLowerCase().contains(keyword);
                          }).toList();
                        }

                        if (selectedTenant != null &&
                            !filteredTenants.any(
                                (tenant) => tenant.id == selectedTenant!.id)) {
                          selectedTenant = null;
                        }
                      });
                    },
                  ),
                  if (searchController.text.isNotEmpty &&
                      filteredTenants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredTenants.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tenant = filteredTenants[index];
                          final isSelected = selectedTenant?.id == tenant.id;

                          return ListTile(
                            dense: true,
                            title: Text(tenant.name),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.primary)
                                : null,
                            selected: isSelected,
                            selectedTileColor: AppColors.muted,
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selectedTenant = null;
                                } else {
                                  selectedTenant = tenant;
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: viewModel.isUpdatingTenant
                        ? 'กำลังส่งคำขอ...'
                        : 'ส่งคำขอ',
                    fullWidth: true,
                    onPressed: viewModel.isUpdatingTenant || selectedTenant == null
                        ? null
                        : () async {
                            final navigator = Navigator.of(dialogContext);
                            final landlordId = AuthScope.of(context).profile?.id;

                            final result = await viewModel.createTenantJoinRequest(
                              landlordId: landlordId,
                              room: room,
                              tenant: selectedTenant!,
                            );

                            if (!context.mounted) return;

                            if (result.success) {
                              navigator.pop();
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRemoveTenantDialog(
      BuildContext context, DashboardViewModel viewModel, Room room) {
    if (room.status != RoomStatus.occupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีห้องที่มีผู้พักอาศัยให้ลบออก')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'ลบผู้พักอาศัยออกจากห้อง',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: viewModel.isUpdatingTenant
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: AppColors.primary),
                      splashRadius: 20,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.destructiveBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.warning_rounded,
                          color: AppColors.destructive,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'คุณต้องการลบผู้พักอาศัยออกจากห้องนี้ใช่หรือไม่? ห้องนี้จะกลับเป็นห้องว่างและไม่ผูกกับผู้เช่าคนเดิมอีกต่อไป',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.destructive,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'รายละเอียดผู้พักอาศัยในห้อง',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TenantDetailRow(label: 'ห้อง', value: room.id),
                      _TenantDetailRow(label: 'ชั้น', value: room.floor),
                      _TenantDetailRow(
                          label: 'ชื่อ', value: room.tenantName ?? '-'),
                      _TenantDetailRow(
                          label: 'เบอร์โทร', value: room.phoneNumber ?? '-'),
                      _TenantDetailRow(
                          label: 'อีเมล', value: room.tenantEmail ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: viewModel.isUpdatingTenant
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.muted,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: viewModel.isUpdatingTenant
                        ? null
                        : () async {
                            final navigator = Navigator.of(dialogContext);

                            final result =
                                await viewModel.removeTenantFromRoom(room);

                            if (!context.mounted) return;

                            if (result.success) {
                              navigator.pop();
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.destructive.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: viewModel.isUpdatingTenant
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ยืนยันลบผู้พักอาศัย',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _TenantDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _TenantDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomTile({required this.room, required this.onTap});

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

    return Tooltip(
      message:
          'ห้อง ${room.id}\nสถานะ: ${room.status == RoomStatus.occupied ? 'มีคนอยู่' : room.status == RoomStatus.vacant ? 'ว่าง' : 'ซ่อม'}\nราคา ฿${room.price.toStringAsFixed(0)}/เดือน',
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: onTap,
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
              Text(room.id,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                room.status == RoomStatus.occupied
                    ? _shortTenantName(room.tenantName)
                    : (room.status == RoomStatus.vacant ? 'ว่าง' : 'ซ่อม'),
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.8), fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortTenantName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return '';
    return fullName.trim().split(RegExp(r'\s+')).first;
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
                    decoration: const BoxDecoration(
                        color: AppColors.destructive, shape: BoxShape.circle),
                    child: Text(badge!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
