import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final SupabaseService _service = SupabaseService();
  String selectedFilter = 'ทั้งหมด';
  bool _isLoading = true;
  bool _isUpdatingTenant = false;
  String? _errorMessage;
  List<Room> _rooms = [];
  List<Tenant> _availableTenants = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _service.fetchRooms();
      final tenants = await _service.fetchAvailableTenants();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _availableTenants = tenants;
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
    final filteredRooms = _rooms.where((room) {
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'มีคนอยู่') return room.status == RoomStatus.occupied;
      if (selectedFilter == 'ว่าง') return room.status == RoomStatus.vacant;
      if (selectedFilter == 'ซ่อมบำรุง') return room.status == RoomStatus.maintenance;
      return true;
    }).toList();

    return Scaffold(
      appBar: const MobileHeader(subtitle: 'ห้องพัก'),
      body: _buildBody(context, filteredRooms),
    );
  }

  Widget _buildBody(BuildContext context, List<Room> filteredRooms) {
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
                'โหลดข้อมูลห้องพักไม่สำเร็จ',
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
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ห้องพักทั้งหมด (${_rooms.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              PrimaryButton(
                label: 'จัดการผู้พักอาศัย',
                icon: Icons.people_alt_outlined,
                onPressed: () => _showTenantManagementSheet(context),
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
          child: RefreshIndicator(
            onRefresh: _loadData,
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
        ),
      ],
    );
  }

  void _showTenantManagementSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('จัดการผู้พัก', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                title: const Text('เพิ่มผู้พักอาศัย'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showAssignTenantDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1, color: AppColors.destructive),
                title: const Text('ลบผู้พักอาศัย'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRemoveTenantDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignTenantDialog(BuildContext context) {
    final vacantRooms = _rooms.where((room) => room.status == RoomStatus.vacant).toList();

    if (vacantRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีห้องว่างสำหรับเพิ่มผู้พักอาศัย')),
      );
      return;
    }

    if (_availableTenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบ tenant ที่ยังไม่ได้ผูกห้องใน tenant_profiles')),
      );
      return;
    }

    Room? selectedRoom = vacantRooms.first;
    Tenant? selectedTenant;
    final searchController = TextEditingController();
    var filteredTenants = <Tenant>[];
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                        'เพิ่มผู้พักอาศัยเข้ากับห้อง',
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
                DropdownButtonFormField<Room>(
                  initialValue: selectedRoom,
                  decoration: const InputDecoration(labelText: 'เลือกห้องว่าง'),
                  items: vacantRooms
                      .map((room) => DropdownMenuItem<Room>(
                            value: room,
                            child: Text(room.id),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRoom = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: AppColors.primary),
                  decoration: const InputDecoration(
                    labelText: 'ค้นหา tenant profile ด้วยชื่อ',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      final keyword = value.trim().toLowerCase();
                      if (keyword.isEmpty) {
                        filteredTenants = [];
                      } else {
                        filteredTenants = _availableTenants.where((tenant) {
                          return tenant.name.toLowerCase().contains(keyword);
                        }).toList();
                      }

                      if (selectedTenant != null &&
                          !filteredTenants.any((tenant) => tenant.id == selectedTenant!.id)) {
                        selectedTenant = null;
                      }
                    });
                  },
                ),
                if (searchController.text.isNotEmpty && filteredTenants.isNotEmpty) ...[
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
                              ? const Icon(Icons.check_circle, color: AppColors.primary)
                              : null,
                          selected: isSelected,
                          selectedTileColor: AppColors.muted,
                          onTap: () {
                            setDialogState(() {
                              selectedTenant = isSelected ? null : tenant;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (selectedTenant != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'รายละเอียด tenant ที่เลือก',
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
                        _TenantDetailRow(label: 'ชื่อ', value: selectedTenant!.name),
                        _TenantDetailRow(label: 'เบอร์โทร', value: selectedTenant!.phoneNumber),
                        _TenantDetailRow(label: 'อีเมล', value: selectedTenant!.email ?? '-'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isUpdatingTenant ? 'กำลังบันทึก...' : 'บันทึก',
                  fullWidth: true,
                  onPressed: _isUpdatingTenant || selectedRoom == null || selectedTenant == null
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);

                          setDialogState(() {
                            _isUpdatingTenant = true;
                          });

                          try {
                            await _service.assignTenantToRoom(
                              roomDbId: selectedRoom!.dbId,
                              tenantId: selectedTenant!.id,
                            );

                            if (!mounted) return;

                            navigator.pop();
                            await _loadData();

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(content: Text('เพิ่ม ${selectedTenant!.name} เข้าห้อง ${selectedRoom!.id} แล้ว')),
                            );
                          } catch (error) {
                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isUpdatingTenant = false;
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRemoveTenantDialog(BuildContext context) {
    final occupiedRooms = _rooms.where((room) => room.status == RoomStatus.occupied).toList();

    if (occupiedRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีห้องที่มีผู้พักอาศัยให้ลบออก')),
      );
      return;
    }

    Room? selectedRoom = occupiedRooms.first;
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                        'ลบผู้พักอาศัยออกจากห้อง',
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
                DropdownButtonFormField<Room>(
                  initialValue: selectedRoom,
                  decoration: const InputDecoration(labelText: 'เลือกห้องที่มีผู้พักอาศัย'),
                  items: occupiedRooms
                      .map((room) => DropdownMenuItem<Room>(
                            value: room,
                            child: Text(room.id),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRoom = value;
                    });
                  },
                ),
                if (selectedRoom != null) ...[
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
                        _TenantDetailRow(label: 'ห้อง', value: selectedRoom!.id),
                        _TenantDetailRow(label: 'ชั้น', value: selectedRoom!.floor),
                        _TenantDetailRow(label: 'ชื่อ', value: selectedRoom!.tenantName ?? '-'),
                        _TenantDetailRow(label: 'เบอร์โทร', value: selectedRoom!.phoneNumber ?? '-'),
                        _TenantDetailRow(label: 'อีเมล', value: selectedRoom!.tenantEmail ?? '-'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isUpdatingTenant ? 'กำลังลบ...' : 'ยืนยันลบออกจากห้อง',
                  fullWidth: true,
                  onPressed: _isUpdatingTenant || selectedRoom == null
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);

                          setDialogState(() {
                            _isUpdatingTenant = true;
                          });

                          try {
                            await _service.removeTenantFromRoom(roomDbId: selectedRoom!.dbId);

                            if (!mounted) return;

                            navigator.pop();
                            await _loadData();

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(content: Text('ลบผู้พักอาศัยออกจากห้อง ${selectedRoom!.id} แล้ว')),
                            );
                          } catch (error) {
                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(content: Text('ลบไม่สำเร็จ: $error')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isUpdatingTenant = false;
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
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
                Expanded(
                  child: Text(
                    room.tenantName ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                  ),
                
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Text(room.phoneNumber ?? '-', style: Theme.of(context).textTheme.bodySmall),
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
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '฿${room.price.toStringAsFixed(0)}/เดือน',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
