import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
