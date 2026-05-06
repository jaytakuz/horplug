import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../mock/mock_data.dart';

class MeterScreen extends StatefulWidget {
  const MeterScreen({super.key});

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<MeterReading> electricityReadings = MockData.electricityReadings;
  final List<MeterReading> waterReadings = MockData.waterReadings;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MobileHeader(subtitle: 'บันทึกมิเตอร์'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('บันทึกค่าน้ำ-ค่าไฟ', style: Theme.of(context).textTheme.titleMedium),
                    PrimaryButton(label: 'บันทึก', icon: Icons.save, onPressed: () {}),
                  ],
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ค่าน้ำ 18 บาท/หน่วย • ค่าไฟ 8 บาท/หน่วย', 
                    style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                ),
              ],
            ),
          ),
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMeterTable(electricityReadings, true),
                _buildMeterTable(waterReadings, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterTable(List<MeterReading> readings, bool isElectricity) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PaperCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                columns: const [
                  DataColumn(label: Text('ห้อง')),
                  DataColumn(label: Text('ชื่อ')),
                  DataColumn(label: Text('เดิม')),
                  DataColumn(label: Text('ปัจจุบัน')),
                  DataColumn(label: Text('หน่วย')),
                  DataColumn(label: Text('฿')),
                  DataColumn(label: Text('')),
                ],
                rows: readings.map((reading) {
                  final units = (reading.currentValue ?? reading.previousValue) - reading.previousValue;
                  final cost = units * (isElectricity ? 8 : 18);
                  return DataRow(cells: [
                    DataCell(Text(reading.roomNumber)),
                    DataCell(Text(reading.tenantName)),
                    DataCell(Text(reading.previousValue.toStringAsFixed(0))),
                    DataCell(
                      SizedBox(
                        width: 60,
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                          style: const TextStyle(fontSize: 14),
                          onChanged: (val) {
                            setState(() {
                              reading.currentValue = double.tryParse(val);
                            });
                          },
                        ),
                      ),
                    ),
                    DataCell(Text(units.toStringAsFixed(0))),
                    DataCell(Text(cost.toStringAsFixed(0))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: AppColors.primary, size: 20),
                        onPressed: () => _mockOCR(reading),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('รวมทั้งหมด ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('฿${_calculateTotal(readings, isElectricity).toStringAsFixed(0)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotal(List<MeterReading> readings, bool isElectricity) {
    double total = 0;
    for (var r in readings) {
      final units = (r.currentValue ?? r.previousValue) - r.previousValue;
      total += units * (isElectricity ? 8 : 18);
    }
    return total;
  }

  void _mockOCR(MeterReading reading) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          reading.currentValue = reading.previousValue + (10 + (DateTime.now().millisecond % 50));
        });
      }
    });
  }
}
