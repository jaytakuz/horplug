import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dormitoryNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _totalFloorsController = TextEditingController();
  final _roomsPerFloorController = TextEditingController();
  final _baseWaterRateController = TextEditingController();
  final _baseElectricityRateController = TextEditingController();

  // Focus nodes for Tab/Enter navigation
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _dormitoryNameFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _totalFloorsFocus = FocusNode();
  final _roomsPerFloorFocus = FocusNode();
  final _baseWaterRateFocus = FocusNode();
  final _baseElectricityRateFocus = FocusNode();

  AppRole _selectedRole = AppRole.tenant;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dormitoryNameController.dispose();
    _locationController.dispose();
    _totalFloorsController.dispose();
    _roomsPerFloorController.dispose();
    _baseWaterRateController.dispose();
    _baseElectricityRateController.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _dormitoryNameFocus.dispose();
    _locationFocus.dispose();
    _totalFloorsFocus.dispose();
    _roomsPerFloorFocus.dispose();
    _baseWaterRateFocus.dispose();
    _baseElectricityRateFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthScope.of(context);

      if (_selectedRole == AppRole.tenant) {
        await auth.registerTenant(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      } else {
        await auth.registerLandlord(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          dormitoryName: _dormitoryNameController.text.trim(),
          location: _locationController.text.trim(),
          totalFloors: int.parse(_totalFloorsController.text.trim()),
          roomsPerFloor: int.parse(_roomsPerFloorController.text.trim()),
          baseWaterRate: double.parse(_baseWaterRateController.text.trim()),
          baseElectricityRate:
              double.parse(_baseElectricityRateController.text.trim()),
        );
      }
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
      return 'สมัครไม่สำเร็จ: กรุณาตรวจสอบอินเตอร์เน็ต';
    }
    if (lower.contains('already registered') ||
        lower.contains('email_exists') ||
        lower.contains('email already')) {
      return 'สมัครไม่สำเร็จ: อีเมลถูกใช้ไปแล้ว';
    }
    if (lower.contains('dormitory_name_exists')) {
      return 'สมัครไม่สำเร็จ: ชื่อหอพักถูกใช้ไปแล้ว';
    }
    if (lower.contains('database error saving new user') ||
        (error is PostgrestException && error.code == '23505')) {
      return 'สมัครไม่สำเร็จ: ชื่อถูกใช้ไปแล้ว';
    }
    return 'สมัครไม่สำเร็จ: ${error.toString().replaceFirst('AuthException: ', '').replaceFirst('Exception: ', '')}';
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'กรอก$fieldName';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLandlord = _selectedRole == AppRole.landlord;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: PaperCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สมัครใช้งาน',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<AppRole>(
                        segments: const [
                          ButtonSegment(
                            value: AppRole.tenant,
                            label: Text('ผู้พักอาศัย'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: AppRole.landlord,
                            label: Text('เจ้าของหอพัก'),
                            icon: Icon(Icons.apartment_outlined),
                          ),
                        ],
                        selected: {_selectedRole},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _selectedRole = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'ชื่อ'),
                              onFieldSubmitted: (_) => _lastNameFocus.requestFocus(),
                              validator: (value) => _requiredValidator(value, 'ชื่อ'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              focusNode: _lastNameFocus,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'นามสกุล'),
                              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                              validator: (value) => _requiredValidator(value, 'นามสกุล'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'อีเมล'),
                        onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                        validator: (value) {
                          final required = _requiredValidator(value, 'อีเมล');
                          if (required != null) return required;
                          if (!value!.contains('@')) return 'อีเมลไม่ถูกต้อง';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (value) => _requiredValidator(value, 'เบอร์โทรศัพท์'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
                        onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
                        validator: (value) {
                          final required = _requiredValidator(value, 'รหัสผ่าน');
                          if (required != null) return required;
                          if (value!.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocus,
                        obscureText: true,
                        textInputAction: isLandlord ? TextInputAction.next : TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่าน'),
                        onFieldSubmitted: (_) => isLandlord
                            ? _dormitoryNameFocus.requestFocus()
                            : (_isLoading ? null : _submit()),
                        validator: (value) {
                          final required = _requiredValidator(value, 'ยืนยันรหัสผ่าน');
                          if (required != null) return required;
                          if (value != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
                          return null;
                        },
                      ),
                      if (isLandlord) ...[
                        const SizedBox(height: 24),
                        Text('ข้อมูลหอพัก', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _dormitoryNameController,
                          focusNode: _dormitoryNameFocus,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'ชื่อหอพัก'),
                          onFieldSubmitted: (_) => _locationFocus.requestFocus(),
                          validator: (value) => _requiredValidator(value, 'ชื่อหอพัก'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          focusNode: _locationFocus,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'ที่อยู่'),
                          onFieldSubmitted: (_) => _totalFloorsFocus.requestFocus(),
                          validator: (value) => _requiredValidator(value, 'ที่อยู่'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _totalFloorsController,
                                focusNode: _totalFloorsFocus,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'จำนวนชั้น'),
                                onFieldSubmitted: (_) => _roomsPerFloorFocus.requestFocus(),
                                validator: (value) => _requiredValidator(value, 'จำนวนชั้น'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _roomsPerFloorController,
                                focusNode: _roomsPerFloorFocus,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'ห้องต่อชั้น'),
                                onFieldSubmitted: (_) => _baseWaterRateFocus.requestFocus(),
                                validator: (value) => _requiredValidator(value, 'ห้องต่อชั้น'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _baseWaterRateController,
                                focusNode: _baseWaterRateFocus,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(labelText: 'ค่าน้ำพื้นฐาน'),
                                onFieldSubmitted: (_) => _baseElectricityRateFocus.requestFocus(),
                                validator: (value) => _requiredValidator(value, 'ค่าน้ำพื้นฐาน'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _baseElectricityRateController,
                                focusNode: _baseElectricityRateFocus,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(labelText: 'ค่าไฟพื้นฐาน'),
                                onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                                validator: (value) => _requiredValidator(value, 'ค่าไฟพื้นฐาน'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.destructive),
                        ),
                      ],
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: isLandlord
                            ? 'สมัครใช้งานเจ้าของหอพัก'
                            : 'สมัครใช้งาน',
                        fullWidth: true,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('เข้าสู่ระบบ', 
                        style: TextStyle(decoration: TextDecoration.underline)),
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
