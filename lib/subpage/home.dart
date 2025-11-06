import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePageContent();
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tinhController = TextEditingController();
  final TextEditingController _huyenController = TextEditingController();
  final TextEditingController _xaController = TextEditingController();

  String _searchText = '';
  String _selectedTinh = '';
  String _selectedHuyen = '';
  String _selectedXa = '';

  @override
  void dispose() {
    _searchController.dispose();
    _tinhController.dispose();
    _huyenController.dispose();
    _xaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterSection(),
        Expanded(child: _buildCoSoList()),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Tìm kiếm theo tên
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tên sân...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchText = '');
                },
              )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchText = value.trim()),
          ),
          const SizedBox(height: 12),
          // Bộ lọc Tỉnh, Huyện, Xã
          Row(
            children: [
              Expanded(
                child: _buildFilterField(
                  controller: _tinhController,
                  hint: 'Tỉnh/TP',
                  value: _selectedTinh,
                  onChanged: (v) => setState(() {
                    _selectedTinh = v.trim();
                    _selectedHuyen = '';
                    _selectedXa = '';
                    _huyenController.clear();
                    _xaController.clear();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterField(
                  controller: _huyenController,
                  hint: 'Quận/Huyện',
                  value: _selectedHuyen,
                  onChanged: (v) => setState(() {
                    _selectedHuyen = v.trim();
                    _selectedXa = '';
                    _xaController.clear();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterField(
                  controller: _xaController,
                  hint: 'Xã/Phường',
                  value: _selectedXa,
                  onChanged: (v) => setState(() => _selectedXa = v.trim()),
                ),
              ),
            ],
          ),
          if (_selectedTinh.isNotEmpty || _selectedHuyen.isNotEmpty || _selectedXa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  _tinhController.clear();
                  _huyenController.clear();
                  _xaController.clear();
                  setState(() {
                    _selectedTinh = '';
                    _selectedHuyen = '';
                    _selectedXa = '';
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Xóa bộ lọc'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterField({
    required TextEditingController controller,
    required String hint,
    required String value,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: value.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () {
            controller.clear();
            onChanged('');
          },
        )
            : null,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildCoSoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('co_so').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có cơ sở nào'));
        }

        // Lọc dữ liệu
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ten = (data['ten'] as String? ?? '').toLowerCase();
          final tinh = (data['tinh'] as String? ?? '').toLowerCase();
          final huyen = (data['huyen'] as String? ?? '').toLowerCase();
          final xa = (data['xa'] as String? ?? '').toLowerCase();

          final matchSearch = _searchText.isEmpty || ten.contains(_searchText.toLowerCase());
          final matchTinh = _selectedTinh.isEmpty || tinh.contains(_selectedTinh.toLowerCase());
          final matchHuyen = _selectedHuyen.isEmpty || huyen.contains(_selectedHuyen.toLowerCase());
          final matchXa = _selectedXa.isEmpty || xa.contains(_selectedXa.toLowerCase());

          return matchSearch && matchTinh && matchHuyen && matchXa;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('Không tìm thấy cơ sở phù hợp'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCoSoCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCoSoCard(BuildContext context, String id, Map<String, dynamic> data) {
    final anh1 = data['anh1'] as String? ?? '';
    final ten = data['ten'] as String? ?? 'Chưa có tên';
    final diaChiChiTiet = data['dia_chi_chi_tiet'] as String? ?? '';
    final xa = data['xa'] as String? ?? '';
    final huyen = data['huyen'] as String? ?? '';
    final tinh = data['tinh'] as String? ?? '';
    final sdt = data['sdt'] as String? ?? '';
    final gioMo = data['gio_mo_cua'] as String? ?? '';
    final gioDong = data['gio_dong_cua'] as String? ?? '';
    final moTa = data['mo_ta'] as String? ?? '';

    final diaChi = [diaChiChiTiet, xa, huyen, tinh]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CoSoDetailPage(coSoId: id, coSoData: data),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: anh1.isNotEmpty
                    ? Image.network(
                  anh1,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(width: 12),
              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ten,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (diaChi.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              diaChi,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (sdt.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(sdt, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    if (gioMo.isNotEmpty || gioDong.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$gioMo - $gioDong',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    if (moTa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          moTa,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.sports_tennis, size: 40, color: Colors.grey),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TRANG CHI TIẾT CƠ SỞ
// ═══════════════════════════════════════════════════════════
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
          .doc(widget.coSoId)
          .collection('users')
          .doc(user.uid)
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
          .doc(widget.coSoId)
          .collection('users')
          .doc(user.uid);

      if (_isFavorite) {
        await docRef.delete();
        setState(() => _isFavorite = false);
        _showMessage('Đã xóa khỏi danh sách yêu thích');
      } else {
        await docRef.set({'user': user.uid});
        setState(() => _isFavorite = true);
        _showMessage('Đã thêm vào danh sách yêu thích');
      }
    } catch (e) {
      _showMessage('Lỗi: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openGoogleMaps() async {
    final toaDoX = widget.coSoData['toa_do_x'];
    final toaDoY = widget.coSoData['toa_do_y'];

    if (toaDoX == null || toaDoY == null) {
      _showMessage('Không có thông tin tọa độ');
      return;
    }

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$toaDoX,$toaDoY');
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

  @override
  Widget build(BuildContext context) {
    final ten = widget.coSoData['ten'] as String? ?? 'Chi tiết cơ sở';

    return Scaffold(
      appBar: AppBar(
        title: Text(ten, style: const TextStyle(fontSize: 18)),
        actions: [
          if (_isLoadingFav)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              color: _isFavorite ? Colors.red : null,
              onPressed: _toggleFavorite,
              tooltip: _isFavorite ? 'Xóa khỏi yêu thích' : 'Thêm vào yêu thích',
            ),
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: _showReviewDialog,
            tooltip: 'Đánh giá',
          ),
          TextButton(
            onPressed: _showReviewDialog,
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
            child: const Text('Đặt lịch'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(),
            _buildInfoSection(),
            _buildMapButton(),
            _buildReviewsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = [
      widget.coSoData['anh1'] as String?,
      widget.coSoData['anh2'] as String?,
      widget.coSoData['anh3'] as String?,
      widget.coSoData['anh4'] as String?,
    ].where((url) => url != null && url.isNotEmpty).toList();

    if (images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.image_not_supported, size: 60)),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 16 : 8, right: index == images.length - 1 ? 16 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                images[index]!,
                width: 250,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 250,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 40),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection() {
    final data = widget.coSoData;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['ten'] as String? ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, 'Địa chỉ',
              '${data['dia_chi_chi_tiet']}, ${data['xa']}, ${data['huyen']}, ${data['tinh']}'),
          _buildInfoRow(Icons.phone, 'Số điện thoại', data['sdt'] as String? ?? ''),
          _buildInfoRow(Icons.access_time, 'Giờ mở cửa',
              '${data['gio_mo_cua']} - ${data['gio_dong_cua']}'),
          if ((data['web'] as String?)?.isNotEmpty == true)
            _buildInfoRow(Icons.language, 'Website', data['web'] as String),
          const SizedBox(height: 16),
          const Text('Mô tả:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            data['mo_ta'] as String? ?? 'Chưa có mô tả',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openGoogleMaps,
          icon: const Icon(Icons.map),
          label: const Text('Mở Google Maps'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đánh giá',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('danh_gia')
                .doc(widget.coSoId)
                .collection('reviews')
                .orderBy('createAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Lỗi: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('Chưa có đánh giá nào');
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final review = doc.data() as Map<String, dynamic>;
                  return _buildReviewCard(review);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final nguoiDanhGia = review['nguoi_danh_gia'] as String? ?? 'Ẩn danh';
    final noiDung = review['noi_dung'] as String? ?? '';
    final soSao = (review['so_sao'] as num?)?.toInt() ?? 0;
    final createAt = review['createAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nguoiDanhGia, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(
                          5,
                              (i) => Icon(
                            i < soSao ? Icons.star : Icons.star_border,
                            size: 16,
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            if (noiDung.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(noiDung),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ═══════════════════════════════════════════════════════════
// DIALOG ĐÁNH GIÁ
// ═══════════════════════════════════════════════════════════
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
        const SnackBar(content: Text('Vui lòng nhập nội dung đánh giá')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Lấy thông tin người dùng
      final userDoc = await FirebaseFirestore.instance
          .collection('nguoi_thue')
          .doc(widget.userId)
          .get();

      final userData = userDoc.data();
      final hoTen = userData?['ho_ten'] as String? ?? 'Người dùng';

      // Tạo đánh giá
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

      // Tạo thông báo
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
          const SnackBar(content: Text('Đánh giá thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đánh giá cơ sở'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chọn số sao:'),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Nội dung đánh giá',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              enabled: !_isSubmitting,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Gửi đánh giá'),
        ),
      ],
    );
  }
}