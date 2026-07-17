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
import 'theme.dart';

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
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyan,
          secondary: AppColors.mint,
          surface: AppColors.surface,
          background: AppColors.bg,
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
    await Future.delayed(const Duration(milliseconds: 1400));
    final loggedIn = await ApiService.isLoggedIn();
    if (mounted) {
      Navigator.pushReplacementNamed(
        context, loggedIn ? '/home' : '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SentinelCore(size: 190, color: AppColors.cyan, icon: Icons.lock_rounded),
            const SizedBox(height: 34),
            const Text(
              'AI Smart Cupboard',
              style: TextStyle(
                color: AppColors.textHi,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'INITIALIZING SECURE SESSION',
              style: TextStyle(
                color: AppColors.textLo,
                fontFamily: kMono,
                fontSize: 11,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    LogsScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (Icons.shield_outlined, Icons.shield_rounded, 'Home'),
    (Icons.list_alt_outlined, Icons.list_alt_rounded, 'Logs'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141A28), AppColors.surface],
          ),
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final selected = i == _selectedIndex;
                final (outline, filled, label) = _tabs[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.cyan.withOpacity(0.10) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.cyan.withOpacity(0.35) : Colors.transparent,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: AppColors.cyan.withOpacity(0.18), blurRadius: 16, spreadRadius: -4)]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? filled : outline,
                            color: selected ? AppColors.cyan : AppColors.textLo,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected ? AppColors.cyan : AppColors.textLo,
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
