import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khachthue/subpage/sub_in_me/like.dart';
import 'package:khachthue/subpage/sub_in_me/profile.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFC44536)));
        }
        final user = snapshot.data;
        return _MePageView(user: user);
      },
    );
  }
}

// =============================================
// View chung cho cả đã và chưa đăng nhập
// =============================================
class _MePageView extends StatelessWidget {
  final User? user;

  const _MePageView({this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(3, 8, 16, 16),
          child: Row(
            children: [
              Icon(Icons.person, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                'Tài khoản & Cài đặt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),

        // SECTION 1: TÀI KHOẢN (chỉ hiển thị khi đã đăng nhập)
        if (user != null) ...[
          _SectionHeader(
            icon: Icons.person_outline,
            title: 'Tài khoản',
          ),
          const SizedBox(height: 12),
          _MenuCard(
            items: [
              _MenuItem(
                icon: Icons.person,
                title: 'Thông tin cá nhân',
                subtitle: 'Quản lý thông tin cá nhân của bạn',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(userId: user!.uid),
                  ),
                ),
              ),
              _MenuDivider(),
              _MenuItem(
                icon: Icons.lock,
                title: 'Đổi mật khẩu',
                subtitle: 'Thay đổi mật khẩu đăng nhập',
                onTap: () => _showChangePasswordDialog(context),
              ),
              _MenuDivider(),
              _MenuItem(
                icon: Icons.favorite,
                title: 'Sân ưa thích',
                subtitle: 'Danh sách sân bạn đã lưu',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LikePage()),
                ),
              ),
              _MenuDivider(),
              _MenuItem(
                icon: Icons.comment,
                title: 'Bình luận của bạn',
                subtitle: 'Xem tất cả bình luận đã đăng',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Nếu chưa đăng nhập, hiển thị card yêu cầu đăng nhập
        if (user == null) ...[
          _SectionHeader(
            icon: Icons.person_outline,
            title: 'Tài khoản',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFC44536).withOpacity(0.1),
                        Color(0xFFE74C3C).withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.account_circle_outlined,
                    size: 50,
                    color: Color(0xFFC44536),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bạn cần đăng nhập',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đăng nhập để quản lý thông tin cá nhân,\nxem sân yêu thích và nhiều tính năng khác',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7F8C8D),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pushNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Đăng nhập ngay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // SECTION 2: CÀI ĐẶT (luôn hiển thị)
        _SectionHeader(
          icon: Icons.settings_outlined,
          title: 'Cài đặt',
        ),
        const SizedBox(height: 12),
        _MenuCard(
          items: [
            _MenuItem(
              icon: Icons.info,
              title: 'Thông tin ứng dụng',
              subtitle: 'Phiên bản 1.0.0',
              onTap: () => _showAboutDialog(context),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.support_agent,
              title: 'Liên hệ chăm sóc khách hàng',
              subtitle: 'Hỗ trợ 24/7',
              onTap: () => _showSupportDialog(context),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.privacy_tip,
              title: 'Chính sách & Điều khoản',
              subtitle: 'Quyền riêng tư và điều khoản sử dụng',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Nút đăng xuất (chỉ hiển thị khi đã đăng nhập)
        if (user != null) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.logout, color: Colors.red),
              ),
              title: Text(
                'Đăng xuất',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.red),
              onTap: () => _showLogoutDialog(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // Dialog đổi mật khẩu
  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFC44536).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock, color: Color(0xFFC44536), size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đổi mật khẩu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Form đổi mật khẩu
              _PasswordField(
                label: 'Mật khẩu hiện tại',
                hintText: 'Nhập mật khẩu hiện tại',
              ),
              SizedBox(height: 16),
              _PasswordField(
                label: 'Mật khẩu mới',
                hintText: 'Nhập mật khẩu mới',
              ),
              SizedBox(height: 16),
              _PasswordField(
                label: 'Xác nhận mật khẩu mới',
                hintText: 'Nhập lại mật khẩu mới',
              ),

              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Color(0xFFBDC3C7)),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: Color(0xFF7F8C8D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showComingSoon(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC44536),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Đổi mật khẩu',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog hỗ trợ khách hàng
  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFC44536).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.support_agent, color: Color(0xFFC44536), size: 24),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chăm sóc khách hàng',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Nội dung
              Text(
                'Chúng tôi luôn sẵn sàng hỗ trợ bạn!',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 16),

              // Thông tin liên hệ
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFC44536).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, color: Color(0xFFC44536), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hotline 24/7',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '0123 456 789',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC44536),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.email, color: Color(0xFFC44536), size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email hỗ trợ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'support@badminton.com',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Đội ngũ hỗ trợ của chúng tôi luôn sẵn sàng phục vụ bạn!',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7F8C8D),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Color(0xFFBDC3C7)),
                      ),
                      child: Text(
                        'Đóng',
                        style: TextStyle(
                          color: Color(0xFF7F8C8D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.phone, size: 18),
                      label: Text('Gọi ngay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC44536),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog đăng xuất
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon cảnh báo
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, size: 32, color: Colors.red),
              ),
              SizedBox(height: 16),

              // Tiêu đề
              Text(
                'Đăng xuất',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 8),

              // Nội dung
              Text(
                'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Color(0xFFBDC3C7)),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: Color(0xFF7F8C8D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã đăng xuất thành công'),
                              backgroundColor: Color(0xFF2E8B57),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Đăng xuất',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog về ứng dụng
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo ứng dụng
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.sports_tennis, size: 40, color: Color(0xFFC44536)),
              ),
              SizedBox(height: 16),

              // Tên ứng dụng
              Text(
                'Đặt Sân Cầu Lông',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 4),

              // Phiên bản
              Text(
                'Phiên bản 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              SizedBox(height: 16),

              // Mô tả
              Text(
                'Ứng dụng đặt sân cầu lông tiện lợi, nhanh chóng và dễ dàng. Kết nối người chơi với các cơ sở cầu lông chất lượng.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),

              // Thông tin phát triển
              Text(
                'Được phát triển bởi Flutter',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 24),

              // Nút đóng
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tính năng đang phát triển
  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Tính năng đang phát triển'),
          ],
        ),
        backgroundColor: Color(0xFFF39C12),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// Widget cho trường mật khẩu
class _PasswordField extends StatelessWidget {
  final String label;
  final String hintText;

  const _PasswordField({
    required this.label,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: 6),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFBDC3C7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFBDC3C7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFC44536)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

// =============================================
// Các component UI
// =============================================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Color(0xFFC44536).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFFC44536), size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Color(0xFFC44536),
                  size: 22,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Color(0xFFBDC3C7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Color(0xFFECF0F1),
      ),
    );
  }
}