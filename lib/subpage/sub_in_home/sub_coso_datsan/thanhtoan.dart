import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() => isLoading = true);

    try {
      String userId = auth.currentUser?.uid ?? 'khachquaduong';

      // ⭐ SỬA: Đổi tên biến và thêm type casting
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
        // ⭐ SỬA: Thêm type casting explicit
        donDatData = orderDocument.data() as Map<String, dynamic>?;
      } else {
        debugPrint("Không tìm thấy đơn hàng sau 3 lần thử: ${widget.maDon}");
        setState(() => isLoading = false);
        return;
      }

      final chiTietSnapshot = await firestore
          .collection('chi_tiet_dat')
          .doc(widget.maDon)
          .collection('danh_sach')
          .get()
          .timeout(const Duration(seconds: 10));

      // ⭐ SỬA: Thêm type casting cho chi tiết
      chiTietList = chiTietSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Lỗi load order: $e");
      setState(() => isLoading = false);

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

  Future<void> _processPayment() async {
    try {
      String userId = auth.currentUser?.uid ?? 'khachquaduong';
      String coSoId = donDatData!['co_so_id'] as String;

      // 1. Cập nhật trạng thái thanh toán trong lich_su_khach
      await firestore
          .collection('lich_su_khach')
          .doc(userId)
          .collection('don_dat')
          .doc(widget.maDon)
          .update({
        'trang_thai': 'da_thanh_toan',
        'timeup': null,
      });

      // 2. Cập nhật trạng thái thanh toán trong lich_su_san
      await firestore
          .collection('lich_su_san')
          .doc(coSoId)
          .collection('khach_dat')
          .doc(widget.maDon)
          .update({
        'trang_thai': 'da_thanh_toan',
        'timeup': null,
      });

      // 3. 🆕 CẬP NHẬT QUAN TRỌNG: Đặt payment_timeup thành thời gian kết thúc của sân
      for (var chiTiet in chiTietList) {
        String maSan = chiTiet['ma_san'] as String;
        String gio = chiTiet['gio'] as String; // Format: "08:00"
        String ngayDat = chiTiet['ngay_dat'] as String; // Format: "dd_MM_yyyy"
        String paymentTimeupKey = '${maSan}_payment_timeup';

        // 🎯 CHUYỂN ĐỔI: Từ "dd_MM_yyyy" và "HH:mm" sang DateTime cho thời gian kết thúc
        try {
          List<String> dateParts = ngayDat.split('_');
          int day = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int year = int.parse(dateParts[2]);

          List<String> timeParts = gio.split(':');
          int hour = int.parse(timeParts[0]);

          // 🆕 TẠO THỜI GIAN KẾT THÚC: giờ bắt đầu + 1 tiếng
          DateTime endTime = DateTime(year, month, day, hour + 1);
          Timestamp endTimestamp = Timestamp.fromDate(endTime);

          await firestore
              .collection('dat_san')
              .doc(coSoId)
              .collection(ngayDat)
              .doc(gio)
              .update({
            paymentTimeupKey: endTimestamp,
          });

          debugPrint("✅ Đã cập nhật $paymentTimeupKey thành ${endTime.toString()}");
        } catch (e) {
          debugPrint("❌ Lỗi chuyển đổi thời gian cho $maSan: $e");
        }
      }

      // 4. Tạo thông báo thanh toán thành công
      await firestore
          .collection('thong_bao')
          .doc(userId)
          .collection('notifications')
          .add({
        'tieu_de': 'Thanh toán thành công',
        'noi_dung': 'Đơn hàng ${widget.maDon} đã được thanh toán thành công',
        'da_xem_chua': false,
        'Urlweb': null,
        'Urlimage': null,
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // 5. Cập nhật UI
      setState(() {
        donDatData!['trang_thai'] = 'da_thanh_toan';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanh toán thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint('Lỗi thanh toán: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi thanh toán: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmPayment() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: const Text('Bạn có chắc chắn muốn thanh toán đơn hàng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            child: const Text('Xác nhận', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processPayment();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán'),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (donDatData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán'),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(
          child: Text('Không tìm thấy thông tin đơn hàng'),
        ),
      );
    }

    final tongTien = (donDatData!['tong_tien'] as num?)?.toInt() ?? 0;
    final trangThai = donDatData!['trang_thai'] as String? ?? 'chua_thanh_toan';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Thanh toán',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade700, Colors.white],
            stops: const [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildStatusCard(trangThai),
                    const SizedBox(height: 16),
                    _buildOrderInfoCard(),
                    const SizedBox(height: 16),
                    _buildDetailCard(),
                    const SizedBox(height: 16),
                    _buildPaymentMethodCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomBar(tongTien, trangThai),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String trangThai) {
    Color statusColor = trangThai == 'da_thanh_toan' ? Colors.green : Colors.orange;
    String statusText = trangThai == 'da_thanh_toan' ? 'Đã thanh toán' : 'Chưa thanh toán';
    IconData statusIcon = trangThai == 'da_thanh_toan' ? Icons.check_circle : Icons.pending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // GIẢM BO GÓC
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mã đơn: ${widget.maDon.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // GIẢM BO GÓC
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin đơn đặt',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.store,
            'Cơ sở',
            donDatData!['ten_co_so'] as String? ?? '',
          ),
          _buildInfoRow(
            Icons.location_on,
            'Địa chỉ',
            donDatData!['dia_chi_co_so'] as String? ?? '',
          ),
          _buildInfoRow(
            Icons.person,
            'Người đặt',
            donDatData!['ten_nguoi_dat'] as String? ?? '',
          ),
          _buildInfoRow(
            Icons.phone,
            'Số điện thoại',
            donDatData!['sdt'] as String? ?? '',
          ),
          _buildInfoRow(
            Icons.calendar_today,
            'Ngày đặt',
            _formatDate(donDatData!['ngay_dat'] as String? ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // GIẢM BO GÓC
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết đặt sân',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...chiTietList.map((detail) {
            final maSan = detail['ma_san'] as String? ?? '';
            final gio = detail['gio'] as String? ?? '';
            final gia = (detail['gia'] as num?)?.toInt() ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6), // GIẢM BO GÓC
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6), // GIẢM BO GÓC
                    ),
                    child: const Icon(
                      Icons.sports_tennis,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maSan.toUpperCase().replaceAll('SAN', 'Sân '),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Giờ: $gio',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_formatCurrency(gia)}đ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 14,
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

  Widget _buildPaymentMethodCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // GIẢM BO GÓC
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6), // GIẢM BO GÓC
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thanh toán QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Quét mã QR để thanh toán',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6), // GIẢM BO GÓC
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.payments, color: Colors.orange.shade700, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thanh toán trực tiếp',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Thanh toán khi đến sân',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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

  Widget _buildBottomBar(int tongTien, String trangThai) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng thanh toán:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatCurrency(tongTien)}đ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: trangThai == 'da_thanh_toan' ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: trangThai == 'da_thanh_toan'
                      ? Colors.grey
                      : Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6), // GIẢM BO GÓC
                  ),
                  elevation: 3,
                ),
                child: Text(
                  trangThai == 'da_thanh_toan'
                      ? 'Đã thanh toán'
                      : 'Tạo mã QR thanh toán',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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