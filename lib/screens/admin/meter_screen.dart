import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/issue_invoices_dialog.dart';
import '../../widgets/refreshable.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/error_message.dart';
import '../../viewmodels/meter_view_model.dart';
import '../../utils/formatters.dart';

class MeterScreen extends StatelessWidget {
  final int dormitoryId;
  const MeterScreen({super.key, required this.dormitoryId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MeterViewModel(dormitoryId: dormitoryId)..loadAllRecords(),
      child: const _MeterView(),
    );
  }
}

class _MeterView extends StatefulWidget {
  const _MeterView();

  @override
  State<_MeterView> createState() => _MeterViewState();
}

class _MeterViewState extends State<_MeterView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _expandedRooms = {};
  final Map<String, FocusNode> _focusNodes = {};
  int _seenReloadTick = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _resetFieldControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
  }

  TextEditingController _getController(String key, String initialValue) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  FocusNode _getFocusNode(String key) {
    return _focusNodes.putIfAbsent(key, () => FocusNode());
  }

  void _focusNextElec(MeterViewModel viewModel, int currentIndex) {
    final records = viewModel.electricityRecords;
    if (currentIndex >= records.length - 1) return;
    final nextRecord = records[currentIndex + 1];
    final nextKey = 'elec-${nextRecord.roomDbId}';
    setState(() => _expandedRooms.add(nextKey));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getFocusNode(nextKey).requestFocus();
    });
  }

  void _focusNextWater(MeterViewModel viewModel, int currentIndex) {
    final records = viewModel.waterRecords;
    if (currentIndex >= records.length - 1) return;
    final nextRecord = records[currentIndex + 1];
    final nextKey = 'water-${nextRecord.roomDbId}';
    _getFocusNode(nextKey).requestFocus();
  }

  /// บันทึกมิเตอร์แล้วเสนอออกบิลของงวดนั้นต่อทันที
  ///
  /// การจดมิเตอร์เสร็จคือจังหวะที่ข้อมูลของงวดนั้นครบพอจะเรียกเก็บเงินได้ กล่อง
  /// เดิมที่เด้งตรงนี้ถามแค่ว่า "จะไปหน้าจัดการบิลไหม" ซึ่งเป็นการชี้ทางไปยัง
  /// หน้าที่ต้องกดต่ออีกปุ่ม ไม่ใช่การทำงานให้จบ · ยังคงต้องยืนยันก่อนออกจริง
  /// เพราะบิลตรึงตัวเลข ณ วันออก เลขมิเตอร์ที่พิมพ์ผิดหลักเดียวจึงแก้ไม่ได้
  /// นอกจากยกเลิกใบนั้นแล้วออกใหม่ หลังผู้เช่าเห็นการ์ดที่ยอดผิดในแชทไปแล้ว
  Future<void> _handleSave(MeterViewModel viewModel) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.saveAll();
    if (!mounted || !success) return;

    // แจ้งผลการบันทึกทันที ไม่รอผลการตรวจร่างบิลซึ่งต้องยิงเครือข่ายอีกรอบ —
    // สิ่งที่เจ้าของหอเพิ่งกดคือปุ่มบันทึก เขาควรรู้ผลของมันก่อนเรื่องอื่น
    messenger.showSnackBar(
      const SnackBar(content: Text('บันทึกข้อมูลมิเตอร์เรียบร้อยแล้ว')),
    );

    // ปรับยอดบิลที่ออกไปแล้วแต่ยังไม่มีใครจ่าย ก่อนจะไปถามเรื่องออกบิลใหม่ —
    // สองอย่างนี้ไม่ทับกัน อย่างแรกแก้ใบที่มีอยู่ อย่างหลังออกใบให้ห้องที่ยังไม่มี
    await _syncInvoices(viewModel, messenger);
    if (!mounted) return;

    final outcome = await maybeShowIssueInvoicesDialog(
      context,
      dormitoryId: viewModel.dormitoryId,
      month: viewModel.selectedMonth,
      year: viewModel.selectedYear,
    );

    if (!mounted) return;
    if (outcome == IssuePromptOutcome.checkFailed) {
      // เงียบตรงนี้ไม่ได้ — ถ้าไม่บอก เจ้าของหอจะอ่านความเงียบว่า "ไม่มีห้องไหน
      // ต้องออกบิลแล้ว" ซึ่งเป็นคนละเรื่องกับ "ยังไม่รู้ว่ามีห้องไหนต้องออก"
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ตรวจสอบห้องที่ออกบิลได้ไม่สำเร็จ '
              'ลองออกบิลอีกครั้งที่หน้าบิล'),
        ),
      );
    }
  }

  /// ปรับยอดบิลค้างชำระของงวดแล้วรายงานผลตามความจริงของแต่ละขั้น
  ///
  /// เงียบเมื่อไม่มีใบไหนเปลี่ยน — งวดที่บันทึกมิเตอร์ซ้ำโดยเลขเท่าเดิม หรืองวด
  /// ที่ยังไม่เคยออกบิล ไม่มีอะไรให้รายงาน และ snackbar ที่เด้งโดยไม่มีเนื้อหา
  /// ทำให้ snackbar ที่มีเนื้อหาถูกมองข้ามไปด้วย
  Future<void> _syncInvoices(
    MeterViewModel viewModel,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final result = await viewModel.syncInvoicesForPeriod();
      if (!mounted || result.adjusted == 0) return;

      messenger.showSnackBar(SnackBar(
        content: Text(result.noticesPosted
            ? 'ปรับยอดบิลที่ยังค้างชำระ ${result.adjusted} ใบ และแจ้งผู้เช่าแล้ว'
            : 'ปรับยอดบิลที่ยังค้างชำระ ${result.adjusted} ใบแล้ว '
                'แต่ส่งข้อความแจ้งผู้เช่าไม่สำเร็จ'),
      ));
    } catch (error) {
      if (!mounted) return;
      // ต้องบอก ไม่ใช่เงียบ — เจ้าของหอเพิ่งแก้เลขมิเตอร์แล้วจะเข้าใจว่าบิล
      // ตามไปด้วยแล้ว ทั้งที่ยังเป็นยอดเดิม
      messenger.showSnackBar(SnackBar(
        content: Text('ปรับยอดบิลตามมิเตอร์ใหม่ไม่สำเร็จ: '
            '${formatErrorMessage(error)}'),
      ));
    }
  }

  /// รีเฟรชที่ถามก่อนทิ้งงานที่ยังไม่ได้บันทึก
  ///
  /// `reloadTick` ล้าง TextEditingController ทั้งชุดทุกครั้งที่โหลดใหม่ ถ้าปล่อยให้
  /// ท่าทางลากเรียก loadAllRecords() ตรงๆ เลขมิเตอร์ที่เพิ่งพิมพ์มาทั้งชั้นจะหายไป
  /// เงียบๆ ด้วยท่าทางที่ผู้ใช้ตั้งใจใช้เพื่อ "ดูข้อมูลล่าสุด" ไม่ใช่เพื่อล้างงานตัวเอง
  Future<void> _handleRefresh(MeterViewModel viewModel) async {
    if (viewModel.hasUnsavedInput) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('มีเลขมิเตอร์ที่ยังไม่ได้บันทึก'),
          content: const Text('รีเฟรชแล้วค่าที่พิมพ์ไว้จะหายทั้งหมด'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive,
              ),
              child: const Text('ทิ้งแล้วรีเฟรช'),
            ),
          ],
        ),
      );
      // กด "ยกเลิก" หรือปิดกล่องทิ้ง = คืน Future ทันที วงแหวนหดกลับเอง
      if (discard != true) return;
    }

    await viewModel.loadAllRecords();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MeterViewModel>();

    if (viewModel.reloadTick != _seenReloadTick) {
      _seenReloadTick = viewModel.reloadTick;
      _resetFieldControllers();
    }

    return ContentBounds(
      gutter: 0,
      child: Column(
      children: [
        _buildHeader(viewModel),
        _buildPeriodSelector(viewModel),
        _buildSearchAndFilterSection(viewModel),
        if (viewModel.errorMessage != null) _buildErrorBanner(viewModel),
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.mutedForeground,
          tabs: const [
            Tab(icon: Icon(Icons.bolt), text: 'ค่าไฟ'),
            Tab(icon: Icon(Icons.water_drop), text: 'ค่าน้ำ'),
          ],
        ),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildElectricityList(viewModel),
                    _buildWaterList(viewModel),
                  ],
                ),
        ),
      ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection(MeterViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหาห้อง หรือชื่อผู้เช่า',
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                TextButton.icon(
                  onPressed: () => _showMeterFilterSheet(context, viewModel),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('ตัวกรอง'),
                ),
                if (viewModel.activeFilterCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${viewModel.activeFilterCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMeterFilterSheet(BuildContext context, MeterViewModel viewModel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: AnimatedBuilder(
              animation: viewModel,
              builder: (sheetContext, _) => SingleChildScrollView(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text('ตัวกรอง', style: Theme.of(context).textTheme.titleLarge),
                        ),
                        TextButton.icon(
                          onPressed: viewModel.activeFilterCount > 0
                              ? viewModel.clearFilters
                              : null,
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('ล้างทั้งหมด'),
                          style: TextButton.styleFrom(
                            foregroundColor: viewModel.activeFilterCount > 0
                                ? AppColors.primary
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMeterFilterGroup(
                      context,
                      title: 'ชั้น',
                      options: ['ทั้งหมด', ...viewModel.availableFloors.toList()..sort()],
                      selectedValue: viewModel.selectedFloor,
                      onSelected: viewModel.setFloorFilter,
                    ),
                    _buildMeterFilterGroup(
                      context,
                      title: 'สถานะห้อง',
                      options: const ['ทั้งหมด', 'มีคนอยู่', 'ว่าง', 'ซ่อมบำรุง'],
                      selectedValue: viewModel.selectedRoomStatus,
                      onSelected: viewModel.setRoomStatusFilter,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: const Text('เสร็จสิ้น'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeterFilterGroup(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isActive = selectedValue == opt;
            return FilterChip(
              label: Text(opt),
              selected: isActive,
              onSelected: (_) => onSelected(opt),
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
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHeader(MeterViewModel viewModel) {
    return ScreenHeader(
      title: 'บันทึกมิเตอร์',
      subtitle:
          'งวด ${_getMonthName(viewModel.selectedMonth)} ${viewModel.selectedYear}',
      action: PrimaryButton(
        label: viewModel.isSaving ? 'กำลังบันทึก...' : 'บันทึกทั้งหมด',
        icon: Icons.save,
        onPressed: viewModel.canSave ? () => _handleSave(viewModel) : null,
      ),
    );
  }

  Widget _buildPeriodSelector(MeterViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedMonth,
              decoration: const InputDecoration(labelText: 'เดือน', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: List.generate(12, (i) => i + 1).map((month) => DropdownMenuItem(value: month, child: Text(_getMonthName(month)))).toList(),
              onChanged: (val) {
                if (val != null) viewModel.setPeriod(month: val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedYear,
              decoration: const InputDecoration(labelText: 'ปี', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: List.generate(5, (i) => 2024 + i).map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
              onChanged: (val) {
                if (val != null) viewModel.setPeriod(year: val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectricityList(MeterViewModel viewModel) {
    if (viewModel.electricityRecords.isEmpty) {
      return _buildEmptyState('ไม่พบรายการห้องพัก', viewModel);
    }

    final records = viewModel.filteredElectricityRecords;
    final recorded = viewModel.electricityRecordedCount;
    final total = viewModel.electricityRecords.length;

    return Column(
      children: [
        // แถบความคืบหน้าอยู่นอก scroll view เช่นเดียวกับหัวหน้าจอ ตัวเลือกงวด
        // และ TabBar — ทั้งหมดต้องนิ่งขณะที่รายการข้างล่างถูกลาก
        _buildProgressHeader(recorded, total),
        Expanded(
          child: PullToRefresh(
            onRefresh: () => _handleRefresh(viewModel),
            child: records.isEmpty
                ? CenteredScrollable(child: _buildNoResultContent(viewModel))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) =>
                        _buildElecCard(viewModel, records[index], index),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterList(MeterViewModel viewModel) {
    if (viewModel.waterRecords.isEmpty) {
      return _buildEmptyState('ไม่พบรายการห้องพัก', viewModel);
    }

    final records = viewModel.filteredWaterRecords;
    final saved = viewModel.waterSavedCount;
    final total = viewModel.waterRecords.length;

    return Column(
      children: [
        _buildProgressHeader(saved, total),
        Expanded(
          child: PullToRefresh(
            onRefresh: () => _handleRefresh(viewModel),
            child: records.isEmpty
                ? CenteredScrollable(child: _buildNoResultContent(viewModel))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) =>
                        _buildWaterCard(viewModel, records[index], index),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultContent(MeterViewModel viewModel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off, size: 40, color: AppColors.mutedForeground),
        const SizedBox(height: 12),
        const Text('ไม่พบห้องตามเงื่อนไขที่เลือก',
            style: TextStyle(color: AppColors.mutedForeground)),
        if (viewModel.activeFilterCount > 0) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: viewModel.clearFilters,
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('ล้างตัวกรอง'),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressHeader(int done, int total) {
    final allDone = done == total;
    final color = allDone ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            allDone ? Icons.check_circle : Icons.pending_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            'บันทึกแล้ว $done/$total ห้อง',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElecCard(MeterViewModel viewModel, ElectricityRecord record, int index) {
    final key = 'elec-${record.roomDbId}';
    final controller = _getController(key, record.currentReading?.toStringAsFixed(0) ?? '');
    final focusNode = _getFocusNode(key);
    final isExpanded = _expandedRooms.contains(key);
    final isRecorded = record.currentReading != null;
    final isOverflow = record.isOverflow;
    final units = record.unitsUsed;
    final cost = record.amount;
    final currentText = record.currentReading != null ? formatMeterReading(record.currentReading!) : '-';

    final Color avatarBg;
    final Color avatarTextColor;
    if (isRecorded && isOverflow) {
      avatarBg = AppColors.warning.withValues(alpha: 0.12);
      avatarTextColor = AppColors.warning;
    } else if (isRecorded) {
      avatarBg = AppColors.success.withValues(alpha: 0.12);
      avatarTextColor = AppColors.success;
    } else {
      avatarBg = AppColors.primary.withValues(alpha: 0.1);
      avatarTextColor = AppColors.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => isExpanded ? _expandedRooms.remove(key) : _expandedRooms.add(key)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarBg,
                    child: Text(record.roomNumber,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: avatarTextColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.tenantName ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'เดิม: ${formatMeterReading(record.previousReading)}  →  ปัจจุบัน: $currentText',
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isRecorded) ...[
                        Row(
                          children: [
                            if (isOverflow)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.refresh, size: 12, color: AppColors.warning),
                              ),
                            Text(
                              '${formatUnits(units)} หน่วย',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOverflow ? AppColors.warning : AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatBaht(cost),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOverflow ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'รอบันทึก',
                          style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppColors.mutedForeground),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoBox('มิเตอร์เดิม', formatMeterReading(record.previousReading))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          textInputAction: index < viewModel.filteredElectricityRecords.length - 1
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'มิเตอร์ปัจจุบัน',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            helperText: '0 – 9999',
                            helperStyle: const TextStyle(fontSize: 10),
                            errorText: record.currentReading != null && record.currentReading! > 9999
                                ? 'ค่าต้องอยู่ในช่วง 0-9999'
                                : null,
                          ),
                          onChanged: (val) => viewModel.setElectricityReading(record, double.tryParse(val)),
                          onSubmitted: (val) {
                            viewModel.setElectricityReading(record, double.tryParse(val));
                            _focusNextElec(viewModel, index);
                          },
                        ),
                      ),
                    ],
                  ),
                  // Overflow info banner
                  if (isOverflow) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'มิเตอร์ครบรอบ (9999→0000): '
                              '(10000 − ${record.previousReading.toStringAsFixed(0)}) + ${record.currentReading!.toStringAsFixed(0)} '
                              '= ${formatUnits(units)} หน่วย',
                              style: const TextStyle(fontSize: 11, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(MeterViewModel viewModel, WaterRecord record, int index) {
    final key = 'water-${record.roomDbId}';
    final controller = _getController(key, record.amount.toStringAsFixed(0));
    final focusNode = _getFocusNode(key);
    final isSaved = record.id != null;
    final isModified = viewModel.modifiedWaterRoomIds.contains(record.roomDbId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSaved && !isModified
              ? AppColors.success.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1),
          child: Icon(
            isSaved && !isModified ? Icons.check : Icons.water_drop,
            color: isSaved && !isModified ? AppColors.success : Colors.blue,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text('ห้อง ${record.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (isSaved && !isModified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('บันทึกแล้ว', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
              )
            else if (isModified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('แก้ไขแล้ว', style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Text(record.tenantName ?? '-', style: const TextStyle(fontSize: 11)),
        trailing: SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: index < viewModel.waterRecords.length - 1
                ? TextInputAction.next
                : TextInputAction.done,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(prefixText: '฿', border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
            onChanged: (val) => viewModel.setWaterAmount(record, double.tryParse(val) ?? 0.0),
            onSubmitted: (val) {
              viewModel.setWaterAmount(record, double.tryParse(val) ?? 0.0);
              _focusNextWater(viewModel, index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg, MeterViewModel viewModel) {
    return PullToRefresh(
      onRefresh: () => _handleRefresh(viewModel),
      child: CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(msg, style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: viewModel.isRefreshing
                  ? null
                  : () => _handleRefresh(viewModel),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                  viewModel.isRefreshing ? 'กำลังโหลดใหม่...' : 'โหลดใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(MeterViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(viewModel.errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    return months[month - 1];
  }
}
