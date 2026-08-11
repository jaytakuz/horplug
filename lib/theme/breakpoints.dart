/// จุดตัดของขนาดหน้าจอ และเครื่องมือถามว่าตอนนี้อยู่ขนาดไหน
///
/// ตัวเลขตามแนวทาง Material 3 window size class ไม่ใช่ตามรุ่นเครื่อง — เพราะ
/// สิ่งที่เลย์เอาต์ต้องรู้คือ "มีที่ว่างเท่าไหร่" ไม่ใช่ "เป็นมือถือหรือเปล่า"
/// บนเว็บผู้ใช้ย่อหน้าต่างให้แคบกว่ามือถือได้ตลอดเวลา และแท็บเล็ตที่แบ่งจอครึ่ง
/// ก็กว้างเท่ามือถือพอดี
library;

import 'package:flutter/widgets.dart';

/// ขนาดหน้าต่างที่เลย์เอาต์สนใจ
enum LayoutSize {
  /// มือถือแนวตั้ง หรือหน้าต่างเว็บที่ย่อจนแคบ — คอลัมน์เดียว แถบล่าง
  compact,

  /// แท็บเล็ต มือถือแนวนอน หรือหน้าต่างครึ่งจอ — เริ่มมีที่ให้สองคอลัมน์
  medium,

  /// เดสก์ท็อป — มีที่เหลือพอจนต้องจำกัดความกว้างของเนื้อหาแทน
  expanded,
}

abstract final class Breakpoints {
  /// ต่ำกว่านี้คือ [LayoutSize.compact]
  static const medium = 600.0;

  /// ตั้งแต่นี้ขึ้นไปคือ [LayoutSize.expanded]
  static const expanded = 1024.0;

  /// ความกว้างสูงสุดของเนื้อหาหนึ่งคอลัมน์
  ///
  /// จอ 27 นิ้วที่ปล่อยให้บรรทัดยาวเต็มความกว้างอ่านไม่ไหว — สายตาต้องกวาด
  /// ไกลเกินไปจนหาบรรทัดถัดไปไม่เจอ · ค่านี้ราว 90–100 ตัวอักษรไทยต่อบรรทัด
  static const contentMaxWidth = 1080.0;

  /// ความกว้างสูงสุดของฟอร์มที่มีช่องกรอกไม่กี่ช่อง (เข้าสู่ระบบ สมัคร)
  ///
  /// ช่องกรอกที่กว้าง 1,400px ไม่ได้ช่วยให้กรอกง่ายขึ้น มีแต่ทำให้ป้ายกำกับ
  /// อยู่ห่างจากค่าที่พิมพ์จนไม่เหมือนอยู่ด้วยกัน
  static const formMaxWidth = 440.0;

  /// ความกว้างสูงสุดของแผ่นซ้อนและกล่องโต้ตอบ
  static const sheetMaxWidth = 560.0;
}

extension LayoutSizeQuery on BuildContext {
  /// ขนาดหน้าต่างปัจจุบัน
  ///
  /// อ่านจาก `MediaQuery.sizeOf` ซึ่ง subscribe เฉพาะขนาด ไม่ใช่ทั้ง MediaQuery
  /// — widget จึงไม่ rebuild ตอนคีย์บอร์ดเด้งหรือ padding เปลี่ยน
  LayoutSize get layoutSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.expanded) return LayoutSize.expanded;
    if (width >= Breakpoints.medium) return LayoutSize.medium;
    return LayoutSize.compact;
  }

  bool get isCompact => layoutSize == LayoutSize.compact;

  /// true เมื่อมีที่พอให้วางแถบนำทางไว้ด้านข้างแทนด้านล่าง
  bool get isWide => layoutSize != LayoutSize.compact;

  /// ระยะขอบรอบเนื้อหาที่ขยายตามความกว้าง
  ///
  /// จอกว้างที่ใช้ระยะขอบของมือถือทำให้เนื้อหาดูลอยติดขอบซ้ายบนพื้นที่ว่าง
  /// มหาศาล
  double get pageGutter => switch (layoutSize) {
        LayoutSize.compact => 16,
        LayoutSize.medium => 24,
        LayoutSize.expanded => 32,
      };
}

/// ระยะขอบที่ทำให้เนื้อหาของ scroll view อยู่กลางและไม่กว้างเกิน [maxWidth]
///
/// ใช้กับ `ListView(padding: ...)` แทนการห่อด้วย [ContentBounds] — ผลต่อสายตา
/// เหมือนกัน แต่แถบเลื่อนยังอยู่ริมหน้าต่างตามที่ผู้ใช้เดสก์ท็อปคาด ไม่ใช่ลอย
/// เข้ามาอยู่กลางจอตามขอบของเนื้อหา
///
/// [availableWidth] คือความกว้างที่ scroll view ได้รับจริง ซึ่งต้องมาจาก
/// `LayoutBuilder` **ไม่ใช่จาก MediaQuery** — บนจอกว้างแถบนำทางกินความกว้างไป
/// 80–250px ถ้าคิดจากขนาดหน้าต่างทั้งบาน ระยะขอบจะเผื่อเกินจริงไปข้างละครึ่ง
/// ของส่วนที่แถบกินไป แล้วเนื้อหาก็เยื้องไปทางขวาและแคบกว่าที่ตั้งใจ
EdgeInsets contentInsets(
  BuildContext context, {
  required double availableWidth,
  double maxWidth = Breakpoints.contentMaxWidth,
  double vertical = 16,
}) {
  final gutter = context.pageGutter;
  final overflow = availableWidth - maxWidth - gutter * 2;
  final extra = overflow > 0 ? overflow / 2 : 0.0;

  return EdgeInsets.fromLTRB(
    gutter + extra,
    vertical,
    gutter + extra,
    vertical,
  );
}

/// จำกัดความกว้างของเนื้อหาแล้วจัดกลางจอ
///
/// ใช้ครอบ body ของทุกหน้าที่เลื่อนได้ · ไม่ได้ใส่ padding แนวตั้งให้ เพราะแต่ละ
/// หน้ามีจังหวะหัวเรื่องของตัวเอง
class ContentBounds extends StatelessWidget {
  const ContentBounds({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.gutter,
  });

  final Widget child;
  final double maxWidth;

  /// null = ใช้ระยะขอบตามขนาดหน้าจอ ([LayoutSizeQuery.pageGutter])
  final double? gutter;

  @override
  Widget build(BuildContext context) {
    final horizontal = gutter ?? context.pageGutter;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + horizontal * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}

/// จำนวนคอลัมน์ของกริดการ์ด ตามความกว้างที่มีจริง
///
/// คิดจากความกว้างที่ลูกต้องการ ([minItemWidth]) ไม่ใช่จากขนาดหน้าจอ — กริดที่
/// อยู่ในคอลัมน์แคบของเลย์เอาต์สองคอลัมน์ก็ควรได้คอลัมน์เดียวแม้จอจะกว้าง
int gridColumnsFor({
  required double availableWidth,
  required double minItemWidth,
  int maxColumns = 4,
}) {
  if (availableWidth <= 0 || minItemWidth <= 0) return 1;
  final fits = availableWidth ~/ minItemWidth;
  return fits.clamp(1, maxColumns);
}
