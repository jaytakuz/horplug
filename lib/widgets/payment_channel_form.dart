import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/thai_bank.dart';
import '../services/promptpay.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../viewmodels/payment_channel_view_model.dart';
import 'promptpay_qr.dart';
import 'reusable_widgets.dart';

/// ช่องกรอกช่องทางรับเงินของหอ (พร้อมเพย์ บัญชีธนาคาร ชื่อบัญชี)
///
/// ต้องอยู่ใต้ [Form] ของหน้าที่ใช้ · ปุ่มบันทึกเป็นของหน้านั้น ไม่ใช่ของส่วนนี้
///
/// เดิมเป็นหน้าแยกที่เปิดจากหน้าบิล ย้ายมาอยู่ในหน้าโปรไฟล์เจ้าของหอ เพราะเป็น
/// การตั้งค่าที่ทำครั้งเดียวตอนเปิดหอ อยู่กลุ่มเดียวกับชื่อหอและอัตราค่าไฟ
/// ไม่ใช่งานประจำเดือนแบบการออกบิล
///
/// ตัวตรวจทุกตัวทำงานเฉพาะตอนที่ส่วนนี้ถูกแก้ ([PaymentChannelViewModel.hasChanges])
/// — หอที่ยังไม่เคยตั้งช่องทางต้องบันทึกชื่อหรือค่าไฟในหน้าเดียวกันได้ โดยไม่
/// โดนบังคับกรอกพร้อมเพย์ก่อน
class PaymentChannelFields extends StatelessWidget {
  const PaymentChannelFields({super.key, required this.viewModel});

  final PaymentChannelViewModel viewModel;

  String? _gate(String? message) => viewModel.hasChanges ? message : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ผู้เช่าจะเห็นข้อมูลนี้ตอนกดชำระเงิน และคิวอาร์จะฝังยอด'
          'ของบิลแต่ละใบให้อัตโนมัติ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 12),
        _buildPromptPaySection(context, viewModel),
        const SizedBox(height: 12),
        _buildBankSection(context, viewModel),
        const SizedBox(height: 12),
        _buildAccountNameField(viewModel),
        // ตรวจ "ต้องมีอย่างน้อยหนึ่งช่องทาง" ที่ระดับฟอร์ม ไม่ใช่รายช่อง เพราะ
        // เป็นเงื่อนไขข้ามช่อง — ผูกไว้กับ FormField ที่ไม่มีช่องกรอกของตัวเอง
        // เพื่อให้เข้าร่วม validate() ตามปกติ
        FormField<void>(
          validator: (_) => _gate(validateHasAnyChannel(
            promptPayId: viewModel.promptPayId,
            bankName: viewModel.bankName,
            accountNo: viewModel.accountNo,
          )),
          builder: (field) => field.hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SectionErrorNote(message: field.errorText!),
                )
              : const SizedBox.shrink(),
        ),
      ],
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
            validator: (value) => _gate(validatePromptPayId(value)),
            onChanged: (value) => viewModel.update(promptPayId: value),
          ),
          const SizedBox(height: 16),
          // QR ตัวอย่างด้วยยอดสมมติ — เจ้าของหอสแกนตรวจเองได้ก่อนบันทึกว่า
          // เข้าบัญชีถูกใบ ซึ่งเป็นทางเดียวที่จะจับเบอร์ที่พิมพ์ผิดแต่ครบ 10 หลัก
          // ช่องกรอกยอดผูกกับความถูกต้องของ "เบอร์" ไม่ใช่ของ payload — ยอดที่
          // ใช้ไม่ได้ทำให้ payload เป็น null และถ้าผูกไว้ด้วยกัน ช่องกรอกจะหาย
          // ไปพร้อมคิวอาร์ทันทีที่ลบยอดทิ้งเพื่อพิมพ์ใหม่
          if (viewModel.canPreviewQr) ...[
            if (payload != null) ...[
              Center(child: PromptPayQr(payload: payload, size: 180)),
              const SizedBox(height: 12),
            ],
            // ปรับยอดได้เพราะการตรวจที่แน่นอนที่สุดคือโอนจริงด้วยยอดเล็กๆ แล้วดู
            // ว่าเงินเข้าบัญชีไหม · ยอดตายตัวบังคับให้ต้องโอนเงินจำนวนนั้นจริง
            // เพื่อทดสอบ ซึ่งไม่มีใครทำ แล้วการตรวจก็เลยไม่เกิดขึ้นเลย
            TextFormField(
              // คิวอาร์ข้างบนโผล่/หายตามความถูกต้องของยอด จำนวนลูกของ Column
              // จึงเปลี่ยน · ไม่มีคีย์ Flutter จะจับคู่ element ตามตำแหน่ง ช่องนี้
              // เลยถูกสร้างใหม่ ข้อความที่พิมพ์ค้างหายและโฟกัสหลุดกลางคัน
              key: const ValueKey('preview-amount'),
              initialValue: PaymentChannelViewModel.defaultPreviewAmount
                  .toStringAsFixed(2),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'ยอดในคิวอาร์ตัวอย่าง',
                prefixText: '฿ ',
                helperText: 'ลองใส่ยอดน้อยๆ แล้วโอนจริงเพื่อตรวจว่าเงินเข้า'
                    'บัญชีถูกใบ',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
                // บอกไปตรงๆ ว่าทำไมคิวอาร์หาย ไม่ใช่ปล่อยให้เดา
                errorText: viewModel.previewAmount == null
                    ? 'ใส่ยอดมากกว่า 0 เพื่อดูคิวอาร์'
                    : null,
              ),
              onChanged: viewModel.setPreviewAmount,
            ),
            if (viewModel.previewAmount != null) ...[
              const SizedBox(height: 8),
              Text(
                'คิวอาร์นี้เป็นของจริง — สแกนแล้วโอนได้ทันที '
                'ยอด ${formatBaht(viewModel.previewAmount!)} จะเข้าบัญชีนี้',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
            ],
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
          // เลือกจากรายการแทนการพิมพ์เอง — ชื่อธนาคารที่สะกดต่างกันเล็กน้อย
          // ("กสิกร" กับ "ธนาคารกสิกรไทย") ทำให้ผู้เช่าต้องเดาว่าหมายถึงที่เดียวกัน
          // ไหม ตอนกำลังจะโอนเงิน
          DropdownButtonFormField<ThaiBank>(
            initialValue: viewModel.selectedBank,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'ธนาคาร',
              border: const OutlineInputBorder(),
              // หอที่ตั้งค่าไว้ตอนช่องนี้ยังพิมพ์เองได้ อาจมีชื่อที่ไม่ตรงรายการ
              // บอกให้เห็นว่าค่าเดิมคืออะไร แทนที่จะทำเหมือนไม่เคยกรอก
              helperText: viewModel.hasUnlistedBank
                  ? 'ค่าเดิม "${viewModel.bankName}" ไม่อยู่ในรายการ '
                      'เลือกใหม่เพื่อแทนที่'
                  : null,
              helperMaxLines: 2,
            ),
            hint: const Text('เลือกธนาคาร'),
            items: [
              const DropdownMenuItem<ThaiBank>(
                child: Text('— ไม่ระบุ —'),
              ),
              ...ThaiBank.values.map(
                (bank) => DropdownMenuItem(
                  value: bank,
                  child:
                      Text(bank.displayName, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            validator: (_) => _gate(validateBankPair(
              bankName: viewModel.bankName,
              accountNo: viewModel.accountNo,
            )),
            onChanged: viewModel.selectBank,
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
            validator: (value) => _gate(validateBankPair(
              bankName: viewModel.bankName,
              accountNo: value ?? '',
            )),
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
        validator: (value) => _gate(
            (value?.trim().isEmpty ?? true) ? 'กรุณากรอกชื่อบัญชี' : null),
        onChanged: (value) => viewModel.update(accountName: value),
      ),
    );
  }
}
