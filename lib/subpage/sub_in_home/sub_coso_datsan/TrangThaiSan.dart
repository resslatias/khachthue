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
  bool isProcessingPayment = false; // ✅ THÊM BIẾN NÀY

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
        return Color(0xFFF39C12); // Orange
      case 3:
        return Color(0xFFC44536); // Primary red
      default:
        return Color(0xFF2E8B57); // Green
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
      _checkAndResetTimeouts(snapshot);

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

  Future<void> _checkAndResetTimeouts(QuerySnapshot snapshot) async {
    final now = DateTime.now();

    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      for (int i = 1; i <= soSan; i++) {
        String sanKey = 'san$i';
        String tempTimeupKey = '${sanKey}_temp_timeup';
        String paymentTimeupKey = '${sanKey}_payment_timeup';

        int currentStatus = data[sanKey] ?? 1;

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

        if (currentStatus == 3 && data[paymentTimeupKey] != null) {
          Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
          if (paymentTimeup.toDate().isBefore(now)) {
            try {
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

  Future<void> datSan(int hour, int index) async {
    String datePath = formatDate(selectedDate);
    String hourPath = "${hour.toString().padLeft(2, '0')}:00";
    String sanKey = "san${index + 1}";
    String tempTimeupKey = "${sanKey}_temp_timeup";
    String paymentTimeupKey = "${sanKey}_payment_timeup";

    final ref = firestore
        .collection("dat_san")
        .doc(widget.coSoId)
        .collection(datePath)
        .doc(hourPath);

    try {
      final docSnapshot = await ref.get();
      Map<String, dynamic> data = docSnapshot.data() ?? {};
      int current = data[sanKey] ?? 1;

      if (current == 3 && data[paymentTimeupKey] != null) {
        Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
        if (paymentTimeup.toDate().isBefore(DateTime.now())) {
          await ref.update({sanKey: 1});
          current = 1;
          debugPrint("✅ Đã reset sân $sanKey (3→1) - giữ payment_timeup");
        }
      }

      if (current == 2 && data[tempTimeupKey] != null) {
        Timestamp tempTimeup = data[tempTimeupKey] as Timestamp;
        if (tempTimeup.toDate().isBefore(DateTime.now())) {
          await ref.update({sanKey: 1, tempTimeupKey: null});
          current = 1;
          debugPrint("✅ Đã reset sân $sanKey (2→1) - xóa temp_timeup");
        }
      }

      if (current == 3) {
        _showSnackBar('Sân này đã được đặt', Color(0xFFC44536));
        return;
      }

      if (current == 2) {
        bool isMyPending = pendingChanges.any(
                (p) => p['hour'] == hour && p['san'] == index
        );

        if (isMyPending) {
          await ref.update({sanKey: 1, tempTimeupKey: null});
          pendingChanges.removeWhere(
                  (p) => p['hour'] == hour && p['san'] == index
          );
        } else {
          _showSnackBar('Sân này vừa được chọn bởi người khác', Color(0xFFF39C12));
          return;
        }
      }
      else if (current == 1) {
        DateTime fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));
        await ref.update({
          sanKey: 2,
          tempTimeupKey: Timestamp.fromDate(fiveMinutesFromNow),
        });

        pendingChanges.add({
          'hour': hour,
          'san': index,
          'ref': ref,
          'sanKey': sanKey,
          'tempTimeupKey': tempTimeupKey,
          'paymentTimeupKey': paymentTimeupKey,
        });
      }

      setState(() {});

      if (pendingChanges.isEmpty) {
        _rollbackTimer?.cancel();
      } else {
        _startRollbackTimer();
      }
    } catch (e) {
      debugPrint("Lỗi datSan: $e");
      _showSnackBar("Lỗi đặt sân: $e", Color(0xFFC44536));
    }
  }

  void _startRollbackTimer() {
    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(minutes: 5), () async {
      await rollbackPending();
      setState(() {});
    });
  }

  Future<void> rollbackPending() async {
    if (pendingChanges.isEmpty) return;

    debugPrint("🔄 Đang rollback ${pendingChanges.length} sân đang chọn...");

    for (var p in pendingChanges) {
      String sanKey = p['sanKey'];
      String tempTimeupKey = p['tempTimeupKey'];

      try {
        await (p['ref'] as DocumentReference).update({
          sanKey: 1,
          tempTimeupKey: null,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    if (hasConflict) {
      _showSnackBar('Một số sân đã được đặt. Vui lòng chọn lại.', Color(0xFFC44536));
      await rollbackPending();
      setState(() {});
      return;
    }

    if (validChanges.isEmpty) {
      _showSnackBar('Không có sân hợp lệ để đặt', Color(0xFFC44536));
      return;
    }

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

    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.sports_tennis, color: Color(0xFFC44536)),
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
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFC44536).withOpacity(0.3)),
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
                        color: Color(0xFFC44536),
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
                            color: Color(0xFFC44536),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "Số điện thoại *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                _showSnackBar("Vui lòng nhập tên người đặt", Color(0xFFF39C12));
                return;
              }

              if (phone.isEmpty) {
                _showSnackBar("Vui lòng nhập số điện thoại", Color(0xFFF39C12));
                return;
              }

              if (!RegExp(r'^(03|05|07|08|09)\d{8}$').hasMatch(phone)) {
                _showSnackBar(
                  "Số điện thoại không hợp lệ. Vui lòng nhập số di động 10 số (03x, 05x, 07x, 08x, 09x)",
                  Color(0xFFF39C12),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC44536),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // ✅ BẮT ĐẦU XỬ LÝ THANH TOÁN
    if (confirmed == true) {
      setState(() => isProcessingPayment = true);

      await _processBooking(
        nameController.text.trim(),
        phoneController.text.trim(),
        validChanges,
        tongTien,
      );

      if (mounted) {
        setState(() => isProcessingPayment = false);
      }
    } else {
      await rollbackPending();
    }

    pendingChanges.clear();
    setState(() {});
  }

  Future<void> _processBooking(
      String name,
      String phone,
      List<Map<String, dynamic>> validChanges,
      int tongTien,
      ) async {
    if (!mounted) return;

    try {
      String ngayDat = formatDate(selectedDate);
      String userId = auth.currentUser?.uid ?? 'khachquaduong';

      final donDatRef = await firestore.collection('temp_order').add({'temp': true});
      String maDon = donDatRef.id;
      await donDatRef.delete();

      debugPrint("✅ Đang xử lý đơn hàng: $maDon");

      DateTime timeoutTime = DateTime.now().add(const Duration(minutes: 15));
      Timestamp timeoutTimestamp = Timestamp.fromDate(timeoutTime);

      List<Map<String, dynamic>> danhSachDat = [];

      for (var p in validChanges) {
        String sanKey = p['sanKey'];
        String tempTimeupKey = p['tempTimeupKey'];
        String paymentTimeupKey = p['paymentTimeupKey'];
        String hourPath = "${(p['hour'] as int).toString().padLeft(2, '0')}:00";

        await (p['ref'] as DocumentReference).update({
          sanKey: 3,
          tempTimeupKey: null,
          paymentTimeupKey: timeoutTimestamp,
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

      await firestore.collection('order_lookup').doc(orderHash).set({
        'user_id': userId,
        'ma_don': maDon,
        'created_at': FieldValue.serverTimestamp(),
        'trang_thai': 'chua_thanh_toan',
      });
      debugPrint("✅ Đã lưu order_lookup/$orderHash");

      debugPrint("✅ Đã update trạng thái sân");

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

      _rollbackTimer?.cancel();

      if (mounted) {
        _showSnackBar('Đặt sân thành công!', Color(0xFF2E8B57));
      }

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
        _showSnackBar("Lỗi xác nhận: $e", Color(0xFFC44536));
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
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
        body: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFC44536)),
              ),
            ),
          ],
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _handleBackPressed();
        return true;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFECF0F1),
        body: Column(
          children: [
            _buildCustomAppBar(),
            _buildDateSelector(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildLegend(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildCourtTable()),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ✅ HEADER ĐÃ GIẢM PADDING
  Widget _buildCustomAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: 8,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
            onPressed: () => _handleBackPressed().then((_) {
              if (pendingChanges.isEmpty) Navigator.pop(context);
            }),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.coSoData['ten'] as String? ?? "Trạng thái sân",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ DATE SELECTOR ĐÃ GIẢM PADDING
  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                    primary: Color(0xFFC44536),
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
            _showSnackBar('Đã chuyển sang ngày ${displayDate(picked)}. Hãy chọn lại sân.', Color(0xFF3498DB));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFBDC3C7)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Color(0xFFC44536), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayDate(selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: Color(0xFFC44536)),
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
          _LegendItem(color: Color(0xFF2E8B57), text: "Trống"),
          _LegendItem(color: Color(0xFFF39C12), text: "Đang chọn"),
          _LegendItem(color: Color(0xFFC44536), text: "Đã đặt"),
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
                color: Color(0xFF2C3E50),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
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
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(0xFFECF0F1)),
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
                                        ? Colors.grey.shade300
                                        : getStatusColor(sanStates[i]),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: past
                                          ? Colors.grey.shade400
                                          : getStatusColor(sanStates[i]).withOpacity(0.3),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: past
                                      ? Icon(Icons.block, color: Colors.white70, size: 16)
                                      : Text(
                                    sanStates[i] == 3
                                        ? '✓'
                                        : sanStates[i].toString(),
                                    style: TextStyle(
                                      color: sanStates[i] == 3
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: sanStates[i] == 3 ? 18 : 14,
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
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }

  // ✅ BOTTOM BAR ĐÃ TỐI ƯU - SÁT BOTTOM NAVIGATION & VÔ HIỆU HÓA KHI PROCESSING
  Widget _buildBottomBar() {
    int tongTien = 0;
    for (var p in pendingChanges) {
      tongTien += getPriceForHour(p['hour']);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFECF0F1)),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingChanges.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Color(0xFFC44536).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFC44536).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã chọn: ${pendingChanges.length} sân',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tạm tính: ${_formatCurrency(tongTien)}đ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC44536),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: isProcessingPayment ? null : () async {
                        await rollbackPending();
                        setState(() {});
                        _showSnackBar('Đã hủy chọn', Color(0xFF7F8C8D));
                      },
                      icon: Icon(Icons.clear, size: 16),
                      label: Text('Hủy chọn', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFFC44536),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isProcessingPayment ? null : confirmAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isProcessingPayment
                      ? Colors.grey
                      : Color(0xFFC44536),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: isProcessingPayment
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Đợi 1 chút để tới trang thanh toán...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
                    : Text(
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

  Future<void> _handleBackPressed() async {
    if (pendingChanges.isNotEmpty) {
      bool? shouldBack = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                foregroundColor: Color(0xFFC44536),
              ),
              child: const Text("Hủy và thoát"),
            ),
          ],
        ),
      );

      if (shouldBack == true) {
        await rollbackPending();
        _showSnackBar('Đã hủy ${pendingChanges.length} sân đang chọn', Color(0xFFF39C12));
      } else {
        return;
      }
    }
  }

  Future<void> _cleanupAllExpiredCourts() async {
    try {
      debugPrint("🔄 Đang dọn dẹp toàn bộ sân hết hạn...");

      final now = DateTime.now();
      final today = formatDate(DateTime.now());

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

          if (currentStatus == 2 && data[tempTimeupKey] != null) {
            Timestamp tempTimeup = data[tempTimeupKey] as Timestamp;
            if (tempTimeup.toDate().isBefore(now)) {
              updates[sanKey] = 1;
              updates[tempTimeupKey] = null;
              cleanupCount++;
              debugPrint("✅ Đã dọn dẹp $sanKey (2→1) - temp_timeup hết hạn");
            }
          }

          if (currentStatus == 3 && data[paymentTimeupKey] != null) {
            Timestamp paymentTimeup = data[paymentTimeupKey] as Timestamp;
            if (paymentTimeup.toDate().isBefore(now)) {
              updates[sanKey] = 1;
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
          width: 16,
          height: 16,
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}