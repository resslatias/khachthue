import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khachthue/subpage/sub_in_home/sub_coso_datsan/thanhtoan.dart';

class BeforPage extends StatelessWidget {
  const BeforPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFC44536)));
        }
        final user = snapshot.data;
        return _BeforPageView(user: user);
      },
    );
  }
}

class _BeforPageView extends StatefulWidget {
  final User? user;

  const _BeforPageView({this.user});

  @override
  State<_BeforPageView> createState() => _BeforPageViewState();
}

class _BeforPageViewState extends State<_BeforPageView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _donDatStream;

  @override
  void initState() {
    super.initState();
    _donDatStream = _getDonDatStream();
  }

  @override
  void didUpdateWidget(_BeforPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cập nhật stream khi user thay đổi
    if (oldWidget.user?.uid != widget.user?.uid) {
      setState(() {
        _donDatStream = _getDonDatStream();
      });
    }
  }

  Stream<QuerySnapshot> _getDonDatStream() {
    if (widget.user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('lich_su_khach')
        .doc(widget.user!.uid)
        .collection('don_dat')
        .orderBy('ngay_tao', descending: true)
        .snapshots();
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

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 60, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
            'Vui lòng đăng nhập để xem lịch sử đặt sân',
            style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailBottomSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Icon(Icons.history, color: Color(0xFFC44536), size: 24),
                SizedBox(width: 8),
                Text(
                  'Lịch sử đặt sân',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLoginRequired()),
        ],
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Icon(Icons.history, color: Color(0xFFC44536), size: 24),
              SizedBox(width: 8),
              Text(
                'Lịch sử đặt sân',
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
            stream: _donDatStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
                      SizedBox(height: 16),
                      Text(
                        'Lỗi: ${snapshot.error}',
                        style: TextStyle(color: Color(0xFF7F8C8D)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: Color(0xFFC44536)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 60, color: Color(0xFFBDC3C7)),
                      SizedBox(height: 16),
                      Text(
                        'Chưa có đơn đặt sân nào',
                        style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
                      ),
                    ],
                  ),
                );
              }

              final orders = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final order = doc.data() as Map<String, dynamic>;

                  return _OrderCard(
                    order: order,
                    onTap: () => _showOrderDetail(order),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

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

  Widget _buildStatusWidget() {
    final trangThai = order['trang_thai'] as String? ?? 'chua_thanh_toan';
    final timeup = order['timeup'] as Timestamp?;

    if (trangThai == 'da_thanh_toan') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Color(0xFF2E8B57).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF2E8B57)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E8B57), size: 16),
            const SizedBox(width: 4),
            Text(
              'Đã thanh toán',
              style: TextStyle(
                color: Color(0xFF2E8B57),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (trangThai == 'chua_thanh_toan') {
      if (timeup != null) {
        final now = DateTime.now();
        final timeout = timeup.toDate();

        if (timeout.isAfter(now)) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFF39C12).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFFF39C12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: Color(0xFFF39C12), size: 16),
                const SizedBox(width: 4),
                Text(
                  'Chưa thanh toán',
                  style: TextStyle(
                    color: Color(0xFFF39C12),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFE74C3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFFE74C3C)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, color: Color(0xFFE74C3C), size: 16),
                const SizedBox(width: 4),
                Text(
                  'Đã hủy',
                  style: TextStyle(
                    color: Color(0xFFE74C3C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0xFFF39C12).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFFF39C12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending, color: Color(0xFFF39C12), size: 16),
          const SizedBox(width: 4),
          Text(
            'Chưa thanh toán',
            style: TextStyle(
              color: Color(0xFFF39C12),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maDon = order['ma_don'] as String? ?? '';
    final tenCoSo = order['ten_co_so'] as String? ?? '';
    final diaChiCoSo = order['dia_chi_co_so'] as String? ?? '';
    final ngayDat = _formatDate(order['ngay_dat'] as String? ?? '');
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(0xFFC44536).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.sports_tennis,
                        color: Color(0xFFC44536),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenCoSo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF2C3E50),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Color(0xFF7F8C8D)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  diaChiCoSo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mã đơn:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          Text(
                            '#${maDon.substring(0, 8).toUpperCase()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ngày đặt:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          Text(
                            ngayDat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng tiền:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          Text(
                            '${_formatCurrency(tongTien)}đ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC44536),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusWidget(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFFBDC3C7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> order;

  const _OrderDetailBottomSheet({required this.order});

  @override
  State<_OrderDetailBottomSheet> createState() => _OrderDetailBottomSheetState();
}

class _OrderDetailBottomSheetState extends State<_OrderDetailBottomSheet> {
  List<Map<String, dynamic>> chiTietList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chi_tiet_dat')
          .doc(widget.order['ma_don'])
          .collection('danh_sach')
          .get();

      setState(() {
        chiTietList = snapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Lỗi load chi tiết: $e');
      setState(() {
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

  Widget _buildStatusWidget() {
    final trangThai = widget.order['trang_thai'] as String? ?? 'chua_thanh_toan';
    final timeup = widget.order['timeup'] as Timestamp?;

    if (trangThai == 'da_thanh_toan') {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2E8B57), size: 20),
          const SizedBox(width: 8),
          Text(
            'Đã thanh toán',
            style: TextStyle(
              color: Color(0xFF2E8B57),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    if (trangThai == 'chua_thanh_toan') {
      if (timeup != null) {
        final now = DateTime.now();
        final timeout = timeup.toDate();

        if (timeout.isAfter(now)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, color: Color(0xFFF39C12), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Chưa thanh toán',
                    style: TextStyle(
                      color: Color(0xFFF39C12),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CountdownTimer(timeup: timeout),
            ],
          );
        } else {
          return Row(
            children: [
              Icon(Icons.cancel, color: Color(0xFFE74C3C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Đã hủy',
                style: TextStyle(
                  color: Color(0xFFE74C3C),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          );
        }
      }
    }

    return Row(
      children: [
        Icon(Icons.pending, color: Color(0xFFF39C12), size: 20),
        const SizedBox(width: 8),
        Text(
          'Chưa thanh toán',
          style: TextStyle(
            color: Color(0xFFF39C12),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final maDon = order['ma_don'] as String? ?? '';
    final tenCoSo = order['ten_co_so'] as String? ?? '';
    final diaChiCoSo = order['dia_chi_co_so'] as String? ?? '';
    final ngayDat = _formatDate(order['ngay_dat'] as String? ?? '');
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;
    final trangThai = order['trang_thai'] as String? ?? 'chua_thanh_toan';
    final timeup = order['timeup'] as Timestamp?;

    final canPay = trangThai == 'chua_thanh_toan' &&
        timeup != null &&
        timeup.toDate().isAfter(DateTime.now());

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFBDC3C7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(0xFFC44536).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sports_tennis,
                            color: Color(0xFFC44536),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenCoSo,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Color(0xFF7F8C8D)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      diaChiCoSo,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF7F8C8D),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(color: Color(0xFFECF0F1)),
                    const SizedBox(height: 20),

                    // Thông tin đơn
                    Text(
                      'Thông tin đơn đặt',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow('Mã đơn', '#${maDon.toUpperCase()}'),
                    _buildInfoRow('Ngày đặt', ngayDat),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trạng thái:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                        _buildStatusWidget(),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: Color(0xFFECF0F1)),
                    const SizedBox(height: 20),

                    // Chi tiết sân đặt
                    Text(
                      'Chi tiết sân đặt',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Color(0xFFC44536)),
                        ),
                      )
                    else if (chiTietList.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Không có chi tiết',
                            style: TextStyle(color: Color(0xFF7F8C8D)),
                          ),
                        ),
                      )
                    else
                      ...chiTietList.map((detail) {
                        final maSan = detail['ma_san'] as String? ?? '';
                        final gio = detail['gio'] as String? ?? '';
                        final gia = (detail['gia'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Color(0xFFC44536).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFC44536).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFFC44536),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.sports_tennis,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      maSan.toUpperCase().replaceAll('SAN', 'Sân '),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Color(0xFF7F8C8D),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          gio,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF7F8C8D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${_formatCurrency(gia)}đ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC44536),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 20),

                    // Tổng tiền
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFECF0F1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng thanh toán:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
                    ),

                    const SizedBox(height: 20),

                    // Nút thanh toán
                    if (canPay)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThanhToanPage(maDon: maDon),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFC44536),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Đi tới thanh toán',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF7F8C8D),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime timeup;

  const _CountdownTimer({required this.timeup});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });
      }
    });
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();
    if (now.isAfter(widget.timeup)) {
      _remainingTime = Duration.zero;
      _timer.cancel();
    } else {
      _remainingTime = widget.timeup.difference(now);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF39C12).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFF39C12).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: Color(0xFFF39C12), size: 18),
          const SizedBox(width: 8),
          Text(
            'Còn ${_formatDuration(_remainingTime)}',
            style: TextStyle(
              color: Color(0xFFF39C12),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}