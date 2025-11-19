import 'dart:io';
import 'dart:convert';
import 'dart:convert' as convert;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:crypto/crypto.dart';

class WebhookService {
  bool verifySignature(String signature, String body, String clientSecret) {
    final hmac = Hmac(sha256, utf8.encode(clientSecret));
    final digest = hmac.convert(utf8.encode(body));
    return signature == digest.toString();
  }

  Handler get handler {
    final router = Router();
    final webhookService = WebhookService();

    // Health check
    router.get('/', (Request request) {
      return Response.ok('PayOS Webhook Server - Dart');
    });

    // Webhook endpoint
    router.post('/webhook', (Request request) async {
      try {
        final body = await request.readAsString();
        final jsonData = convert.jsonDecode(body);

        // Get signature from header
        final signature = request.headers['x-payos-signature'];
        final clientSecret = Platform.environment['PAYOS_CLIENT_SECRET'] ?? '';

        // Verify signature
        if (clientSecret.isNotEmpty && signature != null) {
          final isValid = webhookService.verifySignature(
              signature, body, clientSecret
          );
          if (!isValid) {
            return Response.forbidden('Invalid signature');
          }
        }

        print('Webhook received: ${jsonData['code']} - ${jsonData['desc']}');

        // Process payment result
        if (jsonData['code'] == '00') {
          // Payment successful
          print('Payment successful for order: ${jsonData['data']['orderCode']}');
          // TODO: Update your database here
        } else {
          // Payment failed
          print('Payment failed: ${jsonData['desc']}');
        }

        return Response.ok(
          convert.jsonEncode({
            'error': 0,
            'message': 'success',
            'data': null
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('Webhook error: $e');
        return Response.internalServerError(
          body: convert.jsonEncode({
            'error': 1,
            'message': 'server_error'
          }),
        );
      }
    });

    return router;
  }
}

void main() async {
  final webhookService = WebhookService();
  final handler = webhookService.handler;

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final server = await serve(handler, InternetAddress.anyIPv4, port);

  print('Dart PayOS Webhook Server running on port ${server.port}');
}