import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';

class BillingViewModel extends ChangeNotifier {
  BillingViewModel({required this.dormitoryId, InvoiceService? service})
      : _service = service ?? InvoiceService();

  final int dormitoryId;
  final InvoiceService _service;

  bool isLoading = true;
  List<Invoice> invoices = [];

  /// จำนวนห้องที่มิเตอร์พร้อมแล้วแต่ยังไม่ได้ออกบิล — ใช้แยกสาเหตุรายการว่าง
  int readyToIssueCount = 0;
  String selectedFilter = 'ทั้งหมด';
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  String? _pendingError;

  List<Invoice> get filteredInvoices {
    switch (selectedFilter) {
      case 'ค้างชำระ':
        return invoices.where((i) => i.status == InvoiceStatus.unpaid).toList();
      case 'รอตรวจสลิป':
        return invoices.where((i) => i.status == InvoiceStatus.pending).toList();
      case 'ชำระแล้ว':
        return invoices.where((i) => i.status == InvoiceStatus.paid).toList();
      case 'ยกเลิกแล้ว':
        return invoices.where((i) => i.isVoided).toList();
      default:
        // ใบที่ยกเลิกไม่โผล่ในรายการปกติ ไม่งั้นงวดที่ออกใบแทนจะดูเหมือน
        // ค้างชำระสองใบ
        return invoices.where((i) => !i.isVoided).toList();
    }
  }

  void setFilter(String filter) {
    selectedFilter = filter;
    notifyListeners();
  }

  Future<void> loadInvoices() async {
    isLoading = true;
    notifyListeners();
    try {
      invoices = await _service.fetchInvoices(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      final preview = await _service.previewDrafts(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      readyToIssueCount = preview.drafts.length;
    } catch (e) {
      _pendingError = 'โหลดข้อมูลบิลไม่สำเร็จ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPeriod({int? month, int? year}) async {
    if (month != null) selectedMonth = month;
    if (year != null) selectedYear = year;
    await loadInvoices();
  }

  /// One-shot read: returns the pending error (if any) and clears it, so a
  /// listener doesn't re-show the same SnackBar on every later notify.
  String? consumeError() {
    final error = _pendingError;
    _pendingError = null;
    return error;
  }
}
