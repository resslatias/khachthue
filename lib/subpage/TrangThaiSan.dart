import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrangThaiSan extends StatefulWidget {
  const TrangThaiSan({Key? key}) : super(key: key);

  @override
  State<TrangThaiSan> createState() => _TrangThaiSanState();
}

class _TrangThaiSanState extends State<TrangThaiSan> with WidgetsBindingObserver {
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  String? userId = '9ok6mAN7tDH0bjcTpGiG';

  DateTime selectedDate = DateTime.now();

  List<int> hours = List.generate(17, (i) => 6 + i);

  Map<int, List<int>> states = {};

  List<Map<String, dynamic>> pendingChanges = [];

  StreamSubscription<QuerySnapshot>? subscription;

  Timer? _rollbackTimer;

  String formatDate(DateTime date) => DateFormat('dd_MM_yyyy').format(date);

  String displayDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  bool isPastHour(int hour) {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day &&
        hour <= now.hour;
  }

  String getHourLabel(int hour) {
    int nextHour = hour + 1;
    return "$hour - ${nextHour}h";
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.greenAccent;
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('user_id');

    if (storedId == null || storedId.isEmpty) {
      // Nếu chưa có, check auth và lưu
      User? currentUser = auth.currentUser;
      if (currentUser != null) {
        storedId = currentUser.uid;
        await prefs.setString('user_id', storedId);
      } else {
        // Redirect to login if no auth
        print("Chưa đăng nhập, redirect to login");
        // Ví dụ: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DangNhap()));
        return;
      }
    }

    setState(() {
      userId = storedId;
    });

    if (userId == null) {
      print("Không có userId");
    } else {
      print("Loaded userId: $userId"); // Debug
    }
  }

  Future<void> ensureDayDataExists(String datePath) async {
    if (userId == null) return;

    final dateRef = firestore.collection("dat_san").doc(userId).collection(datePath);
    try {
      final snapshot = await dateRef.limit(1).get();

      if (snapshot.docs.isEmpty) {
        WriteBatch batch = firestore.batch();
        for (int hour = 6; hour <= 22; hour++) {
          final ref = dateRef.doc("${hour.toString().padLeft(2, '0')}:00");
          batch.set(ref, {
            'san1': 1,
            'san2': 1,
            'san3': 1,
            'san4': 1,
          });
        }
        await batch.commit();
        print("✅ Đã tạo dữ liệu cho ngày $datePath");
      } else {
        print("ℹ️ Ngày $datePath đã có dữ liệu (${snapshot.docs.length} doc)");
      }
    } catch (e) {
      print("🔥 Lỗi ensureDayDataExists: $e");
    }
  }

  void setupListeners() {
    if (userId == null) return;

    subscription?.cancel();

    String dayPath = formatDate(selectedDate);

    subscription = firestore.collection("dat_san").doc(userId).collection(dayPath).snapshots().listen((snapshot) {
      states.clear();
      for (var doc in snapshot.docs) {
        int hh = int.parse(doc.id.split(':')[0]);
        Map<String, dynamic> data = doc.data();
        states[hh] = [
          data['san1'] ?? 1,
          data['san2'] ?? 1,
          data['san3'] ?? 1,
          data['san4'] ?? 1,
        ];
      }
      setState(() {});
    }, onError: (e) {
      print("Lỗi listener: $e");
    });
  }

  Future<void> datSan(int hour, int index) async {
    if (userId == null) return;

    String datePath = formatDate(selectedDate);
    String hourPath = "${hour.toString().padLeft(2, '0')}:00";
    String sanKey = "san${index + 1}";
    String timestampKey = "${sanKey}_timestamp";

    final ref = firestore.collection("dat_san").doc(userId).collection(datePath).doc(hourPath);

    try {
      final docSnapshot = await ref.get();
      Map<String, dynamic> data = docSnapshot.data() ?? {};
      int current = data[sanKey] ?? 1;

      if (!docSnapshot.exists) {
        await ref.set({
          'san1': 1, 'san2': 1, 'san3': 1, 'san4': 1,
        });
        data = {'san1': 1, 'san2': 1, 'san3': 1, 'san4': 1};
        current = 1;
      }

      if (current == 2) {
        Timestamp? timestamp = data[timestampKey] as Timestamp?;
        if (timestamp != null) {
          DateTime setTime = timestamp.toDate();
          if (DateTime.now().difference(setTime) > const Duration(minutes: 5)) {
            await ref.update({sanKey: 1, timestampKey: null});
            current = 1;
            setState(() {});
          }
        }
      }

      if (current == 3) return;

      if (current == 2) {
        bool isMyPending = pendingChanges.any((p) => p['hour'] == hour && p['san'] == index);
        if (isMyPending) {
          await ref.update({sanKey: 1, timestampKey: null});
          pendingChanges.removeWhere((p) => p['hour'] == hour && p['san'] == index);
        }
      } else if (current == 1) {
        await ref.update({
          sanKey: 2,
          timestampKey: FieldValue.serverTimestamp(),
        });
        pendingChanges.add({'hour': hour, 'san': index, 'ref': ref, 'sanKey': sanKey});
      }

      setState(() {});
      if (pendingChanges.isEmpty) {
        _rollbackTimer?.cancel();
      } else {
        _startRollbackTimer();
      }
    } catch (e) {
      print("Lỗi datSan: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi đặt sân: $e")));
      }
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
    for (var p in pendingChanges) {
      String sanKey = p['sanKey'];
      String timestampKey = "${sanKey}_timestamp";
      try {
        await (p['ref'] as DocumentReference).update({
          sanKey: 1,
          timestampKey: null,
        });
      } catch (e) {
        print("Lỗi rollback: $e");
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
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );
      return;
    }

    String dateStr = displayDate(selectedDate);
    String selectedInfo = pendingChanges.map((p) => "Sân ${p['san'] + 1} lúc ${p['hour']}-${p['hour'] + 1}h").join("\n");

    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận đặt sân"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ngày: $dateStr\n\nBạn muốn đặt:\n$selectedInfo"),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Tên người đặt", border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(
            onPressed: () {
              String name = nameController.text.trim();
              String phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ tên và số điện thoại.")));
                return;
              }
              if (phone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Số điện thoại phải đúng 10 chữ số.")));
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      String name = nameController.text.trim();
      String phone = phoneController.text.trim();
      String ngayDat = formatDate(selectedDate);

      // Thu thập danh sách đặt sân cho đơn hàng duy nhất
      List<Map<String, dynamic>> danhSachDat = pendingChanges.map((p) {
        return {
          'gio_dat': "${p['hour'].toString().padLeft(2, '0')}:00",
          'thong_tin_san': "Sân ${p['san'] + 1} lúc ${p['hour']}-${p['hour'] + 1}h",
        };
      }).toList();

      try {
        // Update trạng thái sân cho tất cả pending
        for (var p in pendingChanges) {
          String sanKey = p['sanKey'];
          String timestampKey = "${sanKey}_timestamp";
          await (p['ref'] as DocumentReference).update({
            sanKey: 3,
            '${sanKey}_name': name,
            '${sanKey}_phone': phone,
            timestampKey: null,
          });
        }

        // Lưu một đơn hàng duy nhất vào lich_su_dat/userId/chu_dat
        await firestore.collection('lich_su_dat').doc(userId).collection('chu_dat').add({
          'ten_nguoi_dat': name,
          'sdt': phone,
          'ngay_dat': ngayDat,
          'danh_sach_dat': danhSachDat, // List của các sân/giờ
          'timestamp': FieldValue.serverTimestamp(), // Thời gian tạo
        });
        print("Đã lưu đơn hàng lịch sử đặt sân");
      } catch (e) {
        print("Lỗi confirm: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi xác nhận: $e")));
        }
      }

      _rollbackTimer?.cancel();
    } else {
      await rollbackPending();
    }

    pendingChanges.clear();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _initTodayData();
      setupListeners();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initTodayData() async {
    String todayPath = formatDate(DateTime.now());
    await ensureDayDataExists(todayPath);
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
    if (userId == null) {
      return Scaffold(
        body: Center(child: Text("Đang tải user...")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trạng thái sân", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF006B3C),
      ),
      body: Container(
        color: const Color(0xFF004D2C),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Theo ngày", style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        DateTime today = DateTime.now();
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(today.year, today.month, today.day),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null && picked != selectedDate) {
                          await rollbackPending();
                          setState(() {
                            selectedDate = picked;
                            states = {};
                            pendingChanges.clear();
                          });
                          await ensureDayDataExists(formatDate(picked));
                          setupListeners();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hãy chọn lại sân')),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(displayDate(selectedDate), style: const TextStyle(color: Colors.white)),
                            const Spacer(),
                            const Icon(Icons.calendar_today, color: Colors.white, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text("Trạng thái sân", style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _LegendItem(color: Colors.greenAccent, text: "Trống (1)"),
                  _LegendItem(color: Colors.orange, text: "Đang chọn (2)"),
                  _LegendItem(color: Colors.red, text: "Đã đặt (3)"),
                ],
              ),
              const SizedBox(height: 16),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  border: TableBorder.all(color: Colors.white, width: 2),
                  dataRowHeight: 60,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Thời gian', style: TextStyle(color: Colors.white))),
                    DataColumn(label: Text('Sân 1', style: TextStyle(color: Colors.white))),
                    DataColumn(label: Text('Sân 2', style: TextStyle(color: Colors.white))),
                    DataColumn(label: Text('Sân 3', style: TextStyle(color: Colors.white))),
                    DataColumn(label: Text('Sân 4', style: TextStyle(color: Colors.white))),
                  ],
                  rows: hours.map((hour) {
                    bool past = isPastHour(hour);
                    List<int> sanStates = states[hour] ?? [1, 1, 1, 1];
                    return DataRow(
                      cells: [
                        DataCell(Text(getHourLabel(hour), style: const TextStyle(color: Colors.white))),
                        ...List.generate(4, (index) => DataCell(
                          GestureDetector(
                            onTap: past ? null : () => datSan(hour, index),
                            child: Container(
                              color: past ? Colors.grey[700] : getStatusColor(sanStates[index]),
                              alignment: Alignment.center,
                              child: Text(
                                '${sanStates[index]}',
                                style: TextStyle(color: past ? Colors.white60 : Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: ElevatedButton(
                  onPressed: confirmAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  child: const Text(
                    "Xác nhận đặt sân",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}