import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/models/picked_image.dart';
import 'package:horplug/services/supabase_service.dart';

/// SupabaseService ปลอมสำหรับ Feature 9 — บันทึกอาร์กิวเมนต์ที่ถูกเรียกไว้ตรวจสอบ
/// แทนที่จะแตะเครือข่ายจริง เช่นเดียวกับ _FakeMaintenanceService ใน
/// maintenance_unit_test.dart
class _FakeChatService extends SupabaseService {
  _FakeChatService({this.shouldThrow = false});

  final bool shouldThrow;

  int? sentRoomId;
  String? sentSenderId;
  bool? sentIsFromOwner;
  String? sentBody;
  MessageType? sentType;

  @override
  Future<void> sendMessage({
    required int roomId,
    required String senderId,
    required bool isFromOwner,
    required String body,
    MessageType type = MessageType.text,
    String? attachmentUrl,
    int? maintenanceRequestId,
    int? invoiceId,
  }) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    sentRoomId = roomId;
    sentSenderId = senderId;
    sentIsFromOwner = isFromOwner;
    sentBody = body;
    sentType = type;
  }

  @override
  Future<String> uploadChatImage({
    required int roomId,
    required PickedImage image,
  }) async {
    if (shouldThrow) throw const SocketException('Failed host lookup');
    return '$roomId/1700000000.${image.extension}';
  }
}

PickedImage _image() => PickedImage(
      bytes: Uint8List.fromList([1, 2, 3]),
      extension: 'jpg',
      contentType: 'image/jpeg',
    );

void main() {
  group('Feature 9: Dynamic Chat', () {
    group('UTC-40 sendMessage', () {
      test('UTC-40-TC-01 sends a text message, defaulting type to text',
          () async {
        final service = _FakeChatService();

        await service.sendMessage(
          roomId: 101,
          senderId: 'tenant-uuid',
          isFromOwner: false,
          body: 'สวัสดีครับ',
        );

        expect(service.sentRoomId, 101);
        expect(service.sentSenderId, 'tenant-uuid');
        expect(service.sentIsFromOwner, false);
        expect(service.sentBody, 'สวัสดีครับ');
        expect(service.sentType, MessageType.text);
      });

      test('UTC-40-TC-02 throws SocketException on network failure', () {
        final service = _FakeChatService(shouldThrow: true);

        expect(
          () => service.sendMessage(
            roomId: 101,
            senderId: 'tenant-uuid',
            isFromOwner: false,
            body: 'สวัสดีครับ',
          ),
          throwsA(isA<SocketException>()),
        );
      });
    });

    group('UTC-41 uploadChatImage', () {
      test(
          'UTC-41-TC-01 uploads the image and returns a storage path namespaced by room',
          () async {
        final service = _FakeChatService();

        final path = await service.uploadChatImage(
          roomId: 101,
          image: _image(),
        );

        expect(path, startsWith('101/'));
      });

      test('UTC-41-TC-02 throws SocketException on network failure', () {
        final service = _FakeChatService(shouldThrow: true);

        expect(
          () => service.uploadChatImage(roomId: 101, image: _image()),
          throwsA(isA<SocketException>()),
        );
      });
    });
  });
}
