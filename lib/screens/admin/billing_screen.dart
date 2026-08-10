import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';
import '../../models/models.dart';
import '../../viewmodels/auth_view_model.dart' show AuthScope;
import '../../viewmodels/billing_view_model.dart';
import '../../viewmodels/invoice_actions_view_model.dart';
import '../../utils/formatters.dart';
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

class _BillingView extends StatefulWidget {
  const _BillingView();

  @override
  State<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<_BillingView> {
  BillingViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewModel = context.read<BillingViewModel>();
    if (!identical(_viewModel, viewModel)) {
      _viewModel?.removeListener(_onViewModelChanged);
      _viewModel = viewModel..addListener(_onViewModelChanged);
    }
  }

  void _onViewModelChanged() {
    final error = _viewModel?.consumeError();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BillingViewModel>();
    final filteredInvoices = viewModel.filteredInvoices;

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
        _buildFilters(viewModel),
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredInvoices.isEmpty
                  ? _buildEmptyState(viewModel)
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
  Widget _buildEmptyState(BillingViewModel viewModel) {
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
              if (invoice.hasSlip)
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
