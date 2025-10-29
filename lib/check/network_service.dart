import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'app_navigator.dart';

/// Service kiểm tra mạng và tự hiển thị/ẩn dialog mất mạng.
/// - Không cần UI gọi show/hide nữa.
/// - Vẫn expose onChanged để nơi khác nghe nếu muốn.
class NetworkService {
  NetworkService._();
  static final NetworkService instance = NetworkService._();

  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<InternetStatus>? _sub;
  bool _started = false;

  // Trạng thái dialog nội bộ
  bool _dialogShown = false;

  // Public stream: true = có mạng, false = mất mạng
  Stream<bool> get onChanged => _controller.stream;

  Future<bool> isConnected() => InternetConnection().hasInternetAccess;

  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;

    // Bắn trạng thái ban đầu
    final ok = await isConnected();
    _controller.add(ok);
    _updateDialog(ok);

    // Lắng nghe thay đổi
    _sub = InternetConnection().onStatusChange.listen((status) {
      final hasNet = status == InternetStatus.connected;
      _controller.add(hasNet);
      _updateDialog(hasNet);
    });
  }

  // ------- UI handling (dùng navigatorKey toàn cục) -------
  void _updateDialog(bool hasNet) {
    if (hasNet) {
      _hideOfflineDialog();
    } else {
      _showOfflineDialog();
    }
  }

  void _showOfflineDialog() {
    if (_dialogShown) return;
    final ctx = AppNavigator.context;
    if (ctx == null) return; // app chưa mount

    _dialogShown = true;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const AlertDialog(
        title: Text('Mất kết nối mạng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vui lòng kiểm tra Wi-Fi/4G. Ứng dụng sẽ tự tiếp tục khi có mạng.'),
            SizedBox(height: 12),
            LinearProgressIndicator(),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8, bottom: 6),
            child: Text('Đang thử kết nối lại...', style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _hideOfflineDialog() {
    if (!_dialogShown) return;
    final nav = AppNavigator.state;
    if (nav == null) return;

    // Đóng dialog nếu còn trên stack
    if (nav.canPop()) {
      nav.pop();
    }
    _dialogShown = false;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
    _started = false;
    _dialogShown = false;
  }
}
