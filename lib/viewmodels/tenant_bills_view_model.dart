import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/tenant_billing_source.dart';
import 'error_message.dart';
import 'refreshable.dart';
import 'safe_notifier.dart';
import 'tenant_slip_submission.dart';

const tenantBillFilters = [
  'ทั้งหมด',
  'ค้างชำระ',
  'รอตรวจสลิป',
  'ชำระแล้ว',
];

/// กรองตามสถานะของบิล ไม่ใช่ตามป้าย — ป้ายของบิล pending คือ "รอยืนยัน" ซึ่ง
/// ไม่ตรงกับชิป "รอตรวจสลิป" การเทียบข้อความจึงไม่เคยเจอบิลเลย · ชิปนี้รวมทั้ง
/// บิลที่แนบสลิปและที่แจ้งเงินสด เหมือนหน้าบิลฝั่งเจ้าของหอ
List<Invoice> filterBills(List<Invoice> bills, String filter) {
  switch (filter) {
    case 'ค้างชำระ':
      return bills.where((bill) => bill.status == InvoiceStatus.unpaid).toList();
    case 'รอตรวจสลิป':
      return bills.where((bill) => bill.status == InvoiceStatus.pending).toList();
    case 'ชำระแล้ว':
      return bills.where((bill) => bill.status == InvoiceStatus.paid).toList();
    default:
      return bills;
  }
}

double totalOutstanding(List<Invoice> bills) => bills
    .where((bill) => bill.status == InvoiceStatus.unpaid)
    .fold<double>(0, (sum, bill) => sum + bill.total);

double totalPaidInYear(List<Invoice> bills, int year) => bills
    .where((bill) => bill.status == InvoiceStatus.paid && bill.period.year == year)
    .fold<double>(0, (sum, bill) => sum + bill.total);

class TenantBillsViewModel extends ChangeNotifier
    with
        SafeNotifier,
        RefreshableViewModel,
        RefreshOnSignal,
        TenantSlipSubmission {
  TenantBillsViewModel({
    required this.roomId,
    required this.dormitoryId,
    TenantBillingSource? source,
  }) : _source = source ?? SupabaseTenantBillingSource();

  final int? roomId;
  final int? dormitoryId;
  final TenantBillingSource _source;

  String? errorMessage;
  List<Invoice> bills = [];
  String selectedFilter = 'ทั้งหมด';

  @override
  TenantBillingSource get billingSource => _source;

  @override
  Future<void> reloadAfterSlip() => load();

  List<Invoice> get filteredBills => filterBills(bills, selectedFilter);
  double get outstanding => totalOutstanding(bills);
  double get paidThisYear => totalPaidInYear(bills, DateTime.now().year);

  void setFilter(String filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    notifyListeners();
  }

  @override
  Future<void> load() async {
    final room = roomId;
    if (room == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    return runLoad(() async {
      errorMessage = null;
      try {
        bills = await _source.fetchBillHistory(roomDbId: room, monthCount: 6);
        await loadPaymentChannel(dormitoryId);
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }
    });
  }
}
