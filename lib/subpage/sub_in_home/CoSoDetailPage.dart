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

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
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
    } else {
      final toaDoX = widget.coSoData['toa_do_x'];
      final toaDoY = widget.coSoData['toa_do_y'];

      if (toaDoX != null && toaDoY != null) {
        latitude = double.tryParse(toaDoX.toString());
        longitude = double.tryParse(toaDoY.toString());
      }
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

  void _showReviewDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Vui lòng đăng nhập để đánh giá');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ReviewDialog(
        coSoId: widget.coSoId,
        coSoName: widget.coSoData['ten'] as String? ?? 'Cơ sở',
        userId: user.uid,
      ),
    );
  }

  String? _getLogoImage() {
    return widget.coSoData['anh1'] as String?;
  }

  String? _getCoverImage() {
    return widget.coSoData['anh2'] as String?;
  }

  List<String> _getGalleryImages() {
    final images = <String>[];

    final anh3 = widget.coSoData['anh3'] as String?;
    final anh4 = widget.coSoData['anh4'] as String?;
    final anh5 = widget.coSoData['anh5'] as String?;

    if (anh3 != null && anh3.isNotEmpty) images.add(anh3);
    if (anh4 != null && anh4.isNotEmpty) images.add(anh4);
    if (anh5 != null && anh5.isNotEmpty) images.add(anh5);

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

  void _showReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReviewsBottomSheet(),
    );
  }

  // Hàm hiển thị ảnh toàn màn hình
  void _showImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8), // nền đen nhẹ
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(20), // khoảng cách từ mép màn hình
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

            // nút đóng
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
          // Header
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
          // Content
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
          // Header
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
                  'Đánh giá',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _buildReviewsContent(),
          ),
        ],
      ),
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
      body: CustomScrollView(
        slivers: [
          // Phần 1: AppBar với nút quay về và tiêu đề
          SliverAppBar(
            backgroundColor: Colors.white,
            primary: false,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Thông tin sân',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            centerTitle: true,
            pinned: true,
          ),

          // Phần 2: Các nút chức năng
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Nút yêu thích
                  _buildActionButton(
                    icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                    label: 'Yêu thích',
                    color: _isFavorite ? Color(0xFFC44536) : Color(0xFF2C3E50),
                    onTap: _toggleFavorite,
                    isLoading: _isLoadingFav,
                  ),

                  // Nút đánh giá
                  _buildActionButton(
                    icon: Icons.star_border,
                    label: 'Đánh giá',
                    color: Color(0xFF2C3E50),
                    onTap: _showReviewDialog,
                  ),

                  // Nút đặt lịch
                  _buildActionButton(
                    icon: Icons.calendar_today,
                    label: 'Đặt lịch',
                    color: Color(0xFF2C3E50),
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
                  ),

                  // Nút chỉ đường - ĐÃ THÊM LẠI
                  _buildActionButton(
                    icon: Icons.map,
                    label: 'Chỉ đường',
                    color: Color(0xFF2C3E50),
                    onTap: _openGoogleMaps,
                  ),
                ],
              ),
            ),
          ),

          // Phần 3: Ảnh đại diện và ảnh bìa (kiểu Facebook)
          SliverToBoxAdapter(
            child: _buildCoverSection(ten, logoImage, coverImage),
          ),

          // Phần 4: Các ảnh gallery
          if (galleryImages.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildGallerySection(galleryImages),
            ),

          // Phần thông tin cơ bản
          SliverToBoxAdapter(
            child: _buildBasicInfoSection(),
          ),

          // Phần các nút Bảng giá và Bình luận
          SliverToBoxAdapter(
            child: _buildActionSection(),
          ),

          // Khoảng cách cuối
          SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(icon, color: color, size: 24),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverSection(String ten, String? logoImage, String? coverImage) {
    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // Ảnh bìa - CÓ THỂ NHẤN ĐỂ XEM
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

          // Logo và tên
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo - CÓ THỂ NHẤN ĐỂ XEM
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

                // Tên và thông tin
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
                      SizedBox(height: 4),
                      Text(
                        '${widget.coSoData['dia_chi_chi_tiet'] ?? ''}, ${widget.coSoData['xa'] ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
          if ((data['web'] as String?)?.isNotEmpty == true)
            _buildInfoRow(Icons.language, 'Website', data['web'] as String),

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

  Widget _buildActionSection() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showPriceBottomSheet,
              icon: Icon(Icons.attach_money, size: 20),
              label: Text('Bảng giá'),
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
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showReviewsBottomSheet,
              icon: Icon(Icons.comment, size: 20),
              label: Text('Bình luận'),
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

  // Các hàm _buildPriceTables, _buildBangGiaTable, _buildGiaSanTable, _buildPriceSection,
  // _formatCurrency, _buildReviewCard, _formatDate giữ nguyên như code trước
  // ... (giữ nguyên tất cả các hàm này)

  Widget _buildPriceTables() {
    final bangGia = widget.coSoData['bang_gia'] as List<dynamic>?;
    final giaSan = widget.coSoData['gia_san'] as List<dynamic>?;

    if ((bangGia == null || bangGia.isEmpty) &&
        (giaSan == null || giaSan.isEmpty)) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text('Chưa có thông tin bảng giá'),
      );
    }

    return Column(
      children: [
        if (bangGia != null && bangGia.isNotEmpty)
          _buildBangGiaTable(bangGia),

        if (bangGia != null && bangGia.isNotEmpty &&
            giaSan != null && giaSan.isNotEmpty)
          SizedBox(height: 16),

        if (giaSan != null && giaSan.isNotEmpty)
          _buildGiaSanTable(giaSan),
      ],
    );
  }

  Widget _buildBangGiaTable(List<dynamic> bangGia) {
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

    for (int i = gioMo; i < gioDong; i++) {
      if (i < bangGia.length) {
        final price = bangGia[i];
        final priceData = {
          'time': '${i}h - ${i + 1}h',
          'price': price is int ? price : (price as num).toInt(),
        };

        if (i < 12) {
          morningPrices.add(priceData);
        } else if (i < 18) {
          afternoonPrices.add(priceData);
        } else {
          nightPrices.add(priceData);
        }
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

// ReviewDialog giữ nguyên
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