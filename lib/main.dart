import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';           // +++
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khachthue/subpage/befor.dart';
import 'package:khachthue/subpage/home.dart';
import 'package:khachthue/subpage/me.dart';
import 'package:khachthue/subpage/new.dart';
import 'package:khachthue/subpage/orther.dart';

import 'auth_login/AuthService.dart';
import 'auth_login/LoginPage.dart';
import 'auth_login/RegisterPage.dart';
import 'check/network_service.dart';
import 'check/app_navigator.dart';
import 'data/demo_data.dart';

enum TabItem { home, me, before, news, other }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();                 // +++
  await Firebase.initializeApp();

  runApp(const MyApp());
}

/// App gốc
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1DBA6B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key, // OK: chỉ dùng ở MaterialApp gốc
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const Shell(),                                      // +++ đặt Shell là màn chính
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  TabItem _current = TabItem.home;

  // Mỗi tab có Navigator riêng
  final _navKeys = <TabItem, GlobalKey<NavigatorState>>{
    TabItem.home: GlobalKey<NavigatorState>(),
    TabItem.me: GlobalKey<NavigatorState>(),
    TabItem.before: GlobalKey<NavigatorState>(),
    TabItem.news: GlobalKey<NavigatorState>(),
    TabItem.other: GlobalKey<NavigatorState>(),
  };

  StreamSubscription<bool>? _netSub;

  @override
  void initState() {
    super.initState();
    NetworkService.instance.ensureStarted();
    _netSub = NetworkService.instance.onChanged.listen((ok) {
      debugPrint(ok ? 'Đã kết nối mạng' : 'Mất kết nối mạng');
    });
  }

  @override
  void dispose() {
    _netSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = TabItem.values.indexOf(_current);

    return PopScope(
      canPop: !(_navKeys[_current]?.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = _navKeys[_current]?.currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            const HeaderSection(),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  _TabNav(navKey: _navKeys[TabItem.home]!,   builder: (_) => const HomePage()),
                  _TabNav(navKey: _navKeys[TabItem.me]!,     builder: (_) => const MePage()),
                  _TabNav(navKey: _navKeys[TabItem.before]!, builder: (_) => const BeforPage()),
                  _TabNav(navKey: _navKeys[TabItem.news]!,   builder: (_) => const NewsPage()),
                  _TabNav(navKey: _navKeys[TabItem.other]!,  builder: (_) => const OrtherPage()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => setState(() => _current = TabItem.values[i]),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.black54,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Trang chủ'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
            BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Lịch sử'),
            BottomNavigationBarItem(icon: Icon(Icons.add_alert_outlined), label: 'Thông báo'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Khác'),
          ],
        ),
      ),
    );
  }
}

// Navigator riêng cho từng tab (GẮN key vào Navigator)
class _TabNav extends StatelessWidget {
  final WidgetBuilder builder;
  final GlobalKey<NavigatorState> navKey;
  const _TabNav({super.key, required this.builder, required this.navKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey, // +++ quan trọng
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: builder,
        settings: settings,
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════
/// HEADER: hiện avatar/tên khi đã đăng nhập; nút Đăng nhập/Đăng ký khi chưa
/// ════════════════════════════════════════════════════════
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = AuthService();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer.withOpacity(.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
      constraints: const BoxConstraints(minHeight: 86),
      child: StreamBuilder<User?>(
        // Lắng nghe thay đổi đăng nhập từ FirebaseAuth
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, authSnapshot) {
          final isLoggedIn = authSnapshot.data != null;

          if (!isLoggedIn) {
            // Chưa đăng nhập
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: const Icon(Icons.sports_tennis, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bạn chưa đăng nhập',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SmallButton(
                  label: 'Đăng nhập',
                  filled: true,
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/login'),
                ),
                const SizedBox(width: 8),
                _SmallButton(
                  label: 'Đăng ký',
                  filled: false,
                  onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/register'),
                ),
              ],
            );
          }

          // Đã đăng nhập: lấy hồ sơ hiện tại 1 lần (Map<String,dynamic>?)
          return FutureBuilder<Map<String, dynamic>?>(
            future: auth.currentUserData(),
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data;
              final displayName =
              (profile?['ho_ten'] as String?)?.trim().isNotEmpty == true
                  ? profile!['ho_ten'] as String
                  : (FirebaseAuth.instance.currentUser?.displayName ?? 'Đã đăng nhập');
              final avatarUrl = (profile?['anh_dai_dien'] as String?) ?? '';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (avatarUrl.isNotEmpty)
                    CircleAvatar(radius: 18, backgroundImage: NetworkImage(avatarUrl))
                  else
                    const CircleAvatar(radius: 18, child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallButton(
                    label: 'Đăng xuất',
                    filled: false,
                    onTap: () => auth.signOut(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Nút nhỏ dùng trong Header
class _SmallButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? cs.primary : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}