import 'package:flutter/material.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tài khoản',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _MenuSection(
            title: 'Cài đặt tài khoản',
            items: [
              _MenuItem(
                icon: Icons.person_outline,
                title: 'Thông tin cá nhân',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Thông báo',
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuSection(
            title: 'Hỗ trợ',
            items: [
              _MenuItem(
                icon: Icons.help_outline,
                title: 'Trung tâm trợ giúp',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Chính sách & điều khoản',
                onTap: () => _showComingSoon(context),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                title: 'Về ứng dụng',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng đang phát triển')),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Về ứng dụng'),
        content: const Text('Phiên bản 1.0.0\n\nỨng dụng được phát triển bởi Flutter'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          child: Column(children: items.map((e) => e).toList()),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
