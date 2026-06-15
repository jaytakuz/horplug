import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthScope.of(context).sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _emailSent = true;
      });
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
    if (error is SocketException ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('no route to host') ||
        lower.contains('network is unreachable')) {
      return 'ส่งอีเมลไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'ส่งอีเมลไม่สำเร็จ: ลองใหม่อีกครั้งในภายหลัง';
    }
    return 'ส่งอีเมลไม่สำเร็จ: กรุณาลองใหม่อีกครั้ง';
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
                child: _emailSent ? _buildSuccessView() : _buildFormView(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ลืมรหัสผ่าน',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'กรอกอีเมลที่ใช้สมัคร ระบบจะส่งลิงก์รีเซ็ตรหัสผ่านไปให้',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'อีเมล',
            ),
            onFieldSubmitted: (_) => _isLoading ? null : _submit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรอกอีเมล';
              }
              if (!value.contains('@')) {
                return 'รูปแบบอีเมลไม่ถูกต้อง';
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
            label: 'รีเซ็ตรหัสผ่าน',
            fullWidth: true,
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text(
              'กลับสู่หน้าเข้าสู่ระบบ',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ส่งอีเมลแล้ว',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'ระบบส่งลิงก์รีเซ็ตรหัสผ่านไปที่ ${_emailController.text.trim()} แล้ว\nกรุณาตรวจสอบกล่องจดหมายของคุณ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'กลับสู่หน้าเข้าสู่ระบบ',
          fullWidth: true,
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
