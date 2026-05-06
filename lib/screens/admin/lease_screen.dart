import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class LeaseScreen extends StatefulWidget {
  const LeaseScreen({super.key});

  @override
  State<LeaseScreen> createState() => _LeaseScreenState();
}

class _LeaseScreenState extends State<LeaseScreen> {
  bool isPreview = false;
  String? selectedRoom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MobileHeader(
        subtitle: 'สัญญาเช่า',
        actions: isPreview
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  onPressed: () => setState(() => isPreview = false),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: isPreview ? _buildPreviewView() : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    final vacantRooms = MockData.rooms.where((r) => r.status == RoomStatus.vacant).toList();

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('สร้างสัญญาเช่าใหม่', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'ห้อง', border: OutlineInputBorder()),
            items: vacantRooms.map((r) => DropdownMenuItem(value: r.id, child: Text('ห้อง ${r.id}'))).toList(),
            onChanged: (val) => setState(() => selectedRoom = val),
            hint: const Text('เลือกห้องว่าง'),
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'ชื่อผู้พักอาศัย', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'เบอร์โทร', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'ค่าเช่า/เดือน', border: OutlineInputBorder()))),
              SizedBox(width: 16),
              Expanded(child: TextField(decoration: InputDecoration(labelText: 'เงินประกัน', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'สร้างสัญญา',
            fullWidth: true,
            onPressed: vacantRooms.isEmpty
                ? null
                : () {
                    setState(() => isPreview = true);
                  },
          ),
          if (vacantRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('ไม่มีห้องว่างสำหรับสร้างสัญญาใหม่', style: TextStyle(color: AppColors.destructive, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        PaperCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text('สัญญาเช่าห้องพัก', style: Theme.of(context).textTheme.titleLarge),
              const Text('หอพักศักดิ์เพลส', style: TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildLeaseRow('ห้อง', selectedRoom ?? '305'),
              _buildLeaseRow('ผู้พักอาศัย', 'คุณแจ็ค (ตัวอย่าง)'),
              _buildLeaseRow('เบอร์โทร', '081-XXX-XXXX'),
              _buildLeaseRow('ค่าเช่า', '฿4,000 / เดือน'),
              _buildLeaseRow('เงินประกัน', '฿8,000'),
              _buildLeaseRow('วันเริ่มสัญญา', '1 มีนาคม 2569'),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              const Text('ผู้ให้เช่า: คุณลุงศักดิ์ • ศักดิ์เพลส', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => isPreview = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('แก้ไข', style: TextStyle(color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                label: 'ยืนยันสัญญา',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สร้างสัญญาสำเร็จ!')));
                  setState(() => isPreview = false);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
