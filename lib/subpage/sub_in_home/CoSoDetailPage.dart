import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sub_coso_datsan/TrangThaiSan.dart';

class CoSoDetailPage extends StatefulWidget {
  final String coSoId;
  final Map<String, dynamic> coSoData;

  const CoSoDetailPage({
    super.key,
    required this.coSoId,
    required this.coSoData,
  });

  @override
  State<CoSoDetailPage> createState() => _CoSoDetailPageState();
}

class _CoSoDetailPageState extends State<CoSoDetailPage> {
  bool _isFavorite = false;
  bool _isLoadingFav = true;
  List<int> _processedBangGia = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateAndProcessData();
    });
  }

  Future<void> _validateAndProcessData() async {
    // Kiểm tra cơ sở tồn tại
    if (widget.coSoData.isEmpty) {
      _showErrorDialog('Cơ sở không tồn tại', 'Không tìm thấy thông tin cơ sở này.');
      return;
    }

    // Kiểm tra bảng giá
    final giaSan = widget.coSoData['gia_san'] as List<dynamic>?;
    final bangGia = widget.coSoData['bang_gia'] as List<dynamic>?;

    // Nếu cả 2 đều null/rỗng
    if ((giaSan == null || giaSan.isEmpty) && (bangGia == null || bangGia.isEmpty)) {
      _showErrorDialog('Thiếu thông tin giá', 'Cơ sở chưa cập nhật bảng giá.');
      return;
    }

    // Nếu có gia_san → tạo bang_gia từ gia_san
    if (giaSan != null && giaSan.isNotEmpty) {
      _processedBangGia = _createBangGiaFromGiaSan(giaSan);
    }
    // Nếu chỉ có bang_gia → validate bang_gia
    else if (bangGia != null && bangGia.isNotEmpty) {
      if (!_validateBangGia(bangGia)) {
        _showErrorDialog('Bảng giá không hợp lệ', 'Bảng giá phải có đủ 24 giá trị hợp lệ (> 0).');
        return;
      }
      _processedBangGia = bangGia.map((e) => (e is int ? e : (e as num).toInt())).toList();
    }

    // Nếu validate thành công → load favorite status
    _checkFavoriteStatus();
  }

  List<int> _createBangGiaFromGiaSan(List<dynamic> giaSan) {
    List<int> bangGia = List.filled(24, 10000); // Mặc định 10000đ

    for (var item in giaSan) {
      if (item is! Map<String, dynamic>) continue;

      final gio = item['gio'] as String?;
      final gia = item['gia'];

      if (gio == null || gio.isEmpty || gia == null) continue;

      // Parse giờ từ "19:00 - 20:00" → lấy 19
      final gioBatDau = _parseGioBatDau(gio);
      if (gioBatDau == null || gioBatDau < 0 || gioBatDau >= 24) continue;

      final giaInt = gia is int ? gia : (gia as num).toInt();
      bangGia[gioBatDau] = giaInt;
    }

    return bangGia;
  }

  int? _parseGioBatDau(String gioStr) {
    try {
      // "19:00 - 20:00" → "19:00" → 19
      final parts = gioStr.split('-');
      if (parts.isEmpty) return null;

      final gioBatDau = parts[0].trim().split(':');
      if (gioBatDau.isEmpty) return null;

      return int.tryParse(gioBatDau[0]);
    } catch (e) {
      return null;
    }
  }

  bool _validateBangGia(List<dynamic> bangGia) {
    if (bangGia.length != 24) return false;

    for (var gia in bangGia) {
      if (gia == null) return false;

      final giaInt = gia is int ? gia : (gia is num ? (gia as num).toInt() : null);
      if (giaInt == null || giaInt < 1) return false;
    }

    return true;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Color(0xFFC44536)),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC44536),
              foregroundColor: Colors.white,
            ),
            child: Text('Quay lại'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingFav = false);
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('san_ua_thich')
          .doc(user.uid)
          .collection('co_so')
          .doc(widget.coSoId)
          .get();

      setState(() {
        _isFavorite = docSnapshot.exists;
        _isLoadingFav = false;
      });
    } catch (e) {
      setState(() => _isLoadingFav = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Vui lòng đăng nhập để sử dụng tính năng này');
      return;
    }

    try {
      final docRef = FirebaseFirestore.instance
          .collection('san_ua_thich')
          .doc(user.uid)
          .collection('co_so')
          .doc(widget.coSoId);

      if (_isFavorite) {
        await docRef.delete();
        setState(() => _isFavorite = false);
        _showMessage('Đã xóa khỏi danh sách yêu thích');
      } else {
        await docRef.set({
          'co_so_id': widget.coSoId,
          'added_at': Timestamp.now(),
        });
        setState(() => _isFavorite = true);
        _showMessage('Đã thêm vào danh sách yêu thích');
      }
    } catch (e) {
      _showMessage('Lỗi: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    final viTri = widget.coSoData['vi_tri'] as GeoPoint?;

    double? latitude;
    double? longitude;

    if (viTri != null) {
      latitude = viTri.latitude;
      longitude = viTri.longitude;
    }

    if (latitude == null || longitude == null) {
      _showMessage('Không có thông tin tọa độ');
      return;
    }

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Không thể mở Google Maps');
    }
  }

  Future<void> _openWebsite(String webUrl) async {
    if (webUrl.isEmpty) return;

    String url = webUrl;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Không thể mở website');
    }
  }

  Future<void> _openZaloGroup(String zaloUrl) async {
    if (zaloUrl.isEmpty) return;

    final uri = Uri.parse(zaloUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Không thể mở nhóm Zalo');
    }
  }

  void _showReviewDialog() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Hãy đăng nhập trước');
      return;
    }

    try {

      // Kiểm tra xem user đã đặt sân tại cơ sở này chưa
      final snapshot = await FirebaseFirestore.instance
          .collection('lich_su_khach')
          .doc(user.uid)
          .collection('don_dat')
          .where('co_so_id', isEqualTo: widget.coSoId)
          .where('trang_thai', isEqualTo: 'da_thanh_toan')
          .limit(1)
          .get();


      if (snapshot.docs.isEmpty) {
        // Chưa từng đặt sân tại cơ sở này
        _showMessage('Bạn cần đặt sân tại cơ sở này trước khi đánh giá');
        return;
      }

      //  Đã đặt sân -> Hiển thị dialog đánh giá
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => ReviewDialog(
            coSoId: widget.coSoId,
            coSoName: widget.coSoData['ten'] as String? ?? 'Cơ sở', // SỬA LẠI CHO ĐÚNG
            userId: user.uid,
          ),
        );
      }
    } catch (e) {
      // Đóng loading dialog nếu có lỗi - ĐẢM BẢO LUÔN ĐÓNG KHI CÓ LỖI
      if (mounted) Navigator.of(context).pop();
      _showMessage('Lỗi kiểm tra lịch sử: $e');
    }
  }

  String? _getLogoImage() {
    return widget.coSoData['anh_dai_dien'] as String?;
  }

  String? _getCoverImage() {
    final danhSachAnh = widget.coSoData['danh_sach_anh'] as List<dynamic>?;
    if (danhSachAnh != null && danhSachAnh.isNotEmpty) {
      final firstImage = danhSachAnh[0] as String?;
      if (firstImage != null && firstImage.isNotEmpty) {
        return firstImage;
      }
    }
    return null;
  }

  List<String> _getGalleryImages() {
    final images = <String>[];
    final danhSachAnh = widget.coSoData['danh_sach_anh'] as List<dynamic>?;

    if (danhSachAnh != null && danhSachAnh.length > 1) {
      for (int i = 1; i < danhSachAnh.length; i++) {
        final img = danhSachAnh[i] as String?;
        if (img != null && img.isNotEmpty) {
          images.add(img);
        }
      }
    }

    return images;
  }

  void _showPriceBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPriceBottomSheet(),
    );
  }

  void _showServicesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildServicesBottomSheet(),
    );
  }

  void _showReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReviewsBottomSheet(),
    );
  }

  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image, size: 60, color: Colors.white),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFECF0F1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xFF2C3E50)),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Text(
                  'Bảng giá',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: _buildPriceTables(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFECF0F1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xFF2C3E50)),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Text(
                  'Dịch vụ khác',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildServicesContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFECF0F1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xFF2C3E50)),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Các đánh giá',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                // thêm đánh giá
                ElevatedButton.icon(
                  onPressed: _showReviewDialog,
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Viết đánh giá'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC44536),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildReviewsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesContent() {
    final dichVuKhac = widget.coSoData['dich_vu_khac'] as List<dynamic>?;

    if (dichVuKhac == null || dichVuKhac.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chưa có thông tin dịch vụ khác',
            style: TextStyle(color: Color(0xFF7F8C8D)),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: dichVuKhac.length,
      itemBuilder: (context, index) {
        final dichVu = dichVuKhac[index] as Map<String, dynamic>;
        final ten = dichVu['ten'] as String? ?? '';
        final gia = dichVu['gia'];

        if (ten.isEmpty || gia == null) return SizedBox.shrink();

        final giaInt = gia is int ? gia : (gia as num).toInt();

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFFECF0F1)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.room_service, color: Color(0xFFC44536), size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ten,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(giaInt)}đ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC44536),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('danh_gia')
          .doc(widget.coSoId)
          .collection('reviews')
          .orderBy('createAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFC44536)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Chưa có đánh giá nào',
              style: TextStyle(color: Color(0xFF7F8C8D)),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final review = doc.data() as Map<String, dynamic>;
            return _buildReviewCard(review);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ten = widget.coSoData['ten'] as String? ?? 'Chi tiết cơ sở';
    final logoImage = _getLogoImage();
    final coverImage = _getCoverImage();
    final galleryImages = _getGalleryImages();

    return Scaffold(
      backgroundColor: Color(0xFFECF0F1),
      body: Column(
        children: [
          // HEADER CUSTOM VỚI CÁC NÚT TRÊN CÙNG
          Container(
            //height: kToolbarHeight + MediaQuery.of(context).padding.top,
            padding: EdgeInsets.only(
              top: 10,
              left: 8,
              right: 8,
              bottom: 8,
            ),
            color: Colors.white,
            child: Row(
              children: [
                // Nút back
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                  onPressed: () => Navigator.pop(context),
                ),
                // Tiêu đề
                Expanded(
                  child: Text(
                    ten,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Nút yêu thích
                Container(
                  width: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoadingFav ? null : _toggleFavorite,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isFavorite ? Color(0xFFC44536).withOpacity(0.1) : Color(0xFFECF0F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isFavorite ? Color(0xFFC44536) : Color(0xFFBDC3C7),
                                ),
                              ),
                              child: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Color(0xFFC44536) : Color(0xFF2C3E50),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Yêu thích',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8),

                // Nút đặt lịch
                Container(
                  width: 50,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TrangThaiSan(
                                    coSoId: widget.coSoId,
                                    coSoData: widget.coSoData,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFECF0F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFBDC3C7)),
                              ),
                              child: Icon(Icons.calendar_today, size: 18, color: Color(0xFF2C3E50)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Đặt lịch',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // NỘI DUNG CHÍNH
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Ảnh bìa và logo (ĐÃ BỎ CÁC NÚT Ở ĐÂY)
                  _buildCoverSection(ten, logoImage, coverImage),

                  // Gallery
                  if (galleryImages.isNotEmpty)
                    _buildGallerySection(galleryImages),

                  // Thông tin cơ bản
                  _buildBasicInfoSection(),

                  // Khoảng cách cuối để không bị che bởi bottom bar
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom bar cố định
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showPriceBottomSheet,
              icon: Icon(Icons.attach_money, size: 18),
              label: Text('Bảng giá', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFC44536),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showServicesBottomSheet,
              icon: Icon(Icons.room_service, size: 18),
              label: Text('Dịch vụ', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF2C3E50),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Color(0xFFBDC3C7)),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showReviewsBottomSheet,
              icon: Icon(Icons.comment, size: 18),
              label: Text('Đánh giá', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF2C3E50),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Color(0xFFBDC3C7)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection(String ten, String? logoImage, String? coverImage) {
    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Ảnh bìa
          GestureDetector(
            onTap: coverImage != null ? () => _showImageFullScreen(coverImage!) : null,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFFBDC3C7),
              ),
              child: coverImage != null
                  ? Image.network(
                coverImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 40),
              )
                  : Icon(Icons.photo, size: 40, color: Colors.white),
            ),
          ),

          // Logo và thông tin
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                GestureDetector(
                  onTap: logoImage != null ? () => _showImageFullScreen(logoImage!) : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: logoImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        logoImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.business, size: 40),
                      ),
                    )
                        : Icon(Icons.business, size: 40, color: Color(0xFFC44536)),
                  ),
                ),

                // Thông tin và địa chỉ với nút chỉ đường
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ten,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      SizedBox(height: 8),

                      // Địa chỉ và nút chỉ đường
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFECF0F1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Color(0xFF7F8C8D)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.coSoData['dia_chi_chi_tiet'] ?? ''}, ${widget.coSoData['xa'] ?? ''}, ${widget.coSoData['huyen'] ?? ''}, ${widget.coSoData['tinh'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              width: 32,
                              height: 32,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _openGoogleMaps,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFC44536),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.navigation, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection(List<String> galleryImages) {
    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hình ảnh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: galleryImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showImageFullScreen(galleryImages[index]),
                  child: Container(
                    width: 120,
                    height: 120,
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Color(0xFFBDC3C7),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        galleryImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 30),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final data = widget.coSoData;
    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 12),
          _buildInfoRow(
            Icons.location_on,
            'Địa chỉ',
            '${data['dia_chi_chi_tiet']}, ${data['xa']}, ${data['huyen']}, ${data['tinh']}',
          ),
          _buildInfoRow(Icons.phone, 'Số điện thoại', data['sdt'] as String? ?? ''),
          _buildInfoRow(
            Icons.access_time,
            'Giờ mở cửa',
            '${data['gio_mo_cua']} - ${data['gio_dong_cua']}',
          ),

          // Website button
          if ((data['web'] as String?)?.isNotEmpty == true)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _openWebsite(data['web'] as String),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(0xFFC44536).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.language, size: 16, color: Color(0xFFC44536)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Website',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7F8C8D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFFC44536).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFC44536).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    data['web'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFC44536),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.open_in_new, size: 16, color: Color(0xFFC44536)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Nhóm Zalo buttons
          _buildZaloGroupsSection(),

          SizedBox(height: 8),
          Divider(color: Color(0xFFECF0F1)),
          SizedBox(height: 8),

          Text(
            'Mô tả',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 4),
          Text(
            data['mo_ta'] as String? ?? 'Chưa có mô tả',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZaloGroupsSection() {
    final nhomSeVe = widget.coSoData['nhom_xe_ve'];
    List<String> zaloGroups = [];

    if (nhomSeVe is List) {
      zaloGroups = nhomSeVe
          .where((item) => item is String && item.isNotEmpty)
          .map((item) => item as String)
          .toList();
    } else if (nhomSeVe is String && nhomSeVe.isNotEmpty) {
      zaloGroups = [nhomSeVe];
    }

    if (zaloGroups.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFFC44536).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.group, size: 16, color: Color(0xFFC44536)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhóm Zalo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: zaloGroups.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return InkWell(
                      onTap: () => _openZaloGroup(url),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Color(0xFF0068FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF0068FF).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, size: 16, color: Color(0xFF0068FF)),
                            SizedBox(width: 6),
                            Text(
                              'Nhóm ${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0068FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new, size: 14, color: Color(0xFF0068FF)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFFC44536).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Color(0xFFC44536)),
          ),
          SizedBox(width: 12),
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
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTables() {
    final giaSan = widget.coSoData['gia_san'] as List<dynamic>?;

    // Nếu có gia_san, hiển thị chi tiết
    if (giaSan != null && giaSan.isNotEmpty) {
      return Column(
        children: [
          //_buildGiaSanTable(giaSan),
          //SizedBox(height: 16),
          _buildBangGiaTable(_processedBangGia),
        ],
      );
    }

    // Nếu không có gia_san, chỉ hiển thị bang_gia
    return _buildBangGiaTable(_processedBangGia);
  }

  Widget _buildGiaSanTable(List<dynamic> giaSan) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bảng giá chi tiết',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 12),
          ...giaSan.map((item) {
            final map = item as Map<String, dynamic>;
            final gio = map['gio'] as String? ?? '';
            final gia = map['gia'];

            if (gio.isEmpty || gia == null) {
              return SizedBox.shrink();
            }

            final price = gia is int ? gia : (gia as num).toInt();

            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Color(0xFFC44536),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gio,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Text(
                    '${_formatCurrency(price)}đ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC44536),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBangGiaTable(List<int> bangGia) {
    final gioMoCua = widget.coSoData['gio_mo_cua'] as String?;
    final gioDongCua = widget.coSoData['gio_dong_cua'] as String?;

    if (gioMoCua == null || gioDongCua == null) {
      return SizedBox.shrink();
    }

    final gioMo = int.tryParse(gioMoCua.split(':')[0]) ?? 6;
    final gioDong = int.tryParse(gioDongCua.split(':')[0]) ?? 22;

    List<Map<String, dynamic>> morningPrices = [];
    List<Map<String, dynamic>> afternoonPrices = [];
    List<Map<String, dynamic>> nightPrices = [];

    for (int i = gioMo; i < gioDong && i < bangGia.length; i++) {
      final priceData = {
        'time': '${i}h - ${i + 1}h',
        'price': bangGia[i],
      };

      if (i < 12) {
        morningPrices.add(priceData);
      } else if (i < 18) {
        afternoonPrices.add(priceData);
      } else {
        nightPrices.add(priceData);
      }
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bảng giá theo giờ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),

          if (morningPrices.isNotEmpty) ...[
            _buildPriceSection(
              title: 'Buổi sáng',
              icon: Icons.wb_sunny,
              prices: morningPrices,
            ),
            if (afternoonPrices.isNotEmpty || nightPrices.isNotEmpty)
              SizedBox(height: 12),
          ],

          if (afternoonPrices.isNotEmpty) ...[
            _buildPriceSection(
              title: 'Buổi chiều',
              icon: Icons.cloud,
              prices: afternoonPrices,
            ),
            if (nightPrices.isNotEmpty)
              SizedBox(height: 12),
          ],

          if (nightPrices.isNotEmpty)
            _buildPriceSection(
              title: 'Buổi tối',
              icon: Icons.nightlight_round,
              prices: nightPrices,
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> prices,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFC44536).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFC44536).withOpacity(0.2)),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFFC44536), size: 16),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ...prices.map((p) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p['time'],
                    style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                  ),
                ),
                Text(
                  '${_formatCurrency(p['price'])}đ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFC44536),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final nguoiDanhGia = review['nguoi_danh_gia'] as String? ?? 'Ẩn danh';
    final noiDung = review['noi_dung'] as String? ?? '';
    final soSao = (review['so_sao'] as num?)?.toInt() ?? 0;
    final createAt = review['createAt'] as Timestamp?;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFC44536).withOpacity(0.1),
                child: Icon(Icons.person, size: 16, color: Color(0xFFC44536)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nguoiDanhGia,
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                    ),
                    Row(
                      children: List.generate(
                        5,
                            (i) => Icon(
                          i < soSao ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (createAt != null)
                Text(
                  _formatDate(createAt.toDate()),
                  style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                ),
            ],
          ),
          if (noiDung.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                noiDung,
                style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ReviewDialog
class ReviewDialog extends StatefulWidget {
  final String coSoId;
  final String coSoName;
  final String userId;

  const ReviewDialog({
    super.key,
    required this.coSoId,
    required this.coSoName,
    required this.userId,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final TextEditingController _controller = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập nội dung đánh giá'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('nguoi_thue')
          .doc(widget.userId)
          .get();

      final userData = userDoc.data();
      final hoTen = userData?['ho_ten'] as String? ?? 'Người dùng';

      await FirebaseFirestore.instance
          .collection('danh_gia')
          .doc(widget.coSoId)
          .collection('reviews')
          .add({
        'nguoi_danh_gia': hoTen,
        'ma_nguoi_danh_gia': widget.userId,
        'createAt': Timestamp.now(),
        'noi_dung': _controller.text.trim(),
        'so_sao': _rating,
      });

      await FirebaseFirestore.instance
          .collection('thong_bao')
          .doc(widget.userId)
          .collection('notifications')
          .add({
        'tieu_de': 'Đánh giá thành công',
        'noi_dung': 'Bạn đã đánh giá ${widget.coSoName} với $_rating sao',
        'da_xem_chua': false,
        'Urlweb': null,
        'Urlimage': null,
        'ngay_tao': Timestamp.now(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đánh giá thành công!'),
            backgroundColor: Color(0xFF2E8B57),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Color(0xFFC44536),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Color(0xFFC44536)),
                SizedBox(width: 8),
                Text(
                  'Đánh giá cơ sở',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Chọn số sao:', style: TextStyle(color: Color(0xFF2C3E50))),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Nội dung đánh giá',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabled: !_isSubmitting,
              ),
              maxLines: 4,
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF2C3E50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Hủy'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFC44536),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text('Gửi đánh giá'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}