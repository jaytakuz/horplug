import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';

class BillingScreen extends StatefulWidget {
  final int dormitoryId;
  const BillingScreen({super.key, required this.dormitoryId});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final SupabaseService _service = SupabaseService();
  String selectedFilter = 'ทั้งหมด';
  bool _isLoading = true;
  List<Invoice> _invoices = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final invoices = await _service.fetchInvoices(
        dormitoryId: widget.dormitoryId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลบิลไม่สำเร็จ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _invoices.where((inv) {
      if (selectedFilter == 'ทั้งหมด') return true;
      if (selectedFilter == 'ค้างชำระ') return inv.status == InvoiceStatus.unpaid;
      if (selectedFilter == 'รอตรวจสลิป') return inv.status == InvoiceStatus.pending;
      if (selectedFilter == 'ชำระแล้ว') return inv.status == InvoiceStatus.paid;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('จัดการบิลรายเดือน', style: Theme.of(context).textTheme.titleMedium),
                  Text('${_getMonthName(_selectedMonth)} $_selectedYear', 
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
              PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: _loadInvoices,
              ),
            ],
          ),
        ),
        _buildPeriodSelector(),
        _buildFilters(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredInvoices.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredInvoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _InvoiceCard(invoice: filteredInvoices[index]);
                      },
                    ),
        ),
      ],
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
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                labelText: 'เดือน',
                border: OutlineInputBorder(),
              ),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1, 
                child: Text(_getMonthName(i + 1))
              )),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _loadInvoices();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                labelText: 'ปี',
                border: OutlineInputBorder(),
              ),
              items: List.generate(5, (i) => DropdownMenuItem(
                value: DateTime.now().year - 1 + i, 
                child: Text('${DateTime.now().year - 1 + i}')
              )),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _loadInvoices();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['ทั้งหมด', 'ค้างชำระ', 'รอตรวจสลิป', 'ชำระแล้ว'].map((filter) {
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
                fontSize: 12
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_outlined, size: 64, color: AppColors.mutedForeground),
          const SizedBox(height: 16),
          const Text('ไม่พบข้อมูลบิลในเดือนที่เลือก', style: TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 8),
          const Text('กรุณาบันทึกมิเตอร์ในเมนู "มิเตอร์" ก่อน', 
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadInvoices, child: const Text('ลองโหลดใหม่อีกครั้ง')),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    return months[month - 1];
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    BadgeVariant variant = BadgeVariant.destructive;
    String statusText = 'ค้างชำระ';

    if (invoice.status == InvoiceStatus.paid) {
      variant = BadgeVariant.success;
      statusText = 'ชำระแล้ว';
    } else if (invoice.status == InvoiceStatus.pending) {
      variant = BadgeVariant.warning;
      statusText = 'รอตรวจสลิป';
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ห้อง ${invoice.roomNumber}  ${invoice.tenantName}', 
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              StatusBadge(label: statusText, variant: variant),
            ],
          ),
          const SizedBox(height: 12),
          _buildItemRow('🏠 ค่าห้อง', '฿${invoice.roomPrice.toStringAsFixed(0)}'),
          _buildItemRow('⚡ ไฟ ${invoice.electricityUnits.toStringAsFixed(1)} หน่วย', '฿${invoice.electricityCost.toStringAsFixed(0)}'),
          _buildItemRow('💧 ค่าน้ำ', '฿${invoice.waterCost.toStringAsFixed(0)}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดรวมสุทธิ', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  Text('฿${invoice.total.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              if (invoice.hasSlip)
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('ดูสลิป'),
                )
              else if (invoice.status == InvoiceStatus.unpaid)
                const Text('รอการชำระ', style: TextStyle(fontSize: 12, color: AppColors.destructive, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
