import 'package:flutter/material.dart';

/// BEFOR PAGE — Trang tạm thời (placeholder)
class BeforPage extends StatelessWidget {
  const BeforPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Befor')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Befor Page\n(Nội dung đang cập nhật)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Befor: tính năng đang phát triển')),
                );
              },
              child: const Text('Thử nút'),
            ),
          ],
        ),
      ),
    );
  }
}
