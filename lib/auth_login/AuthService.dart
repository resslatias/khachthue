import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String usersCol = 'nguoi_thue';
  String? _lastError;
  String? get lastError => _lastError;

  /// ====== YÊU CẦU 1: Kiểm tra đăng nhập (true/false)
  Future<bool> isLoggedInOnce() async {
    final user = await _auth.authStateChanges().first;
    return user != null;
  }

  /// ====== YÊU CẦU 2: Lấy thông tin người dùng hiện tại (Map data)
  Future<Map<String, dynamic>?> currentUserData() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final snap = await _db.collection(usersCol).doc(u.uid).get();
    return snap.data();
  }

  /// ====== YÊU CẦU 3: Đăng nhập (true nếu thành công)
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _lastError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastError = _mapAuthError(e);
      return false;
    } catch (_) {
      _lastError = 'Có lỗi không xác định khi đăng nhập';
      return false;
    }
  }

  /// ====== YÊU CẦU 4: Đăng ký (true nếu thành công)
  Future<bool> signUp({
    required String hoTen,
    required String email,
    required String password,
    String? soDienThoai,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(hoTen.trim());
      // tạo/đảm bảo hồ sơ Firestore
      final uid = cred.user!.uid;
      final ref = _db.collection(usersCol).doc(uid);
      await ref.set({
        'ho_ten': hoTen.trim(),
        'email': email.trim(),
        'so_dien_thoai': (soDienThoai ?? '').trim(),
        'so_don_cho':0,
        'so_don_huy':0,
        'ngay_sinh': null,
        'anh_dai_dien':null,
      }, SetOptions(merge: true));
      // >>> THÊM THÔNG BÁO CHO NGƯỜI DÙNG VỪA ĐĂNG KÝ <<<
      await _db.collection('thong_bao').add({
        'tieu_de'    : 'Chào mừng bạn!',
        'noi_dung'   : 'Tài khoản của bạn đã được tạo thành công.',
        'nguoi_nhan' : uid,
        'da_xem_chua': false,
        'ngay_tao'   : FieldValue.serverTimestamp()
      });
      // không bắt buộc, có thể lỗi nhưng không ảnh hưởng kết quả
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {}
      _lastError = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _lastError = _mapAuthError(e);
      return false;
    } catch (_) {
      _lastError = 'Có lỗi không xác định khi đăng ký';
      return false;
    }
  }
  /// ====== YÊU CẦU 5: Quên mật khẩu (không trả gì)
  Future<void> sendResetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _lastError = null;
    } on FirebaseAuthException catch (e) {
      _lastError = _mapAuthError(e);
      // vẫn không throw; UI chỉ cần đọc lastError để biết có lỗi hay không
    } catch (_) {
      _lastError = 'Không thể gửi email đặt lại mật khẩu';
    }
  }


  /// Tiện ích thêm: đăng xuất
  Future<void> signOut() => _auth.signOut();


  /// ====== Helper: map lỗi FirebaseAuth -> tiếng Việt
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-disabled':
        return 'Tài khoản đã bị khóa';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'too-many-requests':
        return 'Thao tác quá nhiều lần, thử lại sau';
      case 'network-request-failed':
        return 'Mất kết nối mạng';
      default:
        return 'Lỗi không xác định (${e.code})';
    }
  }
}
