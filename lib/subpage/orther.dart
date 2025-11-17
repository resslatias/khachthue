import 'package:flutter/material.dart';
import 'package:khachthue/subpage/sub_in_orther/doc.dart';
import 'package:khachthue/subpage/sub_in_orther/giaidau.dart';


/// ORTHER PAGE — Trang khám phá (không yêu cầu đăng nhập)
class OrtherPage extends StatelessWidget {
  const OrtherPage({super.key});

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
              Icon(Icons.explore, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                'Khám phá',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),

        // SECTION 1: KINH NGHIỆM CHƠI CẦU LÔNG
        _SectionHeader(
          icon: Icons.lightbulb_outline,
          title: 'Kinh nghiệm chơi cầu lông',
        ),
        const SizedBox(height: 12),
        _MenuCard(
          items: [
            _MenuItem(
              icon: Icons.article,
              title: 'Kỹ thuật cơ bản',
              subtitle: 'Hướng dẫn cách cầm vợt, di chuyển cơ bản',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperienceListPage(
                    category: 'basic',
                    title: 'Kỹ thuật cơ bản',
                  ),
                ),
              ),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.fitness_center,
              title: 'Chiến thuật thi đấu',
              subtitle: 'Mẹo và chiến thuật để thắng trận',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperienceListPage(
                    category: 'tactics',
                    title: 'Chiến thuật thi đấu',
                  ),
                ),
              ),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.healing,
              title: 'Phòng tránh chấn thương',
              subtitle: 'Cách khởi động và bảo vệ cơ thể',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperienceListPage(
                    category: 'health',
                    title: 'Phòng tránh chấn thương',
                  ),
                ),
              ),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.shopping_bag,
              title: 'Chọn mua trang thiết bị',
              subtitle: 'Hướng dẫn chọn vợt, giày và phụ kiện',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExperienceListPage(
                    category: 'equipment',
                    title: 'Chọn mua trang thiết bị',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // SECTION 2: GIẢI ĐẤU
        _SectionHeader(
          icon: Icons.emoji_events_outlined,
          title: 'Giải đấu',
        ),
        const SizedBox(height: 12),
        _MenuCard(
          items: [
            _MenuItem(
              icon: Icons.calendar_today,
              title: 'Giải đấu tháng 12',
              subtitle: 'Thông tin và lịch thi đấu tháng 12/2025',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentDetailPage(
                    month: 12,
                    year: 2025,
                  ),
                ),
              ),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.history,
              title: 'Giải đấu đã tổ chức',
              subtitle: 'Xem lại các giải đấu trước đây',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentHistoryPage(),
                ),
              ),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.app_registration,
              title: 'Đăng ký thi đấu',
              subtitle: 'Đăng ký tham gia giải đấu sắp tới',
              onTap: () => _showComingSoon(context),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.star,
              title: 'Bảng xếp hạng',
              subtitle: 'Xem thứ hạng của các tuyển thủ',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // SECTION 3: CỘNG ĐỒNG
        _SectionHeader(
          icon: Icons.groups_outlined,
          title: 'Cộng đồng',
        ),
        const SizedBox(height: 12),
        _MenuCard(
          items: [
            _MenuItem(
              icon: Icons.forum,
              title: 'Diễn đàn thảo luận',
              subtitle: 'Trao đổi kinh nghiệm với cộng đồng',
              onTap: () => _showComingSoon(context),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.people,
              title: 'Tìm bạn đánh cầu',
              subtitle: 'Kết nối với các golfer khác',
              onTap: () => _showComingSoon(context),
            ),
            _MenuDivider(),
            _MenuItem(
              icon: Icons.share,
              title: 'Chia sẻ khoảnh khắc',
              subtitle: 'Đăng ảnh và video của bạn',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

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

// =============================================
// Các component UI tái sử dụng
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
                child: Icon(icon, color: Color(0xFFC44536), size: 22),
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
              Icon(Icons.chevron_right, color: Color(0xFFBDC3C7), size: 20),
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