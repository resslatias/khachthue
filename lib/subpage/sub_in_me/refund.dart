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

      // ✅ Dùng collectionGroup để query tất cả 'don_dat'
      final snapshot = await _firestore
          .collectionGroup('don_dat')
          .where('user_id', isEqualTo: userId) // Cần thêm field user_id vào đơn
          .orderBy('ngay_yeu_cau_huy', descending: true)
          .get();

      List<Map<String, dynamic>> allOrders = snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'doc_id': doc.id,
        };
      }).toList();

      debugPrint('✅ Tổng: ${allOrders.length} đơn');

      setState(() {
        refundOrders = allOrders;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Lỗi: $e');
      debugPrint('Stack: $stackTrace');
      setState(() {
        errorMessage = e.toString();
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
      return '${parts[0]}/${parts[1]}/${parts[2]}';
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
      backgroundColor: Color(0xFFECF0F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chờ hoàn tiền',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
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
          Text('Vui lòng đăng nhập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Đăng nhập để xem đơn chờ hoàn tiền', style: TextStyle(color: Color(0xFF7F8C8D))),
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
          Text('Có lỗi xảy ra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF7F8C8D))),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadRefundOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC44536),
              foregroundColor: Colors.white,
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
          Text('Chưa có đơn chờ hoàn tiền', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Các đơn đã hủy sẽ hiển thị ở đây', style: TextStyle(color: Color(0xFF7F8C8D))),
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
      return '${parts[0]}/${parts[1]}/${parts[2]}';
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
    final tenCoSo = order['ten_co_so'] as String? ?? '';
    final diaChiCoSo = order['dia_chi_co_so'] as String? ?? '';
    final maDon = order['ma_don'] as String? ?? '';
    final ngayDat = _formatDate(order['ngay_dat'] as String? ?? '');
    final ngayYeuCauHuy = _formatTimestamp(order['ngay_yeu_cau_huy'] as Timestamp?);
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;
    final soTienHoan = (tongTien * 0.8).toInt();
    final daHoanTien = order['da_hoan_tien'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tenCoSo,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: daHoanTien ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        daHoanTien ? 'Đã hoàn' : 'Chờ xử lý',
                        style: TextStyle(
                          color: daHoanTien ? Colors.green : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(diaChiCoSo, style: TextStyle(fontSize: 13, color: Colors.grey)),
                Divider(height: 24),

                // Thông tin
                Row(
                  children: [
                    Expanded(child: _buildInfo('Mã đơn', '#${maDon.substring(0, 8).toUpperCase()}')),
                    Expanded(child: _buildInfo('Ngày đặt', ngayDat)),
                    Expanded(child: _buildInfo('Ngày hủy', ngayYeuCauHuy)),
                  ],
                ),
                SizedBox(height: 12),

                // Tiền
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tổng tiền', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${_formatCurrency(tongTien)}đ', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Hoàn (80%)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('${_formatCurrency(soTienHoan)}đ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
      return '${parts[0]}/${parts[1]}/${parts[2]}';
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Chi tiết hoàn tiền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trạng thái
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: daHoanTien ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(daHoanTien ? Icons.check_circle : Icons.hourglass_empty,
                            color: daHoanTien ? Colors.green : Colors.orange, size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(daHoanTien ? 'Đã hoàn tiền' : 'Chờ xử lý',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(daHoanTien ? 'Đã hoàn vào tài khoản' : 'CSKH sẽ liên hệ sớm',
                                  style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  _buildSection('Thông tin đơn hàng', [
                    _buildRow('Mã đơn', '#${order['ma_don']}'),
                    _buildRow('Tên cơ sở', order['ten_co_so'] ?? ''),
                    _buildRow('Địa chỉ', order['dia_chi_co_so'] ?? ''),
                    _buildRow('Ngày đặt', _formatDate(order['ngay_dat'] ?? '')),
                    _buildRow('Ngày hủy', _formatTimestamp(order['ngay_yeu_cau_huy'])),
                  ]),

                  SizedBox(height: 16),

                  _buildSection('Thông tin người đặt', [
                    _buildRow('Tên', order['ten_nguoi_dat'] ?? ''),
                    _buildRow('SĐT', order['sdt'] ?? ''),
                  ]),

                  SizedBox(height: 16),

                  _buildSection('Thông tin tiền', [
                    _buildRow('Tổng tiền', '${_formatCurrency(tongTien)}đ'),
                    _buildRow('Hoàn (80%)', '${_formatCurrency(soTienHoan)}đ', highlight: true),
                    if (daHoanTien) _buildRow('Thời gian hoàn', _formatTimestamp(order['time_hoan_tien'])),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.orange : Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}