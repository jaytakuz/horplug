import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/utils/formatters.dart';

void main() {
  group('Feature 7: Dashboard for Tenant — shared formatters', () {
    group('UTC-44 formatBaht', () {
      test('UTC-44-TC-01 inserts a thousands separator', () {
        expect(formatBaht(4500), '฿4,500');
        expect(formatBaht(135000), '฿135,000');
        expect(formatBaht(1000000), '฿1,000,000');
      });

      test('UTC-44-TC-02 leaves amounts below one thousand unchanged', () {
        expect(formatBaht(0), '฿0');
        expect(formatBaht(999), '฿999');
      });

      // เคสบั๊กจริง: toStringAsFixed(0) ปัด 4500.50 เป็น '฿4501' ทำให้ผู้เช่า
      // โอนเงินตามที่เห็นแล้วยอดไม่ตรงกับที่เจ้าของหอบันทึกไว้
      test('UTC-44-TC-03 keeps satang instead of rounding them away', () {
        expect(formatBaht(4500.50), '฿4,500.50');
        expect(formatBaht(1234.05), '฿1,234.05');
        expect(formatBaht(1234.567), '฿1,234.57');
      });

      test('UTC-44-TC-04 drops the decimals when the amount is whole', () {
        expect(formatBaht(4500.00), '฿4,500');
      });

      test('UTC-44-TC-05 places the minus sign before the symbol', () {
        expect(formatBaht(-1234.567), '-฿1,234.57');
        expect(formatBaht(-500), '-฿500');
      });

      test('UTC-44-TC-06 omits the symbol when asked', () {
        expect(formatBaht(4500, withSymbol: false), '4,500');
      });
    });

    group('UTC-45 formatUnits', () {
      // เดิมฝั่งเจ้าของหอใช้ toStringAsFixed(1) ฝั่งผู้เช่าใช้ (0)
      // บิลใบเดียวกันจึงอ่านได้ '123.5 หน่วย' กับ '124 หน่วย'
      test('UTC-45-TC-01 keeps one decimal place when there is a fraction', () {
        expect(formatUnits(123.5), '123.5');
        expect(formatUnits(123.46), '123.5');
      });

      test('UTC-45-TC-02 drops .0 when the value is whole', () {
        expect(formatUnits(123), '123');
        expect(formatUnits(123.0), '123');
        expect(formatUnits(0), '0');
      });

      test('UTC-45-TC-03 groups thousands for large usage', () {
        expect(formatUnits(1500), '1,500');
      });
    });

    group('UTC-46 formatMeterReading', () {
      test('UTC-46-TC-01 rounds to a whole number and groups thousands', () {
        expect(formatMeterReading(9999), '9,999');
        expect(formatMeterReading(1234.6), '1,235');
        expect(formatMeterReading(0), '0');
      });
    });

    group('UTC-47 groupThousands', () {
      test('UTC-47-TC-01 handles every digit-count boundary', () {
        expect(groupThousands('1'), '1');
        expect(groupThousands('999'), '999');
        expect(groupThousands('1000'), '1,000');
        expect(groupThousands('12345678'), '12,345,678');
      });

      test('UTC-47-TC-02 keeps the minus sign outside the grouping', () {
        expect(groupThousands('-12345'), '-12,345');
      });
    });
  });
}
