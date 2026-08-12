import 'package:flutter/foundation.dart' show kIsWeb;
// CupertinoPageTransitionsBuilder อยู่ใน cupertino.dart ไม่ใช่ material.dart
// · import แบบ show เพื่อไม่ให้ชื่ออื่นของสองไลบรารีชนกันในไฟล์นี้
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'breakpoints.dart';

class AppColors {
  static const primary = Color(0xFF1B3A5C);
  static const primaryForeground = Colors.white;
  static const ring = Color(0xFF7CB9E8);
  static const background = Color(0xFFFFF8F0);
  static const card = Colors.white;
  
  static const success = Color(0xFF2D6A4F);
  static const successBg = Color(0xFFD4EDDA);
  
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFEF3C7);
  
  static const destructive = Color(0xFFEF4444);
  static const destructiveBg = Color(0xFFFEE2E2);
  
  static const muted = Color(0xFFEEF1F4);
  static const mutedForeground = Color(0xFF6B7C90);
  static const border = Color(0xFFDDE3EA);
}

class AppShadows {
  static const md = [
    BoxShadow(
      color: Color.fromRGBO(27, 58, 92, 0.06),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(27, 58, 92, 0.08),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];
}

ThemeData buildAppTheme() {
  final baseTheme = ThemeData(
    useMaterial3: true,
    // Open Sans ไม่มีอักษรไทยสักตัว (มีแค่ latin/greek/cyrillic/hebrew) ตัวไทย
    // จึงตกไป Noto Sans Thai ผ่าน fallback — ซึ่งทำงานทีละ **ตัวอักษร** ไม่ใช่
    // ทั้งบรรทัด เลขกับคำอังกฤษในประโยคไทยเดียวกันจึงยังเป็น Open Sans
    //
    // ถ้าไม่ประกาศ fallback ตัวไทยจะตกไปใช้ฟอนต์ของระบบ ซึ่งต่างกันทุกเครื่อง
    // (Android=Noto, Windows=Tahoma, iOS=Thonburi) และคุมระยะสระบน-ล่างไม่ได้
    // — ทั้งที่ UI ของแอปนี้เป็นภาษาไทยเกือบทั้งหมด
    fontFamily: 'Open Sans',
    fontFamilyFallback: const ['Noto Sans Thai'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      surface: AppColors.card,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );

  return baseTheme.copyWith(
    // centerTitle ของ AppBar มีค่าเริ่มต้นต่างกันตามแพลตฟอร์ม — false บน
    // Android แต่ true บน iOS/macOS ทำให้หัวข้อเด้งไปอยู่กลางจอเฉพาะบน iOS
    // บังคับเป็นชิดซ้ายเพื่อให้ทุกแพลตฟอร์มเหมือนกัน
    appBarTheme: const AppBarTheme(centerTitle: false),
    // ปัดจากขอบซ้ายเพื่อย้อนกลับ · ตั้งที่เดียวครอบทุกเส้นทางที่ push
    // (รายละเอียดห้อง ประวัติแจ้งซ่อม แชทรายห้อง ตั้งค่าช่องทางรับเงิน) โดยไม่
    // ต้องแก้หน้าจอสักหน้า และไม่มีหน้าไหนหลุดเมื่อมีหน้าใหม่เพิ่มทีหลัง
    //
    // Android บนเครื่องจริงใช้ PredictiveBack ซึ่งให้พรีวิวหน้าถัดไประหว่างปัด
    // ตามมาตรฐาน Android 14+ · ต้องคู่กับ enableOnBackInvokedCallback ใน
    // AndroidManifest.xml
    //
    // บนเว็บต้องแยกด้วย kIsWeb เพราะ PredictiveBack อาศัย platform channel ของ
    // Android ที่ไม่มีในเบราว์เซอร์ แล้วจะตกกลับไปเป็น zoom transition ซึ่ง
    // "ไม่มีท่าทางลากเลย" — เว็บบนมือถือ Android จะกลายเป็นแพลตฟอร์มเดียวที่
    // ปัดกลับไม่ได้ · CupertinoPageTransitionsBuilder พก CupertinoBackGestureDetector
    // มาในตัว จึงลากกลับได้ทั้งด้วยนิ้วและด้วยเมาส์
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: kIsWeb
            ? const CupertinoPageTransitionsBuilder()
            : const PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: const CupertinoPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      // กล่องโต้ตอบมีความกว้างเท่ากับลูกของมัน และลูกส่วนใหญ่เป็น TextField
      // ซึ่งขอความกว้างเท่าที่มี — บนหน้าต่างเว็บ 1,400px จึงได้กล่องยาว 1,320px
      // ที่มีช่องกรอกเดียว · กำหนดที่ธีมทีเดียวครอบทุกกล่องในแอป แทนที่จะไล่ใส่
      // ตามจุดเรียกทั้งสิบกว่าแห่งแล้วลืมบางแห่ง
      constraints: BoxConstraints(maxWidth: Breakpoints.sheetMaxWidth),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: AppColors.primary,
      ),
    ),
    // เหตุผลเดียวกับกล่องโต้ตอบ · แผ่นที่ทอดยาวเต็มจอกว้างทำให้ปุ่มยืนยันไป
    // อยู่คนละมุมจอกับเนื้อหาที่มันยืนยัน
    bottomSheetTheme: const BottomSheetThemeData(
      constraints: BoxConstraints(maxWidth: 640),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      labelStyle: const TextStyle(color: AppColors.primary),
      hintStyle: const TextStyle(color: AppColors.mutedForeground),
      helperStyle: const TextStyle(color: AppColors.mutedForeground),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: Color(0xFFB8D4F1),
      selectionHandleColor: AppColors.primary,
    ),
    // ห้ามส่ง const TextTheme(...) ตรงๆ เข้า ThemeData.copyWith:
    // copyWith เรียก ThemeData.raw จึงข้ามขั้น defaultTextTheme.merge() ที่มี
    // เฉพาะใน constructor ⇒ slot ที่ไม่ได้ระบุกลายเป็น null ทั้งหมด และ
    // TextStyle ที่ color เป็น null จะถูก engine เรนเดอร์เป็น "สีขาว"
    // (เดิม bodyMedium ไม่มี color จึงมองไม่เห็นบนการ์ดขาวและพื้นครีม
    //  และเพราะ Material ใช้ bodyMedium เป็น DefaultTextStyle ของทั้งแอป
    //  Text ที่ไม่ใส่ style เลยก็ขาวไปด้วย)
    //
    // apply() ทับสีทุก slot ก่อน แล้วค่อยปรับขนาดเฉพาะตัวที่ต้องการ
    //
    // ต้อง copyWith ต่อจากสไตล์เดิมของแต่ละ slot ไม่ใช่ยัด const TextStyle
    // ก้อนใหม่ ไม่งั้นจะทิ้ง fontFamily / height / letterSpacing ของ M3
    // typography ไป ทำให้ slot ที่แก้กับ slot ที่ไม่ได้แก้ใช้ฟอนต์คนละตัว
    // ซึ่งเห็นชัดในภาษาไทยเพราะระยะสระบน-ล่างจะไม่เท่ากัน
    textTheme: _buildTextTheme(
      baseTheme.textTheme.apply(
        bodyColor: AppColors.primary,
        displayColor: AppColors.primary,
      ),
    ),
  );
}

TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AppColors.primary,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AppColors.primary,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 12,
      color: AppColors.mutedForeground,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 10,
      color: AppColors.mutedForeground,
    ),
  );
}
