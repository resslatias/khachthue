import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:khachthue/subpage/sub_in_orther/together.dart';

/// ORTHER PAGE – Trang khám phá
class OrtherPage extends StatelessWidget {
  const OrtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFECF0F1),
      body: Column(
        children: [
          // Header - GIỐNG VỚI CÁC TRANG TRƯỚC
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.explore, color: Color(0xFFC44536), size: 24),
                SizedBox(width: 12),
                Text(
                  'Khám phá',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text(
                    'Tính năng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Tìm người chơi cùng
                  _FeatureCard(
                    icon: Icons.people_alt,
                    title: 'Tìm người chơi cùng',
                    subtitle: 'Kết nối với cộng đồng cầu lông',
                    color: Color(0xFF3498DB),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TogetherPage(),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Giải đấu tháng
                  _FeatureCard(
                    icon: Icons.emoji_events,
                    title: 'Giải đấu tháng',
                    subtitle: 'Thông tin và lịch thi đấu',
                    color: Color(0xFFF39C12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoogleDocViewer(
                          url: 'https://docs.google.com/document/d/1NHi2-JlkTOd25YP_eaUuwJH1CQEYCN9NncmyoiZ9TrU/edit?tab=t.0',
                          title: 'Giải đấu tháng',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Kinh nghiệm chơi cầu lông
                  _FeatureCard(
                    icon: Icons.sports_tennis,
                    title: 'Kinh nghiệm chơi cầu lông',
                    subtitle: 'Kỹ thuật và chiến thuật thi đấu',
                    color: Color(0xFFC44536),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoogleDocViewer(
                          url: 'https://docs.google.com/document/d/1yhI66hGoYweF7LLdVtM2QOJt8iHUEfy8/edit',
                          title: 'Kinh nghiệm chơi cầu lông',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Feature Card Widget - ĐÃ TỐI ƯU
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container - NHỎ GỌN HƠN
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
              // Arrow icon - NHỎ HƠN
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

// Google Doc Viewer Page - GIỮ NGUYÊN HOẶC CÓ THỂ TỐI ƯU NẾU CẦN
class GoogleDocViewer extends StatefulWidget {
  final String url;
  final String title;

  const GoogleDocViewer({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<GoogleDocViewer> createState() => _GoogleDocViewerState();
}

class _GoogleDocViewerState extends State<GoogleDocViewer> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF2C3E50),
        elevation: 1,
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC44536),
              ),
            ),
        ],
      ),
    );
  }
}