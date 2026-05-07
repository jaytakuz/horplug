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
  bool _isAssigningTenant = false;
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
                label: 'เพิ่มผู้พักอาศัย',
                icon: Icons.person_add_alt_1,
                onPressed: _rooms.any((room) => room.status == RoomStatus.vacant)
                    ? () => _showAssignTenantDialog(context)
                    : null,
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
        const SnackBar(
          content: Text('ไม่พบ tenant ที่ยังไม่ได้ผูกห้องใน tenant_profiles'),
        ),
      );
      return;
    }

    Room? selectedRoom = vacantRooms.first;
    Tenant? selectedTenant = _availableTenants.first;
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('เพิ่มผู้พักอาศัยเข้ากับห้อง'),
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              DropdownButtonFormField<Tenant>(
                initialValue: selectedTenant,
                decoration: const InputDecoration(labelText: 'เลือก tenant profile'),
                items: _availableTenants
                    .map((tenant) => DropdownMenuItem<Tenant>(
                          value: tenant,
                          child: Text('${tenant.name} (${tenant.phoneNumber})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedTenant = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isAssigningTenant ? 'กำลังบันทึก...' : 'บันทึก',
                fullWidth: true,
                onPressed: _isAssigningTenant || selectedRoom == null || selectedTenant == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(dialogContext);

                        setDialogState(() {
                          _isAssigningTenant = true;
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
                            SnackBar(
                              content: Text(
                                'เพิ่ม ${selectedTenant!.name} เข้ากับห้อง ${selectedRoom!.id} แล้ว',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;

                          messenger.showSnackBar(
                            SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isAssigningTenant = false;
                            });
                          }
                        }
                      },
              ),
            ],
          ),
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
