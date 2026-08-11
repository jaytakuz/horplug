import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/auth_view_model.dart' show AuthScope;
import '../../viewmodels/billing_view_model.dart';
import '../../viewmodels/invoice_actions_view_model.dart';
import '../../utils/formatters.dart';
import 'payment_channel_screen.dart';
import '../../widgets/issue_invoices_dialog.dart';
import '../../widgets/invoice_detail_sheet.dart';
import '../../widgets/slip_review_sheet.dart';

class BillingScreen extends StatelessWidget {
  final int dormitoryId;
  const BillingScreen({super.key, required this.dormitoryId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BillingViewModel(dormitoryId: dormitoryId)..loadInvoices(),
      child: const _BillingView(),
    );
  }
}

/// แสดง error ของการโหลดในตัวหน้าจอ ไม่ใช่ผ่าน SnackBar
///
/// เดิมหน้านี้ addListener แล้วยิง SnackBar ทันทีที่โหลดล้ม ซึ่งพังกับ
/// `IndexedStack` ใน AdminShell ที่ build ทุกแท็บพร้อมกันตั้งแต่เปิดแอป —
/// SnackBar ของหน้าบิลจึงโผล่ทับหน้าหลักทั้งที่ผู้ใช้ยังไม่เคยแตะแท็บบิล
/// วาด error ในหน้าตัวเองทำให้ผู้ใช้เห็นตอนเปิดแท็บนี้จริงๆ และมีที่ให้วางปุ่ม
/// ลองใหม่ ซึ่ง SnackBar ที่หายไปเองใน 4 วินาทีให้ไม่ได้
class _BillingView extends StatelessWidget {
  const _BillingView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BillingViewModel>();
    final filteredInvoices = viewModel.filteredInvoices;

    // ครอบทั้งคอลัมน์ รวมหัวหน้าจอกับตัวกรอง ไม่ใช่เฉพาะรายการบิล — ไม่งั้น
    // ปุ่ม "ออกบิลใหม่" จะไปอยู่ริมขวาสุดของจอ 1,400px ห่างจากรายการที่มัน
    // เกี่ยวข้องด้วยจนดูเหมือนคนละส่วนของหน้า
    return ContentBounds(
      gutter: 0,
      child: Column(
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
                  Text('${_getMonthName(viewModel.selectedMonth)} ${viewModel.selectedYear}',
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ],
              ),
              PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: () async {
                  final issued = await showIssueInvoicesDialog(
                    context,
                    dormitoryId: viewModel.dormitoryId,
                    month: viewModel.selectedMonth,
                    year: viewModel.selectedYear,
                  );
                  if (issued) await viewModel.loadInvoices();
                },
              ),
            ],
          ),
        ),
        _buildPeriodSelector(viewModel),
        // ตั้งค่าช่องทางรับเงินอยู่หน้านี้เพราะเป็นเรื่องของบิลโดยตรง แต่เป็น
        // งานที่ทำครั้งเดียวตอนเปิดหอ ไม่ใช่ทุกเดือนแบบการออกบิล จึงไม่ควรไป
        // เบียดพื้นที่หัวหน้าจอกับปุ่มหลัก
        //
        // มีป้ายกำกับ ไม่ใช่ไอคอนคิวอาร์ลอยๆ แบบเดิม — ไอคอนเปล่าไม่ได้บอกใคร
        // ว่ากดแล้วเกิดอะไร และ tooltip ไม่มีอยู่จริงบนจอสัมผัส
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: const Text('ตั้งค่าช่องทางรับเงิน'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => showPaymentChannelScreen(
                context,
                dormitoryId: viewModel.dormitoryId,
              ),
            ),
          ),
        ),
        _buildFilters(viewModel),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              // error ต้องมาก่อน empty state — รายการที่ว่างเพราะโหลดไม่สำเร็จ
              // ไม่ใช่ "ยังไม่ได้จดมิเตอร์" การบอกผิดทำให้เจ้าของหอไปตามหา
              // ปัญหาผิดที่
              : viewModel.errorMessage != null
                  ? _buildErrorState(context, viewModel)
                  : filteredInvoices.isEmpty
                      ? _buildEmptyState(context, viewModel)
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
      ),
    );
  }

  Widget _buildPeriodSelector(BillingViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedMonth,
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
                if (val != null) viewModel.setPeriod(month: val);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: viewModel.selectedYear,
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
                if (val != null) viewModel.setPeriod(year: val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BillingViewModel viewModel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['ทั้งหมด', 'ค้างชำระ', 'รอตรวจสลิป', 'ชำระแล้ว', 'ยกเลิกแล้ว']
            .map((filter) {
          final isActive = viewModel.selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isActive,
              onSelected: (val) => viewModel.setFilter(filter),
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

  /// รายการว่างมีสองความหมายที่ต่างกันคนละเรื่อง — งวดนี้ยังไม่มีบิลเลย
  /// กับตัวกรองที่เลือกไม่ตรงกับบิลใบไหน อย่างหลังไม่ควรชวนให้ออกบิลใหม่
  /// ทั้งที่บิลอีกยี่สิบใบอยู่ห่างไปแค่ชิปเดียว
  Widget _buildErrorState(BuildContext context, BillingViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text('โหลดข้อมูลบิลไม่สำเร็จ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'ลองใหม่',
              icon: Icons.refresh,
              onPressed: viewModel.loadInvoices,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BillingViewModel viewModel) {
    if (viewModel.invoices.isNotEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ไม่มีบิลในตัวกรองนี้',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    final hasDrafts = viewModel.readyToIssueCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasDrafts ? Icons.playlist_add_check : Icons.speed_outlined,
                size: 64, color: AppColors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              hasDrafts
                  ? 'มิเตอร์พร้อมแล้ว ${viewModel.readyToIssueCount} ห้อง ยังไม่ได้ออกบิลงวดนี้'
                  : 'ยังไม่ได้จดมิเตอร์งวดนี้',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            if (hasDrafts)
              PrimaryButton(
                label: 'ออกบิลใหม่',
                icon: Icons.add_chart,
                onPressed: () async {
                  final issued = await showIssueInvoicesDialog(
                    context,
                    dormitoryId: viewModel.dormitoryId,
                    month: viewModel.selectedMonth,
                    year: viewModel.selectedYear,
                  );
                  if (issued) await viewModel.loadInvoices();
                },
              )
            else
              TextButton(
                onPressed: viewModel.loadInvoices,
                child: const Text('โหลดใหม่อีกครั้ง'),
              ),
          ],
        ),
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

  /// เมนู ⋮ ไม่มี ViewModel ของตัวเองใน tree (ต่างจากแผ่นรายละเอียดที่มี
  /// ChangeNotifierProvider ห่ออยู่) จึงสร้างตัวชั่วคราวแล้วคืนทิ้งเมื่อจบ
  InvoiceActionsViewModel _actionsFor(BuildContext context) =>
      InvoiceActionsViewModel(
        invoice: invoice,
        dormitoryId: context.read<BillingViewModel>().dormitoryId,
      );

  Future<void> _handleVoidMenu(BuildContext context) async {
    final viewModel = context.read<BillingViewModel>();
    final actions = _actionsFor(context);
    try {
      final changed = await runVoidInvoiceFlow(context, actions: actions);
      if (changed && context.mounted) {
        await viewModel.loadInvoices();
      }
    } finally {
      actions.dispose();
    }
  }

  Future<void> _handlePdfMenu(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final dormitoryName = AuthScope.of(context).dormitoryName ?? 'หอพัก';
    final actions = _actionsFor(context);

    try {
      final result = await actions.sharePdf(dormitoryName: dormitoryName);
      if (result.success) return;
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      actions.dispose();
    }
  }

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
    } else if (invoice.isVoided) {
      variant = BadgeVariant.muted;
      statusText = 'ยกเลิกแล้ว';
    }

    return PaperCard(
      onTap: () async {
        final changed = await showInvoiceDetailSheet(
          context,
          invoice: invoice,
          dormitoryId: context.read<BillingViewModel>().dormitoryId,
        );
        if (changed && context.mounted) {
          await context.read<BillingViewModel>().loadInvoices();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('ห้อง ${invoice.roomNumber}  ${invoice.tenantName}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis),
              ),
              StatusBadge(label: statusText, variant: variant),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    color: AppColors.mutedForeground, size: 20),
                onSelected: (value) {
                  if (value == 'void') _handleVoidMenu(context);
                  if (value == 'pdf') _handlePdfMenu(context);
                },
                // "ยกเลิกบิล" หายไปเมื่อใบนี้ถูกยกเลิกแล้ว — ไม่มีอะไรให้ทำต่อ
                // แต่ "บันทึก PDF" ยังอยู่เสมอ เพราะใบที่ยกเลิกแล้วนี่แหละที่
                // ต้องส่งต่อได้ (มันมีลายน้ำ "ยกเลิก" บอกตัวเองอยู่)
                itemBuilder: (context) => [
                  if (!invoice.isVoided)
                    const PopupMenuItem(
                      value: 'void',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined,
                              size: 18, color: AppColors.destructive),
                          SizedBox(width: 10),
                          Text('ยกเลิกบิล'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            size: 18, color: AppColors.mutedForeground),
                        SizedBox(width: 10),
                        Text('บันทึก PDF'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            invoice.revision > 1
                ? '${invoice.invoiceNo} · แก้ไขครั้งที่ ${invoice.revision}'
                : invoice.invoiceNo,
            style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          _buildItemRow('🏠 ค่าห้อง', formatBaht(invoice.roomPrice)),
          _buildItemRow('⚡ ไฟ ${formatUnits(invoice.electricityUnits)} หน่วย', formatBaht(invoice.electricityCost)),
          _buildItemRow('💧 ค่าน้ำ', formatBaht(invoice.waterCost)),
          if (invoice.cleaningFee > 0)
            _buildItemRow('🧹 ค่าทำความสะอาด', formatBaht(invoice.cleaningFee)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดรวมสุทธิ', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  Text(formatBaht(invoice.total),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              // จ่ายสดไม่มีสลิป — ปุ่มนี้จะพาไปหน้าจอว่าง ให้เปิดแผ่นรายละเอียด
              // ซึ่งมีปุ่มยืนยันรับเงินสดแทน (การ์ดทั้งใบกดได้อยู่แล้ว)
              if (invoice.awaitsCashConfirmation)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 16, color: AppColors.warning),
                    SizedBox(width: 6),
                    Text('รอยืนยันรับเงินสด',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500)),
                  ],
                )
              else if (invoice.hasSlip)
                OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await showSlipReviewSheet(
                      context,
                      invoice: invoice,
                      dormitoryId:
                          context.read<BillingViewModel>().dormitoryId,
                    );
                    if (changed && context.mounted) {
                      await context.read<BillingViewModel>().loadInvoices();
                    }
                  },
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
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }
}
