import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RefundPage extends StatelessWidget {
  const RefundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFC44536))),
          );
        }
        return _RefundPageView(user: snapshot.data);
      },
    );
  }
}

class _RefundPageView extends StatefulWidget {
  final User? user;
  const _RefundPageView({this.user});

  @override
  State<_RefundPageView> createState() => _RefundPageViewState();
}

class _RefundPageViewState extends State<_RefundPageView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> refundOrders = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRefundOrders();
  }

  @override
  void didUpdateWidget(_RefundPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid) {
      _loadRefundOrders();
    }
  }

  Future<void> _loadRefundOrders() async {
    if (widget.user == null) {
      setState(() {
        isLoading = false;
        refundOrders = [];
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final userId = widget.user!.uid;

      // ✅ Truy vấn theo cấu trúc mới: cho_hoan_tien/{userId}/co_so/{coSoId}/don_dat/{maDon}
      final coSoSnapshot = await _firestore
          .collection('cho_hoan_tien')
          .doc(userId)
          .collection('co_so')
          .get();

      List<Map<String, dynamic>> allOrders = [];

      debugPrint('📦 Số cơ sở: ${coSoSnapshot.docs.length}');

      // Duyệt qua tất cả các cơ sở
      for (var coSoDoc in coSoSnapshot.docs) {
        final coSoId = coSoDoc.id;
        final coSoData = coSoDoc.data();

        debugPrint('🏢 Đang xử lý cơ sở: $coSoId');

        // ✅ BỎ orderBy - chỉ lấy tất cả đơn hàng
        final donDatSnapshot = await _firestore
            .collection('cho_hoan_tien')
            .doc(userId)
            .collection('co_so')
            .doc(coSoId)
            .collection('don_dat')
            .get(); // ← BỎ orderBy

        debugPrint('  📋 Số đơn của cơ sở $coSoId: ${donDatSnapshot.docs.length}');

        // Thêm thông tin cơ sở vào mỗi đơn hàng
        for (var donDatDoc in donDatSnapshot.docs) {
          var donDatData = donDatDoc.data();

          final orderData = {
            ...donDatData,
            'doc_id': donDatDoc.id,
            'co_so_id': coSoId,
            // Ưu tiên lấy tên cơ sở từ document co_so, nếu không có thì lấy từ đơn hàng
            'ten_co_so': coSoData['ten_co_so'] ?? donDatData['ten_co_so'] ?? '',
            // Ưu tiên lấy địa chỉ từ đơn hàng, nếu không có thì lấy từ document co_so
            'dia_chi_co_so': donDatData['dia_chi_co_so'] ?? coSoData['dia_chi_co_so'] ?? '',
          };

          allOrders.add(orderData);
          debugPrint('    ✅ Thêm đơn: ${donDatDoc.id}');
        }
      }

      // ✅ Sắp xếp toàn bộ danh sách theo thời gian yêu cầu hủy (ở trong code, không dùng Firestore)
      allOrders.sort((a, b) {
        final Timestamp? aTime = a['ngay_yeu_cau_huy'];
        final Timestamp? bTime = b['ngay_yeu_cau_huy'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending - mới nhất lên đầu
      });

      debugPrint('✅ Tổng: ${allOrders.length} đơn chờ hoàn tiền');

      setState(() {
        refundOrders = allOrders;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Lỗi khi tải đơn hoàn tiền: $e');
      debugPrint('Stack: $stackTrace');
      setState(() {
        errorMessage = 'Có lỗi xảy ra khi tải danh sách hoàn tiền: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('_');
      if (parts.length == 3) {
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showRefundDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RefundDetailBottomSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Color(0xFFF8F9FA),
      appBar:

      AppBar(
        toolbarHeight: 28,
        //primary: false,
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          padding: EdgeInsets.only(top: 8.0),
          icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),

        title: Padding(
          padding: EdgeInsets.only(top: 8.0), // Thêm padding top cho title
          child: Text(
            'Đơn chờ hoàn tiền',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50)
            ),
          ),
        ),

        centerTitle: true,
        actions: [
          IconButton(
            padding: EdgeInsets.only(top: 8.0),
            icon: Icon(Icons.refresh, color: Color(0xFFC44536)),
            onPressed: _loadRefundOrders,
          ),
        ],
      ),
      body: widget.user == null
          ? _buildLoginRequired()
          : isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFC44536)))
          : errorMessage != null
          ? _buildErrorView()
          : refundOrders.isEmpty
          ? _buildEmptyView()
          : _buildOrdersList(),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 60, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
              'Vui lòng đăng nhập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))
          ),
          SizedBox(height: 8),
          Text(
              'Đăng nhập để xem đơn chờ hoàn tiền',
              style: TextStyle(color: Color(0xFF7F8C8D))
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
          SizedBox(height: 16),
          Text(
              'Có lỗi xảy ra',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF7F8C8D))
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadRefundOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC44536),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
              'Chưa có đơn chờ hoàn tiền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))
          ),
          SizedBox(height: 8),
          Text(
              'Các đơn đã hủy sẽ hiển thị ở đây',
              style: TextStyle(color: Color(0xFF7F8C8D))
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadRefundOrders,
      color: Color(0xFFC44536),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: refundOrders.length,
        itemBuilder: (context, index) {
          final order = refundOrders[index];
          return _RefundOrderCard(
            order: order,
            onTap: () => _showRefundDetail(order),
          );
        },
      ),
    );
  }
}

class _RefundOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _RefundOrderCard({required this.order, required this.onTap});

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('_');
      if (parts.length == 3) {
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tenCoSo = order['ten_co_so'] as String? ?? 'Chưa có tên';
    final diaChiCoSo = order['dia_chi_co_so'] as String? ?? 'Chưa có địa chỉ';
    final maDon = order['ma_don'] as String? ?? '';
    final ngayDat = _formatDate(order['ngay_dat'] as String? ?? '');
    final ngayYeuCauHuy = _formatTimestamp(order['ngay_yeu_cau_huy'] as Timestamp?);
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;
    final soTienHoan = (tongTien * 0.8).toInt();
    final daHoanTien = order['da_hoan_tien'] as bool? ?? false;
    final minhChung = order['minh_chung'] as String? ?? ''; // THÊM DÒNG NÀY

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4)
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header với trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenCoSo,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF2C3E50)
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            diaChiCoSo,
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF7F8C8D)
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: daHoanTien ? Color(0xFF27AE60).withOpacity(0.1) : Color(0xFFE67E22).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: daHoanTien ? Color(0xFF27AE60) : Color(0xFFE67E22),
                            width: 1
                        ),
                      ),
                      child: Text(
                        daHoanTien ? 'ĐÃ HOÀN' : 'CHỜ XỬ LÝ',
                        style: TextStyle(
                          color: daHoanTien ? Color(0xFF27AE60) : Color(0xFFE67E22),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),
                Divider(height: 1, color: Color(0xFFECF0F1)),

                // Thông tin đơn hàng
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfo('Mã đơn', maDon.isNotEmpty ? '#${maDon.substring(0, 8).toUpperCase()}' : '---'),
                    ),
                    Expanded(
                      child: _buildInfo('Ngày đặt', ngayDat.isNotEmpty ? ngayDat : '---'),
                    ),
                    Expanded(
                      child: _buildInfo('Ngày hủy', ngayYeuCauHuy.isNotEmpty ? ngayYeuCauHuy : '---'),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Thông tin tiền
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFECF0F1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Tổng tiền',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F8C8D),
                                  fontWeight: FontWeight.w500
                              )
                          ),
                          SizedBox(height: 4),
                          Text(
                              '${_formatCurrency(tongTien)}đ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C3E50)
                              )
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFC44536).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Color(0xFFC44536)
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                              'Hoàn 80%',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7F8C8D),
                                  fontWeight: FontWeight.w500
                              )
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_formatCurrency(soTienHoan)}đ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFC44536)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // THÊM PHẦN HIỂN THỊ MINH CHỨNG
                if (daHoanTien && minhChung.isNotEmpty) ...[
                  SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showImageFullScreen(context, minhChung),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF27AE60).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFF27AE60).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              minhChung,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: Icon(Icons.broken_image, color: Colors.grey[600]),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.verified, size: 16, color: Color(0xFF27AE60)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Minh chứng hoàn tiền',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF27AE60),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Nhấn để xem chi tiết',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF27AE60)),
                        ],
                      ),
                    ),
                  ),
                ],

                // Thông báo hỗ trợ
                if (!daHoanTien) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF3498DB).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF3498DB).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF3498DB)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CSKH sẽ liên hệ hoàn 80% tiền trong thời gian sớm nhất',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3498DB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

// Thêm hàm hiển thị ảnh full screen
  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 60, color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Không thể tải ảnh',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
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
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Minh chứng hoàn tiền',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            label,
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7F8C8D),
                fontWeight: FontWeight.w500
            )
        ),
        SizedBox(height: 4),
        Text(
            value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50)
            )
        ),
      ],
    );
  }
}

class _RefundDetailBottomSheet extends StatelessWidget {
  final Map<String, dynamic> order;

  const _RefundDetailBottomSheet({required this.order});

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('_');
      if (parts.length == 3) {
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Chưa cập nhật';
    final dt = timestamp.toDate();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final daHoanTien = order['da_hoan_tien'] as bool? ?? false;
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;
    final soTienHoan = (tongTien * 0.8).toInt();
    final tenCoSo = order['ten_co_so'] as String? ?? 'Chưa có tên';
    final diaChiCoSo = order['dia_chi_co_so'] as String? ?? 'Chưa có địa chỉ';
    final maDon = order['ma_don'] as String? ?? '';
    final tenNguoiDat = order['ten_nguoi_dat'] as String? ?? '';
    final sdt = order['sdt'] as String? ?? '';
    final minhChung = order['minh_chung'] as String? ?? ''; // THÊM DÒNG NÀY

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFECF0F1))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Color(0xFF7F8C8D)),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Text(
                    'Chi tiết hoàn tiền',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50)
                    )
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trạng thái
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: daHoanTien ? Color(0xFF27AE60).withOpacity(0.05) : Color(0xFFE67E22).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: daHoanTien ? Color(0xFF27AE60).withOpacity(0.3) : Color(0xFFE67E22).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            daHoanTien ? Icons.check_circle : Icons.access_time,
                            color: daHoanTien ? Color(0xFF27AE60) : Color(0xFFE67E22),
                            size: 32
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  daHoanTien ? 'Đã hoàn tiền' : 'Chờ xử lý',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: daHoanTien ? Color(0xFF27AE60) : Color(0xFFE67E22)
                                  )
                              ),
                              SizedBox(height: 4),
                              Text(
                                  daHoanTien ? 'Tiền đã được hoàn vào tài khoản của bạn' : 'CSKH sẽ liên hệ hoàn tiền trong thời gian sớm nhất',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF7F8C8D)
                                  )
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // THÊM PHẦN MINH CHỨNG
                  if (daHoanTien && minhChung.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFF27AE60).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF27AE60).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified, size: 20, color: Color(0xFF27AE60)),
                              SizedBox(width: 8),
                              Text(
                                'Minh chứng hoàn tiền',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF27AE60),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _showImageFullScreen(context, minhChung),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                minhChung,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
                                      SizedBox(height: 8),
                                      Text('Không thể tải ảnh', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: double.infinity,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: Color(0xFF27AE60),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Nhấn vào ảnh để xem rõ hơn',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7F8C8D),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  // Thông tin đơn hàng
                  _buildSection(
                      'Thông tin đơn hàng',
                      Icons.receipt_long,
                      [
                        _buildDetailRow('Mã đơn', maDon.isNotEmpty ? '#${maDon.substring(0, 8).toUpperCase()}' : '---'),
                        _buildDetailRow('Tên cơ sở', tenCoSo),
                        _buildDetailRow('Địa chỉ', diaChiCoSo),
                        _buildDetailRow('Ngày đặt', _formatDate(order['ngay_dat'] ?? '')),
                        _buildDetailRow('Ngày hủy', _formatTimestamp(order['ngay_yeu_cau_huy'])),
                      ]
                  ),

                  SizedBox(height: 20),

                  // Thông tin người đặt
                  _buildSection(
                      'Thông tin người đặt',
                      Icons.person,
                      [
                        _buildDetailRow('Tên', tenNguoiDat),
                        _buildDetailRow('SĐT', sdt),
                      ]
                  ),

                  SizedBox(height: 20),

                  // Thông tin tiền
                  _buildSection(
                      'Thông tin tiền',
                      Icons.payments,
                      [
                        _buildDetailRow('Tổng tiền', '${_formatCurrency(tongTien)}đ'),
                        _buildDetailRow('Hoàn 80%', '${_formatCurrency(soTienHoan)}đ', highlight: true),
                        if (daHoanTien && order['time_hoan_tien'] != null)
                          _buildDetailRow('Thời gian hoàn', _formatTimestamp(order['time_hoan_tien'])),
                      ]
                  ),

                  // Thông báo hỗ trợ
                  if (!daHoanTien) ...[
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFF3498DB).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF3498DB).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.support_agent, size: 20, color: Color(0xFF3498DB)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hỗ trợ khách hàng',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3498DB),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Liên hệ CSKH: 1900 1234\nThời gian làm việc: 8:00 - 22:00',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF3498DB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// Thêm hàm hiển thị ảnh full screen (giống như trong _RefundOrderCard)
  void _showImageFullScreen(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 60, color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Không thể tải ảnh',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
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
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Minh chứng hoàn tiền',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Color(0xFFC44536)),
              SizedBox(width: 8),
              Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF2C3E50)
                  )
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Color(0xFFC44536) : Color(0xFF2C3E50),
                fontSize: highlight ? 15 : 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}