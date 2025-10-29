import 'package:flutter/material.dart';

/// ORTHER PAGE — Trang tạm thời (placeholder)
class OrtherPage extends StatelessWidget {
  const OrtherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orther')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Orther Page',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Trang tạm để tránh lỗi build. Bạn có thể thay nội dung sau.'),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Mục ví dụ'),
              subtitle: const Text('Nội dung đang cập nhật'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Orther: tính năng đang phát triển')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
