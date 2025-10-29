import 'package:flutter/widgets.dart';

/// Giữ navigatorKey toàn cục để service có thể mở/đóng dialog.
class AppNavigator {
  AppNavigator._();
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static NavigatorState? get state => key.currentState;
  static BuildContext? get context => key.currentContext;
}
