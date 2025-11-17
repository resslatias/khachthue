import 'package:flutter/material.dart';

/// =============================================
/// Trang chi tiết giải đấu
/// =============================================
class TournamentDetailPage extends StatelessWidget {
  final int month;
  final int year;

  const TournamentDetailPage({
    super.key,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giải đấu tháng $month/$year'),
        backgroundColor: Color(0xFFC44536),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chia sẻ giải đấu')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner giải đấu
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC44536), Color(0xFFE74C3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, size: 60, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Giải Cầu Lông Tháng $month',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '15-20/$month/$year',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Thông tin giải đấu
          InfoSection(
            icon: Icons.info_outline,
            title: 'Thông tin chung',
            children: [
              InfoRow(label: 'Địa điểm', value: 'Sân cầu lông ABC, Hà Nội'),
              InfoRow(label: 'Số đội tham gia', value: '32 đội'),
              InfoRow(label: 'Hạng thi đấu', value: 'Đơn nam, Đơn nữ, Đôi nam, Đôi nữ'),
              InfoRow(label: 'Phí tham gia', value: '500.000 VNĐ/đội'),
              InfoRow(label: 'Thể thức', value: 'Loại trực tiếp'),
            ],
          ),
          const SizedBox(height: 16),

          // Giải thưởng
          InfoSection(
            icon: Icons.card_giftcard,
            title: 'Giải thưởng',
            children: [
              InfoRow(
                label: 'Quán quân',
                value: '10.000.000 VNĐ',
                valueColor: Color(0xFFFFD700),
                icon: Icons.emoji_events,
              ),
              InfoRow(
                label: 'Á quân',
                value: '5.000.000 VNĐ',
                valueColor: Color(0xFFC0C0C0),
                icon: Icons.emoji_events,
              ),
              InfoRow(
                label: 'Hạng 3',
                value: '3.000.000 VNĐ',
                valueColor: Color(0xFFCD7F32),
                icon: Icons.emoji_events,
              ),
              InfoRow(
                label: 'Hạng 4',
                value: '1.000.000 VNĐ',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lịch thi đấu
          InfoSection(
            icon: Icons.schedule,
            title: 'Lịch thi đấu',
            children: [
              InfoRow(label: 'Vòng loại', value: '15-16/$month/$year'),
              InfoRow(label: 'Vòng 1/8', value: '17/$month/$year'),
              InfoRow(label: 'Tứ kết', value: '18/$month/$year'),
              InfoRow(label: 'Bán kết', value: '19/$month/$year'),
              InfoRow(label: 'Chung kết', value: '20/$month/$year - 18:00'),
            ],
          ),
          const SizedBox(height: 16),

          // Điều kiện tham gia
          InfoSection(
            icon: Icons.rule,
            title: 'Điều kiện tham gia',
            children: [
              _BulletPoint(text: 'Tuổi từ 16 trở lên'),
              _BulletPoint(text: 'Có giấy khám sức khỏe trong 3 tháng'),
              _BulletPoint(text: 'Đăng ký trước ngày 10/$month/$year'),
              _BulletPoint(text: 'Nộp phí tham gia đầy đủ'),
            ],
          ),
          const SizedBox(height: 24),

          // Nút hành động
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Xem danh sách đội tham gia
                    _showComingSoon(context, 'Xem danh sách');
                  },
                  icon: Icon(Icons.people),
                  label: Text('Danh sách'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Color(0xFFC44536)),
                    foregroundColor: Color(0xFFC44536),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showRegistrationDialog(context);
                  },
                  icon: Icon(Icons.app_registration),
                  label: Text('Đăng ký'),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature đang phát triển'),
        backgroundColor: Color(0xFFF39C12),
      ),
    );
  }

  void _showRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 60, color: Color(0xFFC44536)),
              SizedBox(height: 16),
              Text(
                'Đăng ký tham gia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Tính năng đăng ký thi đấu đang được phát triển. Vui lòng liên hệ hotline để đăng ký.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: Color(0xFFC44536)),
                    SizedBox(width: 8),
                    Text(
                      '0123 456 789',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC44536),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
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
}

/// =============================================
/// Trang lịch sử giải đấu
/// =============================================
class TournamentHistoryPage extends StatelessWidget {
  const TournamentHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Lấy dữ liệu từ Firebase/API
    final List<Map<String, dynamic>> tournaments = [
      {
        'month': 11,
        'year': 2025,
        'champion': 'Nguyễn Văn A',
        'runnerUp': 'Trần Thị B',
        'participants': 28,
        'location': 'Sân ABC, Hà Nội',
      },
      {
        'month': 10,
        'year': 2025,
        'champion': 'Lê Văn C',
        'runnerUp': 'Phạm Thị D',
        'participants': 24,
        'location': 'Sân XYZ, TP.HCM',
      },
      {
        'month': 9,
        'year': 2025,
        'champion': 'Hoàng Văn E',
        'runnerUp': 'Vũ Thị F',
        'participants': 30,
        'location': 'Sân DEF, Đà Nẵng',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Giải đấu đã tổ chức'),
        backgroundColor: Color(0xFFC44536),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tournaments.length,
        itemBuilder: (context, index) {
          final tournament = tournaments[index];
          return TournamentHistoryCard(
            month: tournament['month'],
            year: tournament['year'],
            champion: tournament['champion'],
            runnerUp: tournament['runnerUp'],
            participants: tournament['participants'],
            location: tournament['location'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentDetailPage(
                    month: tournament['month'],
                    year: tournament['year'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TournamentHistoryCard extends StatelessWidget {
  final int month;
  final int year;
  final String champion;
  final String runnerUp;
  final int participants;
  final String location;
  final VoidCallback onTap;

  const TournamentHistoryCard({
    super.key,
    required this.month,
    required this.year,
    required this.champion,
    required this.runnerUp,
    required this.participants,
    required this.location,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFC44536).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Color(0xFFC44536),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giải đấu $month/$year',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Color(0xFFBDC3C7)),
                ],
              ),
              SizedBox(height: 16),
              Divider(height: 1, color: Color(0xFFECF0F1)),
              SizedBox(height: 12),

              // Thông tin chi tiết
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.emoji_events,
                      label: 'Quán quân',
                      value: champion,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Color(0xFFECF0F1),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.people,
                      label: 'Đội tham gia',
                      value: '$participants đội',
                      color: Color(0xFFC44536),
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
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF95A5A6),
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// =============================================
/// Các widget tái sử dụng
/// =============================================
class InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const InfoSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: valueColor ?? Color(0xFF2C3E50)),
                  SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? Color(0xFF2C3E50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(0xFFC44536),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}