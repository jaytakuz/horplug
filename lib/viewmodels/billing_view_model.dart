import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';
import 'error_message.dart';
import 'refreshable.dart';

class BillingViewModel extends ChangeNotifier with RefreshableViewModel {
  BillingViewModel({required this.dormitoryId, InvoiceService? service})
      : _service = service ?? InvoiceService();

  final int dormitoryId;
  final InvoiceService _service;

  List<Invoice> invoices = [];

  /// จำนวนห้องที่มิเตอร์พร้อมแล้วแต่ยังไม่ได้ออกบิล — ใช้แยกสาเหตุรายการว่าง
  int readyToIssueCount = 0;
  String selectedFilter = 'ทั้งหมด';
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  /// error ของการโหลดล่าสุด · null แปลว่าโหลดสำเร็จ
  ///
  /// เดิมเป็น one-shot ที่ View อ่านแล้วยิง SnackBar ทันที ซึ่งพังกับ
  /// `IndexedStack` ใน AdminShell — ทุกแท็บถูก build พร้อมกันตั้งแต่เปิดแอป
  /// หน้าบิลจึงโหลดและยิง SnackBar ทับหน้าหลักทั้งที่ผู้ใช้ยังไม่ได้เปิดแท็บบิล
  /// เลยสักครั้ง เก็บเป็นสถานะถาวรแล้วให้หน้าจอวาดเองจึงถูกกว่า ทั้งไม่ข้ามแท็บ
  /// ไม่หายไปเองใน 4 วินาที และมีที่ให้วางปุ่มลองใหม่
  String? errorMessage;

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

  Future<void> loadInvoices() {
    return runLoad(() async {
      errorMessage = null;
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
      } catch (error) {
        errorMessage = formatErrorMessage(error);
      }
    });
  }

  /// จุดเดียวที่ท่าทางลากเรียก
  ///
  /// แยกจาก [loadInvoices] เพราะคอมมิทถัดไปจะแทรกการปรับยอดบิลค้างชำระไว้ตรงนี้
  /// ก่อนโหลด — ที่นั่นเป็นการ "เขียน" ซึ่งต้องเกิดจากท่าทางของเจ้าของหอเท่านั้น
  /// ไม่ใช่ทุกครั้งที่หน้าถูก build (AdminShell build ทุกแท็บพร้อมกันตั้งแต่เปิดแอป)
  Future<void> refresh() => loadInvoices();

  Future<void> setPeriod({int? month, int? year}) async {
    if (month != null) selectedMonth = month;
    if (year != null) selectedYear = year;
    await loadInvoices();
  }
}
