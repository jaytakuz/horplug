import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ท่าทางลากลงเพื่อรีเฟรชแบบเดียวกันทั้งแอป
///
/// ต้องอยู่ **ใน** `body` ของ Scaffold เท่านั้น ห้ามครอบ Scaffold ทั้งตัว —
/// header กับแถบนำทางเป็นพารามิเตอร์ของ Scaffold ซึ่งอยู่คนละ subtree กับ body
/// การครอบทั้งก้อนจะลากแถบพวกนั้นตามลงมาด้วย ซึ่งไม่ใช่สิ่งที่ผู้ใช้คาดจากท่าทางนี้
/// บนแพลตฟอร์มไหนเลย
///
/// ลูกต้องเป็น scroll view ที่มี `AlwaysScrollableScrollPhysics` ไม่งั้นหน้าที่
/// เนื้อหาสั้นกว่าจอจะลากไม่ได้ · สถานะว่าง/ผิดพลาดใช้ [CenteredScrollable]
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // .adaptive ให้ตัวหมุนแบบ Cupertino บน iOS/macOS และวงแหวน Material ที่อื่น
    // — ท่าทางเดียวกัน แต่หน้าตาตรงกับที่ผู้ใช้แต่ละแพลตฟอร์มคุ้นเคย
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      child: child,
    );
  }
}

/// เนื้อหาสั้นๆ ที่อยู่กลางจอแต่ยัง "ลากได้"
///
/// สถานะว่างกับสถานะผิดพลาดเคยเป็น `Center` เฉยๆ ซึ่งไม่มี scrollable ให้
/// RefreshIndicator เกาะ หน้าที่โหลดล้มจึงกลายเป็นทางตันที่ท่าทางประจำของแอป
/// ใช้ไม่ได้ ทั้งที่เป็นหน้าที่ต้องการการลองใหม่มากที่สุด
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ),
      ],
    );
  }
}
