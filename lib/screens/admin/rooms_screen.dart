import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../viewmodels/action_result.dart';
import '../../viewmodels/rooms_view_model.dart';
import '../../widgets/create_rooms_dialog.dart';
import '../../widgets/reusable_widgets.dart';
import 'maintenance_history_screen.dart';
import '../../utils/formatters.dart';

class RoomsScreen extends StatelessWidget {
  final int dormitoryId;

  const RoomsScreen({super.key, required this.dormitoryId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoomsViewModel(dormitoryId: dormitoryId)
        ..loadData()
        ..startWatchingRoomChanges(),
      child: const _RoomsView(),
    );
  }
}

class _RoomsView extends StatefulWidget {
  const _RoomsView();

  @override
  State<_RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<_RoomsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoomsViewModel>();
    final filteredRooms = viewModel.filteredRooms;
    final stats = viewModel.stats;

    return _buildBody(context, viewModel, filteredRooms, stats);
  }

  Widget _buildBody(BuildContext context, RoomsViewModel viewModel,
      List<Room> filteredRooms, Map<String, int> stats) {
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
                'โหลดข้อมูลห้องพักไม่สำเร็จ',
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
                onPressed: viewModel.loadData,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.rooms.isEmpty) {
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
                'สร้างห้องทั้งตึกรวดเดียว หรือเพิ่มทีละห้องก็ได้',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              // หอที่ยังไม่มีห้องเลยแทบไม่มีใครอยากเพิ่มทีละห้อง ปุ่มหลักจึงเป็น
              // การสร้างทั้งชุด ส่วนการเพิ่มทีละห้องยังอยู่เป็นทางเลือกรอง
              PrimaryButton(
                label: 'สร้างห้องหลายห้อง',
                icon: Icons.grid_view,
                onPressed: () => _openCreateRoomsDialog(context, viewModel),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มทีละห้อง'),
                onPressed: () => _showAddRoomDialog(context, viewModel),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ContentBounds(
          gutter: 0,
          child: Column(
            children: [
              _buildRoomStatsSection(context, viewModel, stats),
              _buildFilterSection(context, viewModel),
              _buildRoomsListSection(context, viewModel, filteredRooms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomStatsSection(
      BuildContext context, RoomsViewModel viewModel, Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หัวข้อกับปุ่มอยู่คนละแถว — Wrap ที่เป็นลูกแบบไม่ยืดหยุ่นของ Row
          // จะได้ maxWidth เป็นอนันต์ มันจึงไม่มีวันขึ้นบรรทัดใหม่และล้นออกนอกจอ
          // แทนที่จะ wrap · ปุ่มสามอันรวมกันกว้างเกินจอโทรศัพท์ทั่วไปอยู่แล้ว
          Text(
            'ห้องพักทั้งหมด (${stats['total']})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PrimaryButton(
                label: 'เพิ่มห้อง',
                icon: Icons.add,
                onPressed: () => _showAddRoomDialog(context, viewModel),
              ),
              // หอที่มีห้องอยู่แล้วยังต่อเติมชั้นใหม่ได้ การสร้างเป็นชุดจึงไม่ใช่
              // เรื่องของตอนเปิดหอครั้งแรกอย่างเดียว
              PrimaryButton(
                label: 'สร้างหลายห้อง',
                icon: Icons.grid_view,
                onPressed: () => _openCreateRoomsDialog(context, viewModel),
              ),
              PrimaryButton(
                label: 'จัดการ',
                icon: Icons.people_alt_outlined,
                onPressed: () =>
                    _showTenantManagementSheet(context, viewModel),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ไม่มี SizedBox ความสูงตายตัวครอบอีกแล้ว — 180px พอดีกับสองแถวเท่านั้น
          // พอจอกว้างจนเหลือแถวเดียวก็เหลือที่ว่างค้างไว้ครึ่งหนึ่ง และถ้าผู้ใช้
          // ขยายขนาดตัวอักษรของระบบจนแถวสูงเกิน 180 ช่องก็ถูกตัดทิ้งเงียบๆ
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: cardGridDelegate(
                  context,
                  availableWidth: constraints.maxWidth,
                  minItemWidth: 140,
                  itemHeight: 80,
                  itemCount: 4,
                  spacing: 8,
                ),
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
        ],
      ),
    );
  }

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

  Widget _buildFilterSection(BuildContext context, RoomsViewModel viewModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return _buildCompactFilterSection(context, viewModel);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: PaperCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterHeader(context, viewModel),
                _buildFilterGroup(
                  context,
                  title: 'ชั้น',
                  options: ['ทั้งหมด', ...viewModel.floors.toList()..sort()],
                  selectedValue: viewModel.selectedFloor,
                  onSelected: viewModel.setSelectedFloor,
                ),
                _buildFilterGroup(
                  context,
                  title: 'สถานะห้อง',
                  options: ['ทั้งหมด', 'มีคนอยู่', 'ว่าง', 'ซ่อมบำรุง'],
                  selectedValue: viewModel.selectedFilter,
                  onSelected: viewModel.setSelectedFilter,
                ),
                _buildFilterGroup(
                  context,
                  title: 'สถานะการชำระเงิน',
                  options: RoomsViewModel.paymentStatusFilters,
                  selectedValue: viewModel.selectedPaymentStatus,
                  onSelected: viewModel.setSelectedPaymentStatus,
                  note: viewModel.selectedPaymentStatus != 'ทั้งหมด'
                      ? 'ข้อมูลการชำระเงินยังไม่เชื่อมต่อกับสถานะห้องในหน้านี้'
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactFilterSection(
      BuildContext context, RoomsViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหาห้อง',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: viewModel.searchQuery.trim().isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            viewModel.setSearchQuery('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: viewModel.setSearchQuery,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showFilterSheet(context, viewModel),
              icon: const Icon(Icons.filter_list),
              label: const Text('ตัวกรอง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterHeader(BuildContext context, RoomsViewModel viewModel) {
    final activeFilterCount = viewModel.activeFilterCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'ตัวกรอง',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (activeFilterCount > 0) ...[
          Text(
            'เปิดใช้งาน $activeFilterCount ตัวกรอง',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 12),
        ],
        TextButton.icon(
          onPressed: activeFilterCount > 0 ? viewModel.clearAllFilters : null,
          icon: const Icon(Icons.filter_alt_off),
          label: const Text('ล้างทั้งหมด'),
          style: TextButton.styleFrom(
            foregroundColor: activeFilterCount > 0
                ? AppColors.primary
                : AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context, RoomsViewModel viewModel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return AnimatedBuilder(
              animation: viewModel,
              builder: (context, _) => Container(
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.mutedForeground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Text(
                        'ตัวกรอง',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ปรับผลลัพธ์ตามชั้น สถานะห้อง และสถานะการชำระเงิน',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 16),
                      _buildFilterGroup(
                        context,
                        title: 'ชั้น',
                        options: ['ทั้งหมด', ...viewModel.floors.toList()..sort()],
                        selectedValue: viewModel.selectedFloor,
                        onSelected: viewModel.setSelectedFloor,
                      ),
                      _buildFilterGroup(
                        context,
                        title: 'สถานะห้อง',
                        options: ['ทั้งหมด', 'มีคนอยู่', 'ว่าง', 'ซ่อมบำรุง'],
                        selectedValue: viewModel.selectedFilter,
                        onSelected: viewModel.setSelectedFilter,
                      ),
                      _buildFilterGroup(
                        context,
                        title: 'สถานะการชำระเงิน',
                        options: RoomsViewModel.paymentStatusFilters,
                        selectedValue: viewModel.selectedPaymentStatus,
                        onSelected: viewModel.setSelectedPaymentStatus,
                        note: viewModel.selectedPaymentStatus != 'ทั้งหมด'
                            ? 'ข้อมูลการชำระเงินยังไม่เชื่อมต่อกับสถานะห้องในหน้านี้'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              viewModel.clearAllFilters();
                              Navigator.of(context).pop();
                            },
                            child: const Text('ล้างทั้งหมด'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('เสร็จสิ้น'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterGroup(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    String? note,
  }) {
    final isFloorGroup = title == 'ชั้น';
    // ใช้จุดตัดกลางของแอป ไม่ใช่ 600 ที่เขียนไว้ตรงนี้เอง — ตัวเลขที่กระจายอยู่
    // หลายที่จะเลื่อนออกจากกันทันทีที่มีใครแก้ที่เดียว
    final shouldUseDropdown =
        isFloorGroup && options.length > 8 && context.isCompact;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        if (shouldUseDropdown)
          DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: options
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) onSelected(value);
            },
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((filter) {
              final isActive = selectedValue == filter;
              return Tooltip(
                message: filter,
                child: FilterChip(
                  label: Text(filter),
                  selected: isActive,
                  onSelected: (_) => onSelected(filter),
                  backgroundColor: AppColors.card,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : AppColors.primary,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isActive ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRoomsListSection(BuildContext context, RoomsViewModel viewModel,
      List<Room> filteredRooms) {
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
          return _RoomCard(room: room, viewModel: viewModel);
        },
      ),
    );
  }

  void _showTenantManagementSheet(
      BuildContext context, RoomsViewModel viewModel) {
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
                  _showAssignTenantDialog(context, viewModel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_alt_1,
                    color: AppColors.destructive),
                title: const Text('ลบผู้พักอาศัย'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRemoveTenantDialog(context, viewModel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home_repair_service,
                    color: AppColors.primary),
                title: const Text('จัดการราคา'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRoomConfigDialog(context, viewModel);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignTenantDialog(BuildContext context, RoomsViewModel viewModel) {
    final vacantRooms =
        viewModel.rooms.where((room) => room.status == RoomStatus.vacant).toList();

    if (vacantRooms.isEmpty) {
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

    Room? selectedRoom = vacantRooms.first;
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
                                selectedTenant = isSelected ? null : tenant;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label:
                        viewModel.isUpdatingTenant ? 'กำลังส่งคำขอ...' : 'ส่งคำขอ',
                    fullWidth: true,
                    onPressed: viewModel.isUpdatingTenant ||
                            selectedRoom == null ||
                            selectedTenant == null
                        ? null
                        : () async {
                            final navigator = Navigator.of(dialogContext);
                            final landlordId =
                                AuthScope.of(context).profile?.id;

                            final result = await viewModel.createTenantJoinRequest(
                              landlordId: landlordId,
                              room: selectedRoom!,
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

  void _showRemoveTenantDialog(BuildContext context, RoomsViewModel viewModel) {
    final occupiedRooms = viewModel.rooms
        .where((room) => room.status == RoomStatus.occupied)
        .toList();

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
      builder: (dialogContext) => AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
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
                            'ลบผู้พักอาศัยออกจากห้อง',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: viewModel.isUpdatingTenant
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close,
                              color: AppColors.primary),
                          splashRadius: 20,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (selectedRoom != null) ...[
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
                      DropdownButtonFormField<Room>(
                        initialValue: selectedRoom,
                        decoration: const InputDecoration(
                          labelText: 'เลือกห้องที่มีผู้พักอาศัย',
                        ),
                        items: occupiedRooms
                            .map((room) => DropdownMenuItem<Room>(
                                  value: room,
                                  child: Text(room.id),
                                ))
                            .toList(),
                        onChanged: viewModel.isUpdatingTenant
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedRoom = value;
                                });
                              },
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
                        onPressed: viewModel.isUpdatingTenant || selectedRoom == null
                            ? null
                            : () async {
                                final navigator = Navigator.of(dialogContext);

                                final result = await viewModel
                                    .removeTenantFromRoom(selectedRoom!);

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
            );
          },
        ),
      ),
    );
  }

  void _showRoomConfigDialog(BuildContext context, RoomsViewModel viewModel) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth =
            min(420.0, MediaQuery.of(dialogContext).size.width - 48);
        final rooms = viewModel.rooms;
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                          'จำนวนห้องพักทั้งหมด: ${rooms.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาเฉลี่ย: ${formatBaht(rooms.isEmpty ? 0 : rooms.fold<double>(0, (prev, room) => prev + room.price) / rooms.length)}/เดือน',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาสูงสุด: ${formatBaht(rooms.isEmpty ? 0 : rooms.map((r) => r.price).reduce((a, b) => a > b ? a : b))}/เดือน',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ราคาต่ำสุด: ${formatBaht(rooms.isEmpty ? 0 : rooms.map((r) => r.price).reduce((a, b) => a < b ? a : b))}/เดือน',
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

  /// จำนวนชั้นที่กรอกไว้ตอนสมัครใช้เป็นค่าเริ่มต้นของกล่องเท่านั้น ไม่ผูกกับ
  /// ห้องจริง — หอต่อเติมชั้นได้ และเจ้าของหออาจอยากสร้างทีละชั้น
  Future<void> _openCreateRoomsDialog(
    BuildContext context,
    RoomsViewModel viewModel,
  ) =>
      showCreateRoomsDialog(
        context,
        viewModel: viewModel,
        defaultTopFloor: AuthScope.of(context).dormitoryTotalFloors,
      );

  void _showAddRoomDialog(BuildContext context, RoomsViewModel viewModel) {
    final roomNumberController = TextEditingController();
    final basePriceController = TextEditingController();
    final totalFloors = AuthScope.of(context).dormitoryTotalFloors;
    final configuredFloorOptions = totalFloors == null || totalFloors <= 0
        ? <String>{}
        : List.generate(totalFloors, (index) => '${index + 1}').toSet();
    final floorOptions = {
      ...viewModel.floors.map((floor) =>
          floor.startsWith('ชั้น ') ? floor.replaceFirst('ชั้น ', '') : floor),
      ...configuredFloorOptions,
    }..removeWhere((floor) => floor.isEmpty);
    final sortedFloorOptions = floorOptions.toList()..sort();
    String selectedFloor =
        sortedFloorOptions.isNotEmpty ? sortedFloorOptions.first : '1';
    bool isLoading = false;
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void safeSetDialogState(VoidCallback fn) {
            if (!dialogContext.mounted) return;
            setDialogState(fn);
          }

          final dialogWidth =
              min(420.0, MediaQuery.of(dialogContext).size.width - 48);
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('เพิ่มห้องพักใหม่'),
                IconButton(
                  onPressed: isLoading
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
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
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
                              color:
                                  AppColors.destructive.withValues(alpha: 0.3)),
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
                        labelText: 'เลขห้อง *',
                        hintText: 'เช่น 101, A1, R101',
                        prefixIcon: Icon(Icons.door_front_door_outlined),
                      ),
                      onChanged: (_) =>
                          safeSetDialogState(() => errorMessage = null),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFloor,
                      decoration: const InputDecoration(
                        labelText: 'ชั้น *',
                        prefixIcon: Icon(Icons.layers_outlined),
                      ),
                      items: sortedFloorOptions
                          .map((floor) => DropdownMenuItem<String>(
                                value: floor,
                                child: Text('ชั้น $floor'),
                              ))
                          .toList(),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                safeSetDialogState(() => selectedFloor = value);
                              }
                            },
                    ),
                    const SizedBox(height: 16),
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
                      onChanged: (_) =>
                          safeSetDialogState(() => errorMessage = null),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: isLoading ? 'กำลังบันทึก...' : 'เพิ่มห้องพัก',
                      fullWidth: true,
                      isLoading: isLoading,
                      onPressed: isLoading
                          ? null
                          : () async {
                              safeSetDialogState(() => errorMessage = null);
                              safeSetDialogState(() => isLoading = true);

                              final result = await viewModel.addRoom(
                                roomNumber: roomNumberController.text.trim(),
                                floor: selectedFloor,
                                basePriceInput:
                                    basePriceController.text.trim(),
                              );

                              if (!dialogContext.mounted) return;

                              if (result.success) {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              } else {
                                safeSetDialogState(() {
                                  errorMessage = result.message;
                                  isLoading = false;
                                });
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
  final RoomsViewModel viewModel;

  const _RoomCard({required this.room, required this.viewModel});

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
          'ห้อง ${room.id}\nชั้น ${room.floor}\n${roomStatusText(room.status)}\nราคา ${formatBaht(room.price)}/เดือน',
      waitDuration: const Duration(milliseconds: 350),
      child: PaperCard(
        onTap: () => _showRoomDetailDialog(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        '${formatBaht(room.price)}/เดือน',
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
                    } else if (value == 'maintenance') {
                      _showMaintenanceHistory(context);
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
                          Icon(Icons.update,
                              size: 18, color: AppColors.primary),
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
                    const PopupMenuItem(
                      value: 'maintenance',
                      child: Row(
                        children: [
                          Icon(Icons.build_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text('ประวัติการแจ้งซ่อม'),
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

  void _showRoomDetailDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogWidth =
            min(420.0, MediaQuery.of(dialogContext).size.width - 48);
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  _detailRow('ราคา', '${formatBaht(room.price)}/เดือน'),
                  _detailRow('สถานะ', roomStatusText(room.status)),
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
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                  onPressed: () =>
                                      Navigator.of(confirmContext).pop(false),
                                  child: const Text('ยกเลิก'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(confirmContext).pop(true),
                                  child: const Text('ยืนยัน'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          setDialogState(() => isLoading = true);

                          final result = await viewModel.updateRoomNumber(
                              room, newRoomNumber);

                          if (!dialogContext.mounted) return;

                          if (result.success) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          } else {
                            setDialogState(() {
                              errorMessage = result.message;
                              isLoading = false;
                            });
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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

                            final ActionResult result =
                                await viewModel.deleteRoom(room);

                            if (!dialogContext.mounted) return;

                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.destructive,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isLoading ? 'กำลังลบ...' : 'ยืนยันลบห้องพัก'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                  'สถานะปัจจุบัน: ${roomStatusText(room.status)}',
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
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
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
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
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
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
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

  Future<void> _updateRoomStatus(
      BuildContext context, RoomStatus newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await viewModel.updateRoomStatus(room, newStatus);
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _showMaintenanceHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaintenanceHistoryScreen(
          roomId: room.dbId,
          roomNumber: room.id,
        ),
      ),
    );
  }

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
                  'ราคาปัจจุบัน: ${formatBaht(room.price)}/เดือน',
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
                        '${formatBaht(newPrice)}/เดือน',
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
                          final messenger = ScaffoldMessenger.of(context);

                          final result =
                              await viewModel.updateRoomPrice(room, newPrice);

                          if (dialogContext.mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(result.message)),
                            );
                            if (result.success) {
                              Navigator.of(dialogContext).pop();
                            }
                          }

                          setDialogState(() => isLoading = false);
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
