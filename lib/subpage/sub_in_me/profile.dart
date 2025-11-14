import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// =============================================
// Trang hiển thị thông tin cá nhân
// =============================================
class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header với nút back
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(width: 8),
              Icon(Icons.person, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                'Thông tin cá nhân',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('nguoi_thue')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Color(0xFFC44536)));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
                      SizedBox(height: 16),
                      Text(
                        'Lỗi: ${snapshot.error}',
                        style: TextStyle(color: Color(0xFF7F8C8D)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off, size: 60, color: Color(0xFFBDC3C7)),
                      SizedBox(height: 16),
                      Text(
                        'Không tìm thấy thông tin người dùng',
                        style: TextStyle(color: Color(0xFF7F8C8D)),
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              return _UserProfileContent(userId: widget.userId, userData: data);
            },
          ),
        ),
      ],
    );
  }
}

// =============================================
// Nội dung hiển thị thông tin
// =============================================
class _UserProfileContent extends StatelessWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const _UserProfileContent({
    required this.userId,
    required this.userData,
  });

  void _showEditProfileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,

      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9, // Giới hạn 90% màn hình
        child: EditProfileDialog(
          userId: userId,
          userData: userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = userData['anh_dai_dien'] as String? ?? '';
    final email = userData['email'] as String? ?? '';
    final gioiTinh = userData['gioi_tinh'] as String? ?? '';
    final hoTen = userData['ho_ten'] as String? ?? '';
    final ngaySinh = userData['ngay_sinh'] as String? ?? '';
    final soDienThoai = userData['so_dien_thoai'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Ảnh đại diện - HÌNH CHỮ NHẬT BO GÓC
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
              )
                  : _buildPlaceholderImage(),
            ),
          ),
          const SizedBox(height: 24),

          // Thông tin trong card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.person, label: 'Họ tên', value: hoTen),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.email, label: 'Email', value: email),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.phone, label: 'Số điện thoại', value: soDienThoai),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.wc, label: 'Giới tính', value: gioiTinh),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.cake, label: 'Ngày sinh', value: ngaySinh),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Nút chỉnh sửa
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showEditProfileDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFC44536),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                'Chỉnh sửa thông tin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Color(0xFFECF0F1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 50,
          color: Color(0xFFBDC3C7),
        ),
      ),
    );
  }
}

// =============================================
// Hàng thông tin
// =============================================
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFFC44536).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Color(0xFFC44536),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value.isEmpty ? 'Chưa cập nhật' : value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================
// Dialog chỉnh sửa thông tin (Bottom Sheet) - PHIÊN BẢN ĐẦU TIÊN
// =============================================
class EditProfileDialog extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const EditProfileDialog({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hoTenController;
  late TextEditingController _soDienThoaiController;
  late TextEditingController _ngaySinhController;
  String _gioiTinh = '';
  bool _isLoading = false;
  File? _imageFile;
  String _avatarUrl = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _resetData();
  }

  void _resetData() {
    _hoTenController = TextEditingController(text: widget.userData['ho_ten'] ?? '');
    _soDienThoaiController = TextEditingController(text: widget.userData['so_dien_thoai'] ?? '');
    _ngaySinhController = TextEditingController(text: widget.userData['ngay_sinh'] ?? '');
    _avatarUrl = widget.userData['anh_dai_dien'] as String? ?? '';

    final gioiTinhData = widget.userData['gioi_tinh'] as String? ?? '';
    if (['Nam', 'Nữ', 'Khác'].contains(gioiTinhData)) {
      _gioiTinh = gioiTinhData;
    } else {
      _gioiTinh = 'Nam';
    }
    _imageFile = null;
  }

  @override
  void dispose() {
    _hoTenController.dispose();
    _soDienThoaiController.dispose();
    _ngaySinhController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn ảnh: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _avatarUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars/${widget.userId}');

      final uploadTask = await storageRef.putFile(_imageFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi upload ảnh: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? finalAvatarUrl = _avatarUrl;
      if (_imageFile != null) {
        finalAvatarUrl = await _uploadImage();
        if (finalAvatarUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('nguoi_thue')
          .doc(widget.userId)
          .update({
        'ho_ten': _hoTenController.text.trim(),
        'so_dien_thoai': _soDienThoaiController.text.trim(),
        'ngay_sinh': _ngaySinhController.text.trim(),
        'gioi_tinh': _gioiTinh,
        'anh_dai_dien': finalAvatarUrl ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thông tin thành công'),
            backgroundColor: Color(0xFF2E8B57),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _closeDialog() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header với nút đóng
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chỉnh sửa thông tin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: _closeDialog,
                ),
              ],
            ),
          ),
          // Phần nội dung có thể scroll
          Expanded( // Thêm Expanded ở đây
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar với nút chọn ảnh
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFC44536),
                                  Color(0xFFE74C3C),
                                ],
                              ),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!)
                                    : (_avatarUrl.isNotEmpty
                                    ? NetworkImage(_avatarUrl)
                                    : null) as ImageProvider?,
                                child: _imageFile == null && _avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFC44536),
                                    Color(0xFFE74C3C),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text('Chọn ảnh từ thiết bị'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Form fields
                    TextFormField(
                      controller: _hoTenController,
                      decoration: InputDecoration(
                        labelText: 'Họ tên',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập họ tên';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _soDienThoaiController,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _gioiTinh,
                      decoration: InputDecoration(
                        labelText: 'Giới tính',
                        prefixIcon: Icon(Icons.wc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                        DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                        DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                      ],
                      onChanged: (value) {
                        setState(() => _gioiTinh = value ?? 'Nam');
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng chọn giới tính';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _ngaySinhController,
                      decoration: InputDecoration(
                        labelText: 'Ngày sinh (dd/mm/yyyy)',
                        prefixIcon: Icon(Icons.cake),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập ngày sinh';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Nút hành động
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _closeDialog,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text('Lưu thay đổi'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16), // Thêm padding bottom an toàn
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}