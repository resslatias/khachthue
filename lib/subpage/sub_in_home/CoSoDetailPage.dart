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
      // Cấu trúc mới: san_ua_thich/{userId}/co_so/{coSoId}
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
      // Cấu trúc mới: san_ua_thich/{userId}/co_so/{coSoId}
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrangThaiSan()),
              );
            },
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

// ═══════════════════════════════════════════════════════════════
// DIALOG ĐÁNH GIÁ
// ═══════════════════════════════════════════════════════════════
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