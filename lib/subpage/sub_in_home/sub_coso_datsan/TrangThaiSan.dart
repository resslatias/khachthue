import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'OrderHashHelper.dart';
import 'thanhtoan.dart';

class TrangThaiSan extends StatefulWidget {
  final String coSoId;
  final Map<String, dynamic> coSoData;

  const TrangThaiSan({
    Key? key,
    required this.coSoId,
    required this.coSoData,
  }) : super(key: key);

  @override
  State<TrangThaiSan> createState() => _TrangThaiSanState();
}

class _TrangThaiSanState extends State<TrangThaiSan> with WidgetsBindingObserver {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  DateTime selectedDate = DateTime.now();
  List<int> hours = [];
  int soSan = 4;
  Map<int, List<int>> states = {};
  List<Map<String, dynamic>> pendingChanges = [];
  StreamSubscription<QuerySnapshot>? subscription;
  Timer? _rollbackTimer;
  bool isLoading = true;

  String formatDate(DateTime date) => DateFormat('dd_MM_yyyy').format(date);
  String displayDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  bool isPastHour(int hour) {
    final now = DateTime.now();
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return hour < now.hour;
    }
    return false;
  }

  String getHourLabel(int hour) {
    int nextHour = hour + 1;
    return "$hour-${nextHour}h";
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.red.shade400;
      default:
        return Colors.green.shade300;
    }
  }

  int getPriceForHour(int hour) {
    final bangGia = widget.coSoData['bang_gia'] as List<dynamic>?;
    if (bangGia == null || hour >= bangGia.length) return 0;
    final price = bangGia[hour];
    return price is int ? price : (price as num).toInt();
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    soSan = (widget.coSoData['so_san'] as num?)?.toInt() ?? 4;
    final gioMo = int.tryParse((widget.coSoData['gio_mo_cua'] as String?)?.split(':')[0] ?? '6') ?? 6;
    final gioDong = int.tryParse((widget.coSoData['gio_dong_cua'] as String?)?.split(':')[0] ?? '22') ?? 22;
    hours = List.generate(gioDong - gioMo, (i) => gioMo + i);

    // 🆕 THÊM DÒNG NÀY: DỌN DẸP KHI VÀO TRANG
    await _cleanupAllExpiredCourts();

    await ensureDayDataExists(formatDate(selectedDate));
    setupListeners();

    setState(() => isLoading = false);
  }

  Future<void> ensureDayDataExists(String datePath) async {
    final dateRef = firestore
        .collection("dat_san")
        .doc(widget.coSoId)
        .collection(datePath);

    try {
      final snapshot = await dateRef.limit(1).get();

      if (snapshot.docs.isEmpty) {
        WriteBatch batch = firestore.batch();
        for (int hour in hours) {
          final ref = dateRef.doc("${hour.toString().padLeft(2, '0')}:00");
          Map<String, dynamic> data = {};
          for (int i = 1; i <= soSan; i++) {
            data['san$i'] = 1;
          }
          batch.set(ref, data);
        }
        await batch.commit();
        debugPrint("✅ Đã tạo dữ liệu cho ngày $datePath");
      }
    } catch (e) {
      debugPrint("🔥 Lỗi ensureDayDataExists: $e");
    }
  }

  void setupListeners() {
    subscription?.cancel();

    String dayPath = formatDate(selectedDate);

    subscription = firestore
        .collection("dat_san")
        .doc(widget.coSoId)
        .collection(dayPath)
        .snapshots()
        .listen((snapshot) {
      // 🆕 THÊM DÒNG NÀY: DỌN DẸP REAL-TIME MỖI KHI CÓ DATA THAY ĐỔI
      _checkAndResetTimeouts(snapshot);
      // 🆕 (TÙY CHỌN) Có thể thêm dọn dẹp toàn diện nếu cần
      // _cleanupAllExpiredCourts();

      states.clear();
      for (var doc in snapshot.docs) {
        int hh = int.parse(doc.id.split(':')[0]);
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        List<int> sanStates = [];
        for (int i = 1; i <= soSan; i++) {
          sanStates.add(data['san$i'] ?? 1);
        }
        states[hh] = sanStates;
      }
      if (mounted) setState(() {});
    }, onError: (e) {
      debugPrint("Lỗi listener: $e");
    });
  }

  // QUAN TRỌNG: Hàm kiểm tra và reset timeouts
  // SỬA: Chỉ reset trạng thái 2, không reset trạng thái 3
  Future<void> _checkAndResetTimeouts(QuerySnapshot snapshot) async {
    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      for (int i = 1; i <= soSan; i++) {
        String sanKey = 'san$i';
        String tempTimeupKey = '${sanKey}_temp_timeup';
        String paymentTimeupKey = '${sanKey}_payment_timeup';

        int currentStatus = data[sanKey] ?? 1;

        // 🆕 XỬ LÝ TRẠNG THÁI 2: Kiểm tra temp_timeup
        if (currentStatus == 2 && data[tempTimeupKey] != null) {
          Timestamp tempTimeup = data[tempTimeupKey] as Timestamp;
          if (tempTimeup.toDate().isBefore(now)) {
            try {
              await doc.reference.update({
                sanKey: 1,
                tempTimeupKey: null,
              });
              debugPrint("✅ Đã reset sân $sanKey (2→1) - xóa temp_timeup");
            } catch (e) {
              debugPrint("🔥 Lỗi reset temp_timeup: $e");
            }
          }
        }

        // 🆕 XỬ LÝ TRẠNG THÁI 3: Kiểm tra payment_timeup (thời gian kết thúc sân)
        if (currentStatus == 3 && data[paymentTimeupKey] != null) {
          Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
          if (paymentTimeup.toDate().isBefore(now)) {
            try {
              // Reset về 1 nhưng GIỮ NGUYÊN payment_timeup (lịch sử)
              await doc.reference.update({
                sanKey: 1,
              });
              debugPrint("✅ Đã reset sân $sanKey (3→1) - hết giờ sân");
            } catch (e) {
              debugPrint("🔥 Lỗi reset payment_timeup: $e");
            }
          }
        }
      }
    }
  }

  // QUAN TRỌNG: Hàm đặt sân với timeup management
  Future<void> datSan(int hour, int index) async {
    String datePath = formatDate(selectedDate);
    String hourPath = "${hour.toString().padLeft(2, '0')}:00";
    String sanKey = "san${index + 1}";
    String tempTimeupKey = "${sanKey}_temp_timeup"; // 🆕 Timeup cho trạng thái 2
    String paymentTimeupKey = "${sanKey}_payment_timeup"; // 🆕 Timeup cho trạng thái 3

    final ref = firestore
        .collection("dat_san")
        .doc(widget.coSoId)
        .collection(datePath)
        .doc(hourPath);

    try {
      final docSnapshot = await ref.get();
      Map<String, dynamic> data = docSnapshot.data() ?? {};
      int current = data[sanKey] ?? 1;

      // 🔄 XỬ LÝ TRẠNG THÁI 3: Reset nếu hết hạn
      if (current == 3 && data[paymentTimeupKey] != null) {
        Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
        if (paymentTimeup.toDate().isBefore(DateTime.now())) {
          // 3 → 1, GIỮ NGUYÊN payment_timeup (không xóa)
          await ref.update({sanKey: 1});
          current = 1;
          debugPrint("✅ Đã reset sân $sanKey (3→1) - giữ payment_timeup");
        }
      }

      // 🔄 XỬ LÝ TRẠNG THÁI 2: Reset nếu hết hạn
      if (current == 2 && data[tempTimeupKey] != null) {
        Timestamp tempTimeup = data[tempTimeupKey] as Timestamp;
        if (tempTimeup.toDate().isBefore(DateTime.now())) {
          // 2 → 1, XÓA temp_timeup
          await ref.update({sanKey: 1, tempTimeupKey: null});
          current = 1;
          debugPrint("✅ Đã reset sân $sanKey (2→1) - xóa temp_timeup");
        }
      }

      // ❌ TRẠNG THÁI 3: Đã đặt - không thể chọn
      if (current == 3) {
        _showSnackBar('Sân này đã được đặt', Colors.red);
        return;
      }

      // 🔄 TRẠNG THÁI 2: Đang được chọn
      if (current == 2) {
        bool isMyPending = pendingChanges.any(
                (p) => p['hour'] == hour && p['san'] == index
        );

        if (isMyPending) {
          // Hủy chọn sân của chính mình: 2 → 1 + xóa temp_timeup
          await ref.update({sanKey: 1, tempTimeupKey: null});
          pendingChanges.removeWhere(
                  (p) => p['hour'] == hour && p['san'] == index
          );
        } else {
          _showSnackBar('Sân này vừa được chọn bởi người khác', Colors.orange);
          return;
        }
      }
      // ✅ TRẠNG THÁI 1: Trống - có thể đặt
      else if (current == 1) {
        // Đặt trạng thái 2 với temp_timeup 5 phút
        DateTime fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
        await ref.update({
          sanKey: 2,
          tempTimeupKey: Timestamp.fromDate(fiveMinutesFromNow), // 🆕 Tạo temp_timeup
        });

        pendingChanges.add({
          'hour': hour,
          'san': index,
          'ref': ref,
          'sanKey': sanKey,
          'tempTimeupKey': tempTimeupKey, // 🆕
          'paymentTimeupKey': paymentTimeupKey, // 🆕
        });
      }

      setState(() {});

      // ⏰ Quản lý rollback timer
      if (pendingChanges.isEmpty) {
        _rollbackTimer?.cancel();
      } else {
        _startRollbackTimer();
      }
    } catch (e) {
      debugPrint("Lỗi datSan: $e");
      _showSnackBar("Lỗi đặt sân: $e", Colors.red);
    }
  }

  void _startRollbackTimer() {
    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(minutes: 5), () async {
      await rollbackPending();
      setState(() {});
    });
  }

  // 🆕 CẬP NHẬT HÀM rollbackPending - CHỈ rollback trạng thái 2
  Future<void> rollbackPending() async {
    if (pendingChanges.isEmpty) return;

    debugPrint("🔄 Đang rollback ${pendingChanges.length} sân đang chọn...");

    for (var p in pendingChanges) {
      String sanKey = p['sanKey'];
      String tempTimeupKey = p['tempTimeupKey'];

      try {
        // 🎯 QUAN TRỌNG: Chỉ rollback trạng thái 2 → 1 và xóa temp_timeup
        await (p['ref'] as DocumentReference).update({
          sanKey: 1,
          tempTimeupKey: null, // Xóa temp_timeup
        });
        debugPrint("✅ Đã rollback $sanKey: 2→1, xóa temp_timeup");
      } catch (e) {
        debugPrint("❌ Lỗi rollback $sanKey: $e");
      }
    }

    pendingChanges.clear();
    _rollbackTimer?.cancel();
    debugPrint("✅ Rollback hoàn tất");
  }

  Future<void> confirmAll() async {
    if (pendingChanges.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Chưa chọn sân"),
          content: const Text("Vui lòng chọn ít nhất một sân trước khi xác nhận."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    bool hasConflict = false;
    List<Map<String, dynamic>> validChanges = [];

    // 🔍 KIỂM TRA TRẠNG THÁI SÂN TRƯỚC KHI XÁC NHẬN
    for (var p in pendingChanges) {
      String datePath = formatDate(selectedDate);
      String hourPath = "${(p['hour'] as int).toString().padLeft(2, '0')}:00";

      final docSnapshot = await firestore
          .collection("dat_san")
          .doc(widget.coSoId)
          .collection(datePath)
          .doc(hourPath)
          .get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        int current = data[p['sanKey']] ?? 1;

        // 🚫 CHỈ KIỂM TRA TRẠNG THÁI, KHÔNG KIỂM TRA TIMEOUT
        if (current == 3) {
          hasConflict = true;
          debugPrint("❌ Conflict: ${p['sanKey']} đã là trạng thái 3");
        } else if (current == 2) {
          validChanges.add(p);
          debugPrint("✅ Valid: ${p['sanKey']} là trạng thái 2");
        } else {
          debugPrint("ℹ️ ${p['sanKey']} là trạng thái $current - bỏ qua");
        }
      }
    }

    // ❌ XỬ LÝ CONFLICT
    if (hasConflict) {
      _showSnackBar('Một số sân đã được đặt. Vui lòng chọn lại.', Colors.red);
      await rollbackPending();
      setState(() {});
      return;
    }

    // ❌ KHÔNG CÓ SÂN HỢP LỆ
    if (validChanges.isEmpty) {
      _showSnackBar('Không có sân hợp lệ để đặt', Colors.red);
      return;
    }

    // 💰 TÍNH TỔNG TIỀN
    int tongTien = 0;
    for (var p in validChanges) {
      tongTien += getPriceForHour(p['hour']);
    }

    String dateStr = displayDate(selectedDate);
    String selectedInfo = validChanges
        .map((p) => "Sân ${p['san'] + 1} lúc ${p['hour']}-${p['hour'] + 1}h (${_formatCurrency(getPriceForHour(p['hour']))}đ)")
        .join("\n");

    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    // 📝 DIALOG XÁC NHẬN THÔNG TIN
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(Icons.sports_tennis, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text("Xác nhận đặt sân"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.coSoData['ten'] as String? ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Ngày: $dateStr"),
                    const Divider(),
                    Text(
                      "Danh sách đặt:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(selectedInfo, style: const TextStyle(fontSize: 13)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Tổng tiền:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${_formatCurrency(tongTien)}đ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Tên người đặt *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Số điện thoại *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  prefixIcon: const Icon(Icons.phone),
                  hintText: "0xxxxxxxxx",
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () {
              String name = nameController.text.trim();
              String phone = phoneController.text.trim();

              if (name.isEmpty) {
                _showSnackBar("Vui lòng nhập tên người đặt", Colors.orange);
                return;
              }

              if (phone.isEmpty) {
                _showSnackBar("Vui lòng nhập số điện thoại", Colors.orange);
                return;
              }

              if (!RegExp(r'^(03|05|07|08|09)\d{8}$').hasMatch(phone)) {
                _showSnackBar(
                  "Số điện thoại không hợp lệ. Vui lòng nhập số di động 10 số (03x, 05x, 07x, 08x, 09x)",
                  Colors.orange,
                );
                return;
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // 🚀 XỬ LÝ KẾT QUẢ XÁC NHẬN
    if (confirmed == true) {
      await _processBooking(
        nameController.text.trim(),
        phoneController.text.trim(),
        validChanges,
        tongTien,
      );
    } else {
      await rollbackPending(); // CHỈ rollback trạng thái 2
    }

    pendingChanges.clear();
    setState(() {});
  }

  // QUAN TRỌNG: Hàm xử lý đặt sân - giữ nguyên timeup
  Future<void> _processBooking(
      String name,
      String phone,
      List<Map<String, dynamic>> validChanges,
      int tongTien,
      ) async {
    if (!mounted) return;

    // 🚫 BỎ HIỂN THỊ LOADING DIALOG

    try {
      String ngayDat = formatDate(selectedDate);
      String userId = auth.currentUser?.uid ?? 'khachquaduong';

      // 🆔 TẠO MÃ ĐƠN HÀNG DUY NHẤT
      final donDatRef = await firestore.collection('temp_order').add({'temp': true});
      String maDon = donDatRef.id;
      await donDatRef.delete();

      debugPrint("✅ Đang xử lý đơn hàng: $maDon");

      // ⏰ TÍNH THỜI GIAN TIMEOUT CHO THANH TOÁN (15 phút)
      DateTime timeoutTime = DateTime.now().add(const Duration(minutes: 15));
      Timestamp timeoutTimestamp = Timestamp.fromDate(timeoutTime);

      List<Map<String, dynamic>> danhSachDat = [];

      // 🔄 CẬP NHẬT TRẠNG THÁI SÂN: 2 → 3
      for (var p in validChanges) {
        String sanKey = p['sanKey'];
        String tempTimeupKey = p['tempTimeupKey'];
        String paymentTimeupKey = p['paymentTimeupKey'];
        String hourPath = "${(p['hour'] as int).toString().padLeft(2, '0')}:00";

        // 🎯 QUAN TRỌNG: Chỉ cập nhật trạng thái, không reset timeup
        await (p['ref'] as DocumentReference).update({
          sanKey: 3, // 2 → 3
          tempTimeupKey: null, // 🆕 XÓA temp_timeup
          paymentTimeupKey: timeoutTimestamp, // 🆕 TẠO payment_timeup mới
        });

        debugPrint("✅ Đã cập nhật ${p['sanKey']}: 2→3");

        danhSachDat.add({
          'ma_san': sanKey,
          'gio': hourPath,
          'ngay_dat': ngayDat,
          'gia': getPriceForHour(p['hour']),
        });
      }
      final orderHash = OrderHashHelper.generateHash(userId, maDon);
      debugPrint("✅ Order hash: $orderHash");

      // ⭐ LƯU LOOKUP (mapping hash → userId + maDon)
      await firestore.collection('order_lookup').doc(orderHash).set({
        'user_id': userId,
        'ma_don': maDon,
        'created_at': FieldValue.serverTimestamp(),
        'trang_thai': 'chua_thanh_toan',
      });
      debugPrint("✅ Đã lưu order_lookup/$orderHash");


      debugPrint("✅ Đã update trạng thái sân");

      // 💾 LƯU ĐƠN HÀNG VÀO LỊCH SỬ KHÁCH
      Map<String, dynamic> donDatDataKhach = {
        'ma_don': maDon,
        'co_so_id': widget.coSoId,
        'ten_co_so': widget.coSoData['ten'] ?? '',
        'dia_chi_co_so': '${widget.coSoData['dia_chi_chi_tiet'] ?? ''}, ${widget.coSoData['xa'] ?? ''}, ${widget.coSoData['huyen'] ?? ''}, ${widget.coSoData['tinh'] ?? ''}',
        'ten_nguoi_dat': name,
        'sdt': phone,
        'ngay_tao': FieldValue.serverTimestamp(),
        'tong_tien': tongTien,
        'trang_thai': 'chua_thanh_toan',
        'ngay_dat': ngayDat,
        'timeup': timeoutTimestamp,
        'order_hash': orderHash,
      };

      await firestore
          .collection('lich_su_khach')
          .doc(userId)
          .collection('don_dat')
          .doc(maDon)
          .set(donDatDataKhach);

      debugPrint("✅ Đã lưu vào lich_su_khach");

      // 💾 LƯU ĐƠN HÀNG VÀO LỊCH SỬ SÂN
      Map<String, dynamic> donDatDataSan = {
        'ma_don': maDon,
        'user_id_dat': userId,
        'ten_co_so': widget.coSoData['ten'] ?? '',
        'dia_chi_co_so': '${widget.coSoData['dia_chi_chi_tiet'] ?? ''}, ${widget.coSoData['xa'] ?? ''}, ${widget.coSoData['huyen'] ?? ''}, ${widget.coSoData['tinh'] ?? ''}',
        'ten_nguoi_dat': name,
        'sdt': phone,
        'ngay_tao': FieldValue.serverTimestamp(),
        'tong_tien': tongTien,
        'trang_thai': 'chua_thanh_toan',
        'ngay_dat': ngayDat,
        'timeup': timeoutTimestamp,
      };

      await firestore
          .collection('lich_su_san')
          .doc(widget.coSoId)
          .collection('khach_dat')
          .doc(maDon)
          .set(donDatDataSan);

      debugPrint("✅ Đã lưu vào lich_su_san");

      // 💾 LƯU CHI TIẾT ĐẶT SÂN
      WriteBatch batch = firestore.batch();
      for (var detail in danhSachDat) {
        final detailRef = firestore
            .collection('chi_tiet_dat')
            .doc(maDon)
            .collection('danh_sach')
            .doc();
        batch.set(detailRef, {...detail, 'co_so_id': widget.coSoId});
      }
      await batch.commit();

      debugPrint("✅ Đã lưu chi tiết đặt");

      // 🔔 TẠO THÔNG BÁO
      String danhSachSan = validChanges
          .map((p) => "Sân ${p['san'] + 1} lúc ${p['hour']}-${p['hour'] + 1}h")
          .join(", ");

      await firestore
          .collection('thong_bao')
          .doc(userId)
          .collection('notifications')
          .add({
        'tieu_de': 'Đặt sân thành công',
        'noi_dung': 'Bạn đã đặt $danhSachSan tại ${widget.coSoData['ten']}',
        'da_xem_chua': false,
        'Urlweb': null,
        'Urlimage': null,
        'ngay_tao': FieldValue.serverTimestamp(),
      });

      // 🎉 HOÀN TẤT - DỌN DẸP
      _rollbackTimer?.cancel();

      if (mounted) {
        _showSnackBar('Đặt sân thành công!', Colors.green);
      }

      // 🚀 CHUYỂN TRANG THANH TOÁN NGAY - KHÔNG DELAY
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ThanhToanPage(maDon: maDon),
          ),
        );
      }

    } catch (e, stackTrace) {
      debugPrint("🔥 Lỗi confirm: $e");
      debugPrint("Stack trace: $stackTrace");

      if (mounted) {
        _showSnackBar("Lỗi xác nhận: $e", Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Khi app chuyển sang background, rollback trạng thái 2
      if (pendingChanges.isNotEmpty) {
        debugPrint("🔄 App background - tự động rollback trạng thái 2");
        rollbackPending();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    _rollbackTimer?.cancel();

    // 🆕 Khi dispose, rollback trạng thái 2 (an toàn)
    if (pendingChanges.isNotEmpty) {
      debugPrint("🔄 Dispose - tự động rollback trạng thái 2");
      rollbackPending();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Trạng thái sân"),
          backgroundColor: Colors.green.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 🆕 THÊM WILLPOP SCOPE ĐỂ BẮT SỰ KIỆN BACK
    return WillPopScope(
      onWillPop: () async {
        await _handleBackPressed();
        return true; // Cho phép back sau khi xử lý xong
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.coSoData['ten'] as String? ?? "Trạng thái sân",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: Colors.green.shade700,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.green.shade700, Colors.green.shade50],
              stops: const [0.0, 0.2],
            ),
          ),
          child: Column(
            children: [
              _buildDateSelector(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildLegend(),
                      Expanded(child: _buildCourtTable()),
                      _buildBottomBar(),
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

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: InkWell(
        onTap: () async {
          DateTime today = DateTime.now();
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(today.year, today.month, today.day),
            lastDate: DateTime(2030),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.green.shade700,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked != null && picked != selectedDate) {
            await rollbackPending();
            setState(() {
              selectedDate = picked;
              states = {};
              pendingChanges.clear();
              isLoading = true;
            });
            await ensureDayDataExists(formatDate(picked));
            setupListeners();
            setState(() => isLoading = false);
            _showSnackBar('Đã chuyển sang ngày ${displayDate(picked)}. Hãy chọn lại sân.', Colors.blue);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayDate(selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _LegendItem(color: Colors.green.shade300, text: "Trống"),
          _LegendItem(color: Colors.orange.shade400, text: "Đang chọn"),
          _LegendItem(color: Colors.red.shade400, text: "Đã đặt"),
        ],
      ),
    );
  }

  Widget _buildCourtTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildHeaderCell("Thời gian", flex: 2),
                  for (int i = 1; i <= soSan; i++)
                    _buildHeaderCell("Sân $i", flex: 2),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: hours.map((hour) {
                    bool past = isPastHour(hour);
                    List<int> sanStates = states[hour] ?? List.filled(soSan, 1);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildHourCell(hour),
                          for (int i = 0; i < soSan; i++)
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTap: past ? null : () => datSan(hour, i),
                                child: Container(
                                  height: 48,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: past
                                        ? Colors.grey.shade400
                                        : getStatusColor(sanStates[i]),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: past
                                      ? const Icon(Icons.block, color: Colors.white70)
                                      : Text(
                                    sanStates[i] == 3
                                        ? '✓'
                                        : sanStates[i].toString(),
                                    style: TextStyle(
                                      color: sanStates[i] == 3
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                      sanStates[i] == 3 ? 20 : 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildHourCell(int hour) {
    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          getHourLabel(hour),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    int tongTien = 0;
    for (var p in pendingChanges) {
      tongTien += getPriceForHour(p['hour']);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingChanges.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã chọn: ${pendingChanges.length} sân',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tạm tính: ${_formatCurrency(tongTien)}đ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await rollbackPending();
                        setState(() {});
                        _showSnackBar('Đã hủy chọn', Colors.grey);
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Hủy chọn'),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: confirmAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 3,
                ),
                child: Text(
                  pendingChanges.isEmpty ? 'Chọn sân để đặt' : 'Xác nhận đặt sân',
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

  // 🆕 HÀM XỬ LÝ KHI NGƯỜI DÙNG NHẤN BACK
  Future<void> _handleBackPressed() async {
    if (pendingChanges.isNotEmpty) {
      // Hiển thị dialog xác nhận
      bool? shouldBack = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Hủy đặt sân?"),
          content: Text(
            "Bạn có ${pendingChanges.length} sân đang chọn. Bạn có muốn hủy và thoát không?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Ở lại"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Hủy và thoát"),
            ),
          ],
        ),
      );

      if (shouldBack == true) {
        await rollbackPending(); // Rollback trạng thái 2
        _showSnackBar('Đã hủy ${pendingChanges.length} sân đang chọn', Colors.orange);
      } else {
        return; // Ở lại trang, không cho back
      }
    }
  }

  // 🆕 HÀM DỌN DẸP TOÀN DIỆN KHI VÀO TRANG
  Future<void> _cleanupAllExpiredCourts() async {
    try {
      debugPrint("🔄 Đang dọn dẹp toàn bộ sân hết hạn...");

      final now = DateTime.now();
      final today = formatDate(DateTime.now());

      // Dọn dẹp cho ngày hiện tại
      final todayRef = firestore
          .collection("dat_san")
          .doc(widget.coSoId)
          .collection(today);

      final snapshot = await todayRef.get();

      int cleanupCount = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> updates = {};

        for (int i = 1; i <= soSan; i++) {
          String sanKey = 'san$i';
          String tempTimeupKey = '${sanKey}_temp_timeup';
          String paymentTimeupKey = '${sanKey}_payment_timeup';

          int currentStatus = data[sanKey] ?? 1;

          // 🧹 DỌN DẸP TRẠNG THÁI 2 HẾT HẠN
          if (currentStatus == 2 && data[tempTimeupKey] != null) {
            Timestamp tempTimeup = data[tempTimeupKey] as Timestamp;
            if (tempTimeup.toDate().isBefore(now)) {
              updates[sanKey] = 1;
              updates[tempTimeupKey] = null;
              cleanupCount++;
              debugPrint("✅ Đã dọn dẹp $sanKey (2→1) - temp_timeup hết hạn");
            }
          }

          // 🧹 DỌN DẸP TRẠNG THÁI 3 HẾT HẠN
          if (currentStatus == 3 && data[paymentTimeupKey] != null) {
            Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
            if (paymentTimeup.toDate().isBefore(now)) {
              updates[sanKey] = 1;
              // Giữ nguyên payment_timeup
              cleanupCount++;
              debugPrint("✅ Đã dọn dẹp $sanKey (3→1) - payment_timeup hết hạn");
            }
          }
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
        }
      }

      if (cleanupCount > 0) {
        debugPrint("🎉 Đã dọn dẹp $cleanupCount sân hết hạn");
      } else {
        debugPrint("✅ Không có sân nào cần dọn dẹp");
      }

    } catch (e) {
      debugPrint("🔥 Lỗi dọn dẹp toàn diện: $e");
    }
  }
}



class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}