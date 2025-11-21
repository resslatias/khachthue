import 'package:flutter/material.dart';

/// TOGETHER PAGE – Trang tìm người chơi cùng
class TogetherPage extends StatelessWidget {
  const TogetherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tìm người chơi cùng',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Color(0xFF3498DB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Color(0xFF3498DB).withOpacity(0.5),
              ),
              SizedBox(height: 24),
              Text(
                'Tính năng đang phát triển',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Chức năng tìm người chơi cùng sẽ sớm được ra mắt',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}