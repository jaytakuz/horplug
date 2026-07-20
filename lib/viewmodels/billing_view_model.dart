import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

class BillingViewModel extends ChangeNotifier {
  BillingViewModel({required this.dormitoryId, SupabaseService? service})
      : _service = service ?? SupabaseService();

  final int dormitoryId;
  final SupabaseService _service;

  bool isLoading = true;
  List<Invoice> invoices = [];
  String selectedFilter = 'ทั้งหมด';
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  String? _pendingError;

  List<Invoice> get filteredInvoices {
    switch (selectedFilter) {
      case 'ค้างชำระ':
        return invoices.where((inv) => inv.status == InvoiceStatus.unpaid).toList();
      case 'รอตรวจสลิป':
        return invoices.where((inv) => inv.status == InvoiceStatus.pending).toList();
      case 'ชำระแล้ว':
        return invoices.where((inv) => inv.status == InvoiceStatus.paid).toList();
      default:
        return invoices;
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
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      _pendingError = 'โหลดข้อมูลบิลไม่สำเร็จ: $e';
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
