import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
    // Chỉ block giờ đã qua trong ngày hiện tại
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return hour < now.hour; // Chỉ block giờ < giờ hiện tại
    }
    return false; // Ngày khác không block
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

    // Lấy số sân và giờ hoạt động
    soSan = (widget.coSoData['so_san'] as num?)?.toInt() ?? 4;
    final gioMo = int.tryParse((widget.coSoData['gio_mo_cua'] as String?)?.split(':')[0] ?? '6') ?? 6;
    final gioDong = int.tryParse((widget.coSoData['gio_dong_cua'] as String?)?.split(':')[0] ?? '22') ?? 22;
    hours = List.generate(gioDong - gioMo, (i) => gioMo + i);

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
      states.clear();
      for (var doc in snapshot.docs) {
        int hh = int.parse(doc.id.split(':')[0]);
        Map<String, dynamic> data = doc.data();

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

  Future<void> datSan(int hour, int index) async {
    String datePath = formatDate(selectedDate);
    String hourPath = "${hour.toString().padLeft(2, '0')}:00";
    String sanKey = "san${index + 1}";
    String timestampKey = "${sanKey}_timestamp";

    final ref = firestore
        .collection("dat_san")
        .doc(widget.coSoId)
        .collection(datePath)
        .doc(hourPath);

    try {
      final docSnapshot = await ref.get();
      Map<String, dynamic> data = docSnapshot.data() ?? {};
      int current = data[sanKey] ?? 1;

      // Kiểm tra timeout
      if (current == 2) {
        Timestamp? timestamp = data[timestampKey] as Timestamp?;
        if (timestamp != null) {
          DateTime setTime = timestamp.toDate();
          if (DateTime.now().difference(setTime) > const Duration(minutes: 10)) {
            await ref.update({sanKey: 1, timestampKey: null});
            current = 1;
          }
        }
      }

      // Không cho tương tác với sân đã đặt
      if (current == 3) {
        _showSnackBar('Sân này đã được đặt', Colors.red);
        return;
      }

      // Kiểm tra conflict
      if (current == 2) {
        bool isMyPending = pendingChanges.any(
                (p) => p['hour'] == hour && p['san'] == index
        );

        if (isMyPending) {
          // Hủy chọn của mình
          await ref.update({sanKey: 1, timestampKey: null});
          pendingChanges.removeWhere(
                  (p) => p['hour'] == hour && p['san'] == index
          );
        } else {
          // Người khác đang chọn
          _showSnackBar('Sân này vừa được chọn bởi người khác', Colors.orange);
          return;
        }
      } else if (current == 1) {
        // Đặt sân
        await ref.update({
          sanKey: 2,
          timestampKey: FieldValue.serverTimestamp(),
        });
        pendingChanges.add({
          'hour': hour,
          'san': index,
          'ref': ref,
          'sanKey': sanKey,
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
      _showSnackBar("Lỗi đặt sân: $e", Colors.red);
    }
  }

  void _startRollbackTimer() {
    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(minutes: 10), () async {
      await rollbackPending();
      setState(() {});
    });
  }

  Future<void> rollbackPending() async {
    for (var p in pendingChanges) {
      String sanKey = p['sanKey'];
      String timestampKey = "${sanKey}_timestamp";
      try {
        await (p['ref'] as DocumentReference).update({
          sanKey: 1,
          timestampKey: null,
        });
      } catch (e) {
        debugPrint("Lỗi rollback: $e");
      }
    }
    pendingChanges.clear();
    _rollbackTimer?.cancel();
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

    // Kiểm tra conflict trước khi hiển thị dialog
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
        int current = docSnapshot.data()?[p['sanKey']] ?? 1;
        if (current == 3) {
          hasConflict = true;
        } else if (current == 2) {
          validChanges.add(p);
        }
      }
    }

    if (hasConflict) {
      _showSnackBar('Một số sân đã được đặt. Vui lòng chọn lại.', Colors.red);
      await rollbackPending();
      setState(() {});
      return;
    }

    if (validChanges.isEmpty) {
      _showSnackBar('Không có sân hợp lệ để đặt', Colors.red);
      return;
    }

    // Tính tổng tiền
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  borderRadius: BorderRadius.circular(8),
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
                _showSnackBar("Vui lòng nhập tên người đặt", Colors.orange);
                return;
              }

              if (phone.isEmpty) {
                _showSnackBar("Vui lòng nhập số điện thoại", Colors.orange);
                return;
              }

              // Validate SĐT di động Việt Nam
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Xác nhận", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processBooking(
        nameController.text.trim(),
        phoneController.text.trim(),
        validChanges,
        tongTien,
      );
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
    // Show loading dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      String ngayDat = formatDate(selectedDate);
      String userId = auth.currentUser?.uid ?? 'khachquaduong';

      // Tạo ID đơn hàng
      final donDatRef = await firestore.collection('temp_order').add({'temp': true});
      String maDon = donDatRef.id;
      await donDatRef.delete();

      debugPrint("✅ Đang xử lý đơn hàng: $maDon");

      // Danh sách chi tiết đặt
      List<Map<String, dynamic>> danhSachDat = [];

      // Update trạng thái sân
      for (var p in validChanges) {
        String sanKey = p['sanKey'];
        String timestampKey = "${sanKey}_timestamp";
        String hourPath = "${(p['hour'] as int).toString().padLeft(2, '0')}:00";

        await (p['ref'] as DocumentReference).update({
          sanKey: 3,
          '${sanKey}_name': name,
          '${sanKey}_phone': phone,
          timestampKey: null,
        });

        danhSachDat.add({
          'ma_san': sanKey,
          'gio': hourPath,
          'ngay_dat': ngayDat,
          'gia': getPriceForHour(p['hour']),
        });
      }

      debugPrint("✅ Đã update trạng thái sân");

      // Dữ liệu đơn hàng cho lich_su_khach
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
      };

      // Lưu vào lich_su_khach
      await firestore
          .collection('lich_su_khach')
          .doc(userId)
          .collection('don_dat')
          .doc(maDon)
          .set(donDatDataKhach);

      debugPrint("✅ Đã lưu vào lich_su_khach");

      // Dữ liệu đơn hàng cho lich_su_san (thêm user_id_dat)
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
      };

      // Lưu vào lich_su_san
      await firestore
          .collection('lich_su_san')
          .doc(widget.coSoId)
          .collection('khach_dat')
          .doc(maDon)
          .set(donDatDataSan);

      debugPrint("✅ Đã lưu vào lich_su_san");

      // Lưu chi tiết đặt
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

      _rollbackTimer?.cancel();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message
      if (mounted) {
        _showSnackBar('Đặt sân thành công!', Colors.green);
      }

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to payment page
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

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
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
      rollbackPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    _rollbackTimer?.cancel();
    rollbackPending();
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

    return Scaffold(
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
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
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
            borderRadius: BorderRadius.circular(12),
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
            // --- Hàng tiêu đề cố định ---
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
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

            // --- Nội dung có thể cuộn ---
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
                        borderRadius: BorderRadius.circular(8),
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
                                    borderRadius: BorderRadius.circular(6),
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
                  borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(12),
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