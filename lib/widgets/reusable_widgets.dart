import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart' show formatBaht;

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final List<BoxShadow>? shadow;
  final Color? color;
  final VoidCallback? onTap;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.shadow = AppShadows.md,
    this.color = AppColors.card,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          boxShadow: shadow,
        ),
        child: child,
      );
    }

    // ซ้อนสามชั้นเพราะ:
    // - DecoratedBox ชั้นนอกวาดเงา AppShadows.md ตามเดิมเป๊ะ
    //   (ห้ามใช้ Material(elevation:) เพราะมันสร้างเงาสูตร M3 ของตัวเอง)
    // - Material ชั้นกลางวาดพื้นและเป็น ink surface ให้ splash วาดทับได้
    //   เดิม InkWell ครอบ Container ทึบ splash จึงไปตกบน Material บรรพบุรุษ
    //   ที่อยู่ "ใต้" การ์ด แล้วถูกบังจนมองไม่เห็นเลย
    // - clipBehavior ตัด splash ให้อยู่ในมุมโค้งเท่าเดิม
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: color ?? Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

enum BadgeVariant { success, warning, destructive, primary, info, muted }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const StatusBadge({super.key, required this.label, this.variant = BadgeVariant.info});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (variant) {
      case BadgeVariant.success:
        bgColor = AppColors.successBg;
        textColor = AppColors.success;
        break;
      case BadgeVariant.warning:
        bgColor = AppColors.warningBg;
        textColor = AppColors.warning;
        break;
      case BadgeVariant.destructive:
        bgColor = AppColors.destructiveBg;
        textColor = AppColors.destructive;
        break;
      case BadgeVariant.primary:
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        textColor = AppColors.primary;
        break;
      case BadgeVariant.muted:
        bgColor = AppColors.muted;
        textColor = AppColors.mutedForeground;
        break;
      case BadgeVariant.info:
        bgColor = AppColors.ring.withValues(alpha: 0.1);
        textColor = AppColors.ring;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final BadgeVariant variant;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.variant = BadgeVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;

    switch (variant) {
      case BadgeVariant.success:
        iconBg = AppColors.successBg;
        iconColor = AppColors.success;
        break;
      case BadgeVariant.warning:
        iconBg = AppColors.warningBg;
        iconColor = AppColors.warning;
        break;
      case BadgeVariant.primary:
        iconBg = AppColors.primary.withValues(alpha: 0.1);
        iconColor = AppColors.primary;
        break;
      default:
        iconBg = AppColors.muted;
        iconColor = AppColors.primary;
    }

    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ตัวเลขย่อลงเมื่อไม่พอ ไม่ตัดบรรทัดและไม่ตัดท้ายด้วย … — "฿137,5…"
          // อ่านผิดเป็นจำนวนเงินคนละก้อน ซึ่งแย่กว่าตัวเลขที่เล็กลงนิดหน่อย
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            // จำกัดบรรทัดเหมือนหัวการ์ดข้างบน · การ์ดสรุปอยู่ในกริดที่ทุกใบสูง
            // เท่ากัน คำบรรยายที่ตัดขึ้นบรรทัดที่สามบนจอแคบจึงดันเนื้อหาล้น
            // ออกนอกใบ ขึ้นเป็นแถบเหลืองดำแทนที่จะเป็นตัวเลข
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// โลโก้แอปสำหรับใช้ใน UI
///
/// อ่านจากไฟล์ย่อ ไม่ใช่ไอคอนต้นฉบับขนาด 4000×4000 ซึ่งหนัก 13MB — Flutter
/// decode bitmap เต็มขนาดเข้าหน่วยความจำก่อนย่อลงมาวาด คิดเป็นราว 64MB RAM
/// เพื่อแสดงผลสามสิบพิกเซล · [cacheWidth] กำกับซ้ำอีกชั้นให้ decode เท่าที่ใช้จริง
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'lib/assets/horplug_logo.png',
        width: size,
        height: size,
        cacheWidth: pixels,
        cacheHeight: pixels,
        // โลโก้หายไม่ใช่เหตุให้ทั้งหน้าพัง — แสดงตัวแทนที่ยังบอกได้ว่าคือแอปอะไร
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Icon(Icons.home_rounded,
              size: size * 0.6, color: AppColors.background),
        ),
      ),
    );
  }
}

/// แถบหัวของทุกหน้าในแอป
///
/// แสดงโลโก้ ชื่อแอป และชื่อหอ — สามอย่างที่ตอบว่า "นี่คือแอปอะไร ของหอไหน"
///
/// เดิม [subtitle] เป็น "ชื่อหอ • ชื่อหน้า" ซึ่งส่วนหลังบอกซ้ำกับแท็บที่ถูก
/// ไฮไลต์อยู่ด้านล่างจออยู่แล้ว หัวข้อของหน้าก็มักปรากฏเป็นหัวเรื่องใหญ่ในตัว
/// เนื้อหาอีกที ชื่อหน้าจึงถูกพูดถึงสามที่พร้อมกัน ตอนนี้เหลือชื่อหอที่เดียว
class MobileHeader extends StatelessWidget implements PreferredSizeWidget {
  /// ชื่อหอพัก · null เมื่อยังไม่รู้ (เช่นผู้เช่าที่ยังไม่ได้เข้าหอ)
  final String? dormitoryName;
  final List<Widget>? actions;

  const MobileHeader({super.key, this.dormitoryName, this.actions});

  @override
  Widget build(BuildContext context) {
    final name = dormitoryName?.trim();

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HorPlug',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                ),
                if (name != null && name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // ค่าเริ่มต้นคือไม่มีปุ่มอะไรเลย · ของเดิมเป็นกระดิ่งแจ้งเตือนที่ onPressed
      // ว่างเปล่า พร้อมจุดแดงที่ติดค้างตลอดเวลา — บอกผู้ใช้ว่ามีอะไรรออยู่ทั้งที่
      // กดแล้วไม่มีอะไรเกิดขึ้นสักครั้ง
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// A labeled row of selectable [FilterChip]s (e.g. "ชั้น: ทั้งหมด / 1 / 2 / 3").
class FilterChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  /// true = chips stay in one row and scroll horizontally instead of
  /// wrapping to a new row. Default (false) keeps the existing Wrap
  /// behavior everywhere this widget is already used.
  final bool scrollable;

  const FilterChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = options.map((option) {
      final isActive = selectedValue == option;
      return FilterChip(
        label: Text(option),
        selected: isActive,
        onSelected: (_) => onSelected(option),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isActive ? Colors.white : AppColors.primary,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        showCheckmark: false,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      chips[i],
                    ],
                  ],
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
      ],
    );
  }
}

/// แถวข้อมูล "ป้ายกำกับ: ค่า" ที่จัดคอลัมน์ป้ายให้ตรงกัน
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ข้อความแจ้งว่าส่วนย่อยส่วนหนึ่งของหน้าโหลดไม่สำเร็จ พร้อมปุ่มลองใหม่
///
/// ใช้แทนการแสดง error เต็มหน้า เมื่อหน้าประกอบด้วยหลายส่วนที่โหลดแยกกัน —
/// ส่วนที่พังส่วนเดียวไม่ควรทำให้ทั้งหน้าว่าง
class SectionErrorNote extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const SectionErrorNote({
    super.key,
    this.message = 'โหลดไม่สำเร็จ',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 16, color: AppColors.destructive),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.destructive,
                ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ring,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('ลองใหม่', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: fullWidth ? const Size(double.infinity, 48) : null,
      ),
      child: isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );

    return button;
  }
}

/// บรรทัดบอกว่าบิลใบนี้ถูกปรับยอดหลังออกไปแล้ว
///
/// เป็นบรรทัดของตัวเอง ไม่ใช่ป้ายอีกอันข้างสถานะ — แถวหัวการ์ดบิลมีชื่อเดือนกับ
/// ป้ายสถานะเบียดกันอยู่แล้วที่ความกว้าง 360dp การยัดป้ายที่สามเข้าไปทำให้ชื่อ
/// เดือนถูกตัดด้วย ellipsis บนมือถือทุกเครื่อง
///
/// ยอดเดิมสำคัญพอๆ กับการบอกว่ามีการเปลี่ยน เพราะผู้เช่าที่แคปหน้าจอ QR ระบุยอด
/// เก็บไว้ต้องเทียบได้ว่าใบที่ถืออยู่ตรงกับยอดไหน
class RecalculatedNote extends StatelessWidget {
  const RecalculatedNote({super.key, this.previousTotal});

  /// null เมื่อฐานข้อมูลยังไม่มีคอลัมน์ previous_total (ยังไม่ได้รัน
  /// invoices_recalculation.sql) — ยังบอกได้ว่าปรับแล้ว แค่ไม่รู้ว่าจากเท่าไร
  final double? previousTotal;

  @override
  Widget build(BuildContext context) {
    final previous = previousTotal;

    return Row(
      children: [
        const Icon(Icons.published_with_changes,
            size: 13, color: AppColors.warning),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            previous == null
                ? 'ปรับยอดแล้ว'
                : 'ปรับยอดแล้ว · ยอดเดิม ${formatBaht(previous)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// หัวหน้าจอ: ชื่อหน้า + คำอธิบายงวด/บริบท + ปุ่มหลักหนึ่งปุ่ม
///
/// หน้ามิเตอร์กับหน้าบิลเคยเขียนโครงนี้เองคนละชุด และทั้งสองชุดวาง `Column`
/// ของข้อความไว้ใน `Row` โดยไม่มี `Expanded` — พอป้ายปุ่มยาวขึ้น (เช่น
/// "บันทึกทั้งหมด" กลายเป็น "กำลังบันทึก...") หรือผู้ใช้ตั้งขนาดตัวอักษรของ
/// ระบบให้ใหญ่ขึ้น ข้อความจะดันจนล้นขอบเป็นแถบเหลือง-ดำแทนที่จะหดตัวเอง
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;

  /// ปุ่มหลักของหน้า · null = ไม่มีปุ่ม
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Expanded ไม่ใช่ Column เปล่าๆ — ข้อความยอมหดและตัดด้วย ellipsis
          // เพื่อให้ปุ่มได้ความกว้างที่มันต้องการเสมอ ซึ่งเป็นสิ่งที่ต้องเห็น
          // ครบมากกว่าชื่อหน้าที่ผู้ใช้อ่านไปแล้ว
          Expanded(child: text),
          if (action != null) ...[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}
