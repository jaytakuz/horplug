import 'package:flutter/material.dart';

/// controller ที่แสดงข้อความเป็นจุดเองตอน render โดยค่าจริงยังอยู่ใน [text]
///
/// ใช้แทน `obscureText` เพราะ Flutter โชว์ตัวอักษรตัวสุดท้ายที่เพิ่งพิมพ์ชั่วครู่
/// ตามค่าของระบบ (`brieflyShowPassword`) และไม่มีตัวเลือกปิดต่อช่อง · จำนวนจุด
/// เท่ากับความยาวข้อความพอดี ตำแหน่ง cursor/selection จึงตรงกันเสมอ
class MaskedTextEditingController extends TextEditingController {
  MaskedTextEditingController({super.text});

  bool _masked = true;

  bool get masked => _masked;

  set masked(bool value) {
    if (_masked == value) return;
    _masked = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!_masked) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return TextSpan(style: style, text: '•' * text.length);
  }
}

/// ช่องกรอกรหัสผ่านที่ไม่โชว์ตัวอักษรตัวสุดท้าย พร้อมปุ่มสลับดู/ซ่อน
class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final MaskedTextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return TextFormField(
      controller: controller,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      // obscureText ห้ามคัดลอกเมื่อซ่อนอยู่ · ตอน mask เอง Flutter ไม่รู้ว่านี่คือ
      // รหัสผ่าน จึงต้องตัด copy/cut ออกจากเมนูเอง
      contextMenuBuilder: (context, editableTextState) {
        final items = editableTextState.contextMenuButtonItems
            .where(
              (item) =>
                  !controller.masked ||
                  (item.type != ContextMenuButtonType.copy &&
                      item.type != ContextMenuButtonType.cut),
            )
            .toList();
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: IconButton(
          icon: Icon(controller.masked
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: () => setState(() => controller.masked = !controller.masked),
        ),
      ),
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
    );
  }
}
