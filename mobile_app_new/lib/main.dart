import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/owner_faces_screen.dart';
import 'screens/approval_request_screen.dart';
import 'notification_service.dart';
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  runApp(const SmartLockerApp());
}

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Smart Cupboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF00FF88),
          surface: Color(0xFF111827),
          background: Color(0xFF0A0E1A),
        ),
        useMaterial3: true,
      ),
      home: const SplashRouter(),
      routes: {
        '/home':        (context) => const MainNavigation(),
        '/auth':        (context) => const AuthScreen(),
        '/gallery':     (context) => GalleryScreen(),
        '/approval':    (context) => ApprovalRequestScreen(),
        '/logs':        (context) => const LogsScreen(),
        '/owner_faces': (context) => const OwnerFacesScreen(),
      },
    );
  }
}

// ── Splash / Auth router ──────────────────────────────────────
class SplashRouter extends StatefulWidget {
  const SplashRouter({Key? key}) : super(key: key);
  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));
    final loggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      Navigator.pushReplacementNamed(
        context, loggedIn ? '/home' : '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF00D4FF), size: 64),
            SizedBox(height: 20),
            Text('AI Smart Cupboard',
                style: TextStyle(
                    color: Color(0xFFE8EDF5),
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}

// ── Main navigation ───────────────────────────────────────────
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const _bg           = Color(0xFF0A0E1A);
  static const _surface      = Color(0xFF111827);
  static const _border       = Color(0xFF2A3550);
  static const _cyan         = Color(0xFF00D4FF);
  static const _textSecondary = Color(0xFF6B7A99);

  final List<Widget> _screens = const [
    DashboardScreen(),
    LogsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _cyan,
          unselectedItemColor: _textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt_rounded), label: 'Logs'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}