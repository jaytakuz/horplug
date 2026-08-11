import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/invoice_service.dart';
import 'package:horplug/viewmodels/invoice_issue_view_model.dart';

InvoiceDraft _draft({
  int roomDbId = 1,
  String roomNumber = '301',
  SkipReason? skipReason,
}) =>
    InvoiceDraft(
      roomDbId: roomDbId,
      roomNumber: roomNumber,
      tenantId: 'tenant-uuid',
      tenantName: 'สมชาย ใจดี',
      billingMonth: 8,
      billingYear: 2026,
      roomPrice: 3500,
      electricityUnits: 142,
      electricityCost: 1136,
      waterCost: 404,
      cleaningFee: 0,
      skipReason: skipReason,
    );

/// InvoiceService ปลอมที่ไม่แตะเครือข่าย — สืบทอดได้เพราะ `SupabaseService.client`
/// เป็น getter ไม่ใช่ field initializer (ดูเหตุผลเต็มใน
/// invoice_actions_view_model_unit_test.dart)
class _FakeInvoiceService extends InvoiceService {
  _FakeInvoiceService({this.preview, this.error});

  final InvoicePreview? preview;
  final Object? error;

  @override
  Future<InvoicePreview> previewDrafts({
    required int dormitoryId,
    required int month,
    required int year,
  }) async {
    if (error != null) throw error!;
    return preview!;
  }
}

InvoiceIssueViewModel _viewModel({
  InvoicePreview? preview,
  Object? error,
}) =>
    InvoiceIssueViewModel(
      dormitoryId: 1,
      month: 8,
      year: 2026,
      service: _FakeInvoiceService(preview: preview, error: error),
    );

void main() {
  // เงื่อนไขเดียวที่ตัดสินว่าการกดบันทึกมิเตอร์จะเด้งกล่องออกบิลหรือเงียบไป
  group('hasIssuableDrafts', () {
    test('มีห้องที่ออกบิลได้ ถือว่ามีร่างให้ยืนยัน', () async {
      final viewModel = _viewModel(
        preview: InvoicePreview(drafts: [_draft()], skipped: const []),
      );

      await viewModel.load();

      expect(viewModel.hasIssuableDrafts, isTrue);
    });

    test('มีแต่ห้องที่ถูกข้าม ไม่นับว่ามีร่างให้ยืนยัน', () async {
      // เคสของเจ้าของหอที่แก้ค่าน้ำของงวดที่ออกบิลครบไปแล้ว — ทุกห้องอยู่ใน
      // skipped ด้วยเหตุผล alreadyIssued การเด้งกล่องที่มีแต่รายการห้องที่ข้าม
      // จึงไม่มีอะไรให้ตัดสินใจ
      final viewModel = _viewModel(
        preview: InvoicePreview(
          drafts: const [],
          skipped: [_draft(skipReason: SkipReason.alreadyIssued)],
        ),
      );

      await viewModel.load();

      expect(viewModel.hasIssuableDrafts, isFalse);
    });

    test('ยังไม่ได้โหลด ไม่นับว่ามีร่าง', () {
      expect(_viewModel().hasIssuableDrafts, isFalse);
    });

    test('โหลดไม่สำเร็จ ไม่นับว่ามีร่าง และรายงาน errorMessage', () async {
      // ต้องแยกจาก "ไม่มีห้องให้ออก" ให้ได้ที่ระดับนี้ ไม่งั้นผู้เรียกอัตโนมัติ
      // จะเงียบเหมือนกันทั้งสองกรณี แล้วเจ้าของหอจะอ่านความเงียบตอนเครือข่าย
      // ล่มว่าบิลงวดนี้จัดการครบแล้ว
      final viewModel = _viewModel(error: Exception('network down'));

      await viewModel.load();

      expect(viewModel.hasIssuableDrafts, isFalse);
      expect(viewModel.errorMessage, isNotNull);
    });
  });

  group('issue', () {
    test('ไม่มีร่างบิล ไม่ยิงเครือข่ายและตอบว่าออกไม่ได้', () async {
      final viewModel = _viewModel(
        preview: const InvoicePreview(drafts: [], skipped: []),
      );

      await viewModel.load();
      final result = await viewModel.issue();

      expect(result.success, isFalse);
      expect(viewModel.hasIssued, isFalse);
    });
  });
}
