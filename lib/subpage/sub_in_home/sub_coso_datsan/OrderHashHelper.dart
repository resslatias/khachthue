import 'dart:convert';
import 'package:crypto/crypto.dart';

/// HASH HELPER - Tạo hash ngắn gọn cho đơn hàng

class OrderHashHelper {

  /// Tạo hash 8 ký tự từ userId + maDon
  /// VD: "7IfqjFkZ" + "CJRFje1J" -> "A7F3E9B2"

  static String generateHash(String userId, String maDon) {
    // Kết hợp userId và maDon
    final combined = '$userId-$maDon';

    // Tạo MD5 hash
    final bytes = utf8.encode(combined);
    final digest = md5.convert(bytes);

    // Lấy 8 ký tự đầu (viết hoa)
    final hash = digest.toString().substring(0, 8).toUpperCase();

    return hash;
  }

  /// Format addInfo cho QR code
  /// Output: "PAY{hash}" - VD: "PAYA7F3E9B2"

  static String formatAddInfo(String hash) {
    return 'PAY$hash';
  }

  /// Parse addInfo từ nội dung chuyển khoản
  /// Input: "...PAYA7F3E9B2..."
  /// Output: "A7F3E9B2"

  static String? parseAddInfo(String content) {
    final pattern = RegExp(r'PAY([A-F0-9]{8})', caseSensitive: false);
    final match = pattern.firstMatch(content);
    return match?.group(1)?.toUpperCase();
  }
}