import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'reusable_widgets.dart';

/// พื้นที่ที่ยังโหลดไม่เสร็จ — ให้ [SkeletonBox] ทุกชิ้นข้างในเต้นจังหวะเดียวกัน
///
/// ใช้ตัวควบคุมเดียวต่อหนึ่งพื้นที่ ไม่ใช่ชิ้นละตัว: กระดูกสิบชิ้นที่เต้นคนละ
/// จังหวะดูเหมือนจอกระพริบ และเปลือง ticker สิบตัวโดยไม่ได้อะไรเพิ่ม
///
/// ไม่ใช้ ShaderMask แบบแพ็กเกจ shimmer เพราะมันระบายทับทุกพิกเซลที่ทึบ
/// รวมถึงพื้นขาวของ PaperCard — การ์ดทั้งใบจะกลายเป็นสีเทาไปด้วย
class SkeletonScope extends StatefulWidget {
  const SkeletonScope({
    super.key,
    required this.child,
    this.semanticsLabel = 'กำลังโหลด',
  });

  final Widget child;

  /// สิ่งที่โปรแกรมอ่านหน้าจอพูดแทนกล่องเทาทั้งหมด
  final String semanticsLabel;

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _pulse =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ผู้ใช้ที่เปิด "ลดการเคลื่อนไหว" ได้กล่องเทานิ่ง — ยังบอกได้ว่ากำลังโหลด
    // โดยไม่ต้องมีอะไรขยับ
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ห่อเป็น container เดียวที่มีป้ายเดียว — โปรแกรมอ่านหน้าจอได้ยินว่า
    // "กำลังโหลด" ครั้งเดียว ไม่ใช่ไล่อ่านกล่องว่างทีละชิ้น
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: _SkeletonPulse(animation: _pulse, child: widget.child),
    );
  }
}

class _SkeletonPulse extends InheritedNotifier<Animation<double>> {
  const _SkeletonPulse({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  /// นอก [SkeletonScope] คืน 0 — กระดูกที่หลุดออกมาจึงเป็นกล่องนิ่ง ไม่พัง
  static double valueOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_SkeletonPulse>()
          ?.notifier
          ?.value ??
      0;
}

/// กล่องเทาหนึ่งชิ้นที่ยืนแทนข้อความ ตัวเลข หรือไอคอน
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  /// null = กว้างเต็มพ่อ (บรรทัดข้อความที่ยาวเต็มการ์ด)
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(
          AppColors.muted,
          AppColors.skeletonHighlight,
          _SkeletonPulse.valueOf(context),
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// สลับจากโครงร่างไปเป็นเนื้อหาจริงแบบค่อยๆ จาง
///
/// [builder] ถูกเรียกเฉพาะเมื่อโหลดเสร็จแล้ว หน้าจอจึงไม่ต้องกันค่า null ของ
/// ข้อมูลที่ยังไม่มาในช่วงโหลด · ใช้ที่ระดับ body ของหน้า (พ่อต้องมีขนาดจำกัด)
class LoadingSwap extends StatelessWidget {
  const LoadingSwap({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.builder,
    this.semanticsLabel = 'กำลังโหลด',
  });

  final bool isLoading;
  final Widget skeleton;
  final WidgetBuilder builder;
  final String semanticsLabel;

  /// สั้นพอที่จะไม่รู้สึกว่ารอ แต่ยาวพอที่เนื้อหาจะไม่ "ดีด" ขึ้นมา
  static const duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration:
          MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isLoading
          ? KeyedSubtree(
              key: const ValueKey('skeleton'),
              child: SkeletonScope(
                semanticsLabel: semanticsLabel,
                child: skeleton,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: Builder(builder: builder),
            ),
    );
  }
}

/// รูปทรงและระยะเดียวกับ [StatCard] — ต้องลงช่องกริดความสูงคงที่ของ
/// cardGridDelegate (132) ได้พอดี เนื้อหาจริงจะได้มาแทนที่โดยไม่ขยับ
class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key, this.showSubtitle = true});

  /// ตรงกับการ์ดจริงที่มี/ไม่มี subtitle · ใส่ผิดแล้วความสูงจะต่างกันราว 14px
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              // 8 + ไอคอน 20 + 8 = 36 เท่ากล่องไอคอนของ StatCard
              SkeletonBox(width: 36, height: 36, radius: 12),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 10)),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: 96, height: 22),
          if (showSubtitle) ...[
            const SizedBox(height: 4),
            const SkeletonBox(width: 72, height: 10),
          ],
        ],
      ),
    );
  }
}

/// โครงคร่าวๆ ของ TenantBillCard: หัวบิล+ป้ายสถานะ เลขบิล รายการสามแถว
/// เส้นคั่น ยอดรวม และแถวปุ่ม
///
/// ทุกบรรทัดสูงเท่าบรรทัดข้อความจริงของ slot เดียวกันใน textTheme — การ์ดเรียง
/// ต่อกันในลิสต์ ถ้าโครงร่างเตี้ยกว่าของจริง ใบที่สองสามจะถูกดันลงตอนเนื้อหา
/// จางเข้ามา · ยึดบิลที่จ่ายแล้วเป็นแบบ เพราะเป็นส่วนใหญ่ของประวัติ บิลค้างจ่าย
/// จะสูงกว่าราว 40px จากบรรทัดวันครบกำหนดและปุ่มชำระเงิน
class TenantBillCardSkeleton extends StatelessWidget {
  const TenantBillCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget lineItem() => Padding(
          // bottom 6 เท่า _LineItem ของการ์ดจริง
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: _TextLineBone(style: text.bodyMedium, width: 120)),
              const SizedBox(width: 16),
              _TextLineBone(style: text.bodyMedium, width: 64),
            ],
          ),
        );

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _TextLineBone(style: text.titleMedium, width: 160)),
              // ป้ายสถานะ = บรรทัด labelSmall + padding บนล่าง 4+4 เหมือน StatusBadge
              SkeletonBox(
                width: 64,
                height: _lineHeight(context, text.labelSmall) + 8,
                radius: 999,
              ),
            ],
          ),
          _TextLineBone(style: text.labelSmall, width: 110),
          const SizedBox(height: 12),
          lineItem(),
          lineItem(),
          lineItem(),
          const Divider(height: 24, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TextLineBone(style: text.labelSmall, width: 70),
              _TextLineBone(style: text.titleLarge, width: 100),
            ],
          ),
          const SizedBox(height: 12),
          // สูง 32 เท่า minimumSize ของปุ่ม "บันทึก PDF" บนการ์ดจริง
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 96, height: 32, radius: 999),
              SkeletonBox(width: 88, height: 32, radius: 999),
            ],
          ),
        ],
      ),
    );
  }
}

/// ความสูงหนึ่งบรรทัดของ [style] หลังคูณ textScaler แล้วปัดขึ้น — TextPainter
/// ปัดความสูงข้อความจริงขึ้นเป็นพิกเซลเต็มเหมือนกัน ถ้าไม่ปัด แต่ละบรรทัดจะขาด
/// ไปครึ่งพิกเซล สะสมทั้งการ์ดจนเห็นขยับ
double _lineHeight(BuildContext context, TextStyle? style) =>
    (MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
            (style?.height ?? 1.2))
        .ceilToDouble();

/// กล่องเทาที่กินที่แนวตั้งเท่าข้อความหนึ่งบรรทัดของ [style]
///
/// ตัวกล่องสูงราวสามในสี่ของขนาดตัวอักษร จึงดูเป็นเส้นข้อความ ไม่ใช่แท่งทึบ
/// และสูงตาม textScaler — ผู้ใช้ขยายตัวอักษร 1.3 เท่า การ์ดจริงสูงขึ้นเท่าไหร่
/// โครงร่างก็ต้องสูงขึ้นเท่านั้น
class _TextLineBone extends StatelessWidget {
  const _TextLineBone({required this.style, this.width});

  final TextStyle? style;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final fontSize =
        MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14);
    return SizedBox(
      width: width,
      height: _lineHeight(context, style),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SkeletonBox(width: width, height: fontSize * 0.75),
      ),
    );
  }
}
