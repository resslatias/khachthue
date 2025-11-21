import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// PayOS Service - Tích hợp PayOS API
class PayOSService {
  static const String _baseUrl = 'https://api-merchant.payos.vn';

  /// Tạo payment link từ PayOS
  static Future<Map<String, dynamic>?> createPaymentLink({
    required Map<String, dynamic> coSoData,
    required int amount, // so tiền thanh toán
    required String description,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {

      final clientId = coSoData['client_Id'] as String?;
      final apiKey = coSoData['api_Key'] as String?;
      final checksumKey = coSoData['checksum_Key'] as String?;

      if (clientId == null || apiKey == null || checksumKey == null) {
        print('🔥 Thiếu API keys: clientId=$clientId, apiKey=$apiKey, checksumKey=$checksumKey');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final orderCode = timestamp % 9999999999; // Tăng range để tránh trùng

      //  Tạo expiredAt đúng định dạng (timestamp seconds)
      final expiredAt = (DateTime.now().add(Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000);

      //  Tạo data cho signature (KHÔNG bao gồm expiredAt và items)
      final signatureData = {
        'amount': amount,
        'cancelUrl': cancelUrl ?? 'myapp://payment-cancel',// khi hủy đơn hàng
        'description': description.length > 25 ? description.substring(0, 25) : description,
        'orderCode': orderCode,
        'returnUrl': returnUrl ?? 'myapp://payment-success', // thành công
      };

      //  Tạo signature
      final signature = _createSignature(signatureData, checksumKey);

      //  Tạo request body đầy đủ (có expiredAt, items, signature)
      final requestBody = {
        'orderCode': orderCode, // mã đơn hàng
        'amount': amount, // sô tiền thanh toán
        'description': signatureData['description'], // mo tả
        'items': [
          {
            'name': description.length > 50 ? description.substring(0, 50) : description,
            'quantity': 1,
            'price': amount
          }
        ],
        'returnUrl': signatureData['returnUrl'],
        'cancelUrl': signatureData['cancelUrl'],
        'expiredAt': expiredAt,
        'signature': signature,
        //'webhookUrl': 'https://kl10.resslatias.workers.dev/',
      };

      print('📦 Request to PayOS:');
      print('   - orderCode: $orderCode');
      print('   - amount: $amount');
      print('   - expiredAt: $expiredAt (${DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000)})');
      print('   - signature: $signature');

      final response = await http.post(
        Uri.parse('$_baseUrl/v2/payment-requests'),
        headers: {
          'x-client-id': clientId,
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📨 PayOS Response: ${response.statusCode}');
      print('📨 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == '00' || data['error'] == 0) {
          print('✅ Tạo payment link thành công');

          // ✅ Trả về data gốc, QR string sẽ được xử lý ở UI
          final responseData = data['data'];
          print('📱 QR Code String: ${responseData['qrCode']}');

          return responseData;
        } else {
          print('🔥 PayOS API error: ${data['message'] ?? data['desc']}');
          return null;
        }
      } else {
        print('🔥 HTTP Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('🔥 Exception khi tạo payment link: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// ✅ Tạo chữ ký cho request - ĐÚNG THEO TÀI LIỆU PAYOS
  static String _createSignature(Map<String, dynamic> data, String checksumKey) {
    try {
      //  PayOS yêu cầu format chính xác: amount&cancelUrl&description&orderCode&returnUrl
      // Theo thứ tự alphabet: amount, cancelUrl, description, orderCode, returnUrl

      final amount = data['amount'].toString();
      final cancelUrl = data['cancelUrl'] ?? '';
      final description = data['description'] ?? '';
      final orderCode = data['orderCode'].toString();
      final returnUrl = data['returnUrl'] ?? '';

      // Tạo chuỗi theo format chính xác của PayOS (KHÔNG có expiredAt)
      final signatureString = 'amount=$amount&cancelUrl=$cancelUrl&description=$description&orderCode=$orderCode&returnUrl=$returnUrl';

      print('🔐 Signature string: $signatureString');

      // Tạo HMAC SHA256 signature
      final hmac = Hmac(sha256, utf8.encode(checksumKey));
      final digest = hmac.convert(utf8.encode(signatureString));

      final signature = digest.toString();
      print('🔐 Generated signature: $signature');

      return signature;
    } catch (e) {
      print('🔥 Lỗi tạo signature: $e');
      rethrow;
    }
  }
}