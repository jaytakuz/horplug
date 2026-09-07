import 'package:flutter/material.dart';

import 'reusable_widgets.dart';

/// กล่องค้นหา + ตัวกรองสถานะสำหรับหน้าประวัติแจ้งซ่อม ใช้ร่วมกันทั้งฝั่ง
/// เจ้าของหอ (admin/maintenance_history_screen.dart) และฝั่งผู้เช่า
/// (tenant/tenant_maintenance_screen.dart) เพื่อให้หน้าตาและพฤติกรรมตรงกัน
///
/// เป็นเจ้าของ TextEditingController เองแทนที่แต่ละหน้าจะต้องประกาศ/dispose
/// ซ้ำ — [searchQuery] จากภายนอกใช้แค่ตัดสินใจว่าจะโชว์ปุ่มล้างค่าไหม ตัว
/// ข้อความจริงเก็บอยู่ใน controller ภายใน
class MaintenanceSearchAndFilter extends StatefulWidget {
  const MaintenanceSearchAndFilter({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.statusOptions,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  final List<String> statusOptions;
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  @override
  State<MaintenanceSearchAndFilter> createState() =>
      _MaintenanceSearchAndFilterState();
}

class _MaintenanceSearchAndFilterState
    extends State<MaintenanceSearchAndFilter> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.searchQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperCard(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'ค้นหารายการ',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: widget.searchQuery.trim().isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: widget.onSearchChanged,
          ),
        ),
        const SizedBox(height: 12),
        FilterChipGroup(
          title: 'สถานะ',
          options: widget.statusOptions,
          selectedValue: widget.selectedStatus,
          onSelected: widget.onStatusChanged,
          scrollable: true,
        ),
      ],
    );
  }
}
