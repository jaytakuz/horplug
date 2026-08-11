import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/models/models.dart';
import 'package:horplug/utils/chat_preview.dart';

ChatMessage _message({
  required bool isFromOwner,
  MessageType type = MessageType.text,
  String text = 'สวัสดีครับ',
  DateTime? timestamp,
}) =>
    ChatMessage(
      id: '1',
      senderName: isFromOwner ? 'เจ้าของหอ' : 'สมชาย ใจดี',
      text: text,
      timestamp: timestamp ?? DateTime(2026, 8, 11, 14, 23),
      isFromOwner: isFromOwner,
      type: type,
    );

void main() {
  group('chatSenderLabel', () {
    test('ผู้เช่าเห็น "คุณ" เมื่อตัวเองเป็นคนส่ง', () {
      expect(
        chatSenderLabel(_message(isFromOwner: false), viewerIsOwner: false),
        'คุณ',
      );
    });

    test('ผู้เช่าเห็นชื่อเจ้าของหอเมื่ออีกฝ่ายส่ง', () {
      expect(
        chatSenderLabel(_message(isFromOwner: true), viewerIsOwner: false),
        'เจ้าของหอ',
      );
    });

    // ฟังก์ชันเดียวกันใช้ได้ทั้งสองฝั่ง — ฝั่งเจ้าของหอเห็นกลับด้าน
    test('เจ้าของหอเห็น "คุณ" เมื่อตัวเองเป็นคนส่ง', () {
      expect(
        chatSenderLabel(_message(isFromOwner: true), viewerIsOwner: true),
        'คุณ',
      );
    });
  });

  group('chatMessagePreview', () {
    test('ข้อความธรรมดาแสดงตามที่พิมพ์', () {
      expect(
        chatMessagePreview(_message(isFromOwner: true, text: 'ค่าน้ำเท่าไหร่')),
        'ค่าน้ำเท่าไหร่',
      );
    });

    // ถ้าปล่อยว่าง การ์ดจะขึ้นแค่ "เจ้าของหอ:" ลอยๆ ซึ่งอ่านแล้วเหมือนระบบพัง
    test('ข้อความที่ไม่ใช่ตัวอักษรมีคำอธิบายแทน ไม่ปล่อยว่าง', () {
      final previews = {
        MessageType.image: 'รูปภาพ',
        MessageType.invoice: 'บิลค่าเช่า',
        MessageType.maintenanceRequest: 'แจ้งซ่อม',
        MessageType.cleaningRequest: 'แจ้งทำความสะอาด',
        MessageType.maintenanceUpdate: 'อัปเดตงานซ่อม',
        MessageType.cleaningUpdate: 'อัปเดตงานทำความสะอาด',
        MessageType.parcelNotification: 'แจ้งพัสดุ',
      };

      previews.forEach((type, expected) {
        expect(
          chatMessagePreview(
              _message(isFromOwner: true, type: type, text: '')),
          expected,
        );
      });
    });

    test('ทุกชนิดข้อความมีพรีวิว ไม่มีตัวไหนคืนค่าว่าง', () {
      for (final type in MessageType.values) {
        final preview = chatMessagePreview(
          _message(isFromOwner: true, type: type, text: ''),
        );
        expect(preview.trim(), isNotEmpty,
            reason: 'ชนิด ${type.name} ไม่มีพรีวิว');
      }
    });

    test('ข้อความตัวอักษรที่ว่างเปล่าถือว่าเป็นรูป', () {
      expect(
        chatMessagePreview(_message(isFromOwner: true, text: '   ')),
        'รูปภาพ',
      );
    });
  });

  group('chatPreviewLine', () {
    test('ประกอบเป็น "ผู้ส่ง: เนื้อความ"', () {
      expect(
        chatPreviewLine(
          _message(isFromOwner: true, type: MessageType.image, text: ''),
          viewerIsOwner: false,
        ),
        'เจ้าของหอ: รูปภาพ',
      );
    });

    test('ข้อความของตัวเองขึ้นต้นด้วย "คุณ:"', () {
      expect(
        chatPreviewLine(
          _message(isFromOwner: false, text: 'ได้ครับ'),
          viewerIsOwner: false,
        ),
        'คุณ: ได้ครับ',
      );
    });
  });

  // แบบเดิมบอกว่า "นานแค่ไหน" (6 วันที่แล้ว) แต่คนอ่านแชทสนใจว่า "เมื่อไหร่"
  group('chatTimestampLabel', () {
    final now = DateTime(2026, 8, 11, 20, 0);

    test('วันนี้แสดงเป็นเวลา', () {
      expect(
        chatTimestampLabel(DateTime(2026, 8, 11, 9, 5), now: now),
        '09:05',
      );
    });

    test('เที่ยงคืนแสดง 00:00 ไม่ใช่ 0:0', () {
      expect(
        chatTimestampLabel(DateTime(2026, 8, 11, 0, 0), now: now),
        '00:00',
      );
    });

    test('เมื่อวานแสดงคำว่าเมื่อวาน', () {
      expect(
        chatTimestampLabel(DateTime(2026, 8, 10, 23, 59), now: now),
        'เมื่อวาน',
      );
    });

    // นับตามวันปฏิทิน ไม่ใช่ 24 ชั่วโมง — ข้อความเมื่อ 23:59 คืนก่อนคือ
    // "เมื่อวาน" แม้จะห่างแค่ไม่กี่ชั่วโมง
    test('นับเป็นวันปฏิทิน ไม่ใช่ช่วง 24 ชั่วโมง', () {
      final justAfterMidnight = DateTime(2026, 8, 11, 0, 30);
      expect(
        chatTimestampLabel(DateTime(2026, 8, 10, 23, 30),
            now: justAfterMidnight),
        'เมื่อวาน',
      );
    });

    test('ภายในสัปดาห์แสดงชื่อวัน', () {
      // 2026-08-08 เป็นวันเสาร์
      expect(chatTimestampLabel(DateTime(2026, 8, 8, 10, 0), now: now), 'ส.');
    });

    test('เกินหนึ่งสัปดาห์แสดงวันที่', () {
      expect(
        chatTimestampLabel(DateTime(2026, 7, 20, 10, 0), now: now),
        '20/7/26',
      );
    });

    test('ปีที่ลงท้ายด้วยศูนย์ยังเติมสองหลักครบ', () {
      expect(
        chatTimestampLabel(DateTime(2026, 1, 5, 10, 0),
            now: DateTime(2026, 3, 1)),
        '5/1/26',
      );
    });
  });
}
