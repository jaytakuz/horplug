import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'viewmodels/auth_view_model.dart';
import 'models/models.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/billing_screen.dart';
import 'screens/admin/chat_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/lease_screen.dart';
import 'screens/admin/maintenance_overview_screen.dart';
import 'screens/admin/meter_screen.dart';
import 'screens/admin/rooms_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/tenant/tenant_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerFontLicenses();

  // URL แบบไม่มี # บนเว็บ · ต้องเรียกก่อน runApp
  //
  // ไม่ใช่แค่ความสวยงาม — Supabase ส่งลิงก์รีเซ็ตรหัสผ่านกลับมาพร้อม token ใน
  // fragment (`#access_token=...`) ถ้า go_router ใช้ fragment เป็นเส้นทางด้วย
  // สองอย่างจะแย่ง `#` กันเอง แล้วลิงก์รีเซ็ตจะพังบนเว็บทั้งหมด
  //
  // แลกกับการที่เซิร์ฟเวอร์ต้อง rewrite ทุก path มาที่ index.html — ดู
  // vercel.json ที่รากโปรเจกต์
  usePathUrlStrategy();

  await AppConfig.loadDotEnvIfPresent();

  // ค่าไม่ครบไม่ควรทำให้แอปตายเงียบๆ เป็นหน้าขาว · แสดงหน้าที่บอกว่าขาดอะไรและ
  // ต้องทำอะไรแทน ซึ่งเป็นข้อความเดียวกับที่คนตั้งค่า Vercel ต้องการเห็นที่สุด
  if (!AppConfig.isConfigured) {
    runApp(const _MisconfiguredApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  final authController = AuthViewModel();
  await authController.initialize();

  runApp(HorPlugApp(authController: authController));
}

/// ใบอนุญาตของฟอนต์ที่ฝังมากับแอป
///
/// Open Sans และ Noto Sans Thai เป็น SIL OFL 1.1 ทั้งคู่ ซึ่งกำหนดให้แจกใบอนุญาต
/// ไปพร้อมกับฟอนต์ · หน้า licenses ของ Flutter (`showLicensePage`) คือที่ที่ผู้ใช้
/// หามันเจอ แต่มันรู้จักเฉพาะแพ็กเกจ ไม่รู้จักไฟล์ที่เราหยิบมาใส่เอง
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final path in const [
      'lib/assets/fonts/OFL-OpenSans.txt',
      'lib/assets/fonts/OFL-NotoSansThai.txt',
    ]) {
      yield LicenseEntryWithLineBreaks(
        const ['ฟอนต์ที่ฝังมากับแอป'],
        await rootBundle.loadString(path),
      );
    }
  });
}

/// หน้าที่แสดงแทนแอปทั้งตัวเมื่อยังไม่ได้ตั้งค่า Supabase
class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HorPlug',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_outlined,
                      size: 48, color: AppColors.mutedForeground),
                  const SizedBox(height: 16),
                  Text(
                    'ตั้งค่าไม่ครบ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    AppConfig.missingConfigMessage,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HorPlugApp extends StatelessWidget {
  const HorPlugApp({
    super.key,
    required this.authController,
  });

  final AuthViewModel authController;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: authController,
      child: MaterialApp.router(
        title: 'HorPlug — ระบบจัดการหอพัก',
        theme: buildAppTheme(),
        scrollBehavior: const _AppScrollBehavior(),
        routerConfig: _buildRouter(authController),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// พฤติกรรมการเลื่อนที่รองรับเมาส์
///
/// Flutter ไม่นับเมาส์เป็นอุปกรณ์ที่ลากเพื่อเลื่อนได้ตามค่าเริ่มต้น เพราะบนเดสก์ท็อป
/// ปกติจะใช้ล้อหรือแถบเลื่อน · แต่แถวชิปตัวกรองที่เลื่อนแนวนอนในหน้าบิลกับหน้า
/// มิเตอร์ไม่มีแถบเลื่อนให้จับ และล้อเมาส์เลื่อนแนวตั้งอย่างเดียว ผู้ใช้เว็บจึง
/// เลื่อนแถวพวกนั้นไม่ได้เลยสักทาง
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

GoRouter _buildRouter(AuthViewModel authController) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authController,
    redirect: (context, state) {
      final location = state.uri.path;
      final isLoading = authController.status == AuthStatus.loading;
      final isAuthPage = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';

      if (isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (authController.isRecovering) {
        return location == '/reset-password' ? null : '/reset-password';
      }

      if (!authController.isAuthenticated) {
        if (isAuthPage) return null;
        return '/login';
      }

      final role = authController.role;
      if (role == null) {
        return '/login';
      }

      if (isAuthPage || location == '/' || location == '/splash') {
        return role == AppRole.landlord ? '/landlord' : '/tenant';
      }

      if (role == AppRole.landlord && location.startsWith('/tenant')) {
        return '/landlord';
      }

      if (role == AppRole.tenant && location.startsWith('/landlord')) {
        return '/tenant';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => const AdminShell(),
        routes: [
          GoRoute(
            path: '/landlord',
            builder: (context, state) {
              final dormitoryId = AuthScope.of(context).dormitoryId;
              return DashboardScreen(dormitoryId: dormitoryId ?? 0);
            },
          ),
          GoRoute(
            path: '/landlord/rooms',
            builder: (context, state) {
              final dormitoryId = AuthScope.of(context).dormitoryId;
              return RoomsScreen(dormitoryId: dormitoryId ?? 0);
            },
          ),
          GoRoute(
            path: '/landlord/meter',
            builder: (context, state) {
              final dormitoryId = AuthScope.of(context).dormitoryId;
              return MeterScreen(dormitoryId: dormitoryId ?? 0);
            },
          ),
          GoRoute(
            path: '/landlord/billing',
            builder: (context, state) {
              final dormitoryId = AuthScope.of(context).dormitoryId;
              return BillingScreen(dormitoryId: dormitoryId ?? 0);
            },
          ),
          GoRoute(
            path: '/landlord/chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: '/landlord/lease',
            builder: (context, state) => const LeaseScreen(),
          ),
          GoRoute(
            path: '/landlord/maintenance',
            builder: (context, state) {
              final dormitoryId = AuthScope.of(context).dormitoryId;
              return MaintenanceOverviewScreen(dormitoryId: dormitoryId ?? 0);
            },
          ),
        ],
      ),
      // ฝั่งผู้เช่าใช้ ShellRoute แบบเดียวกับ AdminShell: shell ถือ IndexedStack
      // ของทุกแท็บเอง จึงจงใจทิ้ง `child` และให้ builder ของแต่ละ route คืน
      // widget ว่าง แทนที่จะสร้างหน้าซ้ำสองครั้ง
      ShellRoute(
        builder: (context, state, child) => const TenantShell(),
        routes: [
          GoRoute(
            path: '/tenant',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/tenant/bills',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/tenant/maintenance',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/tenant/chat',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/tenant/profile',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
}
