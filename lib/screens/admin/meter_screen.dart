import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';

class MeterScreen extends StatefulWidget {
  final int dormitoryId;
  const MeterScreen({super.key, required this.dormitoryId});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _service = SupabaseService();
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  final Set<String> _expandedRooms = {};
  final Set<int> _modifiedWaterRoomIds = {};
  final Map<String, FocusNode> _focusNodes = {};

  List<ElectricityRecord> _electricityRecords = [];
  List<WaterRecord> _waterRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllRecords();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRecords() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final elecs = await _service.fetchElectricityRecords(
        dormitoryId: widget.dormitoryId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      final waters = await _service.fetchWaterRecords(
        dormitoryId: widget.dormitoryId,
        month: _selectedMonth,
        year: _selectedYear,
      );

      // Clean up old controllers and focus nodes
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _focusNodes.clear();
      _modifiedWaterRoomIds.clear();

      if (!mounted) return;
      setState(() {
        _electricityRecords = elecs;
        _waterRecords = waters;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลได้: $error';
        _isLoading = false;
      });
    }
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

  void _focusNextElec(int currentIndex) {
    if (currentIndex >= _electricityRecords.length - 1) return;
    final nextRecord = _electricityRecords[currentIndex + 1];
    final nextKey = 'elec-${nextRecord.roomDbId}';
    setState(() => _expandedRooms.add(nextKey));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getFocusNode(nextKey).requestFocus();
    });
  }

  void _focusNextWater(int currentIndex) {
    if (currentIndex >= _waterRecords.length - 1) return;
    final nextRecord = _waterRecords[currentIndex + 1];
    final nextKey = 'water-${nextRecord.roomDbId}';
    _getFocusNode(nextKey).requestFocus();
  }

  bool get _canSave {
    if (_isLoading || _isSaving) return false;

    final hasValidElec = _electricityRecords.any(
      (r) => r.currentReading != null && r.currentReading! >= r.previousReading,
    );
    // Only enable save for water if the user explicitly changed an amount
    // or if there are new water records (id == null) that haven't been saved yet
    final hasNewOrModifiedWater = _modifiedWaterRoomIds.isNotEmpty ||
        _waterRecords.any((r) => r.id == null);

    return hasValidElec || hasNewOrModifiedWater;
  }

  Future<void> _saveAll() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveElectricityRecords(_electricityRecords);

      // Only save water records that are new (no id) or explicitly modified
      final waterToSave = _waterRecords
          .where((r) => r.id == null || _modifiedWaterRoomIds.contains(r.roomDbId))
          .toList();
      await _service.saveWaterRecords(waterToSave);

      if (mounted) {
        _showSuccessDialog();
        await _loadAllRecords();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('บันทึกสำเร็จ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'บันทึกข้อมูลมิเตอร์เรียบร้อยแล้ว คุณต้องการไปตรวจสอบความถูกต้องที่หน้าจัดการบิลหรือไม่?',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
            child: const Text('อยู่หน้านี้ต่อ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/landlord/billing');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('ไปหน้าจัดการบิล'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildPeriodSelector(),
        if (_errorMessage != null) _buildErrorBanner(),
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildElectricityList(),
                    _buildWaterList(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('บันทึกมิเตอร์', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                'งวด ${_getMonthName(_selectedMonth)} $_selectedYear',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
          PrimaryButton(
            label: _isSaving ? 'กำลังบันทึก...' : 'บันทึกทั้งหมด',
            icon: Icons.save,
            onPressed: _canSave ? _saveAll : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(labelText: 'เดือน', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: List.generate(12, (i) => i + 1).map((month) => DropdownMenuItem(value: month, child: Text(_getMonthName(month)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _loadAllRecords();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'ปี', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
              items: List.generate(5, (i) => 2024 + i).map((year) => DropdownMenuItem(value: year, child: Text('$year'))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadAllRecords();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectricityList() {
    if (_electricityRecords.isEmpty) return _buildEmptyState('ไม่พบรายการห้องพัก');

    final recorded = _electricityRecords
        .where((r) => r.currentReading != null && r.currentReading! >= r.previousReading)
        .length;
    final total = _electricityRecords.length;

    return Column(
      children: [
        _buildProgressHeader(recorded, total),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _electricityRecords.length,
            itemBuilder: (context, index) => _buildElecCard(_electricityRecords[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterList() {
    if (_waterRecords.isEmpty) return _buildEmptyState('ไม่พบรายการห้องพัก');

    final saved = _waterRecords.where((r) => r.id != null).length;
    final total = _waterRecords.length;

    return Column(
      children: [
        _buildProgressHeader(saved, total),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _waterRecords.length,
            itemBuilder: (context, index) => _buildWaterCard(_waterRecords[index], index),
          ),
        ),
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

  Widget _buildElecCard(ElectricityRecord record, int index) {
    final key = 'elec-${record.roomDbId}';
    final controller = _getController(key, record.currentReading?.toStringAsFixed(0) ?? '');
    final focusNode = _getFocusNode(key);
    final isExpanded = _expandedRooms.contains(key);
    final units = record.unitsUsed;
    final cost = record.amount;
    final currentText = record.currentReading != null ? record.currentReading!.toStringAsFixed(0) : '-';

    final isRecorded = record.currentReading != null && record.currentReading! >= record.previousReading;
    final isInvalid = record.currentReading != null && record.currentReading! < record.previousReading;

    final avatarBg = isRecorded
        ? AppColors.success.withValues(alpha: 0.12)
        : isInvalid
            ? AppColors.destructive.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.1);
    final avatarTextColor = isRecorded
        ? AppColors.success
        : isInvalid
            ? AppColors.destructive
            : AppColors.primary;

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
                    child: Text(record.roomNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: avatarTextColor)),
                  ),
                  const SizedBox(width: 12),
                  // Column 1: ชื่อผู้เช่า + เลขมิเตอร์
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
                          'เดิม: ${record.previousReading.toStringAsFixed(0)}  →  ปัจจุบัน: $currentText',
                          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Column 2: หน่วย + ยอดเงิน / สถานะ
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isRecorded) ...[
                        Text(
                          '${units.toStringAsFixed(1)} หน่วย',
                          style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '฿${cost.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                        ),
                      ] else if (isInvalid) ...[
                        const Text('ข้อมูลผิดพลาด', style: TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w500)),
                      ] else ...[
                        Text(
                          'รอบันทึก',
                          style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.mutedForeground),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildInfoBox('มิเตอร์เดิม', record.previousReading.toStringAsFixed(0))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textInputAction: index < _electricityRecords.length - 1
                              ? TextInputAction.next
                              : TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'มิเตอร์ปัจจุบัน',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (val) => setState(() => record.currentReading = double.tryParse(val)),
                          onSubmitted: (val) {
                            setState(() => record.currentReading = double.tryParse(val));
                            _focusNextElec(index);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (record.currentReading != null && record.currentReading! < record.previousReading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('เลขปัจจุบันต้องไม่น้อยกว่าเลขเดิม', style: TextStyle(color: Colors.red, fontSize: 11)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(WaterRecord record, int index) {
    final key = 'water-${record.roomDbId}';
    final controller = _getController(key, record.amount.toStringAsFixed(0));
    final focusNode = _getFocusNode(key);
    final isSaved = record.id != null;
    final isModified = _modifiedWaterRoomIds.contains(record.roomDbId);

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
            textInputAction: index < _waterRecords.length - 1
                ? TextInputAction.next
                : TextInputAction.done,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(prefixText: '฿', border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
            onChanged: (val) => setState(() {
              record.amount = double.tryParse(val) ?? 0.0;
              _modifiedWaterRoomIds.add(record.roomDbId);
            }),
            onSubmitted: (val) {
              setState(() {
                record.amount = double.tryParse(val) ?? 0.0;
                _modifiedWaterRoomIds.add(record.roomDbId);
              });
              _focusNextWater(index);
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

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.mutedForeground),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadAllRecords,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('โหลดใหม่'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    return months[month - 1];
  }
}
