import 'package:flutter/material.dart';

import '../../viewmodels/auth_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthScope.of(context).updatePassword(
        password: _passwordController.text,
      );
      // Router will redirect to home once isRecovering = false and profile loads
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _mapError(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable')) {
      return 'เปลี่ยนรหัสผ่านไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต';
    }
    if (lower.contains('weak password') || lower.contains('password')) {
      return 'เปลี่ยนรหัสผ่านไม่สำเร็จ: รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    }
    return 'เปลี่ยนรหัสผ่านไม่สำเร็จ: กรุณาลองใหม่อีกครั้ง';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: PaperCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ตั้งรหัสผ่านใหม่',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กรอกรหัสผ่านใหม่ของคุณ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่านใหม่',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onFieldSubmitted: (_) =>
                            _confirmFocusNode.requestFocus(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรอกรหัสผ่านใหม่';
                          }
                          if (value.length < 6) {
                            return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        focusNode: _confirmFocusNode,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'ยืนยันรหัสผ่านใหม่',
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        onFieldSubmitted: (_) =>
                            _isLoading ? null : _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'ยืนยันรหัสผ่านใหม่';
                          }
                          if (value != _passwordController.text) {
                            return 'รหัสผ่านไม่ตรงกัน';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.destructive),
                        ),
                      ],
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'บันทึกรหัสผ่านใหม่',
                        fullWidth: true,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
