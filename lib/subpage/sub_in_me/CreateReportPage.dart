import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =============================================
// Trang tạo đơn báo cáo
// =============================================
class CreateReportPage extends StatefulWidget {
  const CreateReportPage({super.key});

  @override
  _CreateReportPageState createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _attachmentController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingUserInfo = true;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // Hàm load thông tin user từ Firestore
  Future<void> _loadUserInfo() async {
    try {
      final userId = auth.currentUser?.uid;
      if (userId == null) {
        setState(() => _isLoadingUserInfo = false);
        return;
      }

      final userDoc = await firestore.collection('nguoi_thue').doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          // Tự động điền email nếu có
          if (userData?['email'] != null && userData!['email'].toString().isNotEmpty) {
            _emailController.text = userData['email'];
          } else if (auth.currentUser?.email != null) {
            _emailController.text = auth.currentUser!.email!;
          }

          // Tự động điền số điện thoại nếu có
          if (userData?['so_dien_thoai'] != null && userData!['so_dien_thoai'].toString().isNotEmpty) {
            _phoneController.text = userData['so_dien_thoai'];
          } else if (userData?['phone'] != null && userData!['phone'].toString().isNotEmpty) {
            _phoneController.text = userData['phone'];
          }

          _isLoadingUserInfo = false;
        });

        debugPrint('✅ Đã load thông tin user và điền vào form');
      } else {
        setState(() => _isLoadingUserInfo = false);
        debugPrint('⚠️ Không tìm thấy thông tin user');
      }
    } catch (e) {
      setState(() => _isLoadingUserInfo = false);
      debugPrint('🔥 Lỗi load thông tin user: $e');
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập');
      }

      // 1. Lưu đơn báo cáo vào collection khieu_nai -> doc nguoi_thue -> collection reports
      final reportData = {
        'id_nguoi_tao': user.uid,
        'ten_nguoi_tao': user.displayName ?? 'Người dùng',
        'sdt': _phoneController.text,
        'email': _emailController.text.isNotEmpty ? _emailController.text : null,
        'tieu_de': _titleController.text,
        'noi_dung': _contentController.text,
        'trang_thai': 'chua_su_ly',
        'ngay_tao': FieldValue.serverTimestamp(),
        'dinh_kem': _attachmentController.text.isNotEmpty ? _attachmentController.text : null,
      };

      await firestore
          .collection('khieu_nai')
          .doc('nguoi_thue')
          .collection('reports')
          .add(reportData);

      // 2. Tạo thông báo cho người dùng
      await firestore
          .collection('thong_bao')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'tieu_de': 'Đơn báo cáo đã được gửi',
        'noi_dung': 'Đơn báo cáo "${_titleController.text}" của bạn đã được tiếp nhận. Chúng tôi sẽ liên hệ với bạn trong thời gian sớm nhất.',
        'da_xem_chua': false,
        'Urlweb': '',
        'Urlimage': '',
        'ngay_tao': FieldValue.serverTimestamp(),
        'loai_thong_bao': 'bao_cao',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Đơn báo cáo đã được gửi thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF2E8B57),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gửi đơn báo cáo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingUserInfo
          ? Center(child: CircularProgressIndicator(color: Color(0xFFC44536)))
          : _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFC44536)))
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông báo quan trọng
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF3498DB), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF3498DB), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Thông báo quan trọng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3498DB),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Hãy báo cáo việc bạn cần xử lý với chúng tôi. Lưu ý bạn phải tự chịu trách nhiệm với thông tin bạn cung cấp. Bạn có thể thu thập bằng chứng thông tin liên quan và gửi đường dẫn cho chúng tôi qua mục đính kèm. Chúng tôi sẽ liên hệ để xử lý cho bạn.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2C3E50),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Tiêu đề
              Text(
                'Tiêu đề *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Nhập tiêu đề báo cáo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Nội dung
              Text(
                'Nội dung *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Mô tả chi tiết vấn đề cần báo cáo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập nội dung';
                  }
                  if (value.length < 10) {
                    return 'Nội dung quá ngắn (ít nhất 10 ký tự)';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Số điện thoại
              Text(
                'Số điện thoại *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Nhập số điện thoại liên hệ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _phoneController.text.isNotEmpty
                      ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  // Kiểm tra số điện thoại Việt Nam
                  final phoneRegex = RegExp(r'^(0|\+84)(\d{9,10})$');
                  if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
                    return 'Số điện thoại không hợp lệ';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Email
              Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Nhập email (không bắt buộc)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _emailController.text.isNotEmpty
                      ? Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : null,
                ),
              ),
              SizedBox(height: 16),

              // Đính kèm
              Text(
                'Đính kèm',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _attachmentController,
                decoration: InputDecoration(
                  hintText: 'Dán đường dẫn hình ảnh/tài liệu (nếu có)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bạn có thể đính kèm link hình ảnh, file từ Google Drive, Dropbox...',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              SizedBox(height: 32),

              // Nút gửi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'GỬI ĐƠN BÁO CÁO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }
}