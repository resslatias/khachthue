import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:khachthue/subpage/sub_in_home/sub_coso_datsan/thanhtoan.dart';

class BeforPage extends StatefulWidget {
  const BeforPage({super.key});

  @override
  State<BeforPage> createState() => _BeforPageState();
}

class _BeforPageState extends State<BeforPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot> _donDatStream;

  @override
  void initState() {
    super.initState();
    _donDatStream = _getDonDatStream();
  }

  Stream<QuerySnapshot> _getDonDatStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('lich_su_khach')
        .doc(user.uid)
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
          const Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Vui lòng đăng nhập để xem lịch sử đặt sân',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Có thể điều hướng đến trang đăng nhập ở đây
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử đặt sân')),
        body: _buildLoginRequired(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử đặt sân'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _donDatStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có đơn đặt sân nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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

              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool isExpanded = false;
  List<Map<String, dynamic>> chiTietList = [];

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
      });
    } catch (e) {
      debugPrint('Lỗi load chi tiết: $e');
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
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 4),
          Text(
            'Đã thanh toán',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
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
          // Chưa thanh toán và chưa hết hạn - hiển thị countdown
          return _CountdownTimer(timeup: timeout);
        } else {
          // Đã hết hạn - hiển thị đã hủy
          return Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 4),
              Text(
                'Đã hủy',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }
      }
    }

    return Row(
      children: [
        Icon(Icons.pending, color: Colors.orange.shade700, size: 16),
        const SizedBox(width: 4),
        Text(
          'Chưa thanh toán',
          style: TextStyle(
            color: Colors.orange.shade700,
            fontWeight: FontWeight.bold,
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
    final ngayDat = _formatDate(order['ngay_dat'] as String? ?? '');
    final tongTien = (order['tong_tien'] as num?)?.toInt() ?? 0;
    final trangThai = order['trang_thai'] as String? ?? 'chua_thanh_toan';
    final timeup = order['timeup'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sports_tennis,
            color: Colors.green.shade700,
            size: 20,
          ),
        ),
        title: Text(
          tenCoSo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Mã đơn: ${maDon.substring(0, 8)}...'),
            Text('Ngày đặt: $ngayDat'),
            Text('Tổng tiền: ${_formatCurrency(tongTien)}đ'),
            const SizedBox(height: 4),
            _buildStatusWidget(),
          ],
        ),
        trailing: trangThai == 'chua_thanh_toan' &&
            timeup != null &&
            timeup.toDate().isAfter(DateTime.now())
            ? ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ThanhToanPage(maDon: maDon),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            'Thanh toán',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        )
            : null,
        onExpansionChanged: (expanded) {
          setState(() {
            isExpanded = expanded;
          });
        },
        children: [
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiết đặt sân:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (chiTietList.isEmpty)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else
                    ...chiTietList.map((detail) {
                      final maSan = detail['ma_san'] as String? ?? '';
                      final gio = detail['gio'] as String? ?? '';
                      final gia = (detail['gia'] as num?)?.toInt() ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.sports_tennis,
                                color: Colors.white,
                                size: 16,
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
            ),
          ],
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
      return 'Còn $hours:$minutes:$seconds';
    } else {
      return 'Còn $minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.access_time, color: Colors.orange.shade700, size: 16),
        const SizedBox(width: 4),
        Text(
          _formatDuration(_remainingTime),
          style: TextStyle(
            color: Colors.orange.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}