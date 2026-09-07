import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/invoice_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'safe_notifier.dart';

/// แปลง error ตอนออกบิลให้เป็นข้อความที่บอกทางออกได้
///
/// [formatErrorMessage] จับ 23505 อยู่แล้วแต่ตอบแบบกลางๆ ว่า "มีข้อมูลนี้อยู่แล้ว"
/// ที่นี่รู้บริบทมากกว่าว่า 23505 หมายถึงชนกับ partial unique index ของงวดบิล
/// จึงบอกได้ตรงกว่าว่าห้องไหนถูกออกบิลไปแล้ว · error อื่นส่งต่อให้ตัวกลางจัดการ
/// ไม่ทำงานซ้ำซ้อนกัน
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

  /// true เมื่อมีอย่างน้อยหนึ่งห้องที่ออกบิลได้ในงวดนี้
  ///
  /// เป็นเงื่อนไขที่ตัวเรียกอัตโนมัติ (หน้ามิเตอร์) ใช้ตัดสินว่าจะเปิดกล่องไหม
  /// ต่างจากหน้าบิลที่เปิดกล่องเสมอเพราะผู้ใช้ตั้งใจกด — คำตอบว่า "ไม่มีห้องที่
  /// ออกบิลได้" คือสิ่งที่เขามาหา ส่วนคนที่เพิ่งกดบันทึกมิเตอร์ไม่ได้ถามอะไรเลย
  ///
  /// ยังไม่โหลดเสร็จหรือโหลดไม่สำเร็จนับเป็น false ทั้งคู่ — ทั้งสองกรณีไม่มี
  /// รายชื่อห้องให้ยืนยัน การเปิดกล่องจึงไม่มีอะไรให้ตัดสินใจ
  bool get hasIssuableDrafts => preview?.drafts.isNotEmpty ?? false;

  /// บิลที่ออกไปแล้วแต่การ์ดในแชทยังโพสต์ไม่สำเร็จ
  ///
  /// ต้องถือไว้ที่นี่เพราะไม่มีทางกลับมาหาบิลชุดนี้ได้อีกเลย พอออกบิลสำเร็จ
  /// ห้องทั้งหมดกลายเป็น `alreadyIssued` ร่างบิลจึงว่าง ปุ่มออกบิลถูกปิด และ
  /// `postIssueNotices` ไม่มีทางถูกเรียกอีก คำแนะนำเดิมที่บอกให้ "กดออกบิลอีก
  /// ครั้งเพื่อส่งแจ้งเตือนซ้ำ" จึงเป็นคำแนะนำที่ทำตามไม่ได้
  List<Invoice> unnotified = const [];

  /// บิลที่ออกไปแล้วแต่รายการค่าใช้จ่ายเพิ่มเติมแบบทุกเดือนที่ควรพกมาจาก
  /// งวดก่อนยังไม่ถูกคัดลอกมาสำเร็จ — เหตุผลเดียวกับ [unnotified]
  List<Invoice> extraFeesCarryForwardFailed = const [];

  /// ร่างบิลชุดล่าสุดที่สั่งออก — เก็บไว้เพื่อให้ [retryExtraFeesCarryForward]
  /// รู้ว่าห้องไหนควรพกรายการอะไรมา โดยไม่ต้องโหลด preview ใหม่
  List<InvoiceDraft> _issuedDrafts = const [];

  /// true เมื่อบิลถูกสร้างไปแล้วในกล่องนี้ ไม่ว่าการแจ้งเตือนจะสำเร็จหรือไม่ —
  /// หน้าที่เรียกต้องรีเฟรชรายการแม้ผู้ใช้จะปิดกล่องด้วยปุ่ม "ปิด"
  bool hasIssued = false;

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

  int _nextLocalFeeId = -1;

  /// เพิ่มค่าใช้จ่ายเพิ่มเติมให้ร่างบิลของห้องหนึ่ง ก่อนกดออกบิลจริง —
  /// ยังไม่แตะเครือข่ายเลย แค่แก้ [preview] ในหน่วยความจำ รายการนี้จะถูกเขียน
  /// ลง invoice_extra_fees จริงพร้อมกับตอนออกบิล (ผ่าน
  /// InvoiceService.carryForwardExtraFeesForIssued ซึ่งใช้ isRecurring ของ
  /// แต่ละแถวตามจริง ไม่ได้ตั้งเป็นทุกเดือนทั้งหมด)
  ///
  /// id เป็นเลขติดลบไล่ลง — ไม่ใช่ id จริงจากฐานข้อมูล (ยังไม่มีบิลให้ผูก)
  /// ใช้แค่แยกแต่ละแถวในลิสต์นี้ออกจากกันเพื่อให้กดลบรายการที่ถูกต้องได้
  void addExtraFeeToDraft(
    InvoiceDraft draft, {
    required String name,
    required double amount,
    required bool isRecurring,
  }) {
    final currentPreview = preview;
    if (currentPreview == null) return;

    final fee = ExtraFee(
      id: _nextLocalFeeId--,
      invoiceId: 0,
      name: name,
      amount: amount,
      isRecurring: isRecurring,
    );
    final updatedDraft = draft.copyWith(
      carriedExtraFees: [...draft.carriedExtraFees, fee],
    );

    preview = InvoicePreview(
      drafts: [
        for (final d in currentPreview.drafts)
          d.roomDbId == draft.roomDbId ? updatedDraft : d,
      ],
      skipped: currentPreview.skipped,
    );
    notifyListeners();
  }

  /// ถอนรายการที่เพิ่งเพิ่มไว้ในร่าง (ก่อนออกบิล) ออก — คนละอย่างกับ
  /// [InvoiceActionsViewModel.removeExtraFee] ซึ่งลบรายการที่ออกบิลไปแล้วจริง
  void removeExtraFeeFromDraft(InvoiceDraft draft, ExtraFee fee) {
    final currentPreview = preview;
    if (currentPreview == null) return;

    final updatedDraft = draft.copyWith(
      carriedExtraFees:
          draft.carriedExtraFees.where((f) => f.id != fee.id).toList(),
    );

    preview = InvoicePreview(
      drafts: [
        for (final d in currentPreview.drafts)
          d.roomDbId == draft.roomDbId ? updatedDraft : d,
      ],
      skipped: currentPreview.skipped,
    );
    notifyListeners();
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
      hasIssued = true;
      _issuedDrafts = drafts;

      // สองขั้นถัดไปเป็น insert แยกจาก transaction ของการออกบิล — ล้มได้เอง
      // โดยที่บิลยังอยู่ครบ เก็บความล้มไว้คนละก้อนเพื่อให้ปุ่ม "ลองใหม่" ของ
      // แต่ละอย่างกดแยกกันได้ ไม่ต้องออกบิลซ้ำ
      final failures = <String>[];

      try {
        await _service.carryForwardExtraFeesForIssued(
          invoices: issued,
          drafts: drafts,
        );
      } catch (_) {
        extraFeesCarryForwardFailed = issued;
        failures.add('ค่าใช้จ่ายเพิ่มเติมที่ต่อเนื่องมาจากงวดก่อนไม่สำเร็จ');
      }

      try {
        await _service.postIssueNotices(invoices: issued);
      } catch (_) {
        // success: false ไม่ได้แปลว่าบิลล้ม — บิลอยู่ครบแล้ว แต่กล่องต้องไม่ปิด
        // ตัวเอง ไม่งั้นปุ่มส่งแจ้งเตือนซ้ำจะหายไปพร้อมกับกล่อง
        unnotified = issued;
        failures.add('แจ้งเตือนในแชทไม่สำเร็จ');
      }

      if (failures.isNotEmpty) {
        return ActionResult(
          success: false,
          message: 'ออกบิลแล้ว ${issued.length} ห้อง แต่${failures.join(" และ")}',
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

  /// ส่งการ์ดบิลที่ค้างอยู่เข้าแชทอีกครั้ง
  ///
  /// `postIssueNotices` ข้ามใบที่เคยแจ้งไปแล้วอยู่แล้ว การกดซ้ำจึงไม่ทำให้เกิด
  /// ข้อความซ้อนแม้บางใบจะส่งผ่านไปแล้วในรอบก่อน
  Future<ActionResult> retryNotices() async {
    if (unnotified.isEmpty) {
      return const ActionResult(success: true, message: 'ไม่มีแจ้งเตือนค้างส่ง');
    }

    isIssuing = true;
    notifyListeners();

    try {
      final sent = await _service.postIssueNotices(invoices: unnotified);
      unnotified = const [];
      return ActionResult(
        success: true,
        message: 'ส่งแจ้งเตือนเข้าแชทแล้ว $sent ห้อง',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ส่งแจ้งเตือนไม่สำเร็จ: ${describeIssueError(error)}',
      );
    } finally {
      isIssuing = false;
      notifyListeners();
    }
  }

  /// คัดลอกค่าใช้จ่ายเพิ่มเติมที่ค้างไม่สำเร็จตอนออกบิลอีกครั้ง
  ///
  /// ปลอดภัยที่จะกดซ้ำ — ถ้ารอบก่อนคัดลอกไปแล้วบางส่วนก่อนล้ม รอบนี้จะแทรกซ้ำ
  /// เป็นแถวใหม่ ไม่ใช่อัปเดตทับ แต่กรณีนี้เกิดยากในทางปฏิบัติเพราะ insert เป็น
  /// ก้อนเดียว ล้มคือล้มทั้งก้อน ไม่ใช่ล้มครึ่งทาง
  Future<ActionResult> retryExtraFeesCarryForward() async {
    if (extraFeesCarryForwardFailed.isEmpty) {
      return const ActionResult(
          success: true, message: 'ไม่มีรายการค่าใช้จ่ายเพิ่มเติมค้างคัดลอก');
    }

    isIssuing = true;
    notifyListeners();

    try {
      await _service.carryForwardExtraFeesForIssued(
        invoices: extraFeesCarryForwardFailed,
        drafts: _issuedDrafts,
      );
      final count = extraFeesCarryForwardFailed.length;
      extraFeesCarryForwardFailed = const [];
      return ActionResult(
        success: true,
        message: 'คัดลอกค่าใช้จ่ายเพิ่มเติมแล้ว $count ห้อง',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'คัดลอกค่าใช้จ่ายเพิ่มเติมไม่สำเร็จ: '
            '${describeIssueError(error)}',
      );
    } finally {
      isIssuing = false;
      notifyListeners();
    }
  }
}
