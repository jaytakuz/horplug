import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/promptpay.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/payment_channel_view_model.dart';
import '../../widgets/promptpay_qr.dart';
import '../../widgets/reusable_widgets.dart';

/// เปิดหน้าตั้งค่าช่องทางชำระเงินของหอ · คืน true เมื่อบันทึกสำเร็จ
Future<bool> showPaymentChannelScreen(
  BuildContext context, {
  required int dormitoryId,
}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => PaymentChannelViewModel(dormitoryId: dormitoryId)..load(),
        child: const _PaymentChannelScreen(),
      ),
    ),
  );
  return saved ?? false;
}

class _PaymentChannelScreen extends StatefulWidget {
  const _PaymentChannelScreen();

  @override
  State<_PaymentChannelScreen> createState() => _PaymentChannelScreenState();
}

class _PaymentChannelScreenState extends State<_PaymentChannelScreen> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _save() async {
    final viewModel = context.read<PaymentChannelViewModel>();
    if (viewModel.isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await viewModel.save();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PaymentChannelViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('ช่องทางชำระเงิน'),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (viewModel.errorMessage != null) ...[
                      SectionErrorNote(message: viewModel.errorMessage!),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'ผู้เช่าจะเห็นข้อมูลนี้ตอนกดชำระเงิน และคิวอาร์จะฝังยอด'
                      'ของบิลแต่ละใบให้อัตโนมัติ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _buildPromptPaySection(context, viewModel),
                    const SizedBox(height: 20),
                    _buildBankSection(context, viewModel),
                    const SizedBox(height: 20),
                    _buildAccountNameField(viewModel),
                    const SizedBox(height: 12),
                    // ตรวจ "ต้องมีอย่างน้อยหนึ่งช่องทาง" ที่ระดับฟอร์ม ไม่ใช่ราย
                    // ช่อง เพราะเป็นเงื่อนไขข้ามช่อง — ผูกไว้กับ FormField ที่ไม่มี
                    // ช่องกรอกของตัวเอง เพื่อให้เข้าร่วม validate() ตามปกติ
                    FormField<void>(
                      validator: (_) => validateHasAnyChannel(
                        promptPayId: viewModel.promptPayId,
                        bankName: viewModel.bankName,
                        accountNo: viewModel.accountNo,
                      ),
                      builder: (field) => field.hasError
                          ? SectionErrorNote(message: field.errorText!)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'บันทึก',
                      icon: Icons.save_outlined,
                      fullWidth: true,
                      isLoading: viewModel.isSaving,
                      onPressed: _save,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPromptPaySection(
    BuildContext context,
    PaymentChannelViewModel viewModel,
  ) {
    final payload = viewModel.previewPayload;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('พร้อมเพย์', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: viewModel.promptPayId,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(13),
            ],
            decoration: const InputDecoration(
              labelText: 'เบอร์พร้อมเพย์',
              hintText: '0812345678',
              helperText: 'เบอร์โทร 10 หลัก หรือเลขบัตรประชาชน 13 หลัก',
              border: OutlineInputBorder(),
            ),
            validator: validatePromptPayId,
            onChanged: (value) => viewModel.update(promptPayId: value),
          ),
          const SizedBox(height: 16),
          // QR ตัวอย่างด้วยยอดสมมติ — เจ้าของหอสแกนตรวจเองได้ก่อนบันทึกว่า
          // เข้าบัญชีถูกใบ ซึ่งเป็นทางเดียวที่จะจับเบอร์ที่พิมพ์ผิดแต่ครบ 10 หลัก
          if (payload != null) ...[
            Center(child: PromptPayQr(payload: payload, size: 180)),
            const SizedBox(height: 8),
            Text(
              'ลองสแกนด้วยแอปธนาคารเพื่อตรวจว่าเข้าบัญชีถูกต้อง '
              '(ตัวอย่างยอด ${formatBaht(PaymentChannelViewModel.previewAmount)} '
              'ยังไม่ต้องกดโอน)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
          ] else if (viewModel.promptPayId.trim().isNotEmpty)
            Text(
              'กรอกให้ครบ 10 หรือ 13 หลักเพื่อดูตัวอย่างคิวอาร์',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildBankSection(
    BuildContext context,
    PaymentChannelViewModel viewModel,
  ) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('บัญชีธนาคาร (ไม่บังคับ)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'สำหรับผู้เช่าที่สแกนคิวอาร์ไม่ได้',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: viewModel.bankName,
            decoration: const InputDecoration(
              labelText: 'ชื่อธนาคาร',
              hintText: 'ธนาคารกสิกรไทย',
              border: OutlineInputBorder(),
            ),
            validator: (value) => validateBankPair(
              bankName: value ?? '',
              accountNo: viewModel.accountNo,
            ),
            onChanged: (value) => viewModel.update(bankName: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: viewModel.accountNo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'เลขบัญชี',
              hintText: '1438323216',
              border: OutlineInputBorder(),
            ),
            validator: (value) => validateBankPair(
              bankName: viewModel.bankName,
              accountNo: value ?? '',
            ),
            onChanged: (value) => viewModel.update(accountNo: value),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNameField(PaymentChannelViewModel viewModel) {
    return PaperCard(
      child: TextFormField(
        initialValue: viewModel.accountName,
        decoration: const InputDecoration(
          labelText: 'ชื่อบัญชี',
          hintText: 'ชื่อตามสมุดบัญชี',
          helperText: 'ผู้เช่าใช้ชื่อนี้ตรวจปลายทางก่อนกดโอน',
          border: OutlineInputBorder(),
        ),
        validator: (value) => (value?.trim().isEmpty ?? true)
            ? 'กรุณากรอกชื่อบัญชี'
            : null,
        onChanged: (value) => viewModel.update(accountName: value),
      ),
    );
  }
}
