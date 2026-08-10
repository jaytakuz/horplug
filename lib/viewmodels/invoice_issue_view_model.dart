import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/invoice_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// แปลง error ตอนออกบิลให้เป็นข้อความที่บอกทางออกได้
///
/// 23505 คือชนกับ partial unique index แปลว่ามีคนออกบิลงวดนี้ไปก่อนแล้ว
/// ซึ่งต่างจากเน็ตหลุดโดยสิ้นเชิง ผู้ใช้ต้องโหลดใหม่ ไม่ใช่ลองใหม่
String describeIssueError(Object error) {
  if (error is PostgrestException && error.code == '23505') {
    return 'บางห้องถูกออกบิลงวดนี้ไปแล้ว กรุณาโหลดใหม่';
  }
  return formatErrorMessage(error);
}

class InvoiceIssueViewModel extends ChangeNotifier with SafeNotifier {
  InvoiceIssueViewModel({
    required this.dormitoryId,
    required this.month,
    required this.year,
    InvoiceService? service,
  }) : _service = service ?? InvoiceService();

  final int dormitoryId;
  final int month;
  final int year;
  final InvoiceService _service;

  bool isLoading = true;
  bool isIssuing = false;
  String? errorMessage;
  InvoicePreview? preview;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      preview = await _service.previewDrafts(
        dormitoryId: dormitoryId,
        month: month,
        year: year,
      );
    } catch (error) {
      errorMessage = describeIssueError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<ActionResult> issue() async {
    final drafts = preview?.drafts ?? const [];
    if (drafts.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'ไม่มีห้องที่ออกบิลได้ในงวดนี้',
      );
    }

    isIssuing = true;
    notifyListeners();

    try {
      final issued = await _service.issueInvoices(
        dormitoryId: dormitoryId,
        drafts: drafts,
      );

      try {
        await _service.postIssueNotices(invoices: issued);
      } catch (_) {
        return ActionResult(
          success: true,
          message: 'ออกบิลแล้ว ${issued.length} ห้อง '
              'แต่แจ้งเตือนในแชทไม่สำเร็จ กดออกบิลอีกครั้งเพื่อส่งแจ้งเตือนซ้ำ',
        );
      }

      return ActionResult(
          success: true, message: 'ออกบิลแล้ว ${issued.length} ห้อง');
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ออกบิลไม่สำเร็จ: ${describeIssueError(error)}',
      );
    } finally {
      isIssuing = false;
      notifyListeners();
    }
  }
}
