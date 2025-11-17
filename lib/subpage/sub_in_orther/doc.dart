import 'package:flutter/material.dart';

/// =============================================
/// Trang danh sách bài chia sẻ kinh nghiệm
/// =============================================
class ExperienceListPage extends StatelessWidget {
  final String category;
  final String title;

  const ExperienceListPage({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Thay thế bằng dữ liệu thực từ Firestore hoặc API
    final List<Map<String, dynamic>> articles = _getArticlesByCategory(category);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Color(0xFFC44536),
        foregroundColor: Colors.white,
      ),
      body: articles.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return ArticleCard(
            title: article['title'],
            summary: article['summary'],
            imageUrl: article['imageUrl'],
            date: article['date'],
            views: article['views'],
            onTap: () {
              // TODO: Mở trang chi tiết bài viết hoặc Google Docs
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailPage(
                    articleId: article['id'],
                    title: article['title'],
                    docsUrl: article['docsUrl'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
            'Chưa có bài viết',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7F8C8D),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Nội dung đang được cập nhật',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7F8C8D),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getArticlesByCategory(String category) {
    // TODO: Thay thế bằng dữ liệu từ Firebase/API
    // Đây là dữ liệu mẫu
    switch (category) {
      case 'basic':
        return [
          {
            'id': '1',
            'title': '5 kỹ thuật cầm vợt cơ bản cho người mới',
            'summary': 'Hướng dẫn chi tiết cách cầm vợt đúng cách để có cú đánh hiệu quả nhất',
            'imageUrl': null,
            'date': '15/11/2025',
            'views': 1234,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
          {
            'id': '2',
            'title': 'Bí quyết di chuyển nhanh trên sân',
            'summary': 'Các bài tập để cải thiện tốc độ di chuyển và phản xạ',
            'imageUrl': null,
            'date': '10/11/2025',
            'views': 892,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
          {
            'id': '3',
            'title': 'Cách đánh cầu cao hiệu quả',
            'summary': 'Kỹ thuật đánh cầu cao để tạo thế chủ động',
            'imageUrl': null,
            'date': '08/11/2025',
            'views': 756,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
        ];
      case 'tactics':
        return [
          {
            'id': '4',
            'title': 'Chiến thuật đánh đôi hiệu quả',
            'summary': 'Phối hợp với đồng đội để giành chiến thắng',
            'imageUrl': null,
            'date': '12/11/2025',
            'views': 1056,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
          {
            'id': '5',
            'title': 'Cách đọc đường bóng đối thủ',
            'summary': 'Dự đoán và phản ứng với cú đánh của đối phương',
            'imageUrl': null,
            'date': '05/11/2025',
            'views': 823,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
        ];
      case 'health':
        return [
          {
            'id': '6',
            'title': 'Khởi động đúng cách trước khi chơi',
            'summary': '10 động tác khởi động quan trọng để tránh chấn thương',
            'imageUrl': null,
            'date': '08/11/2025',
            'views': 1456,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
          {
            'id': '7',
            'title': 'Xử lý chấn thương phổ biến',
            'summary': 'Cách sơ cứu và phục hồi khi bị chấn thương',
            'imageUrl': null,
            'date': '03/11/2025',
            'views': 932,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
        ];
      case 'equipment':
        return [
          {
            'id': '8',
            'title': 'Top 5 vợt cầu lông tốt nhất 2025',
            'summary': 'Đánh giá chi tiết các dòng vợt phổ biến hiện nay',
            'imageUrl': null,
            'date': '05/11/2025',
            'views': 2103,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
          {
            'id': '9',
            'title': 'Hướng dẫn chọn giày cầu lông',
            'summary': 'Các tiêu chí quan trọng khi mua giày chơi cầu lông',
            'imageUrl': null,
            'date': '01/11/2025',
            'views': 1567,
            'docsUrl': 'https://docs.google.com/document/d/YOUR_DOC_ID',
          },
        ];
      default:
        return [];
    }
  }
}

/// =============================================
/// Card hiển thị bài viết
/// =============================================
class ArticleCard extends StatelessWidget {
  final String title;
  final String summary;
  final String? imageUrl;
  final String date;
  final int views;
  final VoidCallback onTap;

  const ArticleCard({
    super.key,
    required this.title,
    required this.summary,
    this.imageUrl,
    required this.date,
    required this.views,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              // Tóm tắt
              Text(
                summary,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Thông tin phụ
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Color(0xFF95A5A6)),
                  SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(fontSize: 12, color: Color(0xFF95A5A6)),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.visibility, size: 14, color: Color(0xFF95A5A6)),
                  SizedBox(width: 4),
                  Text(
                    '$views lượt xem',
                    style: TextStyle(fontSize: 12, color: Color(0xFF95A5A6)),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, color: Color(0xFFC44536)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================================
/// Trang chi tiết bài viết (hiển thị Google Docs)
/// =============================================
class ArticleDetailPage extends StatelessWidget {
  final String articleId;
  final String title;
  final String docsUrl;

  const ArticleDetailPage({
    super.key,
    required this.articleId,
    required this.title,
    required this.docsUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Color(0xFFC44536),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tính năng chia sẻ đang phát triển')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description,
                  size: 64,
                  color: Color(0xFFC44536),
                ),
              ),
              SizedBox(height: 24),

              // Tiêu đề
              Text(
                'Bài viết trên Google Docs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              SizedBox(height: 12),

              // Mô tả
              Text(
                'Nội dung bài viết được lưu trữ trên Google Docs. Nhấn nút bên dưới để mở và đọc bài viết.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7F8C8D),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),

              // Nút mở link
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Sử dụng url_launcher để mở link
                    // import 'package:url_launcher/url_launcher.dart';
                    // final Uri url = Uri.parse(docsUrl);
                    // launchUrl(url, mode: LaunchMode.externalApplication);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sẽ mở: $docsUrl'),
                        action: SnackBarAction(
                          label: 'OK',
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.open_in_new, size: 20),
                  label: Text(
                    'Mở bài viết',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Nút quay lại
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Color(0xFFBDC3C7)),
                  ),
                  child: Text(
                    'Quay lại',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}