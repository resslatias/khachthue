import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho User Profile trong Firestore
class nguoi_thue {
  final String id;
  final String email;
  final String ten;
  final String? anh_dai_dien;
  final String? sdt;
  final DateTime? ngay_sinh;
  nguoi_thue({
    required this.id,
    required this.email,
    required this.ten,
    this.anh_dai_dien,
    this.sdt,
    this.ngay_sinh,
  });
  // Chuyển từ Map sang Object
  factory nguoi_thue.fromMap(Map<String, dynamic> map, String id) {
    return nguoi_thue(
      id: id,
      email: map['email'] ?? '',
      ten: map['ten'] ?? '',
      anh_dai_dien: map['anh_dai_dien'],
      sdt: map['sdt'],
      ngay_sinh: map['ngay_sinh'] != null
          ? (map['ngay_sinh'] as Timestamp).toDate()
          : null,
    );
  }

  // Chuyển từ Object sang Map
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'ten': ten,
      'anh_dai_dien': anh_dai_dien,
      'sdt': sdt,
      'ngay_sinh': ngay_sinh != null ? Timestamp.fromDate(ngay_sinh!) : null,
    };
  }

  // Copy with method để update
  nguoi_thue copyWith({
    String? ten,
    String? anh_dai_dien,
    String? sdt,
    DateTime? ngay_sinh,
  }) {
    return nguoi_thue(
      id: id,
      email: email,
      ten: ten ?? this.ten,
      anh_dai_dien: anh_dai_dien ?? this.anh_dai_dien,
      sdt: sdt ?? this.sdt,
      ngay_sinh: ngay_sinh ?? this.ngay_sinh,
    );
  }
}

/// Service quản lý Authentication & User Profile
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection name trong Firestore
  static const String _usersCollection = 'nguoi_thue';

  // Stream controllers
  final _authStateController = StreamController<bool>.broadcast();
  final _userProfileController = StreamController<nguoi_thue?>.broadcast();

  // Cache user profile
  nguoi_thue? _cachedProfile;

  // Public getters
  Stream<bool> get authState => _authStateController.stream;
  Stream<nguoi_thue?> get userProfileStream => _userProfileController.stream;
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  nguoi_thue? get cachedProfile => _cachedProfile;

  // Quick access properties từ cache
  String? get ten => _cachedProfile?.ten;
  String? get email => _cachedProfile?.email;
  String? get anh_dai_dien => _cachedProfile?.anh_dai_dien;
  String? get sdt => _cachedProfile?.sdt;
  DateTime? get ngay_sinh => _cachedProfile?.ngay_sinh;

  /// Khởi tạo service - Gọi trong main()
  Future<void> initialize() async {
    // Lắng nghe thay đổi auth state
    _auth.authStateChanges().listen((user) async {
      _authStateController.add(user != null);

      if (user != null) {
        // Load user profile khi đăng nhập
        await _loadUserProfile(user.uid);
      } else {
        // Clear cache khi đăng xuất
        _cachedProfile = null;
        _userProfileController.add(null);
      }
    });

    // Load profile nếu đã đăng nhập
    if (currentUser != null) {
      await _loadUserProfile(currentUser!.uid);
    }
  }

  /// Load user profile từ Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists) {
        _cachedProfile = nguoi_thue.fromMap(doc.data()!, uid);
        _userProfileController.add(_cachedProfile);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  /// ĐĂNG KÝ - Tạo tài khoản mới
  Future<nguoi_thue> signUp({
    required String email,
    required String password,
    required String name,
    String? phoneNumber,
    DateTime? dateOfBirth,
  }) async {
    try {
      // Validation
      if (email.isEmpty || password.isEmpty || name.isEmpty) {
        throw Exception('Vui lòng điền đầy đủ thông tin bắt buộc');
      }

      if (!email.contains('@')) {
        throw Exception('Email không hợp lệ');
      }

      if (password.length < 6) {
        throw Exception('Mật khẩu phải có ít nhất 6 ký tự');
      }

      // 1. Tạo tài khoản Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Không thể tạo tài khoản');

      // 2. Tạo User Profile trong Firestore
      final profile = nguoi_thue(
        uid: user.uid,
        email: email,
        name: name,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        photoUrl: null, // Sẽ update sau khi upload ảnh
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Lưu vào Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(profile.toMap());

      // 4. Update display name trong Firebase Auth
      await user.updateDisplayName(name);

      // 5. Cache và emit event
      _cachedProfile = profile;
      _userProfileController.add(profile);
      _authStateController.add(true);

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  /// ĐĂNG NHẬP
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Validation
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email và mật khẩu không được để trống');
      }

      if (!email.contains('@')) {
        throw Exception('Email không hợp lệ');
      }

      // 1. Đăng nhập Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Đăng nhập thất bại');

      // 2. Load profile từ Firestore
      await _loadUserProfile(user.uid);

      if (_cachedProfile == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      return _cachedProfile!;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  /// ĐĂNG XUẤT
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _cachedProfile = null;
      _userProfileController.add(null);
      _authStateController.add(false);
    } catch (e) {
      throw Exception('Đăng xuất thất bại: $e');
    }
  }

  /// LẤY THÔNG TIN USER PROFILE
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists) return null;

      return UserProfile.fromMap(doc.data()!, uid);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  /// CẬP NHẬT THÔNG TIN USER PROFILE
  Future<void> updateProfile({
    String? name,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? photoUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      if (_cachedProfile == null) {
        await _loadUserProfile(user.uid);
      }

      if (_cachedProfile == null) {
        throw Exception('Không tìm thấy thông tin người dùng');
      }

      // Tạo profile mới với thông tin cập nhật
      final updatedProfile = _cachedProfile!.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        photoUrl: photoUrl,
      );

      // Update Firestore
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(updatedProfile.toMap());

      // Update Firebase Auth display name nếu có
      if (name != null && name != user.displayName) {
        await user.updateDisplayName(name);
      }

      // Update cache và emit
      _cachedProfile = updatedProfile;
      _userProfileController.add(updatedProfile);
    } catch (e) {
      throw Exception('Cập nhật thất bại: $e');
    }
  }

  /// ĐỔI MẬT KHẨU
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('Chưa đăng nhập');
      }

      if (newPassword.length < 6) {
        throw Exception('Mật khẩu mới phải có ít nhất 6 ký tự');
      }

      // Xác thực lại với mật khẩu hiện tại
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Đổi mật khẩu
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Mật khẩu hiện tại không đúng');
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Đổi mật khẩu thất bại: $e');
    }
  }

  /// GỬI EMAIL RESET PASSWORD
  Future<void> resetPassword(String email) async {
    try {
      if (email.isEmpty || !email.contains('@')) {
        throw Exception('Email không hợp lệ');
      }

      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Gửi email thất bại: $e');
    }
  }

  /// XÓA TÀI KHOẢN
  Future<void> deleteAccount(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('Chưa đăng nhập');
      }

      // Xác thực lại
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Xóa data trong Firestore
      await _firestore.collection(_usersCollection).doc(user.uid).delete();

      // Xóa tài khoản Firebase Auth
      await user.delete();

      // Clear cache
      _cachedProfile = null;
      _userProfileController.add(null);
      _authStateController.add(false);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Xóa tài khoản thất bại: $e');
    }
  }

  /// KIỂM TRA EMAIL ĐÃ TỒN TẠI
  Future<bool> checkEmailExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// GỬI XÁC THỰC EMAIL
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('Chưa đăng nhập');

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw Exception('Gửi email xác thực thất bại: $e');
    }
  }

  /// RELOAD USER (để check email verified)
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  /// Handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Mật khẩu quá yếu';
      case 'email-already-in-use':
        return 'Email đã được sử dụng';
      case 'invalid-email':
        return 'Email không hợp lệ';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản';
      case 'wrong-password':
        return 'Mật khẩu không đúng';
      case 'user-disabled':
        return 'Tài khoản đã bị khóa';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập chưa được kích hoạt';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng';
      default:
        return 'Lỗi: ${e.message ?? e.code}';
    }
  }

  /// Dispose
  void dispose() {
    _authStateController.close();
    _userProfileController.close();
  }
}