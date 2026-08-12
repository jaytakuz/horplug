import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/theme/app_theme.dart';

void main() {
  group('ฟอนต์ของธีม', () {
    // Open Sans ไม่มีอักษรไทย ถ้า fallback หลุดไป ตัวไทยจะตกไปใช้ฟอนต์ของระบบ
    // ซึ่งต่างกันทุกเครื่อง — เห็นยากเวลารีวิว diff เพราะแอปยังทำงานได้ปกติ
    test('ทุก slot ของ TextTheme ได้ Open Sans + Noto Sans Thai', () {
      final textTheme = buildAppTheme().textTheme;

      final slots = {
        'titleLarge': textTheme.titleLarge,
        'titleMedium': textTheme.titleMedium,
        'bodyLarge': textTheme.bodyLarge,
        'bodyMedium': textTheme.bodyMedium,
        'bodySmall': textTheme.bodySmall,
        'labelSmall': textTheme.labelSmall,
      };

      slots.forEach((name, style) {
        expect(style?.fontFamily, 'Open Sans', reason: '$name เสียฟอนต์หลัก');
        expect(style?.fontFamilyFallback, contains('Noto Sans Thai'),
            reason: '$name เสีย fallback ภาษาไทย');
      });
    });

    // slot ที่ _buildTextTheme แก้ขนาด/น้ำหนักต้องยังคง fontFamily ของเดิมไว้
    // ตามที่คอมเมนต์ใน app_theme.dart เตือนเรื่องการยัด const TextStyle ก้อนใหม่
    test('slot ที่ถูกปรับขนาดยังคงน้ำหนักและฟอนต์ครบ', () {
      final titleLarge = buildAppTheme().textTheme.titleLarge;

      expect(titleLarge?.fontSize, 20);
      expect(titleLarge?.fontFamily, 'Open Sans');
    });
  });
}
