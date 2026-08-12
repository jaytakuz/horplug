import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/maintenance_overview_view_model.dart';
import '../../viewmodels/maintenance_view_model.dart'
    show maintenanceRequestTypeLabel, maintenanceStatusLabel;
import '../../widgets/refreshable.dart';
import '../../widgets/reusable_widgets.dart';
import 'maintenance_history_screen.dart';

/// รายการห้องที่มีประวัติแจ้งซ่อม/ทำความสะอาด ของทั้งหอ
///
/// จงใจใช้โครงเดียวกับหน้ารวมแชท — ค้นหา ชิปกรองชั้น แล้วการ์ดต่อห้องที่มี
/// ข้อความล่าสุดกับเวลา · สองหน้านี้เป็นรายการห้องเหมือนกัน ต่างกันแค่ว่ากำลัง
/// ดูอะไรของห้องนั้น การให้หน้าตาคนละแบบทำให้ต้องเรียนรู้สองหน้าจอโดยไม่ได้อะไร
class MaintenanceOverviewScreen extends StatelessWidget {
  const MaintenanceOverviewScreen({super.key, required this.dormitoryId});

  final int dormitoryId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MaintenanceOverviewViewModel(dormitoryId: dormitoryId)..load(),
      child: const _MaintenanceOverviewView(),
    );
  }
}

class _MaintenanceOverviewView extends StatefulWidget {
  const _MaintenanceOverviewView();

  @override
  State<_MaintenanceOverviewView> createState() =>
      _MaintenanceOverviewViewState();
}

class _MaintenanceOverviewViewState extends State<_MaintenanceOverviewView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// เปิดประวัติของห้องนั้น แล้วโหลดรายการใหม่ตอนกลับมา
  ///
  /// หน้าประวัติแก้สถานะและค่าทำความสะอาดได้ ตัวเลขงานค้างกับเวลาล่าสุดบนการ์ด
  /// จึงเป็นของเก่าทันทีที่เจ้าของหอกดอะไรในนั้น
  Future<void> _openRoom(RoomMaintenanceSummary summary) async {
    final viewModel = context.read<MaintenanceOverviewViewModel>();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MaintenanceHistoryScreen(
          roomId: summary.roomDbId,
          roomNumber: summary.roomNumber,
        ),
      ),
    );

    if (!mounted) return;
    await viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MaintenanceOverviewViewModel>();

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
              Text('โหลดประวัติไม่สำเร็จ',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(viewModel.errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              PrimaryButton(
                label: viewModel.isRefreshing ? 'กำลังลองใหม่...' : 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.isRefreshing ? null : viewModel.load,
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.summaries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.handyman_outlined,
                  color: AppColors.mutedForeground, size: 48),
              const SizedBox(height: 12),
              Text('ยังไม่มีประวัติการแจ้งซ่อม/ทำความสะอาด',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('ห้องจะขึ้นที่นี่เมื่อผู้เช่าแจ้งเรื่องเข้ามาผ่านหน้าแชท',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final rooms = viewModel.filteredSummaries;

    return ContentBounds(
      gutter: 0,
      child: Column(
        children: [
          _buildSearchSection(viewModel),
          _buildSummaryLine(context, viewModel),
          _buildFloorFilterSection(viewModel),
          Expanded(
            child: PullToRefresh(
              onRefresh: viewModel.load,
              child: rooms.isEmpty
                  ? _buildNoResultState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _RoomRow(
                        summary: rooms[index],
                        onTap: () => _openRoom(rooms[index]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(MaintenanceOverviewViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ค้นหาห้อง ชื่อผู้เช่า หรือเรื่องที่แจ้ง',
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
    );
  }

  /// บรรทัดสรุปว่ามีกี่ห้องที่ยังมีงานค้าง
  ///
  /// รายการเรียงตามเวลาล่าสุด ไม่ใช่ตามงานค้าง ห้องที่ยังไม่จบจึงกระจายอยู่
  /// ทั่วรายการ ตัวเลขรวมตรงนี้คือสิ่งเดียวที่บอกได้ว่ายังเหลืออีกเท่าไร
  Widget _buildSummaryLine(
    BuildContext context,
    MaintenanceOverviewViewModel viewModel,
  ) {
    final openRooms = viewModel.roomsWithOpenWork;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Icon(
            openRooms > 0 ? Icons.pending_actions : Icons.check_circle_outline,
            size: 16,
            color: openRooms > 0 ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 6),
          Text(
            openRooms > 0
                ? 'มีงานค้างอยู่ $openRooms ห้อง'
                : 'ไม่มีงานค้างในตอนนี้',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFloorFilterSection(MaintenanceOverviewViewModel viewModel) {
    final floorOptions = [
      MaintenanceOverviewViewModel.allFloors,
      ...viewModel.availableFloors.toList()..sort(),
    ];

    if (floorOptions.length <= 1) return const SizedBox.shrink();

    return FilterChipGroup(
      title: '',
      options: floorOptions,
      selectedValue: viewModel.selectedFloor,
      onSelected: viewModel.setFloorFilter,
    );
  }

  Widget _buildNoResultState() {
    return const CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: AppColors.mutedForeground),
          SizedBox(height: 12),
          Text('ไม่พบห้องตามที่ค้นหา',
              style: TextStyle(color: AppColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.summary, required this.onTap});

  final RoomMaintenanceSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latest;

    return PaperCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ห้อง ${summary.roomNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summary.tenantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // ชนิดของงานนำหน้าข้อความ เพราะ "แอร์ไม่เย็น" กับ "ทำความสะอาด
                // ห้องน้ำ" ต้องแยกออกจากกันได้ตั้งแต่ยังไม่เปิดเข้าไปดู
                Text(
                  '${maintenanceRequestTypeLabel(latest.requestType)} · '
                  '${latest.description}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                StatusBadge(
                  label: maintenanceStatusLabel(latest.status),
                  variant: _statusVariant(latest.status),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (summary.openCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.destructive,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${summary.openCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (summary.openCount > 0) const SizedBox(height: 4),
              Text(
                formatRelativeTime(summary.lastRequestedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'ทั้งหมด ${summary.totalCount} ครั้ง',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BadgeVariant _statusVariant(MaintenanceStatus status) => switch (status) {
        MaintenanceStatus.pending => BadgeVariant.warning,
        MaintenanceStatus.inProgress => BadgeVariant.primary,
        MaintenanceStatus.completed => BadgeVariant.success,
        MaintenanceStatus.cancelled => BadgeVariant.muted,
      };
}
