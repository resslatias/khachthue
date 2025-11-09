import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home.dart';
import '../sub_in_home/CoSoDetailPage.dart';


class LikePage extends StatefulWidget {
  const LikePage({super.key});

  @override
  State<LikePage> createState() => _LikePageState();
}

class _LikePageState extends State<LikePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sân ưa thích'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng đăng nhập để xem sân ưa thích',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sân ưa thích'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('san_ua_thich')
            .doc(user!.uid)
            .collection('co_so')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.heart_broken, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có sân ưa thích nào',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hãy thêm sân yêu thích của bạn!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final favoriteCoSoIds = snapshot.data!.docs.map((doc) => doc.id).toList();

          return FutureBuilder<List<DocumentSnapshot>>(
            future: _getCoSoDetails(favoriteCoSoIds),
            builder: (context, coSoSnapshot) {
              if (coSoSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (coSoSnapshot.hasError) {
                return Center(child: Text('Lỗi: ${coSoSnapshot.error}'));
              }

              if (!coSoSnapshot.hasData || coSoSnapshot.data!.isEmpty) {
                return const Center(child: Text('Không tìm thấy thông tin cơ sở'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: coSoSnapshot.data!.length,
                itemBuilder: (context, index) {
                  final doc = coSoSnapshot.data![index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildCoSoCard(context, doc.id, data);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot>> _getCoSoDetails(List<String> coSoIds) async {
    if (coSoIds.isEmpty) return [];

    final List<DocumentSnapshot> results = [];
    for (final id in coSoIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('co_so')
            .doc(id)
            .get();
        if (doc.exists) {
          results.add(doc);
        }
      } catch (e) {
        debugPrint('Lỗi lấy thông tin cơ sở $id: $e');
      }
    }
    return results;
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
                  ],
                ),
              ),
              // Nút xóa khỏi yêu thích
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _removeFromFavorites(context, id, ten),
                tooltip: 'Xóa khỏi yêu thích',
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

  Future<void> _removeFromFavorites(BuildContext context, String coSoId, String coSoName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text('Bạn có muốn xóa "$coSoName" khỏi danh sách yêu thích?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('san_ua_thich')
          .doc(user!.uid)
          .collection('co_so')
          .doc(coSoId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa khỏi danh sách yêu thích'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}