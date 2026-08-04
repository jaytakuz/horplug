import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/tenant_billing_source.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'tenant_dashboard_view_model.dart' show billStatusLabel;

const tenantBillFilters = [
  'ทั้งหมด',
  'ค้างชำระ',
  'รอตรวจสลิป',
  'ชำระแล้ว',
];

List<TenantBill> filterBills(List<TenantBill> bills, String filter) {
  if (filter == 'ทั้งหมด') return bills;
  return bills.where((bill) => billStatusLabel(bill.status) == filter).toList();
}

double totalOutstanding(List<TenantBill> bills) => bills
    .where((bill) => bill.status == InvoiceStatus.unpaid)
    .fold<double>(0, (sum, bill) => sum + bill.total);

double totalPaidInYear(List<TenantBill> bills, int year) => bills
    .where((bill) => bill.status == InvoiceStatus.paid && bill.period.year == year)
    .fold<double>(0, (sum, bill) => sum + bill.total);

class TenantBillsViewModel extends ChangeNotifier {
  TenantBillsViewModel({
    required this.roomId,
    required this.dormitoryId,
    TenantBillingSource? source,
  }) : _source = source ?? MockTenantBillingSource();

  final int? roomId;
  final int? dormitoryId;
  final TenantBillingSource _source;

  /// true เฉพาะการโหลดครั้งแรก — pull-to-refresh ไม่ควรล้างรายการบิลทิ้ง
  bool isLoading = true;
  bool _hasLoadedOnce = false;
  bool isSubmittingSlip = false;
  String? errorMessage;
  List<TenantBill> bills = [];
  PaymentChannel? paymentChannel;
  String selectedFilter = 'ทั้งหมด';

  List<TenantBill> get filteredBills => filterBills(bills, selectedFilter);
  double get outstanding => totalOutstanding(bills);
  double get paidThisYear => totalPaidInYear(bills, DateTime.now().year);

  void setFilter(String filter) {
    if (selectedFilter == filter) return;
    selectedFilter = filter;
    notifyListeners();
  }

  Future<void> load() async {
    final room = roomId;
    if (room == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    isLoading = !_hasLoadedOnce;
    errorMessage = null;
    notifyListeners();

    try {
      bills = await _source.fetchBillHistory(roomDbId: room, monthCount: 6);

      final dorm = dormitoryId;
      if (dorm != null) {
        // ช่องทางชำระเงินไม่ critical — ล้มก็แค่ไม่โชว์ QR
        try {
          paymentChannel = await _source.fetchPaymentChannel(dormitoryId: dorm);
        } catch (_) {}
      }
    } catch (error) {
      errorMessage = formatErrorMessage(error);
    } finally {
      isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<ActionResult> submitSlip({
    required String billId,
    required File slip,
  }) async {
    isSubmittingSlip = true;
    notifyListeners();

    try {
      final result =
          await _source.submitPaymentSlip(billId: billId, slip: slip);
      if (result.success) await load();
      return result;
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งสลิปไม่สำเร็จ: ${formatErrorMessage(error)}',
      );
    } finally {
      isSubmittingSlip = false;
      notifyListeners();
    }
  }
}
