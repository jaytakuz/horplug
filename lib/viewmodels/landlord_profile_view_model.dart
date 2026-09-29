import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/models.dart';
import '../services/landlord_profile_service.dart';
import 'action_result.dart';
import 'error_message.dart';
import 'payment_channel_view_model.dart';
import 'safe_notifier.dart';

/// ค่าไฟต่อหน่วยที่สูงเกินนี้แทบแน่ใจว่าพิมพ์เกิน (เช่น 80 แทน 8) · การไฟฟ้า
/// เก็บราว 4–5 บาท หอทั่วไปเก็บ 7–10 บาท
const maxElectricityRate = 100.0;

/// ค่าน้ำเหมาจ่ายต่อห้องต่อเดือนที่สูงเกินนี้น่าจะพิมพ์ศูนย์เกินมา
const maxWaterRate = 10000.0;

/// แปลงข้อความในช่องอัตราเป็นตัวเลข · null เมื่อไม่ใช่ตัวเลข
double? parseRate(String value) =>
    double.tryParse(value.trim().replaceAll(',', ''));

String? validateRequired(String? value, String fieldName) =>
    (value?.trim().isEmpty ?? true) ? 'กรุณากรอก$fieldName' : null;

/// เบอร์โทรไทย 9–10 หลัก · ยอมให้มีขีดหรือช่องว่างคั่น เพราะคนพิมพ์กันแบบนั้น
String? validatePhone(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'กรุณากรอกเบอร์โทรศัพท์';
  if (!RegExp(r'^[0-9\- ]+$').hasMatch(raw)) {
    return 'เบอร์โทรใช้ได้เฉพาะตัวเลข';
  }
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 9 || digits.length > 10) {
    return 'เบอร์โทรต้องมี 9–10 หลัก';
  }
  return null;
}

String? validateElectricityRate(String? value) {
  if (value == null || value.trim().isEmpty) return 'กรุณากรอกค่าไฟต่อหน่วย';
  final rate = parseRate(value);
  if (rate == null) return 'กรอกเป็นตัวเลข เช่น 8 หรือ 7.50';
  if (rate <= 0) return 'ค่าไฟต้องมากกว่า 0';
  if (rate > maxElectricityRate) {
    return 'ค่าไฟสูงผิดปกติ — ตรวจว่าพิมพ์เกินหรือไม่';
  }
  return null;
}

String? validateWaterRate(String? value) {
  if (value == null || value.trim().isEmpty) return 'กรุณากรอกค่าน้ำ';
  final rate = parseRate(value);
  if (rate == null) return 'กรอกเป็นตัวเลข เช่น 100';
  // ค่าน้ำ 0 ใช้ได้ — บางหอรวมค่าน้ำไว้ในค่าเช่าแล้ว
  if (rate < 0) return 'ค่าน้ำติดลบไม่ได้';
  if (rate > maxWaterRate) return 'ค่าน้ำสูงผิดปกติ — ตรวจว่าพิมพ์เกินหรือไม่';
  return null;
}

/// หน้าโปรไฟล์เจ้าของหอ: ข้อมูลส่วนตัว ข้อมูลหอ อัตราค่าน้ำ-ไฟ และช่องทางรับเงิน
///
/// ทั้งหน้ามีปุ่มบันทึกปุ่มเดียว แต่เบื้องหลังเขียนแยกสามที่ (สองตาราง + ช่องทาง
/// รับเงิน) และเขียนเฉพาะส่วนที่ถูกแก้ · ส่วนที่บันทึกสำเร็จถูกนับว่าเป็นค่าใหม่
/// ทันทีแม้ส่วนอื่นจะล้ม เจ้าของหอจึงกดบันทึกซ้ำได้โดยไม่เขียนของที่ผ่านแล้วอีก
class LandlordProfileViewModel extends ChangeNotifier with SafeNotifier {
  LandlordProfileViewModel({
    required this.landlordId,
    required this.dormitoryId,
    LandlordProfileService? service,
    PaymentChannelViewModel? paymentChannel,
  })  : _service = service ?? LandlordProfileService(),
        paymentChannel = paymentChannel ??
            PaymentChannelViewModel(dormitoryId: dormitoryId) {
    this.paymentChannel.addListener(notifyListeners);
  }

  final String landlordId;
  final int dormitoryId;
  final LandlordProfileService _service;

  /// ฟอร์มช่องทางรับเงินเดิมทั้งชุด · ผูกไว้ในนี้เพื่อให้ปุ่มบันทึกกับกล่องยืนยัน
  /// ตอนปิดหน้ารู้ว่าส่วนนี้ถูกแก้หรือเปล่า
  final PaymentChannelViewModel paymentChannel;

  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  /// ค่าในฐานข้อมูลตอนนี้ · null ระหว่างโหลดครั้งแรกหรือโหลดล้ม
  LandlordSettings? saved;

  String firstName = '';
  String lastName = '';
  String phone = '';
  String dormitoryName = '';
  String location = '';

  /// เก็บเป็นข้อความตามที่พิมพ์ ไม่ใช่ double — ช่องที่กำลังพิมพ์ "7." ต้องไม่
  /// ถูกแปลงเป็น 7.0 กลับไปทับสิ่งที่ผู้ใช้กำลังพิมพ์
  String electricityRate = '';
  String waterRate = '';

  String get email => saved?.email ?? '';

  bool get profileChanged {
    final s = saved;
    if (s == null) return false;
    return firstName.trim() != s.firstName.trim() ||
        lastName.trim() != s.lastName.trim() ||
        phone.trim() != s.phone.trim();
  }

  bool get dormitoryChanged {
    final s = saved;
    if (s == null) return false;
    // เทียบเป็นตัวเลข ไม่ใช่ข้อความ — "8" กับ "8.00" คืออัตราเดียวกัน ถ้าเทียบ
    // ข้อความ แค่แตะช่องแล้วพิมพ์ทศนิยมก็ถูกนับว่าแก้ แล้วโดนถามยืนยันตอนปิดหน้า
    return dormitoryName.trim() != s.dormitoryName.trim() ||
        location.trim() != s.location.trim() ||
        parseRate(electricityRate) != s.baseElectricityRate ||
        parseRate(waterRate) != s.baseWaterRate;
  }

  bool get hasChanges =>
      profileChanged || dormitoryChanged || paymentChannel.hasChanges;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // ช่องทางรับเงินจัดการ error ของตัวเอง (แสดงในส่วนของมันเอง) — ส่วนนั้น
      // โหลดล้มไม่ควรทำให้เจ้าของหอแก้ชื่อหรือค่าไฟไม่ได้
      final results = await Future.wait<Object?>([
        _service.fetch(landlordId: landlordId, dormitoryId: dormitoryId),
        paymentChannel.load(),
      ]);
      _apply(results[0] as LandlordSettings);
    } catch (error) {
      errorMessage = formatErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _apply(LandlordSettings settings) {
    saved = settings;
    firstName = settings.firstName;
    lastName = settings.lastName;
    phone = settings.phone;
    dormitoryName = settings.dormitoryName;
    location = settings.location;
    electricityRate = _formatRate(settings.baseElectricityRate);
    waterRate = _formatRate(settings.baseWaterRate);
  }

  void update({
    String? firstName,
    String? lastName,
    String? phone,
    String? dormitoryName,
    String? location,
    String? electricityRate,
    String? waterRate,
  }) {
    this.firstName = firstName ?? this.firstName;
    this.lastName = lastName ?? this.lastName;
    this.phone = phone ?? this.phone;
    this.dormitoryName = dormitoryName ?? this.dormitoryName;
    this.location = location ?? this.location;
    this.electricityRate = electricityRate ?? this.electricityRate;
    this.waterRate = waterRate ?? this.waterRate;
    notifyListeners();
  }

  /// บันทึกเฉพาะส่วนที่แก้ · ผู้เรียกต้อง validate ฟอร์มก่อน
  Future<ActionResult> save() async {
    final before = saved;
    if (before == null || isSaving) {
      return const ActionResult(
          success: false, message: 'ยังโหลดข้อมูลไม่เสร็จ');
    }
    if (!hasChanges) {
      return const ActionResult(success: true, message: 'ไม่มีการเปลี่ยนแปลง');
    }

    isSaving = true;
    notifyListeners();

    final failures = <String>[];
    var current = before;

    try {
      if (profileChanged) {
        try {
          await _service.saveProfile(
            landlordId: landlordId,
            firstName: firstName,
            lastName: lastName,
            phone: phone,
          );
          current = _copy(current,
              firstName: firstName.trim(),
              lastName: lastName.trim(),
              phone: phone.trim());
        } catch (error) {
          failures.add('ข้อมูลส่วนตัว: ${formatErrorMessage(error)}');
        }
      }

      if (dormitoryChanged) {
        try {
          final electricity = parseRate(electricityRate)!;
          final water = parseRate(waterRate)!;
          await _service.saveDormitory(
            dormitoryId: dormitoryId,
            name: dormitoryName,
            location: location,
            baseElectricityRate: electricity,
            baseWaterRate: water,
          );
          current = _copy(current,
              dormitoryName: dormitoryName.trim(),
              location: location.trim(),
              baseElectricityRate: electricity,
              baseWaterRate: water);
        } catch (error) {
          failures.add('ข้อมูลหอพัก: ${_describeDormitoryError(error)}');
        }
      }

      if (paymentChannel.hasChanges) {
        final result = await paymentChannel.save();
        if (!result.success) failures.add('ช่องทางรับเงิน: ${result.message}');
      }
    } finally {
      // ไม่เรียก _apply — ค่าที่ผู้ใช้พิมพ์ในส่วนที่ล้มต้องอยู่ในฟอร์มต่อ ให้
      // แก้แล้วกดบันทึกซ้ำได้ ไม่ใช่ถูกรีเซ็ตกลับเป็นค่าเดิมจนต้องพิมพ์ใหม่
      saved = current;
      isSaving = false;
      notifyListeners();
    }

    if (failures.isEmpty) {
      return const ActionResult(
          success: true, message: 'บันทึกการเปลี่ยนแปลงแล้ว');
    }
    return ActionResult(
      success: false,
      message: 'บันทึกไม่สำเร็จบางส่วน — ${failures.join(' · ')}',
    );
  }

  /// ชื่อหอเป็น unique ในฐานข้อมูล (หน้าสมัครสมาชิกก็เจอกรณีนี้) · ข้อความกลาง
  /// "มีข้อมูลนี้อยู่แล้ว กรุณาโหลดใหม่" ชี้ผิดทาง เพราะโหลดใหม่กี่รอบก็ไม่หาย
  String _describeDormitoryError(Object error) {
    if (error is PostgrestException && error.code == '23505') {
      debugPrint('[error] $error');
      return 'ชื่อหอพักนี้ถูกใช้ไปแล้ว กรุณาใช้ชื่ออื่น';
    }
    return formatErrorMessage(error);
  }

  @override
  void dispose() {
    paymentChannel.removeListener(notifyListeners);
    paymentChannel.dispose();
    super.dispose();
  }
}

LandlordSettings _copy(
  LandlordSettings s, {
  String? firstName,
  String? lastName,
  String? phone,
  String? dormitoryName,
  String? location,
  double? baseElectricityRate,
  double? baseWaterRate,
}) =>
    LandlordSettings(
      firstName: firstName ?? s.firstName,
      lastName: lastName ?? s.lastName,
      phone: phone ?? s.phone,
      email: s.email,
      dormitoryName: dormitoryName ?? s.dormitoryName,
      location: location ?? s.location,
      baseElectricityRate: baseElectricityRate ?? s.baseElectricityRate,
      baseWaterRate: baseWaterRate ?? s.baseWaterRate,
    );

/// 8.0 → "8", 7.5 → "7.5" · ไม่ใช้ toStringAsFixed(2) เพราะ "8.00" ในช่องที่
/// ผู้ใช้จะพิมพ์ทับดูรกโดยไม่จำเป็น
String _formatRate(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
