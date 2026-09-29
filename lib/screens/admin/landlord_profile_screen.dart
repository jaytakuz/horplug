import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/landlord_profile_view_model.dart';
import '../../widgets/payment_channel_form.dart';
import '../../widgets/refreshable.dart';
import '../../widgets/reusable_widgets.dart';
import '../../widgets/skeleton.dart';

/// เปิดหน้าโปรไฟล์เจ้าของหอเป็นหน้าเต็มจอแยกจากแท็บ
///
/// push ทับทั้ง shell ไม่ใช่ route ใน ShellRoute — หน้านี้เป็นการตั้งค่าที่มี
/// ปุ่มบันทึกของตัวเอง ถ้าเป็นแท็บ ผู้ใช้จะกดแท็บอื่นหนีออกไปได้ทั้งที่ยังไม่
/// บันทึก โดยไม่มีจังหวะให้ถามยืนยัน
///
/// [focusPaymentChannel] เลื่อนลงไปที่ส่วนช่องทางรับเงินหลังโหลดเสร็จ · ใช้กับ
/// ทางลัด "ช่องทางรับเงิน" บนแดชบอร์ด ซึ่งเดิมเปิดหน้าแยกของส่วนนี้โดยตรง
Future<void> showLandlordProfileScreen(
  BuildContext context, {
  bool focusPaymentChannel = false,
}) async {
  final auth = AuthScope.of(context);
  final profile = auth.profile;
  final dormitoryId = profile?.dormitoryId;
  if (profile == null || dormitoryId == null) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      // fullscreenDialog ให้ปุ่มปิด (X) แทนลูกศรย้อนกลับ — สื่อว่าเป็นหน้าแก้ไข
      // ที่เปิดขึ้นมาทำงานหนึ่งแล้วปิด ไม่ใช่อีกชั้นของการนำทาง
      fullscreenDialog: true,
      builder: (_) => ChangeNotifierProvider(
        create: (_) => LandlordProfileViewModel(
          landlordId: profile.id,
          dormitoryId: dormitoryId,
        )..load(),
        child: LandlordProfileScreen(
          focusPaymentChannel: focusPaymentChannel,
          // ชื่อหอบนแถบหัวของ shell อ่านจากโปรไฟล์ใน AuthViewModel
          onSaved: auth.reloadProfileInPlace,
        ),
      ),
    ),
  );
}

enum _LeaveChoice { keepEditing, discard, save }

class LandlordProfileScreen extends StatefulWidget {
  const LandlordProfileScreen({
    super.key,
    this.focusPaymentChannel = false,
    this.onSaved,
  });

  final bool focusPaymentChannel;

  /// เรียกหลังกดบันทึกทุกครั้ง ไม่ว่าผลจะเป็นอย่างไร — การบันทึกที่ล้มบางส่วน
  /// อาจเปลี่ยนชื่อหอไปแล้ว ส่วนอื่นของแอปที่แสดงชื่อหอต้องโหลดใหม่ตาม
  final Future<void> Function()? onSaved;

  @override
  State<LandlordProfileScreen> createState() => _LandlordProfileScreenState();
}

class _LandlordProfileScreenState extends State<LandlordProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentSectionKey = GlobalKey();

  /// เริ่มแบบไม่ตรวจ — ข้อความสีแดงเต็มฟอร์มตั้งแต่เปิดหน้า (เช่นหอที่ยังไม่มี
  /// ช่องทางรับเงิน) ทำให้ดูเหมือนมีอะไรพังทั้งที่ยังไม่ได้แตะเลย · หลังกด
  /// บันทึกแล้วไม่ผ่านหนึ่งครั้ง จึงเปลี่ยนเป็นตรวจตามที่พิมพ์
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool _didFocusPayment = false;

  /// คืน true เมื่อบันทึกสำเร็จ (หรือไม่มีอะไรต้องบันทึก)
  Future<bool> _save() async {
    final viewModel = context.read<LandlordProfileViewModel>();
    if (viewModel.isSaving) return false;
    FocusManager.instance.primaryFocus?.unfocus();

    final messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      messenger.showSnackBar(const SnackBar(
        content: Text('กรุณาแก้ช่องที่มีข้อความสีแดงก่อนบันทึก'),
      ));
      return false;
    }

    final result = await viewModel.save();
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
    await widget.onSaved?.call();
    return result.success;
  }

  Future<void> _handleBlockedPop() async {
    final viewModel = context.read<LandlordProfileViewModel>();
    // ระหว่างบันทึกห้ามปิด — ปิดตอนนี้ผู้ใช้จะไม่รู้ว่าบันทึกสำเร็จหรือไม่
    if (viewModel.isSaving) return;

    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยังไม่ได้บันทึกการเปลี่ยนแปลง'),
        content: const Text(
          'ถ้าปิดหน้านี้ตอนนี้ สิ่งที่แก้ไว้จะหายไปทั้งหมด',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: const Text('ทิ้งการแก้ไข'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_LeaveChoice.keepEditing),
            child: const Text('แก้ไขต่อ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.save),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
            ),
            child: const Text('บันทึกแล้วปิด'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (choice) {
      case _LeaveChoice.discard:
        Navigator.of(context).pop();
      case _LeaveChoice.save:
        // บันทึกไม่ผ่านต้องอยู่หน้าเดิม ให้เห็นว่าช่องไหนผิดหรือส่วนไหนล้ม
        if (await _save() && mounted) Navigator.of(context).pop();
      case _LeaveChoice.keepEditing:
      case null:
        break;
    }
  }

  void _maybeFocusPayment(LandlordProfileViewModel viewModel) {
    if (!widget.focusPaymentChannel || _didFocusPayment) return;
    if (viewModel.isLoading || viewModel.saved == null) return;
    _didFocusPayment = true;

    // รอเฟรมถัดไปให้ LoadingSwap วางเนื้อหาจริงลงไปก่อน ไม่งั้น key ยังไม่มี
    // context ให้เลื่อนไปหา
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _paymentSectionKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LandlordProfileViewModel>();
    final ready = !viewModel.isLoading && viewModel.saved != null;
    _maybeFocusPayment(viewModel);

    return PopScope(
      canPop: !viewModel.hasChanges && !viewModel.isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBlockedPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          shape: const Border(bottom: BorderSide(color: AppColors.border)),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('โปรไฟล์'),
        ),
        body: LoadingSwap(
          isLoading: viewModel.isLoading,
          semanticsLabel: 'กำลังโหลด…',
          skeleton: const LandlordProfileSkeleton(),
          builder: (context) => viewModel.saved == null
              ? _buildError(context, viewModel)
              : _buildForm(context, viewModel),
        ),
        bottomNavigationBar: ready ? _SaveBar(onSave: _save) : null,
      ),
    );
  }

  Widget _buildError(BuildContext context, LandlordProfileViewModel viewModel) {
    return PullToRefresh(
      onRefresh: viewModel.load,
      child: CenteredScrollable(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 48, color: AppColors.mutedForeground),
              const SizedBox(height: 12),
              Text('โหลดข้อมูลโปรไฟล์ไม่สำเร็จ',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                viewModel.errorMessage ?? 'กรุณาลองใหม่อีกครั้ง',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่',
                icon: Icons.refresh,
                onPressed: viewModel.load,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, LandlordProfileViewModel viewModel) {
    final mainSections = [
      _ProfileSummary(viewModel: viewModel),
      const SizedBox(height: 20),
      _PersonalSection(viewModel: viewModel),
      const SizedBox(height: 20),
      _DormitorySection(viewModel: viewModel),
      const SizedBox(height: 20),
      _RatesSection(viewModel: viewModel),
    ];
    final paymentSection = KeyedSubtree(
      key: _paymentSectionKey,
      child: _PaymentSection(viewModel: viewModel),
    );

    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      // SingleChildScrollView + Column ไม่ใช่ ListView — ListView สร้างลูกแบบ
      // lazy ช่องที่เลื่อนพ้นจอจะหลุดจาก tree แล้ว deregister จาก Form ทำให้
      // validate() ข้ามช่องนั้นไปเงียบๆ (เหตุผลเดียวกับหน้าช่องทางรับเงินเดิม)
      child: LayoutBuilder(
        builder: (context, constraints) {
          // จอกว้างวางช่องทางรับเงินเป็นคอลัมน์ขวา — ส่วนนี้ยาวที่สุด (มีคิวอาร์)
          // ถ้าต่อท้ายคอลัมน์เดียว เจ้าของหอบนเดสก์ท็อปต้องเลื่อนยาวทั้งที่
          // จอมีที่เหลือเปล่าๆ ทั้งซีก
          final twoColumns = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ContentBounds(
              maxWidth: twoColumns ? Breakpoints.contentMaxWidth : 640,
              child: twoColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: mainSections,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(child: paymentSection),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...mainSections,
                        const SizedBox(height: 20),
                        paymentSection,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// แถบบันทึกติดขอบล่าง · อยู่นอกส่วนที่เลื่อนได้ ปุ่มจึงเห็นตลอดไม่ว่าจะแก้
/// ส่วนไหนของหน้าที่ยาวเกินจอ
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.onSave});

  final Future<bool> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LandlordProfileViewModel>();
    final dirty = viewModel.hasChanges;

    final status = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Text(
        dirty ? 'มีการเปลี่ยนแปลงที่ยังไม่บันทึก' : 'ข้อมูลเป็นปัจจุบันแล้ว',
        key: ValueKey(dirty),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: dirty ? AppColors.warning : AppColors.mutedForeground,
            ),
      ),
    );
    final button = PrimaryButton(
      label: 'บันทึกการเปลี่ยนแปลง',
      icon: Icons.save_outlined,
      fullWidth: context.isCompact,
      isLoading: viewModel.isSaving,
      // ปิดปุ่มเมื่อไม่มีอะไรเปลี่ยน — ปุ่มที่กดได้เสมอทำให้เจ้าของหอไม่แน่ใจว่า
      // ที่แก้ไปเมื่อกี้บันทึกไปแล้วหรือยัง
      onPressed: dirty ? () => onSave() : null,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        // Column ขนาดเล็กสุดครอบไว้ — ContentBounds มี Center อยู่ข้างใน และ
        // bottomNavigationBar ได้ความสูงให้ถึงเต็มจอ ถ้าไม่ครอบ แถบนี้จะขยาย
        // เต็มหน้าแล้วบังเนื้อหาทั้งหมดรวมถึงปุ่มปิด
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ContentBounds(
                // จอแคบวางปุ่มเต็มกว้างอย่างเดียว — ข้อความสถานะกับปุ่มยาวๆ ไม่พอ
                // ในแถวเดียวที่ 360dp และสถานะเปิด/ปิดของปุ่มก็บอกอยู่แล้วว่ามี
                // อะไรให้บันทึกไหม
                child: context.isCompact
                    ? button
                    : Row(
                        children: [
                          Expanded(child: status),
                          const SizedBox(width: 12),
                          button,
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          )),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// ชื่อและหอบนหัวหน้า · อ่านจากค่าที่กำลังแก้ ไม่ใช่ค่าที่บันทึกไว้ — เจ้าของหอ
/// เห็นผลของสิ่งที่พิมพ์ทันที
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.viewModel});

  final LandlordProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final fullName =
        '${viewModel.firstName.trim()} ${viewModel.lastName.trim()}'.trim();
    // กรอง part ที่ว่างก่อนหยิบตัวแรก เหตุผลเดียวกับหน้าโปรไฟล์ผู้เช่า
    final initials = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();
    final dormName = viewModel.dormitoryName.trim();

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.muted,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials.isEmpty ? '?' : initials.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isEmpty ? 'เจ้าของหอ' : fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (dormName.isNotEmpty) dormName,
                  if (viewModel.email.isNotEmpty) viewModel.email,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalSection extends StatelessWidget {
  const _PersonalSection({required this.viewModel});

  final LandlordProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.person_outline,
          title: 'ข้อมูลส่วนตัว',
          subtitle: 'ผู้เช่าเห็นชื่อและเบอร์โทรนี้ในหน้าติดต่อเจ้าของหอ',
        ),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: viewModel.firstName,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => validateRequired(value, 'ชื่อ'),
                      onChanged: (value) => viewModel.update(firstName: value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: viewModel.lastName,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'นามสกุล',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => validateRequired(value, 'นามสกุล'),
                      onChanged: (value) => viewModel.update(lastName: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: viewModel.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\- ]')),
                  LengthLimitingTextInputFormatter(14),
                ],
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์',
                  hintText: '0812345678',
                  border: OutlineInputBorder(),
                ),
                validator: validatePhone,
                onChanged: (value) => viewModel.update(phone: value),
              ),
              const SizedBox(height: 12),
              // อีเมลผูกกับบัญชีเข้าสู่ระบบ การเปลี่ยนต้องยืนยันผ่านอีเมลใหม่
              // ซึ่งเป็นอีกขั้นตอนหนึ่ง · แสดงไว้ให้รู้ว่าบัญชีไหน แต่ไม่ให้แก้
              TextFormField(
                initialValue: viewModel.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  helperText: 'ใช้เข้าสู่ระบบ · เปลี่ยนจากหน้านี้ไม่ได้',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DormitorySection extends StatelessWidget {
  const _DormitorySection({required this.viewModel});

  final LandlordProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.apartment_outlined,
          title: 'ข้อมูลหอพัก',
        ),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: viewModel.dormitoryName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหอพัก',
                  helperText: 'แสดงบนแถบหัวของแอป บิล และหน้าของผู้เช่า',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => validateRequired(value, 'ชื่อหอพัก'),
                onChanged: (value) => viewModel.update(dormitoryName: value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: viewModel.location,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'ที่อยู่',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) => validateRequired(value, 'ที่อยู่'),
                onChanged: (value) => viewModel.update(location: value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RatesSection extends StatelessWidget {
  const _RatesSection({required this.viewModel});

  final LandlordProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rateFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          icon: Icons.bolt_outlined,
          title: 'อัตราค่าน้ำ-ค่าไฟ',
          subtitle: 'ค่าเริ่มต้นตอนจดมิเตอร์และออกบิล',
        ),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: viewModel.electricityRate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: [rateFormatter],
                decoration: const InputDecoration(
                  labelText: 'ค่าไฟฟ้า',
                  suffixText: 'บาท/หน่วย',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt, size: 18),
                ),
                validator: validateElectricityRate,
                onChanged: (value) => viewModel.update(electricityRate: value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: viewModel.waterRate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [rateFormatter],
                decoration: const InputDecoration(
                  labelText: 'ค่าน้ำเหมาจ่าย',
                  suffixText: 'บาท/ห้อง/เดือน',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined, size: 18),
                ),
                validator: validateWaterRate,
                onChanged: (value) => viewModel.update(waterRate: value),
              ),
              const SizedBox(height: 12),
              // มิเตอร์แต่ละงวดเก็บอัตราของตัวเองไว้ตอนบันทึก · ต้องบอกให้ชัด
              // ไม่งั้นเจ้าของหอจะคาดว่าบิลเดือนนี้ที่ออกไปแล้วเปลี่ยนตาม
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'อัตราใหม่ใช้กับงวดที่ยังไม่ได้จดมิเตอร์ · งวดที่บันทึก'
                      'แล้วและบิลที่ออกไปแล้วยังใช้อัตราเดิม',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.viewModel});

  final LandlordProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final channel = viewModel.paymentChannel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.qr_code_2,
          title: 'ช่องทางรับเงิน',
          trailing: channel.errorMessage == null && !channel.isConfigured
              ? const StatusBadge(
                  label: 'ยังไม่ได้ตั้งค่า',
                  variant: BadgeVariant.warning,
                )
              : null,
        ),
        // โหลดส่วนนี้ล้มต้องซ่อนฟอร์ม ไม่ใช่โชว์ช่องว่าง — ช่องว่างดูเหมือนยังไม่
        // เคยตั้งค่า เจ้าของหอที่กรอกใหม่แล้วบันทึกจะเขียนทับของเดิมที่ยังอยู่
        if (channel.errorMessage != null)
          PaperCard(
            child: SectionErrorNote(
              message: 'โหลดช่องทางรับเงินไม่สำเร็จ: ${channel.errorMessage}',
              onRetry: channel.load,
            ),
          )
        else
          PaymentChannelFields(viewModel: channel),
      ],
    );
  }
}

/// โครงร่างของหน้าโปรไฟล์ระหว่างโหลดครั้งแรก · เป็น public เพื่อให้เทสต์ pump
/// ได้โดยไม่ต้องมี Supabase
///
/// ยึดเลย์เอาต์คอลัมน์เดียวของจอแคบ — จอกว้างจะเห็นเนื้อหาจริงแตกเป็นสองคอลัมน์
/// ตอนจางเข้ามา ซึ่งยอมรับได้เพราะหน้านี้ไม่มีรายการยาวที่ผู้ใช้กำลังไล่อ่าน
class LandlordProfileSkeleton extends StatelessWidget {
  const LandlordProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget field() => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonBox(height: 48, radius: 8),
        );
    Widget section(int fields) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: SkeletonBox(width: 120, height: 16),
            ),
            PaperCard(
              child: Column(
                children: [for (var i = 0; i < fields; i++) field()],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );

    return SkeletonScope(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ContentBounds(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  SkeletonBox(width: 56, height: 56, radius: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 160, height: 20),
                        SizedBox(height: 6),
                        SkeletonBox(width: 200, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              section(3),
              section(2),
              section(2),
            ],
          ),
        ),
      ),
    );
  }
}
