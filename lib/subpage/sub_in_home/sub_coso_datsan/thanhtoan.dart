import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'OrderHashHelper.dart';

class ThanhToanPage extends StatefulWidget {
  final String maDon;

  const ThanhToanPage({
    Key? key,
    required this.maDon,
  }) : super(key: key);

  @override
  State<ThanhToanPage> createState() => _ThanhToanPageState();
}

class _ThanhToanPageState extends State<ThanhToanPage> {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  bool isLoading = true;
  Map<String, dynamic>? donDatData;
  List<Map<String, dynamic>> chiTietList = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
    _startAutoRefresh();
  }

  // 🔄 TỰ ĐỘNG REFRESH MỖI 10 GIÂY
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadOrderData(showLoading: false);
      }
    });
  }

  Future<void> _loadOrderData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => isLoading = true);
    }

    try {
      String userId = auth.currentUser?.uid ?? 'khachquaduong';

      DocumentSnapshot? orderDocument;
      for (int i = 0; i < 3; i++) {
        try {
          orderDocument = await firestore
              .collection('lich_su_khach')
              .doc(userId)
              .collection('don_dat')
              .doc(widget.maDon)
              .get()
              .timeout(const Duration(seconds: 5));

          if (orderDocument.exists) break;

          if (i < 2) {
            await Future.delayed(const Duration(seconds: 1));
            debugPrint("🔄 Retry loading order data...");
          }
        } catch (e) {
          debugPrint("Lỗi lần $i: $e");
          if (i == 2) rethrow;
        }
      }

      if (orderDocument != null && orderDocument.exists) {
        donDatData = orderDocument.data() as Map<String, dynamic>?;
      } else {
        debugPrint("Không tìm thấy đơn hàng sau 3 lần thử: ${widget.maDon}");
        if (showLoading) {
          setState(() => isLoading = false);
        }
        return;
      }

      final chiTietSnapshot = await firestore
          .collection('chi_tiet_dat')
          .doc(widget.maDon)
          .collection('danh_sach')
          .get()
          .timeout(const Duration(seconds: 10));

      chiTietList = chiTietSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      if (mounted) {
        setState(() {
          if (showLoading) {
            isLoading = false;
          }
        });
      }

      // ✅ Kiểm tra nếu đã thanh toán thì dừng auto-refresh
      if (donDatData!['trang_thai'] == 'da_thanh_toan') {
        _autoRefreshTimer?.cancel();
        debugPrint("✅ Đơn hàng đã thanh toán - Dừng auto-refresh");
      }

    } catch (e) {
      debugPrint("Lỗi load order: $e");
      if (showLoading) {
        setState(() => isLoading = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thông tin đơn hàng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔗 TẠO URL QR CODE VIETQR
  String _generateQRUrl() {
    /*final tongTien = (donDatData!['tong_tien'] as num?)?.toInt() ?? 0;

    final maDon = widget.maDon;
    final userId = auth.currentUser?.uid ?? "khachquaduong";

    // Lấy 10 ký tự đầu UID và 10 ký tự đầu mã đơn
    ///final uidShort = userId.length > 10 ? userId.substring(0, 10) : userId;
    ///final maDonShort = maDon.length > 10 ? maDon.substring(0, 10) : maDon;

    final addInfo = 'USE${userId}DON${maDon}END';

    return 'https://api.vietqr.io/image/963388-0868089513-bl9RhYA.jpg'
        '?amount=$tongTien&addInfo=$addInfo';*/
    final tongTien = (donDatData!['tong_tien'] as num?)?.toInt() ?? 0;

    // Lấy hash từ dữ liệu đơn
    final orderHash = donDatData!['order_hash'] as String? ?? '';

    // Format addInfo ngắn gọn
    final addInfo = OrderHashHelper.formatAddInfo(orderHash);
    // VD: "PAYA7F3E9B2" - chỉ 11 ký tự!

    return 'https://api.vietqr.io/image/963388-0868089513-bl9RhYA.jpg'
        '?amount=$tongTien&addInfo=$addInfo';
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
      return '${parts[0]}/${parts[1]}/${parts[2]}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC44536))),
      );
    }

    if (donDatData == null) {
      return Scaffold(
        body: Center(
          child: Text('Không tìm thấy thông tin đơn hàng'),
        ),
      );
    }

    final tongTien = (donDatData!['tong_tien'] as num?)?.toInt() ?? 0;
    final trangThai = donDatData!['trang_thai'] as String? ?? 'chua_thanh_toan';

    return Scaffold(
      body: Column(
        children: [
          // Simple Header thay cho AppBar
          Container(
            padding: EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
                  onPressed: () => Navigator.pop(context),
                ),
                SizedBox(width: 8),
                Text(
                  'Thanh toán',
                  style: TextStyle(
                    fontSize: 20,
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
              child: Column(
                children: [
                  // Trạng thái thanh toán
                  _buildStatusCard(trangThai),
                  SizedBox(height: 20),

                  // QR Code - ĐƯA XUỐNG CUỐI CÙNG CỦA CONTENT
                  if (trangThai == 'chua_thanh_toan') ...[
                    _buildQRCodeCard(),
                    SizedBox(height: 20),
                  ],

                  // Thông tin đơn hàng
                  _buildOrderInfoCard(),
                  SizedBox(height: 20),

                  // Chi tiết đặt sân
                  _buildDetailCard(),
                  SizedBox(height: 20),

                ],
              ),
            ),
          ),

          // Bottom bar
          _buildBottomBar(tongTien, trangThai),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String trangThai) {
    Color statusColor = trangThai == 'da_thanh_toan' ? Color(0xFF2E8B57) : Color(0xFFF39C12);
    String statusText = trangThai == 'da_thanh_toan' ? 'Đã thanh toán' : 'Chờ thanh toán';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            trangThai == 'da_thanh_toan' ? Icons.check_circle : Icons.pending,
            color: statusColor,
            size: 24,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Mã đơn: ${widget.maDon}',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin đơn hàng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Cơ sở', donDatData!['ten_co_so'] ?? ''),
          SizedBox(height: 12),
          _buildInfoRow('Địa chỉ', donDatData!['dia_chi_co_so'] ?? ''),
          SizedBox(height: 12),
          _buildInfoRow('Người đặt', donDatData!['ten_nguoi_dat'] ?? ''),
          SizedBox(height: 12),
          _buildInfoRow('Số điện thoại', donDatData!['sdt'] ?? ''),
          SizedBox(height: 12),
          _buildInfoRow('Ngày đặt', _formatDate(donDatData!['ngay_dat'] ?? '')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết đặt sân',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),
          ...chiTietList.map((detail) {
            final maSan = detail['ma_san'] as String? ?? '';
            final gio = detail['gio'] as String? ?? '';
            final gia = (detail['gia'] as num?)?.toInt() ?? 0;

            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFC44536).withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_tennis, color: Color(0xFFC44536), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maSan.toUpperCase().replaceAll('SAN', 'Sân '),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          'Giờ: $gio',
                          style: TextStyle(
                            color: Color(0xFF7F8C8D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_formatCurrency(gia)}đ',
                    style: TextStyle(
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

  Widget _buildQRCodeCard() {
    final qrUrl = _generateQRUrl();
    final tongTien = (donDatData!['tong_tien'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFECF0F1)),
      ),
      child: Column(
        children: [
          Text(
            'Quét mã QR để thanh toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          SizedBox(height: 16),

          // QR Code
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFECF0F1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.network(
              qrUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFC44536),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      SizedBox(height: 8),
                      Text('Lỗi tải mã QR'),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),

          // Thông tin chuyển khoản
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFC44536).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin chuyển khoản:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 12),
                _buildBankInfoRow('Ngân hàng', 'Vietcombank'),
                _buildBankInfoRow('Số tài khoản', '9915033623'),
                _buildBankInfoRow('Số tiền', '${_formatCurrency(tongTien)}đ'),
                _buildBankInfoRow('Nội dung', widget.maDon),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Auto refresh indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 16, color: Color(0xFF7F8C8D)),
              SizedBox(width: 8),
              Text(
                'Tự động kiểm tra thanh toán mỗi 10 giây',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int tongTien, String trangThai) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECF0F1), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng thanh toán:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  '${_formatCurrency(tongTien)}đ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC44536),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: trangThai == 'da_thanh_toan' ? Color(0xFF2E8B57) : Color(0xFFC44536),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  trangThai == 'da_thanh_toan' ? 'ĐÃ THANH TOÁN' : 'QUÉT MÃ QR ĐỂ THANH TOÁN!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}