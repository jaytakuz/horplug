import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/services/landlord_profile_service.dart';
import 'package:horplug/services/payment_channel_service.dart';
import 'package:horplug/viewmodels/landlord_profile_view_model.dart';
import 'package:horplug/viewmodels/payment_channel_view_model.dart';

const _settings = LandlordSettings(
  firstName: 'สมชาย',
  lastName: 'ใจดี',
  phone: '0812345678',
  email: 'owner@example.com',
  dormitoryName: 'ศักดิ์เพลส',
  location: 'เชียงใหม่',
  baseElectricityRate: 8,
  baseWaterRate: 100,
);

class FakeLandlordProfileService extends LandlordProfileService {
  FakeLandlordProfileService({this.fetchError, this.dormitoryError});

  final Object? fetchError;
  final Object? dormitoryError;
  int profileSaves = 0;
  int dormitorySaves = 0;
  double? savedElectricityRate;

  @override
  Future<LandlordSettings> fetch({
    required String landlordId,
    required int dormitoryId,
  }) async {
    if (fetchError != null) throw fetchError!;
    return _settings;
  }

  @override
  Future<void> saveProfile({
    required String landlordId,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    profileSaves++;
  }

  @override
  Future<void> saveDormitory({
    required int dormitoryId,
    required String name,
    required String location,
    required double baseElectricityRate,
    required double baseWaterRate,
  }) async {
    dormitorySaves++;
    if (dormitoryError != null) throw dormitoryError!;
    savedElectricityRate = baseElectricityRate;
  }
}

class FakePaymentChannelService extends PaymentChannelService {
  FakePaymentChannelService({this.channel});

  final PaymentChannel? channel;
  int saves = 0;

  @override
  Future<PaymentChannel?> fetch({required int dormitoryId}) async => channel;

  @override
  Future<void> save({
    required int dormitoryId,
    required PaymentChannel channel,
  }) async {
    saves++;
  }
}

LandlordProfileViewModel buildViewModel({
  FakeLandlordProfileService? service,
  FakePaymentChannelService? channels,
}) =>
    LandlordProfileViewModel(
      landlordId: 'landlord-1',
      dormitoryId: 1,
      service: service ?? FakeLandlordProfileService(),
      paymentChannel: PaymentChannelViewModel(
        dormitoryId: 1,
        service: channels ?? FakePaymentChannelService(),
      ),
    );

void main() {
  group('LandlordProfileViewModel', () {
    test('load fills the form and starts with no changes', () async {
      final vm = buildViewModel();
      await vm.load();

      expect(vm.isLoading, isFalse);
      expect(vm.firstName, 'สมชาย');
      expect(vm.electricityRate, '8');
      expect(vm.waterRate, '100');
      expect(vm.hasChanges, isFalse);
    });

    test('load failure keeps saved null and exposes a message', () async {
      final vm = buildViewModel(
        service: FakeLandlordProfileService(fetchError: Exception('ล้ม')),
      );
      await vm.load();

      expect(vm.saved, isNull);
      expect(vm.errorMessage, 'ล้ม');
    });

    test('rates compare as numbers, so 8.00 is not a change', () async {
      final vm = buildViewModel();
      await vm.load();

      vm.update(electricityRate: '8.00');
      expect(vm.hasChanges, isFalse);

      vm.update(electricityRate: '9');
      expect(vm.dormitoryChanged, isTrue);
      expect(vm.hasChanges, isTrue);
    });

    test('reverting an edit clears the change flag', () async {
      final vm = buildViewModel();
      await vm.load();

      vm.update(firstName: 'สมหญิง');
      expect(vm.hasChanges, isTrue);
      vm.update(firstName: 'สมชาย');
      expect(vm.hasChanges, isFalse);
    });

    test('save writes only the sections that changed', () async {
      final service = FakeLandlordProfileService();
      final channels = FakePaymentChannelService();
      final vm = buildViewModel(service: service, channels: channels);
      await vm.load();

      vm.update(electricityRate: '9.5');
      final result = await vm.save();

      expect(result.success, isTrue);
      expect(service.dormitorySaves, 1);
      expect(service.savedElectricityRate, 9.5);
      expect(service.profileSaves, 0);
      expect(channels.saves, 0);
      expect(vm.hasChanges, isFalse);
      expect(vm.saved!.baseElectricityRate, 9.5);
    });

    test('payment channel edits count as changes and are saved', () async {
      final channels = FakePaymentChannelService();
      final vm = buildViewModel(channels: channels);
      await vm.load();

      vm.paymentChannel.update(promptPayId: '0812345678', accountName: 'ก');
      expect(vm.hasChanges, isTrue);

      final result = await vm.save();
      expect(result.success, isTrue);
      expect(channels.saves, 1);
      expect(vm.paymentChannel.isConfigured, isTrue);
      expect(vm.hasChanges, isFalse);
    });

    test('partial failure keeps the failed section dirty, not the rest',
        () async {
      final service = FakeLandlordProfileService(
        dormitoryError: Exception('ชื่อซ้ำ'),
      );
      final vm = buildViewModel(service: service);
      await vm.load();

      vm.update(firstName: 'สมหญิง', dormitoryName: 'หอใหม่');
      final result = await vm.save();

      expect(result.success, isFalse);
      expect(result.message, contains('ข้อมูลหอพัก'));
      expect(vm.profileChanged, isFalse);
      expect(vm.dormitoryChanged, isTrue);
      // ค่าที่พิมพ์ไว้ต้องอยู่ต่อ ให้แก้แล้วบันทึกซ้ำได้
      expect(vm.dormitoryName, 'หอใหม่');
    });
  });

  group('PaymentChannelViewModel change tracking', () {
    test('existing channel loads clean and becomes dirty on edit', () async {
      final vm = PaymentChannelViewModel(
        dormitoryId: 1,
        service: FakePaymentChannelService(
          channel: const PaymentChannel(
            accountName: 'สมชาย',
            promptPayId: '0812345678',
          ),
        ),
      );
      await vm.load();

      expect(vm.isConfigured, isTrue);
      expect(vm.hasChanges, isFalse);

      vm.setPreviewAmount('10');
      expect(vm.hasChanges, isFalse, reason: 'ยอดคิวอาร์ตัวอย่างไม่ใช่ข้อมูล');

      vm.update(accountName: 'สมหญิง');
      expect(vm.hasChanges, isTrue);
    });

    test('unconfigured dormitory reports not configured', () async {
      final vm = PaymentChannelViewModel(
        dormitoryId: 1,
        service: FakePaymentChannelService(),
      );
      await vm.load();

      expect(vm.isConfigured, isFalse);
      expect(vm.hasChanges, isFalse);
    });
  });

  group('profile validators', () {
    test('phone', () {
      expect(validatePhone('081-234-5678'), isNull);
      expect(validatePhone('021234567'), isNull);
      expect(validatePhone(''), isNotNull);
      expect(validatePhone('08123'), isNotNull);
      expect(validatePhone('08a2345678'), isNotNull);
    });

    test('electricity rate', () {
      expect(validateElectricityRate('7.5'), isNull);
      expect(validateElectricityRate('0'), isNotNull);
      expect(validateElectricityRate('abc'), isNotNull);
      expect(validateElectricityRate('800'), isNotNull);
    });

    test('water rate allows zero but not negative', () {
      expect(validateWaterRate('0'), isNull);
      expect(validateWaterRate('1,200'), isNull);
      expect(validateWaterRate('-1'), isNotNull);
      expect(validateWaterRate(''), isNotNull);
    });
  });
}
