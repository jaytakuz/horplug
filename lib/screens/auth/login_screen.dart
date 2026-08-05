import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../viewmodels/auth_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthScope.of(context).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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
      return 'เข้าสู่ระบบไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต';
    }
    return 'เข้าสู่ระบบไม่สำเร็จ: อีเมลหรือรหัสผ่านไม่ถูกต้อง';
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
                        'เข้าสู่ระบบ HorPlug',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กรอกอีเมลและรหัสผ่านเพื่อเข้าสู่ระบบ',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'อีเมล',
                        ),
                        onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรอกรหัสผ่าน';
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
                        label: 'เข้าสู่ระบบ',
                        fullWidth: true,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('สมัครใช้งาน',
                                style: TextStyle(
                                    decoration: TextDecoration.underline)),
                          ),
                          TextButton(
                            onPressed: () => context.go('/forgot-password'),
                            child: const Text('ลืมรหัสผ่าน',
                                style: TextStyle(
                                    decoration: TextDecoration.underline)),
                          ),
                        ],
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
