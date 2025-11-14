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
      return Column(
        children: [
          // Header nhỏ cho trang với nút back
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                // Nút quay về
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(width: 8),
                Icon(Icons.favorite, color: Color(0xFFC44536), size: 24),
                SizedBox(width: 8),
                Text(
                  'Sân ưa thích',
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Vui lòng đăng nhập để xem sân ưa thích',
                    style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Header nhỏ cho trang với nút back
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              // Nút quay về
              IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              SizedBox(width: 8),
              Icon(Icons.favorite, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                'Sân ưa thích',
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('san_ua_thich')
                .doc(user!.uid)
                .collection('co_so')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorWidget('Lỗi: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingWidget();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyWidget();
              }

              final favoriteCoSoIds = snapshot.data!.docs.map((doc) => doc.id).toList();

              return FutureBuilder<List<DocumentSnapshot>>(
                future: _getCoSoDetails(favoriteCoSoIds),
                builder: (context, coSoSnapshot) {
                  if (coSoSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingWidget();
                  }

                  if (coSoSnapshot.hasError) {
                    return _buildErrorWidget('Lỗi: ${coSoSnapshot.error}');
                  }

                  if (!coSoSnapshot.hasData || coSoSnapshot.data!.isEmpty) {
                    return _buildEmptyWidget();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
        ),
      ],
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

  // Widget thẻ cơ sở GIỐNG TRANG HOME - HIỂN THỊ CẢ 2 ẢNH
  Widget _buildCoSoCard(BuildContext context, String id, Map<String, dynamic> data) {
    final anh1 = data['anh1'] as String? ?? '';
    final anh2 = data['anh2'] as String? ?? '';
    final ten = data['ten'] as String? ?? 'Chưa có tên';
    final diaChiChiTiet = data['dia_chi_chi_tiet'] as String? ?? '';
    final xa = data['xa'] as String? ?? '';
    final huyen = data['huyen'] as String? ?? '';
    final tinh = data['tinh'] as String? ?? '';
    final sdt = data['sdt'] as String? ?? '';
    final gioMo = data['gio_mo_cua'] as String? ?? '';
    final gioDong = data['gio_dong_cua'] as String? ?? '';
    final isOke = data['is_oke'] as int? ?? 0;

    final diaChi = [diaChiChiTiet, xa, huyen, tinh].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CoSoDetailPage(coSoId: id, coSoData: data),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // PHẦN ẢNH: Hiển thị cả ảnh bìa (anh2) và logo (anh1) - GIỐNG HOME
              Container(
                width: 140,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // Ảnh bìa (anh2) - background
                    if (anh2.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: Image.network(
                          anh2,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderBanner(),
                        ),
                      )
                    else
                      _buildPlaceholderBanner(),

                    // Logo (anh1) - overlay ở góc dưới phải
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: anh1.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            anh1,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderLogo(),
                          ),
                        )
                            : _buildPlaceholderLogo(),
                      ),
                    ),

                    // Badge is_oke - góc trên trái
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFC44536),
                              Color(0xFFE74C3C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              '$isOke',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nút xóa yêu thích - góc trên phải
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _removeFromFavorites(context, id, ten),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Color(0xFFC44536),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // PHẦN THÔNG TIN
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tên sân
                      Text(
                        ten,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Địa chỉ
                      if (diaChi.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Color(0xFF7F8C8D)),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                diaChi,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7F8C8D),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      // Thông tin liên hệ và giờ làm việc
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sdt.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: Color(0xFF7F8C8D)),
                                SizedBox(width: 4),
                                Text(
                                  sdt,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                                ),
                              ],
                            ),

                          if (gioMo.isNotEmpty || gioDong.isNotEmpty) ...[
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: Color(0xFF7F8C8D)),
                                SizedBox(width: 4),
                                Text(
                                  '$gioMo - $gioDong',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget placeholder cho ảnh bìa
  Widget _buildPlaceholderBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Icon(Icons.photo, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  // Widget placeholder cho logo
  Widget _buildPlaceholderLogo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(Icons.sports_tennis, size: 20, color: Colors.grey[500]),
      ),
    );
  }

  // Widget loading
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFC44536)),
          SizedBox(height: 16),
          Text(
            'Đang tải dữ liệu...',
            style: TextStyle(color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }

  // Widget empty
  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.heart_broken, size: 60, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
            'Chưa có sân ưa thích nào',
            style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
          ),
          SizedBox(height: 8),
          Text(
            'Hãy thêm sân yêu thích của bạn!',
            style: TextStyle(fontSize: 14, color: Color(0xFF95A5A6)),
          ),
        ],
      ),
    );
  }

  // Widget error
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
          SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Color(0xFF7F8C8D)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromFavorites(BuildContext context, String coSoId, String coSoName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận', style: TextStyle(color: Color(0xFF2C3E50))),
        content: Text('Bạn có muốn xóa "$coSoName" khỏi danh sách yêu thích?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Hủy', style: TextStyle(color: Color(0xFF7F8C8D))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC44536),
            ),
            child: Text('Xóa', style: TextStyle(color: Colors.white)),
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
          SnackBar(
            content: Text('Đã xóa khỏi danh sách yêu thích'),
            backgroundColor: Color(0xFF2E8B57),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    }
  }
}