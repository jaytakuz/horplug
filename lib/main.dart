import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/admin/rooms_screen.dart';
import 'screens/admin/meter_screen.dart';
import 'screens/admin/billing_screen.dart';
import 'screens/admin/chat_screen.dart';
import 'screens/admin/lease_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const HorPlugApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/sakplace/admin',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        final dormSlug = state.pathParameters['dormSlug'] ?? 'sakplace';
        return AdminShell(dormSlug: dormSlug, child: child);
      },
      routes: [
        GoRoute(
          path: '/:dormSlug/admin',
          builder: (context, state) => DashboardScreen(dormSlug: state.pathParameters['dormSlug']!),
        ),
        GoRoute(
          path: '/:dormSlug/admin/rooms',
          builder: (context, state) => const RoomsScreen(),
        ),
        GoRoute(
          path: '/:dormSlug/admin/meter',
          builder: (context, state) => const MeterScreen(),
        ),
        GoRoute(
          path: '/:dormSlug/admin/billing',
          builder: (context, state) => const BillingScreen(),
        ),
        GoRoute(
          path: '/:dormSlug/admin/chat',
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: '/:dormSlug/admin/lease',
          builder: (context, state) => const LeaseScreen(),
        ),
      ],
    ),
  ],
);

class HorPlugApp extends StatelessWidget {
  const HorPlugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HorPlug Admin Portal',
      theme: buildAppTheme(),
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
