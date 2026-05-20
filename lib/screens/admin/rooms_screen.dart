import 'dart:math';

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
  String selectedFloor = 'ทั้งหมด';
  String selectedPaymentStatus = 'ทั้งหมด';
  final List<String> _paymentStatusFilters = [
    'ทั้งหมด',
    'ชำระแล้ว',
    'รอดำเนินการ',
    'ค้างชำระ',
  ];
  bool _isLoading = true;
  bool _isUpdatingTenant = false;
  String? _errorMessage;
  List<Room> _rooms = [];
  List<Tenant> _availableTenants = [];
  Set<String> _floors = {};

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
      final floors = rooms.map((room) => room.floor).toSet();

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _availableTenants = tenants;
        _floors = floors;
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

  /// ฟิลเตอร์ห้องตามเงื่อนไข
  List<Room> _getFilteredRooms() {
    return _rooms.where((room) {
      // ฟิลเตอร์ตามชั้น
      if (selectedFloor != 'ทั้งหมด' && room.floor != selectedFloor)
        return false;

      // ฟิลเตอร์ตามสถานะ
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'มีคนอยู่')
        return room.status == RoomStatus.occupied;
      if (selectedFilter == 'ว่าง') return room.status == RoomStatus.vacant;
      if (selectedFilter == 'ซ่อมบำรุง')
        return room.status == RoomStatus.maintenance;
      return true;
    }).toList();
  }

  /// คำนวณสถิติห้องพัก
  Map<String, int> _calculateRoomStats() {
    final filtered = _getFilteredRooms();
    return {
      'occupied': filtered.where((r) => r.status == RoomStatus.occupied).length,
      'vacant': filtered.where((r) => r.status == RoomStatus.vacant).length,
      'maintenance':
          filtered.where((r) => r.status == RoomStatus.maintenance).length,
      'total': filtered.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _getFilteredRooms();
    final stats = _calculateRoomStats();

    return _buildBody(context, filteredRooms, stats);
  }

  Widget _buildBody(
      BuildContext context, List<Room> filteredRooms, Map<String, int> stats) {
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
              const Icon(Icons.error_outline,
                  color: AppColors.destructive, size: 32),
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

    if (_rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.home_work_outlined,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 16),
              Text(
                'ยังไม่มีข้อมูลห้องพัก',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'เริ่มต้นโดยการเพิ่มห้องพักใหม่',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'เพิ่มห้องพัก',
                icon: Icons.add,
                onPressed: () => _showAddRoomDialog(context),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ส่วนสรุปสถิติห้องพัก
            _buildRoomStatsSection(context, stats),

            // ส่วนฟิลเตอร์
            _buildFilterSection(context),

            // ส่วนแสดงรายการห้องพัก
            _buildRoomsListSection(context, filteredRooms),
          ],
        ),
      ),
    );
  }

  /// สร้างส่วนสถิติห้องพัก
  Widget _buildRoomStatsSection(BuildContext context, Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'ห้องพักทั้งหมด (${stats['total']})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  PrimaryButton(
                    label: 'เพิ่มห้อง',
                    icon: Icons.add,
                    onPressed: () => _showAddRoomDialog(context),
                  ),
                  PrimaryButton(
                    label: 'จัดการ',
                    icon: Icons.people_alt_outlined,
                    onPressed: () => _showTenantManagementSheet(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick stats grid
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.5,
                  children: [
                    _buildStatTile(context, 'ทั้งหมด', stats['total'].toString(),
                        AppColors.primary),
                    _buildStatTile(context, 'มีคนอยู่',
                        stats['occupied'].toString(), AppColors.primary),
                    _buildStatTile(context, 'ว่าง', stats['vacant'].toString(),
                        AppColors.success),
                    _buildStatTile(context, 'ซ่อมบำรุง',
                        stats['maintenance'].toString(), AppColors.destructive),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// สร้าง Stat Tile เล็กๆ
  Widget _buildStatTile(
      BuildContext context, String label, String value, Color color) {
    return PaperCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  overflow: TextOverflow.ellipsis,
                  color: AppColors.mutedForeground,
                ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  /// สร้างส่วนฟิลเตอร์
  Widget _buildFilterSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ฟิลเตอร์ตามชั้น',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ทั้งหมด', ..._floors.toList()..sort()].map((floor) {
                final isActive = selectedFloor == floor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(floor),
                    selected: isActive,
                    onSelected: (val) => setState(() => selectedFloor = floor),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.primary,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color:
                              isActive ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text('ฟิลเตอร์ตามสถานะ',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['ทั้งหมด', 'มีคนอยู่', 'ว่าง', 'ซ่อมบำรุง'].map((filter) {
                final isActive = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (val) =>
                        setState(() => selectedFilter = filter),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.primary,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color:
                              isActive ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text('ฟิลเตอร์ตามสถานะการชำระเงิน',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _paymentStatusFilters.map((filter) {
                final isActive = selectedPaymentStatus == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isActive,
                    onSelected: (val) => setState(
                        () => selectedPaymentStatus = filter),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.white : AppColors.primary,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                          color:
                              isActive ? AppColors.primary : AppColors.border),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          if (selectedPaymentStatus != 'ทั้งหมด') ...[
            const SizedBox(height: 8),
            Text(
              'ระบบยังไม่รองรับการกรองสถานะการชำระเงินเต็มรูปแบบในหน้านี้',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// สร้างส่วนแสดงรายการห้องพัก
  Widget _buildRoomsListSection(
      BuildContext context, List<Room> filteredRooms) {
    if (filteredRooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.search_off,
                color: AppColors.mutedForeground, size: 40),
            const SizedBox(height: 12),
            Text(
              'ไม่พบห้องพักตามเงื่อนไขที่เลือก',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredRooms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final room = filteredRooms[index];
          return _RoomCard(
            room: room,
            onStatusUpdate: () => _loadData(),
          );
        },
      ),
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
              Text('จัดการผู้พัก',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1,
                    color: AppColors.primary),
                title: const Text('เพิ่มผู้พักอาศัย'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showAssignTenantDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1,
                    color: AppColors.destructive),
                title: const Text('ลบผู้พักอาศัย'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRemoveTenantDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home_repair_service,
                    color: AppColors.primary),
                title: const Text('จัดการราคา'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRoomConfigDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignTenantDialog(BuildContext context) {
    final vacantRooms =
        _rooms.where((room) => room.status == RoomStatus.vacant).toList();

    if (vacantRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีห้องว่างสำหรับเพิ่มผู้พักอาศัย')),
      );
      return;
    }

    if (_availableTenants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('ไม่พบ tenant ที่ยังไม่ได้ผูกห้องใน tenant_profiles')),
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
                        _TenantDetailRow(
                            label: 'ชื่อ', value: selectedTenant!.name),
                        _TenantDetailRow(
                            label: 'เบอร์โทร',
                            value: selectedTenant!.phoneNumber),
                        _TenantDetailRow(
                            label: 'อีเมล',
                            value: selectedTenant!.email ?? '-'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isUpdatingTenant ? 'กำลังบันทึก...' : 'บันทึก',
                  fullWidth: true,
                  onPressed: _isUpdatingTenant ||
                          selectedRoom == null ||
                          selectedTenant == null
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
                              SnackBar(
                                  content: Text(
                                      'เพิ่ม ${selectedTenant!.name} เข้าห้อง ${selectedRoom!.id} แล้ว')),
                            );
                          } catch (error) {
                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text('บันทึกไม่สำเร็จ: $error')),
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
    final occupiedRooms =
        _rooms.where((room) => room.status == RoomStatus.occupied).toList();

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
                  decoration: const InputDecoration(
                      labelText: 'เลือกห้องที่มีผู้พักอาศัย'),
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
                        _TenantDetailRow(
                            label: 'ห้อง', value: selectedRoom!.id),
                        _TenantDetailRow(
                            label: 'ชั้น', value: selectedRoom!.floor),
                        _TenantDetailRow(
                            label: 'ชื่อ',
                            value: selectedRoom!.tenantName ?? '-'),
                        _TenantDetailRow(
                            label: 'เบอร์โทร',
                            value: selectedRoom!.phoneNumber ?? '-'),
                        _TenantDetailRow(
                            label: 'อีเมล',
                            value: selectedRoom!.tenantEmail ?? '-'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label:
                      _isUpdatingTenant ? 'กำลังลบ...' : 'ยืนยันลบออกจากห้อง',
                  fullWidth: true,
                  onPressed: _isUpdatingTenant || selectedRoom == null
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);

                          setDialogState(() {
                            _isUpdatingTenant = true;
                          });

                          try {
                            await _service.removeTenantFromRoom(
                                roomDbId: selectedRoom!.dbId);

                            if (!mounted) return;

                            navigator.pop();
                            await _loadData();

                            if (!mounted) return;

                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'ลบผู้พักอาศัยออกจากห้อง ${selectedRoom!.id} แล้ว')),
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

  /// แสดง dialog สำหรับจัดการราคาและกำหนดค่าห้องพัก
  void _showRoomConfigDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = min(420.0, MediaQuery.of(dialogContext).size.width - 48);
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('จัดการราคาและกำหนดค่า'),
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
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ฟิลเตอร์ห้องที่จะแก้ไข',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'จำนวนห้องพักทั้งหมด: ${_rooms.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาเฉลี่ย: ฿${(_rooms.isEmpty ? 0 : _rooms.fold<double>(0, (prev, room) => prev + room.price) / _rooms.length).toStringAsFixed(0)}/เดือน',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาสูงสุด: ฿${(_rooms.isEmpty ? 0 : _rooms.map((r) => r.price).reduce((a, b) => a > b ? a : b)).toStringAsFixed(0)}/เดือน',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาต่ำสุด: ฿${(_rooms.isEmpty ? 0 : _rooms.map((r) => r.price).reduce((a, b) => a < b ? a : b)).toStringAsFixed(0)}/เดือน',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '💡 เคล็ดลับ: คลิกที่ห้องเพื่อแก้ไขราคาของห้องนั้น',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'ปิด',
                    fullWidth: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// แสดง dialog สำหรับเพิ่มห้องพักใหม่
  void _showAddRoomDialog(BuildContext context) {
    final roomNumberController = TextEditingController();
    final basePriceController = TextEditingController();
    String selectedFloor = _floors.isNotEmpty ? _floors.first : 'ชั้น 1';
    bool isLoading = false;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final dialogWidth = min(420.0, MediaQuery.of(dialogContext).size.width - 48);
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('เพิ่มห้องพักใหม่'),
              IconButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.primary),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message display
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.destructiveBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.destructive.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.destructive, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
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
                  ],
                  // Room Number Field
                  TextField(
                    controller: roomNumberController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'เลขห้อง *',
                      hintText: 'เช่น 101, A1, R101',
                      prefixIcon: Icon(Icons.door_front_door_outlined),
                    ),
                    onChanged: (_) => setDialogState(() => errorMessage = null),
                  ),
                  const SizedBox(height: 16),
                  // Floor Selection Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedFloor,
                    decoration: const InputDecoration(
                      labelText: 'ชั้น *',
                      prefixIcon: Icon(Icons.layers_outlined),
                    ),
                    items: [..._floors.toList()..sort(), 'ชั้น 1', 'ชั้น 2', 'ชั้น 3']
                        .toSet()
                        .toList()
                        .map((floor) => DropdownMenuItem<String>(
                              value: floor,
                              child: Text(floor),
                            ))
                        .toList(),
                    onChanged: isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(
                                  () => selectedFloor = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  // Base Price Field
                  TextField(
                    controller: basePriceController,
                    enabled: !isLoading,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'ราคาห้องพัก (บาท/เดือน) *',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    onChanged: (_) => setDialogState(() => errorMessage = null),
                  ),
                  const SizedBox(height: 24),
                  // Submit Button
                  PrimaryButton(
                    label: isLoading ? 'กำลังบันทึก...' : 'เพิ่มห้องพัก',
                    fullWidth: true,
                    isLoading: isLoading,
                    onPressed: isLoading
                        ? null
                        : () async {
                            setDialogState(() => errorMessage = null);

                            final roomNumber = roomNumberController.text.trim();
                            final basePriceStr =
                                basePriceController.text.trim();

                            // Validation
                            if (roomNumber.isEmpty ||
                                basePriceStr.isEmpty) {
                              setDialogState(() {
                                errorMessage =
                                    'กรุณากรอกข้อมูลที่จำเป็นทั้งหมด';
                              });
                              return;
                            }

                            final basePrice =
                                double.tryParse(basePriceStr);
                            if (basePrice == null || basePrice < 0) {
                              setDialogState(() {
                                errorMessage = 'ราคาไม่ถูกต้อง';
                              });
                              return;
                            }

                            setDialogState(() => isLoading = true);

                            try {
                              // Add room to database
                              await _service.addRoom(
                                roomNumber: roomNumber,
                                floor: selectedFloor,
                                basePrice: basePrice,
                              );

                              if (!mounted) return;

                              Navigator.of(dialogContext).pop();
                              await _loadData();

                              if (!mounted) return;

                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'เพิ่มห้อง $roomNumber สำเร็จ'),
                                ),
                              );
                            } catch (error) {
                              final errorMsg = error.toString();
                              if (errorMsg.contains('already exists')) {
                                setDialogState(() {
                                  errorMessage =
                                      'เลขห้องนี้มีอยู่แล้ว';
                                });
                              } else {
                                setDialogState(() {
                                  errorMessage = 'การเพิ่มห้องไม่สำเร็จ: $error';
                                });
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(() => isLoading = false);
                              }
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
  final VoidCallback? onStatusUpdate;

  const _RoomCard({required this.room, this.onStatusUpdate});

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

    return Tooltip(
      message:
          'ห้อง ${room.id}\nชั้น ${room.floor}\n${_getStatusText(room.status)}\nราคา ฿${room.price.toStringAsFixed(0)}/เดือน',
      waitDuration: const Duration(milliseconds: 350),
      child: PaperCard(
        onTap: () => _showRoomDetailDialog(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header: Room ID and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ห้อง ${room.id}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'ชั้น ${room.floor}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: statusText, variant: variant),
            ],
          ),
          const SizedBox(height: 12),

          // Tenant Info or Maintenance Status
          if (room.status == RoomStatus.occupied) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          room.tenantName ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(room.phoneNumber ?? '-',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  if (room.tenantEmail != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            room.tenantEmail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (room.status == RoomStatus.maintenance) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructiveBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.destructive.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.build_outlined,
                      size: 16, color: AppColors.destructive),
                  const SizedBox(width: 8),
                  Text(
                    'อยู่ระหว่างซ่อมบำรุง',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.destructive,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Room Price and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _showEditRoomPriceDialog(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ราคาห้องพัก',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '฿${room.price.toStringAsFixed(0)}/เดือน',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.primary),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showRoomDetailDialog(context);
                  } else if (value == 'status') {
                    _showRoomStatusDialog(context);
                  } else if (value == 'price') {
                    _showEditRoomPriceDialog(context);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('ดูรายละเอียด'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(Icons.update, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('เปลี่ยนสถานะ'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'price',
                    child: Row(
                      children: [
                        Icon(Icons.attach_money,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('แก้ไขราคา'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  /// แสดง dialog รายละเอียดห้องพัก
  void _showRoomDetailDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = min(420.0, MediaQuery.of(dialogContext).size.width - 48);
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('รายละเอียดห้อง ${room.id}'),
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
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('ห้องเลขที่', room.id),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showEditRoomNumberDialog(context);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('แก้ไขเลขห้อง'),
                    ),
                  ),
                  _detailRow('ชั้น', room.floor),
                  _detailRow('ราคา', '฿${room.price.toStringAsFixed(0)}/เดือน'),
                  _detailRow('สถานะ', _getStatusText(room.status)),
                  if (room.status == RoomStatus.occupied) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'ข้อมูลผู้พักอาศัย',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _detailRow('ชื่อ', room.tenantName ?? '-'),
                    _detailRow('เบอร์โทร', room.phoneNumber ?? '-'),
                    _detailRow('อีเมล', room.tenantEmail ?? '-'),
                  ],
                  // Delete button section for vacant rooms
                  if (room.status == RoomStatus.vacant) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _showDeleteRoomDialog(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบห้องพัก'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.destructive,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// แสดง dialog แก้ไขเลขห้อง
  void _showEditRoomNumberDialog(BuildContext context) {
    final roomNumberController = TextEditingController(text: room.id);
    bool isLoading = false;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('แก้ไขเลขห้อง'),
              IconButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.primary),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.destructiveBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.destructive.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.destructive, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
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
                ],
                TextField(
                  controller: roomNumberController,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'เลขห้องใหม่',
                    prefixIcon: Icon(Icons.door_front_door_outlined),
                  ),
                  onChanged: (_) => setDialogState(() => errorMessage = null),
                ),
                const SizedBox(height: 12),
                Text(
                  'การแก้ไขเลขห้องอาจส่งผลถึงประวัติการเช่าและใบแจ้งหนี้ย้อนหลัง โปรดยืนยันก่อนบันทึก',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: isLoading ? 'กำลังบันทึก...' : 'บันทึกการเปลี่ยนแปลง',
                  fullWidth: true,
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newRoomNumber =
                              roomNumberController.text.trim();

                          if (newRoomNumber.isEmpty) {
                            setDialogState(() {
                              errorMessage = 'กรุณากรอกเลขห้องใหม่';
                            });
                            return;
                          }

                          if (newRoomNumber == room.id) {
                            setDialogState(() {
                              errorMessage = 'เลขห้องใหม่ต้องแตกต่างจากเดิม';
                            });
                            return;
                          }

                          final confirmed = await showDialog<bool>(
                            context: dialogContext,
                            builder: (confirmContext) => AlertDialog(
                              backgroundColor: AppColors.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              title: const Text('ยืนยันการเปลี่ยนเลขห้อง'),
                              content: const Text(
                                'การเปลี่ยนเลขห้องอาจส่งผลต่อประวัติการเช่าและใบแจ้งหนี้ย้อนหลัง หากต้องการเปลี่ยนหมายเลขห้อง โปรดยืนยัน',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(confirmContext).pop(false),
                                  child: const Text('ยกเลิก'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(confirmContext).pop(true),
                                  child: const Text('ยืนยัน'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          setDialogState(() => isLoading = true);

                          try {
                            await SupabaseService().updateRoomNumber(
                              roomDbId: room.dbId,
                              newRoomNumber: newRoomNumber,
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();
                            onStatusUpdate?.call();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'เปลี่ยนเลขห้อง ${room.id} เป็น $newRoomNumber เรียบร้อยแล้ว'),
                              ),
                            );
                          } catch (error) {
                            setDialogState(() {
                              final message = error.toString();
                              if (message.contains('กำลังถูกใช้งาน')) {
                                errorMessage = 'หมายเลขห้องนี้ถูกใช้งานอยู่แล้ว';
                              } else {
                                errorMessage = 'เปลี่ยนเลขห้องไม่สำเร็จ: $error';
                              }
                            });
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isLoading = false);
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

  /// แสดง dialog ยืนยันการลบห้องพัก
  void _showDeleteRoomDialog(BuildContext context) {
    bool isLoading = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ลบห้องพัก'),
              IconButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.primary),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.destructiveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.destructive.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_outlined,
                          color: AppColors.destructive, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'คุณต้องการลบห้องนี้ใช่หรือไม่? ข้อมูลประวัติการเงินและการเช่าในอดีตจะยังคงถูกเก็บไว้เพื่อการทำบัญชี แต่ห้องนี้จะไม่แสดงบนแผนผังอีกต่อไป',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.destructive,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ห้อง ${room.id}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.muted,
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setDialogState(() => isLoading = true);

                            try {
                              final service = SupabaseService();
                              await service.deleteRoom(roomDbId: room.dbId);

                              if (!dialogContext.mounted) return;

                              Navigator.of(dialogContext).pop();
                              onStatusUpdate?.call();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'ลบห้อง ${room.id} สำเร็จ'),
                                ),
                              );
                            } catch (error) {
                              if (!dialogContext.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'ลบห้องไม่สำเร็จ: $error'),
                                ),
                              );
                              Navigator.of(dialogContext).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                        isLoading ? 'กำลังลบ...' : 'ยืนยันลบห้องพัก'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// แสดง dialog เปลี่ยนสถานะห้องพัก
  void _showRoomStatusDialog(BuildContext context) {
    bool isLoading = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('เปลี่ยนสถานะห้อง ${room.id}'),
              IconButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.primary),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สถานะปัจจุบัน: ${_getStatusText(room.status)}',
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label:
                        isLoading ? 'กำลังบันทึก...' : 'เปลี่ยนเป็น มีคนอยู่',
                    isLoading: isLoading && room.status != RoomStatus.occupied,
                    onPressed: isLoading || room.status == RoomStatus.occupied
                        ? null
                        : () async {
                            setDialogState(() => isLoading = true);
                            await _updateRoomStatus(
                                context, RoomStatus.occupied);
                            if (dialogContext.mounted)
                              Navigator.of(dialogContext).pop();
                          },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: isLoading ? 'กำลังบันทึก...' : 'เปลี่ยนเป็น ว่าง',
                    isLoading: isLoading && room.status != RoomStatus.vacant,
                    onPressed: isLoading || room.status == RoomStatus.vacant
                        ? null
                        : () async {
                            setDialogState(() => isLoading = true);
                            await _updateRoomStatus(context, RoomStatus.vacant);
                            if (dialogContext.mounted)
                              Navigator.of(dialogContext).pop();
                          },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label:
                        isLoading ? 'กำลังบันทึก...' : 'เปลี่ยนเป็น ซ่อมบำรุง',
                    isLoading:
                        isLoading && room.status != RoomStatus.maintenance,
                    onPressed:
                        isLoading || room.status == RoomStatus.maintenance
                            ? null
                            : () async {
                                setDialogState(() => isLoading = true);
                                await _updateRoomStatus(
                                    context, RoomStatus.maintenance);
                                if (dialogContext.mounted)
                                  Navigator.of(dialogContext).pop();
                              },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// อัปเดตสถานะห้องพัก (placeholder)
  Future<void> _updateRoomStatus(
      BuildContext context, RoomStatus newStatus) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // ใช้ Supabase service เพื่ออัปเดตสถานะ
      final service = SupabaseService();
      await service.updateRoomStatus(
        roomDbId: room.dbId,
        newStatus: newStatus,
      );

      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'เปลี่ยนสถานะห้อง ${room.id} เป็น ${_getStatusText(newStatus)} แล้ว')),
      );
      onStatusUpdate?.call();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ: $error')),
      );
    }
  }

  /// Widget ช่วยแสดง detail row
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                const TextStyle(color: AppColors.mutedForeground, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// ดึงข้อความสถานะในภาษาไทย
  String _getStatusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.occupied:
        return 'มีคนอยู่';
      case RoomStatus.vacant:
        return 'ว่าง';
      case RoomStatus.maintenance:
        return 'ซ่อมบำรุง';
    }
  }

  /// แสดง dialog แก้ไขราคาห้องพัก
  void _showEditRoomPriceDialog(BuildContext context) {
    double newPrice = room.price;
    bool isLoading = false;
    final priceController =
        TextEditingController(text: room.price.toStringAsFixed(0));

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('แก้ไขราคาห้อง ${room.id}'),
              IconButton(
                onPressed:
                    isLoading ? null : () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: AppColors.primary),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ราคาปัจจุบัน: ฿${room.price.toStringAsFixed(0)}/เดือน',
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'ราคาใหม่ (บาท)',
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: '0.00',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      newPrice = double.tryParse(value) ?? room.price;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ราคาใหม่:',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '฿${newPrice.toStringAsFixed(0)}/เดือน',
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: isLoading ? 'กำลังบันทึก...' : 'บันทึกการเปลี่ยนแปลง',
                  fullWidth: true,
                  isLoading: isLoading,
                  onPressed: isLoading || newPrice == room.price
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);
                          final service = SupabaseService();
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            // อัปเดตราคาผ่าน Supabase
                            await service.updateRoomPrice(
                              roomDbId: room.dbId,
                              newPrice: newPrice,
                            );

                            if (dialogContext.mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'เปลี่ยนราคาห้อง ${room.id} เป็น ฿${newPrice.toStringAsFixed(0)}/เดือน แล้ว')),
                              );
                              Navigator.of(dialogContext).pop();
                              onStatusUpdate?.call();
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                    content: Text('บันทึกไม่สำเร็จ: $error')),
                              );
                            }
                          } finally {
                            setDialogState(() => isLoading = false);
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
