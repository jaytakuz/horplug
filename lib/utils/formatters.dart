/// ตัวช่วยจัดรูปแบบตัวเลขที่ใช้ร่วมกันทั้งฝั่งผู้เช่าและฝั่งเจ้าของหอ
///
/// ทุกฟังก์ชันเป็น top-level และไฟล์นี้ไม่ import อะไรเลย เพื่อให้เขียน
/// unit test ได้โดยตรง (SupabaseService สร้าง client ตอน field initializer
/// จึงสร้าง ViewModel ใน unit test ไม่ได้)
library;

/// ใส่ลูกน้ำคั่นหลักพันให้สตริงตัวเลขจำนวนเต็ม
///
/// '4500' → '4,500' · '900' → '900' · '-12345' → '-12,345'
String groupThousands(String integerDigits) {
  final isNegative = integerDigits.startsWith('-');
  final digits = isNegative ? integerDigits.substring(1) : integerDigits;

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return isNegative ? '-$buffer' : buffer.toString();
}

/// จำนวนเงินบาทพร้อมสัญลักษณ์ ฿ และตัวคั่นหลักพัน
///
/// ปัดที่ 2 ตำแหน่ง (ระดับสตางค์) แล้วตัด '.00' ทิ้งเมื่อลงตัว — ค่าห้องและ
/// ค่าน้ำเป็นจำนวนเต็มเกือบทั้งหมด การโชว์ '฿4,500.00' ทุกที่จะรกโดยไม่ได้
/// ข้อมูลเพิ่ม แต่ถ้ามีเศษสตางค์จริงต้องแสดงให้ครบ ห้ามปัดทิ้ง เพราะผู้เช่า
/// โอนเงินตามตัวเลขที่เห็นแล้วยอดจะไม่ตรงกับที่เจ้าของหอบันทึกไว้
///
/// 4500 → '฿4,500' · 4500.5 → '฿4,500.50' · -1234.567 → '-฿1,234.57'
String formatBaht(double amount, {bool withSymbol = true}) {
  final symbol = withSymbol ? '฿' : '';
  final isNegative = amount < 0;
  final absolute = amount.abs();

  final satang = (absolute * 100).round();
  final wholeBaht = satang ~/ 100;
  final remainder = satang % 100;

  final whole = groupThousands(wholeBaht.toString());
  final body = remainder == 0
      ? '$symbol$whole'
      : '$symbol$whole.${remainder.toString().padLeft(2, '0')}';

  return isNegative ? '-$body' : body;
}

/// จำนวนหน่วยไฟ/น้ำ — มาตรฐานเดียวกันทั้งสองฝั่ง
///
/// ทศนิยมไม่เกิน 1 ตำแหน่ง และตัด '.0' ทิ้งเมื่อลงตัว:
///   123 → '123' · 123.5 → '123.5' · 123.46 → '123.5'
///
/// เลือก "ไม่เกิน 1 ตำแหน่ง" แทน 0 ตำแหน่ง เพราะ toStringAsFixed(0) ปัดเศษ
/// ทิ้งได้ถึง 0.5 หน่วย ทำให้ผู้เช่าเห็น '124 หน่วย' ขณะที่เจ้าของหอเห็น
/// '123.5 หน่วย' บนบิลใบเดียวกัน และเลือกตัด '.0' ทิ้งเพราะมิเตอร์กรอกเป็น
/// จำนวนเต็ม ค่าปกติจึงลงตัวเสมอ ไม่ต้องโชว์ '123.0' ให้ดูเหมือนมีความ
/// ละเอียดที่ไม่มีจริง
String formatUnits(double units) {
  final rounded = (units * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return groupThousands(rounded.toInt().toString());
  }
  return rounded.toStringAsFixed(1);
}

/// เลขมิเตอร์ดิบ (ไม่ใช่ปริมาณการใช้) — ใส่ตัวคั่นหลักพัน ไม่มีทศนิยม
String formatMeterReading(double reading) =>
    groupThousands(reading.round().toString());

/// เวลาแบบ "นานแค่ไหนมาแล้ว" สำหรับรายการห้องที่เรียงตามเวลาล่าสุด
///
/// เกินเจ็ดวันเปลี่ยนไปบอกวันที่ เพราะ "23 วันที่แล้ว" ต้องนั่งคำนวณต่อในหัว
/// กว่าจะรู้ว่าคือเมื่อไหร่ ขณะที่ช่วงไม่กี่วันแรกคนอ่านต้องการรู้ว่า "เพิ่ง"
/// หรือ "นานแล้ว" มากกว่าวันที่จริง
///
/// [now] มีไว้ให้เทสต์กำหนดเวลาอ้างอิงได้ · ค่าเริ่มต้นคือเวลาปัจจุบัน
///
/// ใช้ร่วมกันระหว่างหน้ารวมแชทกับหน้ารวมประวัติแจ้งซ่อม — สองรายการที่หน้าตา
/// เหมือนกันแต่ถือนาฬิกาคนละเรือนคือจุดที่ค่อยๆ เพี้ยนออกจากกันโดยไม่มีใคร
/// สังเกตจนกว่าจะมีคนวางสองหน้าจอไว้ข้างกัน
String formatRelativeTime(DateTime timestamp, {DateTime? now}) {
  final local = timestamp.toLocal();
  final difference = (now ?? DateTime.now()).difference(local);

  if (difference.inMinutes < 1) return 'เมื่อสักครู่';
  if (difference.inMinutes < 60) return '${difference.inMinutes} นาทีที่แล้ว';
  if (difference.inHours < 24) return '${difference.inHours} ชม.ที่แล้ว';
  if (difference.inDays < 7) return '${difference.inDays} วันที่แล้ว';
  return '${local.day}/${local.month}/${local.year}';
}
