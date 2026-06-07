import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/auth_controller.dart';
import 'models/models.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/billing_screen.dart';
import 'screens/admin/chat_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/lease_screen.dart';
import 'screens/admin/meter_screen.dart';
import 'screens/admin/rooms_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/tenant/tenant_home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final authController = AuthController();
  await authController.initialize();

  runApp(HorPlugApp(authController: authController));
}

class HorPlugApp extends StatelessWidget {
  const HorPlugApp({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: authController,
      child: MaterialApp.router(
        title: 'HorPlug Admin Portal',
        theme: buildAppTheme(),
        routerConfig: _buildRouter(authController),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

GoRouter _buildRouter(AuthController authController) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authController,
    redirect: (context, state) {
      final location = state.uri.path;
      final isLoading = authController.status == AuthStatus.loading;
      final isAuthPage = location == '/login' || location == '/register';

      if (isLoading) {
        return location == '/splash' ? null : '/splash';
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
        ],
      ),
      GoRoute(
        path: '/tenant',
        builder: (context, state) => const TenantHomeScreen(),
      ),
    ],
  );
}
