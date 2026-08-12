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

  /// ผลของการปรับยอดครั้งล่าสุด · null = ไม่มีอะไรผิดพลาด
  ///
  /// one-shot: หน้าจออ่านแล้วเคลียร์ทิ้งหลังแสดง SnackBar เพราะเป็นผลของ
  /// ท่าทางครั้งนั้น ไม่ใช่สถานะของหน้า (ต่างจาก [errorMessage] ที่ค้างไว้
  /// เพราะรายการบิลว่างอยู่จริงๆ จนกว่าจะโหลดสำเร็จ)
  String? syncErrorMessage;

  /// ท่าทางลากของเจ้าของหอ = ปรับยอดให้ตรงข้อมูลล่าสุดก่อน แล้วค่อยโหลด
  ///
  /// การเขียนฐานข้อมูลจากท่าทางรีเฟรชเป็นเรื่องผิดปกติ จึงจำกัดไว้ที่นี่ซึ่งเป็น
  /// หน้าของเจ้าของหอ (ฝั่งผู้เช่าถูก RLS ปิดอยู่แล้ว) และผูกกับท่าทาง ไม่ใช่กับ
  /// การ build — AdminShell build ทุกแท็บพร้อมกันตั้งแต่เปิดแอป ถ้าผูกกับ build
  /// การเปิดแอปครั้งเดียวจะเขียนบิลทั้งหอโดยที่ไม่มีใครสั่ง
  ///
  /// เป็น no-op เมื่อไม่มีอะไรเปลี่ยน — ไม่มีการเขียน ไม่มีข้อความถึงผู้เช่า
  Future<void> refresh() async {
    syncErrorMessage = null;
    try {
      final adjustments = await _service.syncUnpaidInvoices(
        dormitoryId: dormitoryId,
        month: selectedMonth,
        year: selectedYear,
      );
      if (adjustments.isNotEmpty) {
        await _service.postAdjustmentNotices(adjustments);
      }
    } catch (error) {
      // ปรับยอดล้มไม่ควรแปลว่าผู้ใช้ไม่ได้เห็นรายการบิลเลย · เก็บไว้บอกทีหลัง
      // แล้วโหลดต่อตามปกติ
      syncErrorMessage = formatErrorMessage(error);
    }
    await loadInvoices();
  }

  Future<void> setPeriod({int? month, int? year}) async {
    if (month != null) selectedMonth = month;
    if (year != null) selectedYear = year;
    await loadInvoices();
  }
}
