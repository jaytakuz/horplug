import 'package:flutter/material.dart';
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

      // Clean up old controllers
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();

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

  bool get _canSave {
    if (_isLoading || _isSaving) return false;
    
    // Check for at least one valid change
    final hasValidElec = _electricityRecords.any((r) => 
      r.currentReading != null && r.currentReading! >= r.previousReading
    );
    final hasWater = _waterRecords.isNotEmpty;

    return hasValidElec || hasWater;
  }

  Future<void> _saveAll() async {
    if (!_canSave) return;
    
    setState(() => _isSaving = true);
    try {
      await _service.saveElectricityRecords(_electricityRecords);
      await _service.saveWaterRecords(_waterRecords);
      
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
            Text('บันทึกสำเร็จ'),
          ],
        ),
        content: const Text('บันทึกข้อมูลมิเตอร์เรียบร้อยแล้ว คุณต้องการไปตรวจสอบความถูกต้องที่หน้าจัดการบิลหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('อยู่หน้านี้ต่อ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/landlord/billing');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
        children: [
          Text('บันทึกมิเตอร์', style: Theme.of(context).textTheme.titleLarge),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _electricityRecords.length,
      itemBuilder: (context, index) => _buildElecCard(_electricityRecords[index]),
    );
  }

  Widget _buildWaterList() {
    if (_waterRecords.isEmpty) return _buildEmptyState('ไม่พบรายการห้องพัก');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _waterRecords.length,
      itemBuilder: (context, index) => _buildWaterCard(_waterRecords[index]),
    );
  }

  Widget _buildElecCard(ElectricityRecord record) {
    final key = 'elec-${record.roomDbId}';
    final controller = _getController(key, record.currentReading?.toStringAsFixed(0) ?? '');
    final isExpanded = _expandedRooms.contains(key);
    final units = record.unitsUsed;
    final cost = record.amount;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => isExpanded ? _expandedRooms.remove(key) : _expandedRooms.add(key)),
            leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(record.roomNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            title: Text(record.tenantName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('เลขเดิม: ${record.previousReading.toStringAsFixed(0)} | ใช้ไป: ${units.toStringAsFixed(1)} หน่วย', style: const TextStyle(fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('฿${cost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(width: 8),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
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
                      Expanded(child: _buildInfoBox('ราคาต่อหน่วย', '${record.unitRate.toStringAsFixed(1)} บาท')),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'เลขปัจจุบัน', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          onChanged: (val) => setState(() => record.currentReading = double.tryParse(val)),
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

  Widget _buildWaterCard(WaterRecord record) {
    final key = 'water-${record.roomDbId}';
    final controller = _getController(key, record.amount.toStringAsFixed(0));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.water_drop, color: Colors.blue, size: 20)),
        title: Text('ห้อง ${record.roomNumber} (${record.tenantName})'),
        subtitle: const Text('ยอดเหมาจ่ายรายเดือน', style: TextStyle(fontSize: 11)),
        trailing: SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(prefixText: '฿', border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
            onChanged: (val) => setState(() => record.amount = double.tryParse(val) ?? 0.0),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          const SizedBox(height: 4),
          const Text(
            'ตรวจสอบว่ามีข้อมูลห้องพักใน Supabase และ RLS Policy ถูกต้อง',
            style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
            textAlign: TextAlign.center,
          ),
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
