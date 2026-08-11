import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/quick_action.dart';
import '../../services/invoice_pdf.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/error_message.dart';
import '../../viewmodels/maintenance_view_model.dart'
    show maintenanceStatusLabel;
import '../../viewmodels/quick_actions_view_model.dart';
import '../../viewmodels/tenant_dashboard_view_model.dart';
import '../../viewmodels/tenant_shell_view_model.dart';
import '../../widgets/maintenance_request_dialog.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/quick_actions_editor.dart';
import '../../widgets/reusable_widgets.dart';
import '../../utils/chat_preview.dart';
import '../../utils/formatters.dart';

class TenantDashboardScreen extends StatelessWidget {
  const TenantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return MultiProvider(
      key: ValueKey(profile?.roomId),
      providers: [
        ChangeNotifierProvider(
          create: (_) => TenantDashboardViewModel(
            roomId: profile?.roomId,
            dormitoryId: profile?.dormitoryId,
            tenantId: profile?.id,
            tenantName: profile?.fullName.isNotEmpty == true
                ? profile!.fullName
                : 'ผู้พักอาศัย',
          )..load(),
        ),
        // แยก provider เพราะทางลัดอ่านจากดิสก์ ไม่ใช่เครือข่าย — การรีเฟรช
        // แดชบอร์ดจึงไม่ทำให้ปุ่มกระพริบ และการจัดปุ่มไม่ทำให้ต้องโหลดบิลใหม่
        ChangeNotifierProvider(
          create: (_) =>
              QuickActionsViewModel(userId: profile?.id ?? 'guest')..load(),
        ),
      ],
      child: const _TenantDashboardView(),
    );
  }
}

class _TenantDashboardView extends StatelessWidget {
  const _TenantDashboardView();

  Future<void> _handleRespond(
    BuildContext context,
    TenantDashboardViewModel viewModel,
    TenantJoinRequest request,
    bool accept,
  ) async {
    final result = await viewModel.respondToRequest(
      request: request,
      accept: accept,
    );
    if (!context.mounted) return;

    if (result.success) {
      await AuthScope.of(context).refreshProfile();
    }
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile;
    final viewModel = context.watch<TenantDashboardViewModel>();

    return RefreshIndicator(
      onRefresh: () async {
        await auth.refreshProfile();
        await viewModel.load();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _Greeting(profile: profile),
          const SizedBox(height: 16),
          if (profile?.roomId == null)
            ..._buildNoRoomSections(context, viewModel)
          else
            ..._buildDashboardSections(context, viewModel),
        ],
      ),
    );
  }

  // ── ยังไม่มีห้อง: โฟกัสที่คำขอเข้าหออย่างเดียว ────────────────────────────

  List<Widget> _buildNoRoomSections(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.isLoadingRequests) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (viewModel.pendingRequests.isNotEmpty ||
        viewModel.requestErrorMessage != null) {
      return [_buildJoinRequestSection(context, viewModel)];
    }

    return [
      PaperCard(
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty,
                size: 48, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            Text(
              'รอเจ้าของหอเพิ่มคุณเข้าห้อง',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'เมื่อเจ้าของหอส่งคำขอเข้าพัก คุณจะเห็นปุ่มตอบรับที่นี่',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'รีเฟรช',
              icon: Icons.refresh,
              onPressed: () async {
                await AuthScope.of(context).refreshProfile();
                await viewModel.load();
              },
            ),
          ],
        ),
      ),
    ];
  }

  // ── มีห้องแล้ว: เนื้อหาแดชบอร์ดจริง ───────────────────────────────────────

  List<Widget> _buildDashboardSections(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      if (viewModel.pendingRequests.isNotEmpty) ...[
        _buildJoinRequestSection(context, viewModel),
        const SizedBox(height: 16),
      ],
      // เรียงตามความถี่ที่ผู้เช่าต้องการ: ยอดที่ต้องจ่าย → ค่าน้ำค่าไฟงวดนี้ →
      // ข้อความล่าสุด → ปุ่มที่กดบ่อย → ประวัติที่ย้อนดูเป็นครั้งคราว
      // ประวัติแจ้งซ่อมลงล่างสุดเพราะเป็นสิ่งที่เปิดดูน้อยที่สุดในหน้านี้
      _BillHeroCard(viewModel: viewModel),
      const SizedBox(height: 16),
      _UsageSection(viewModel: viewModel),
      const SizedBox(height: 16),
      _LatestMessageCard(viewModel: viewModel),
      const SizedBox(height: 16),
      _QuickActions(viewModel: viewModel),
      const SizedBox(height: 16),
      _MaintenanceSummary(viewModel: viewModel),
    ];
  }

  Widget _buildJoinRequestSection(
    BuildContext context,
    TenantDashboardViewModel viewModel,
  ) {
    if (viewModel.requestErrorMessage != null) {
      return PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คำขอเข้าหอ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SectionErrorNote(
              message: viewModel.requestErrorMessage!,
              onRetry: viewModel.load,
            ),
          ],
        ),
      );
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คำขอเข้าหอ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'ตรวจสอบและตอบรับคำขอจากเจ้าของหอพัก',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...viewModel.pendingRequests.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.dormitoryName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InfoRow(label: 'เจ้าของหอ', value: request.landlordName),
                    InfoRow(label: 'ห้อง', value: request.roomNumber ?? '—'),
                    InfoRow(
                      label: 'ส่งเมื่อ',
                      value:
                          '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: viewModel.isResponding
                                ? null
                                : () => _handleRespond(
                                    context, viewModel, request, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.destructive,
                              side: const BorderSide(
                                  color: AppColors.destructive),
                            ),
                            child: const Text('ปฏิเสธ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: viewModel.isResponding
                                ? null
                                : () => _handleRespond(
                                    context, viewModel, request, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: viewModel.isResponding
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('ตอบรับ'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ยอดที่ต้องชำระ ─────────────────────────────────────────────────────────
// การ์ดที่สำคัญที่สุดของหน้า — ตอบคำถาม "ฉันต้องจ่ายเท่าไหร่" และให้จ่ายได้เลย
// จากที่นี่โดยไม่ต้องเข้าแท็บบิล

/// เปิดแผ่นชำระเงินของบิลใบหนึ่ง
///
/// อยู่นอกคลาสเพราะทั้งการ์ดยอดค้างและปุ่มทางลัดเรียกใช้ — สองที่บนหน้าจอ
/// เดียวกันที่ต้องเปิดแผ่นแบบเดียวกันเป๊ะ
Future<void> _openPaymentSheet(
  BuildContext context,
  TenantDashboardViewModel viewModel,
  Invoice bill,
) =>
    showPaymentSheet(
      context,
      bill: bill,
      channel: viewModel.paymentChannel,
      onSubmit: (slip) => viewModel.submitSlip(bill: bill, slip: slip),
      onSubmitCash: () => viewModel.submitCash(bill: bill),
    );

/// บันทึกบิลเป็น PDF · ใช้ร่วมกับปุ่มทางลัด
Future<void> _saveBillPdf(
  BuildContext context,
  TenantDashboardViewModel viewModel,
  Invoice bill,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final dormitoryName = AuthScope.of(context).dormitoryName ?? 'หอพัก';

  try {
    await shareInvoicePdf(
      invoice: bill,
      dormitoryName: dormitoryName,
      channel: viewModel.paymentChannel,
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(
      content: Text('สร้างไฟล์ PDF ไม่สำเร็จ: ${formatErrorMessage(error)}'),
    ));
  }
}

class _BillHeroCard extends StatelessWidget {
  const _BillHeroCard({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  Future<void> _pay(BuildContext context, Invoice bill) =>
      _openPaymentSheet(context, viewModel, bill);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bill = viewModel.currentBill;

    return PaperCard(
      onTap: () => context.go('/tenant/bills'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'บิลเดือน${thaiMonthName(now.month)} ${now.year}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (bill != null)
                StatusBadge(
                  label: billStatusLabel(bill.status),
                  variant: billStatusVariant(bill.status),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (viewModel.billErrorMessage != null)
            SectionErrorNote(
              message: viewModel.billErrorMessage!,
              onRetry: viewModel.load,
            )
          else ...[
            Text(
              bill != null ? formatBaht(bill.total) : formatBaht(0),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            if (bill == null)
              Text(
                'ยังไม่ออกบิลเดือนนี้ — เจ้าของหอจะออกบิลหลังจดมิเตอร์',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Text(
                'ครบกำหนด ${bill.dueDate.day} ${thaiMonthName(bill.dueDate.month)} ${bill.dueDate.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _buildAction(context, bill),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, Invoice bill) {
    switch (bill.status) {
      case InvoiceStatus.unpaid:
        return PrimaryButton(
          label: 'ชำระเงิน',
          icon: Icons.qr_code_2,
          fullWidth: true,
          onPressed: () => _pay(context, bill),
        );
      case InvoiceStatus.pending:
        return Row(
          children: [
            const Icon(Icons.hourglass_top, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(
              'รอเจ้าของหอตรวจสลิป',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.warning),
            ),
          ],
        );
      case InvoiceStatus.paid:
        return Row(
          children: [
            const Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'ชำระแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.success),
            ),
          ],
        );
      case InvoiceStatus.voided:
        return Row(
          children: [
            const Icon(Icons.block, size: 16, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(
              'ยกเลิกแล้ว',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedForeground),
            ),
          ],
        );
    }
  }
}

// ── การใช้ไฟ-น้ำเดือนนี้ ───────────────────────────────────────────────────

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final invoice = viewModel.currentBill;
    final hasRecord = invoice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'ค่าไฟ',
                value: hasRecord ? formatBaht(invoice.electricityCost) : '—',
                // ตัวเลขมาจากบิลที่ออกแล้ว ไม่ใช่มิเตอร์สด — งวดที่จดมิเตอร์แล้ว
                // แต่ยังไม่ออกบิลจึงยังว่างอยู่ ข้อความต้องไม่โทษการจดมิเตอร์
                //
                // "฿0 · 0 หน่วย" อ่านเหมือนระบบคำนวณพลาด ทั้งที่แปลว่าบิลงวดนี้
                // ออกมาโดยไม่มีค่าไฟจริงๆ (ยังไม่ได้จดมิเตอร์ตอนออกบิล) บอกตรงๆ
                // ดีกว่าปล่อยให้ผู้เช่าเดาว่าตัวเลขหายไปไหน
                subtitle: !hasRecord
                    ? 'รอเจ้าของหอออกบิล'
                    : invoice.electricityUnits > 0
                        ? '${formatUnits(invoice.electricityUnits)} หน่วย'
                        : 'ไม่มีค่าไฟในบิลงวดนี้',
                icon: Icons.bolt,
                variant: BadgeVariant.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'ค่าน้ำ',
                value: hasRecord ? formatBaht(invoice.waterCost) : '—',
                subtitle: hasRecord ? 'เหมาจ่ายรายเดือน' : 'รอเจ้าของหอออกบิล',
                icon: Icons.water_drop,
                variant: BadgeVariant.primary,
              ),
            ),
          ],
        ),
        // ซ่อนเมื่อข้อความซ้ำกับกล่อง error ของบิลด้านบน — ทั้งสองส่วนอ่านจาก
        // ตาราง invoices เหมือนกัน เวลาชั้นฐานข้อมูลล้มจึงได้ข้อความเดียวกัน
        // แล้วผู้เช่าเห็นกล่องแดงสองใบซ้อนกันในหน้าจอเดียว · ยังแยก field ไว้
        // ใน ViewModel เพราะสองส่วนนี้ล้มคนละเหตุผลได้จริง (เช่นบิลโหลดผ่านแต่
        // ประวัติ 2 เดือนไม่ผ่าน) กรณีนั้นยังต้องเห็นทั้งคู่
        if (viewModel.usageErrorMessage != null &&
            viewModel.usageErrorMessage != viewModel.billErrorMessage) ...[
          const SizedBox(height: 8),
          SectionErrorNote(
            message: viewModel.usageErrorMessage!,
            onRetry: viewModel.load,
          ),
        ] else if (viewModel.electricityTrend != null) ...[
          const SizedBox(height: 8),
          _TrendLine(trend: viewModel.electricityTrend!),
        ],
      ],
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.trend});

  final UtilityTrend trend;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;

    final units = formatUnits(trend.delta.abs());
    final percent = trend.percent == null
        ? ''
        : ' (${trend.percent! > 0 ? '+' : ''}${trend.percent!.toStringAsFixed(0)}%)';

    switch (trend.direction) {
      case TrendDirection.up:
        icon = Icons.trending_up;
        color = AppColors.destructive;
        text = 'ใช้ไฟมากกว่าเดือนก่อน $units หน่วย$percent';
        break;
      case TrendDirection.down:
        icon = Icons.trending_down;
        color = AppColors.success;
        text = 'ใช้ไฟน้อยกว่าเดือนก่อน $units หน่วย$percent';
        break;
      case TrendDirection.flat:
        icon = Icons.trending_flat;
        color = AppColors.mutedForeground;
        text = 'ใช้ไฟเท่ากับเดือนก่อน';
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

// ── สถานะแจ้งซ่อม ──────────────────────────────────────────────────────────

class _MaintenanceSummary extends StatelessWidget {
  const _MaintenanceSummary({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final open = viewModel.openRequests.take(2).toList();

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                // ชื่อเดิม "แจ้งซ่อม/ทำความสะอาด" อ่านเหมือนปุ่มสำหรับแจ้งเรื่อง
                // ใหม่ ทั้งที่การ์ดนี้แสดงของที่แจ้งไปแล้ว ส่วนการแจ้งจริงอยู่ที่
                // ปุ่มทางลัดด้านบน
                child: Text('ประวัติการแจ้งซ่อม/ทำความสะอาด',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => context.go('/tenant/maintenance'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ring,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('ดูทั้งหมด', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (viewModel.maintenanceErrorMessage != null)
            SectionErrorNote(
              message: viewModel.maintenanceErrorMessage!,
              onRetry: viewModel.load,
            )
          else if (open.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Text('ไม่มีงานค้าง',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            )
          else
            ...open.map((request) => _OpenRequestRow(request: request)),
        ],
      ),
    );
  }
}

class _OpenRequestRow extends StatelessWidget {
  const _OpenRequestRow({required this.request});

  final MaintenanceRequest request;

  @override
  Widget build(BuildContext context) {
    final isRepair = request.requestType == MaintenanceRequestType.repair;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isRepair ? AppColors.warning : AppColors.ring)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isRepair ? Icons.build : Icons.cleaning_services,
              size: 18,
              color: isRepair ? AppColors.warning : AppColors.ring,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              request.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(
            label: maintenanceStatusLabel(request.status),
            variant: request.status == MaintenanceStatus.pending
                ? BadgeVariant.warning
                : BadgeVariant.primary,
          ),
        ],
      ),
    );
  }
}

// ── ข้อความล่าสุด ──────────────────────────────────────────────────────────

class _LatestMessageCard extends StatelessWidget {
  const _LatestMessageCard({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final message = viewModel.latestMessage;
    // อ่านจาก shell VM ตัวเดียวกับ badge บน nav เพื่อให้ตัวเลขตรงกันเสมอ
    final unreadCount =
        context.watch<TenantShellViewModel>().unreadMessageCount;

    return PaperCard(
      onTap: () => context.go('/tenant/chat'),
      child: viewModel.chatErrorMessage != null
          ? SectionErrorNote(
              message: viewModel.chatErrorMessage!,
              onRetry: viewModel.load,
            )
          : Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เจ้าของหอ',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message == null
                            ? 'ยังไม่มีข้อความ — แตะเพื่อเริ่มแชท'
                            // ผู้เช่าเป็นคนดู จึงเห็น "คุณ:" เมื่อตัวเองเป็น
                            // คนส่งล่าสุด ซึ่งบอกได้ทันทีว่ากำลังรอเจ้าของหอ
                            // ตอบอยู่ โดยไม่ต้องเปิดห้องแชทเข้าไปดู
                            : chatPreviewLine(message, viewerIsOwner: false),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (unreadCount > 0)
                        Badge(label: Text('$unreadCount'))
                      else
                        const SizedBox(height: 16),
                      const SizedBox(height: 4),
                      Text(chatTimestampLabel(message.timestamp),
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

// ── ทางลัด ─────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.viewModel});

  final TenantDashboardViewModel viewModel;

  Future<void> _request(
    BuildContext context,
    MaintenanceRequestType type,
  ) async {
    if (viewModel.isSubmittingRequest) return;

    final description = await showMaintenanceRequestDialog(context, type);
    if (description == null || !context.mounted) return;

    final result = await viewModel.submitMaintenanceRequest(
      description: description,
      requestType: type,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  /// สิ่งที่เกิดขึ้นเมื่อกดทางลัดแต่ละอัน · null แปลว่ากดไม่ได้ตอนนี้
  ///
  /// ทางลัดที่ต้องใช้บิลจะกดไม่ได้เมื่อยังไม่มีบิล — ปุ่มยังอยู่ที่เดิมแต่จาง
  /// ลง ดีกว่าหายไปมาโผล่มาเอง ซึ่งทำให้ตำแหน่งที่ผู้เช่าจำไว้ขยับทุกครั้งที่
  /// สถานะบิลเปลี่ยน
  VoidCallback? _handlerFor(BuildContext context, QuickAction action) {
    final bill = viewModel.currentBill;

    switch (action) {
      case QuickAction.reportRepair:
        return () => _request(context, MaintenanceRequestType.repair);
      case QuickAction.requestCleaning:
        return () => _request(context, MaintenanceRequestType.cleaning);
      case QuickAction.payLatestBill:
        // เปิดได้เฉพาะบิลที่ยังค้างชำระ ตามกฎเดียวกับ canOpenPaymentSheet
        if (bill == null || !canOpenPaymentSheet(bill)) return null;
        return () => _openPaymentSheet(context, viewModel, bill);
      case QuickAction.saveLatestBillPdf:
        if (bill == null) return null;
        return () => _saveBillPdf(context, viewModel, bill);
      case QuickAction.openBills:
        return () => context.go('/tenant/bills');
      case QuickAction.openMaintenance:
        return () => context.go('/tenant/maintenance');
      case QuickAction.openChat:
        return () => context.go('/tenant/chat');
      case QuickAction.openProfile:
        return () => context.go('/tenant/profile');
    }
  }

  IconData _iconFor(QuickAction action) => switch (action) {
        QuickAction.reportRepair => Icons.build,
        QuickAction.requestCleaning => Icons.cleaning_services,
        QuickAction.payLatestBill => Icons.qr_code_2,
        QuickAction.saveLatestBillPdf => Icons.picture_as_pdf_outlined,
        QuickAction.openBills => Icons.receipt_long,
        QuickAction.openMaintenance => Icons.handyman_outlined,
        QuickAction.openChat => Icons.chat_bubble,
        QuickAction.openProfile => Icons.person_outline,
      };

  Color _colorFor(QuickAction action) => switch (action) {
        QuickAction.reportRepair => AppColors.warning,
        QuickAction.requestCleaning => AppColors.ring,
        QuickAction.payLatestBill => AppColors.primary,
        QuickAction.saveLatestBillPdf => AppColors.mutedForeground,
        QuickAction.openBills => AppColors.primary,
        QuickAction.openMaintenance => AppColors.warning,
        QuickAction.openChat => AppColors.success,
        QuickAction.openProfile => AppColors.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        context.watch<TenantShellViewModel>().unreadMessageCount;
    final quickActions = context.watch<QuickActionsViewModel>();

    // ลบทางลัดออกจนหมดคือวิธีเดียวที่ผู้เช่าซึ่งไม่ต้องการการ์ดนี้จะเอามันออก
    // จากหน้าจอได้ — การ์ดเปล่าที่มีแต่หัวเรื่องไม่ได้ให้อะไรใคร
    if (quickActions.isLoading || quickActions.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ทางลัด', style: Theme.of(context).textTheme.titleMedium),
              if (viewModel.isSubmittingRequest) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text('กำลังส่งคำขอ...',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'จัดการทางลัด',
                color: AppColors.mutedForeground,
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    showQuickActionsEditor(context, viewModel: quickActions),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Wrap แทน Row เพราะจำนวนปุ่มไม่คงที่แล้ว — เกินสี่อันต้องขึ้นแถวใหม่
          // ไม่ใช่บีบจนป้ายอ่านไม่ออก · ความกว้างคิดจากสี่ปุ่มต่อแถวเท่าเดิม
          LayoutBuilder(
            builder: (context, constraints) {
              const perRow = 4;
              const spacing = 8.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (perRow - 1)) / perRow;

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final action in quickActions.actions)
                    SizedBox(
                      width: itemWidth,
                      child: _QuickActionItem(
                        icon: _iconFor(action),
                        label: action.label,
                        color: _colorFor(action),
                        badgeCount:
                            action == QuickAction.openChat ? unreadCount : 0,
                        onTap: _handlerFor(context, action),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// null = กดไม่ได้ตอนนี้ (เช่นทางลัดชำระบิลตอนไม่มีบิลค้าง)
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    // จางลงแทนที่จะหายไป — ปุ่มที่โผล่มาหายไปตามสถานะบิลทำให้ตำแหน่งที่ผู้เช่า
    // จำไว้ขยับทุกครั้ง ซึ่งแย่กว่าปุ่มที่กดไม่ได้ชั่วคราว
    final enabled = onTap != null;
    final tint = enabled ? color : AppColors.mutedForeground;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: tint),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: const BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // ไม่ล็อกความกว้าง — กว้างตามช่อง Expanded และขึ้นบรรทัดที่สองได้
              // เมื่อผู้ใช้ตั้งขนาดตัวอักษรใหญ่ แทนที่จะโดนตัดเป็น '…' เงียบๆ
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: enabled
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final firstName = profile?.firstName.trim();
    final name =
        firstName != null && firstName.isNotEmpty ? firstName : 'ผู้พักอาศัย';

    final roomNumber = profile?.roomNumber;
    final dormName = profile?.dormitoryName;
    final subtitle = [
      if (roomNumber != null) 'ห้อง $roomNumber',
      if (dormName != null) dormName,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('สวัสดี, $name', style: Theme.of(context).textTheme.titleLarge),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
