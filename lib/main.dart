// =============================================
// IMPORT THƯ VIỆN VÀ DEPENDENCIES
// =============================================

/// Core Dart libraries
import 'dart:async'; // Xử lý bất đồng bộ (Stream, Future)
import 'package:flutter/services.dart';

/// Firebase services - Backend & Authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database
import 'package:firebase_core/firebase_core.dart'; // Firebase core
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication

/// Flutter core
import 'package:flutter/material.dart'; // Flutter UI framework

/// Subpages - Các màn hình chính trong app
import 'package:khachthue/subpage/befor.dart'; // Lịch sử
import 'package:khachthue/subpage/home.dart'; // Trang chủ
import 'package:khachthue/subpage/me.dart'; // Cá nhân
import 'package:khachthue/subpage/new.dart'; // Thông báo
import 'package:khachthue/subpage/orther.dart'; // Khác

/// Authentication module
import 'auth_login/AuthService.dart'; // Service xử lý auth
import 'auth_login/LoginPage.dart'; // Màn hình đăng nhập
import 'auth_login/RegisterPage.dart'; // Màn hình đăng ký

/// Utility services
import 'check/network_service.dart'; // Kiểm tra kết nối mạng
import 'check/app_navigator.dart'; // Quản lý navigation
import 'data/demo_data.dart'; // Dữ liệu demo (có thể không dùng)

/// Enum định nghĩa các tab chính trong bottom navigation
enum TabItem { home, me, before, news, other }

// =============================================
// OPTIMIZED MAIN - Async Firebase Init
// =============================================

// =============================================
// Cấu trúc :
// main--> SplashApp
//     --> Khỏi tạo firebase
// =============================================
Future<void> main() async {
  // Đảm bảo Flutter binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Hiển thị splash -- gần dòng 81
  runApp(const SplashApp());

  // Init Firebase trong background
  await Firebase.initializeApp();

  //createSamplePosts();

  // Cleanup không blocking --> gần dòng 64
  _cleanupExpiredCourtsOnStartup().catchError((e) {
    debugPrint("Hàm debug này ở main.dart . Lỗi dọn dẹp : $e");
  });

  // Chuyển sang app chính
  runApp(const MyApp());
}

Future<void> _cleanupExpiredCourtsOnStartup() async {
  try {
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) return;
    debugPrint(" Hàm debug này ở main.dart . Đang dọn dẹp sân hết hạn...");
    final now = DateTime.now();
    // Thêm logic cleanup  ở đây

  } catch (e) {
    debugPrint("Hàm debug này ở main.dart. Lỗi dọn dẹp: $e");
  }
}

// =============================================
// SPLASH SCREEN
// =============================================
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFC44536),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.sports_tennis,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              SizedBox(height: 24),
              // App name
              Text(
                'KL10 - Đặt Sân Cầu Lông',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              // Loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================
// 🎨 MAIN APP - Giữ nguyên theme
// =============================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC44536);
    const secondaryColor = Color(0xFFE67E22);
    const backgroundColor = Color(0xFF2C3E50);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          background: const Color(0xFFECF0F1),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFECF0F1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 3,
          iconTheme: IconThemeData(color: Color(0xFF2C3E50)),
          titleTextStyle: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFC44536),
          unselectedItemColor: Color(0xFF7F8C8D),
        ),
      ),
      home: const Shell(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
      },
    );
  }
}

// =============================================
// 🏠 SHELL - Giữ nguyên
// =============================================
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  TabItem _current = TabItem.home;

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
      //canPop: !(_navKeys[_current]?.currentState?.canPop() ?? false),
      canPop: false, // Luôn chặn pop mặc định (không thoát app)
     /* onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = _navKeys[_current]?.currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },*/
      onPopInvoked: (didPop) async {
        final nav = _navKeys[_current]?.currentState;

        // Nếu trong tab hiện tại có thể pop thì pop màn hình đó
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }

        // Nếu đang không ở tab Home => quay về tab Home
        if (_current != TabItem.home) {
          setState(() => _current = TabItem.home);
          return;
        }

        // Nếu đang ở tab Home => hỏi xác nhận thoát app
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thoát ứng dụng?'),
            content: const Text('Bạn có chắc muốn thoát ứng dụng không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Không'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Thoát'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          // Dùng SystemNavigator.pop() để thoát
          Future.delayed(const Duration(milliseconds: 100), () {
            // ignore: deprecated_member_use
            SystemNavigator.pop();
          });
        }
      },

      child: Scaffold(
        body: Column(
          children: [
            const OptimizedHeaderSection(), // 🎯 Header đã tối ưu
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  _TabNav(navKey: _navKeys[TabItem.home]!,   builder: (_) => const HomePage()),
                  _TabNav(navKey: _navKeys[TabItem.other]!,  builder: (_) => const OrtherPage()),
                  _TabNav(navKey: _navKeys[TabItem.before]!, builder: (_) => const BeforPage()),
                  _TabNav(navKey: _navKeys[TabItem.news]!,   builder: (_) => const NewsPage()),
                  _TabNav(navKey: _navKeys[TabItem.me]!,     builder: (_) => const MePage()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(context),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: TabItem.values.indexOf(_current),
        onTap: (i) => setState(() => _current = TabItem.values[i]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: const Color(0xFF7F8C8D),
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.home_outlined, size: 24),
            ),
            activeIcon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.home_filled, size: 24, color: Theme.of(context).colorScheme.primary),
            ),
            label: 'Trang chủ',
          ),


          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.local_fire_department_outlined, size: 24),
            ),
            activeIcon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_fire_department, size: 24, color: Theme.of(context).colorScheme.primary),
            ),
            label: 'Hot',
          ),


          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.history_outlined, size: 24),
            ),
            activeIcon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history, size: 24, color: Theme.of(context).colorScheme.primary),
            ),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.notifications_outlined, size: 24),
            ),
            activeIcon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications, size: 24, color: Theme.of(context).colorScheme.primary),
            ),
            label: 'Thông báo',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.person_outline, size: 24),
            ),
            activeIcon: Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person, size: 24, color: Theme.of(context).colorScheme.primary),
            ),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

class _TabNav extends StatelessWidget {
  final WidgetBuilder builder;
  final GlobalKey<NavigatorState> navKey;
  const _TabNav({super.key, required this.builder, required this.navKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: builder,
        settings: settings,
      ),
    );
  }
}

// =============================================
// 🚀 OPTIMIZED HEADER - Load data async
// =============================================
class OptimizedHeaderSection extends StatefulWidget {
  const OptimizedHeaderSection({super.key});

  @override
  State<OptimizedHeaderSection> createState() => _OptimizedHeaderSectionState();
}

class _OptimizedHeaderSectionState extends State<OptimizedHeaderSection> {
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfileAsync();
  }

  // 🎯 Load profile không blocking UI
  Future<void> _loadUserProfileAsync() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingProfile = true);

    try {
      final profile = await AuthService().currentUserData();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi load profile: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFC44536),
            Color(0xFFE74C3C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, authSnapshot) {
          final isLoggedIn = authSnapshot.data != null;

          return Row(
            children: [
              // Avatar/Logo với placeholder
              _buildProfileImage(isLoggedIn),
              SizedBox(width: 16),
              Expanded(
                child: _buildUserInfo(isLoggedIn),
              ),
              if (!isLoggedIn) ..._buildAuthButtons(context)
              else _buildLogoutButton(context),
            ],
          );
        },
      ),
    );
  }

  // 🎯 Profile image với placeholder ngay lập tức
  Widget _buildProfileImage(bool isLoggedIn) {
    if (!isLoggedIn) {
      return _buildLogoPlaceholder();
    }

    final avatarUrl = (_userProfile?['anh_dai_dien'] as String?) ?? '';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingProfile
          ? _buildAvatarSkeleton()
          : avatarUrl.isNotEmpty
          ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
          : CircleAvatar(
        backgroundColor: Colors.white.withOpacity(0.2),
        child: Icon(Icons.person, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.sports_tennis,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  Widget _buildAvatarSkeleton() {
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.3),
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  // 🎯 User info với placeholder
  Widget _buildUserInfo(bool isLoggedIn) {
    if (!isLoggedIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xin chào!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'KL10 - Đặt sân cầu lông',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    // Hiển thị placeholder trong khi load
    if (_isLoadingProfile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào mừng trở lại!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      );
    }

    // Hiển thị tên thực
    final displayName = (_userProfile?['ho_ten'] as String?)?.trim().isNotEmpty == true
        ? _userProfile!['ho_ten'] as String
        : (FirebaseAuth.instance.currentUser?.displayName ?? 'Người dùng');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào mừng trở lại!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAuthButtons(BuildContext context) {
    return [
      _HeaderButton(
        label: 'Đăng nhập',
        filled: true,
        onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/login'),
      ),
      SizedBox(width: 10),
      _HeaderButton(
        label: 'Đăng ký',
        filled: false,
        onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/register'),
      ),
    ];
  }

  Widget _buildLogoutButton(BuildContext context) {
    return _HeaderButton(
      label: 'Đăng xuất',
      filled: false,
      onTap: () => AuthService().signOut(),
    );
  }
}

// =============================================
// 🎨 HEADER BUTTON - Giữ nguyên
// =============================================
class _HeaderButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: filled ? 0 : 1.5,
          ),
          boxShadow: filled ? [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Theme.of(context).colorScheme.primary : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}