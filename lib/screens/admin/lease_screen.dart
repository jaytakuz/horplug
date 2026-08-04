import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/lease_view_model.dart';
import '../../widgets/reusable_widgets.dart';
import '../../utils/formatters.dart';

class LeaseScreen extends StatelessWidget {
  const LeaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaseViewModel(),
      child: const _LeaseView(),
    );
  }
}

class _LeaseView extends StatelessWidget {
  const _LeaseView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LeaseViewModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: viewModel.isPreview
          ? _buildPreviewView(context, viewModel)
          : _buildFormView(context, viewModel),
    );
  }

  Widget _buildFormView(BuildContext context, LeaseViewModel viewModel) {
    final vacantRooms = viewModel.vacantRooms;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('สร้างสัญญาเช่าใหม่',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'ห้อง', border: OutlineInputBorder()),
            items: vacantRooms
                .map((r) =>
                    DropdownMenuItem(value: r.id, child: Text('ห้อง ${r.id}')))
                .toList(),
            onChanged: viewModel.selectRoom,
            hint: const Text('เลือกห้องว่าง'),
          ),
          const SizedBox(height: 16),
          const TextField(
              decoration: InputDecoration(
                  labelText: 'ชื่อผู้พักอาศัย', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const TextField(
              decoration: InputDecoration(
                  labelText: 'เบอร์โทร', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                  child: TextField(
                      decoration: InputDecoration(
                          labelText: 'ค่าเช่า/เดือน',
                          border: OutlineInputBorder()))),
              SizedBox(width: 16),
              Expanded(
                  child: TextField(
                      decoration: InputDecoration(
                          labelText: 'เงินประกัน',
                          border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'สร้างสัญญา',
            fullWidth: true,
            onPressed: vacantRooms.isEmpty ? null : viewModel.showPreview,
          ),
          if (vacantRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('ไม่มีห้องว่างสำหรับสร้างสัญญาใหม่',
                  style: TextStyle(color: AppColors.destructive, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewView(BuildContext context, LeaseViewModel viewModel) {
    return Column(
      children: [
        PaperCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text('สัญญาเช่าห้องพัก',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text('หอพักศักดิ์เพลส',
                  style: TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildLeaseRow('ห้อง', viewModel.selectedRoom ?? '305'),
              _buildLeaseRow('ผู้พักอาศัย', 'คุณแจ็ค (ตัวอย่าง)'),
              _buildLeaseRow('เบอร์โทร', '081-XXX-XXXX'),
              _buildLeaseRow('ค่าเช่า', '${formatBaht(4000)}/เดือน'),
              _buildLeaseRow('เงินประกัน', formatBaht(8000)),
              _buildLeaseRow('วันเริ่มสัญญา', '1 มีนาคม 2569'),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              const Text('ผู้ให้เช่า: คุณลุงศักดิ์ • ศักดิ์เพลส',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: viewModel.backToForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('แก้ไข',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PrimaryButton(
                label: 'ยืนยันสัญญา',
                onPressed: () {
                  viewModel.confirmLease();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('สร้างสัญญาสำเร็จ!')));
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
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
