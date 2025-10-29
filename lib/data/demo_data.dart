import 'package:cloud_firestore/cloud_firestore.dart';


/// Ghi 1 bản Cơ sở
Future<DocumentReference<Map<String, dynamic>>> add_1_co_so() async {
  final co_so = {
    'ten': 'Eaxe bát min tòn',
    'mo_ta': 'sân bình thương',
    'anh1': null,
    'anh2': null,
    'anh3': null,
    'anh4': null,
    'dia_chi_chi_tiet': 'không có',
    'xa': 'Phường 200',
    'huyen': 'Quận 1660',
    'tinh': 'Hà nam',
    'sdt': '113',
    'web': null,
    'gio_mo_cua': '06:00',
    'gio_dong_cua': '22:00',
    'vi_tri': '',
    'toa_do_x': '28.0285',
    'toa_do_y':'15.8542',
    'createdAt': FieldValue.serverTimestamp(),
  };

  // thêm vào collection "facilities"
  final ref = await FirebaseFirestore.instance
      .collection('co_so')
      .add(co_so);

  return ref; // để lát nữa đọc lại đúng bản ghi này
}

/// thêm 1 sân của cơ sở
Future<DocumentReference<Map<String, dynamic>>> add_1_san() async {
  final san = {
    'co_so':'HzQemAv9nzdYQSoI6ozR',
    'ten_san': 'Thường',
    'mo_ta': 'sân đơn',
    'gia_6_7': 80000,
    'gia_7_8': 90000,
    'gia_8_9': 100000,
    'gia_9_10': 100000,
    'gia_10_11': 90000,
    'gia_11_12': 80000,
    'gia_12_13': 75000,
    'gia_13_14': 75000,
    'gia_14_15': 80000,
    'gia_15_16': 85000,
    'gia_16_17': 90000,
    'gia_17_18': 95000,
    'gia_18_19': 100000,
    'gia_19_20': 110000,
    'gia_20_21': 120000,
    'gia_21_22': 130000,
    'createdAt': FieldValue.serverTimestamp(),
  };

  final ref = await FirebaseFirestore.instance
      .collection('san')
      .add(san);

  return ref;
}

Future<DocumentReference<Map<String, dynamic>>> add_1_san2() async {
  final san = {
    'co_so':'Stn9qQs4D9rx7Cq6bgE8',
    'ten_san': 'vip',
    'mo_ta': 'sân đơn',
    'gia_6_7': 80000,
    'gia_7_8': 90000,
    'gia_8_9': 100000,
    'gia_9_10': 100000,
    'gia_10_11': 90000,
    'gia_11_12': 80000,
    'gia_12_13': 75000,
    'gia_13_14': 75000,
    'gia_14_15': 80000,
    'gia_15_16': 85000,
    'gia_16_17': 90000,
    'gia_17_18': 95000,
    'gia_18_19': 100000,
    'gia_19_20': 110000,
    'gia_20_21': 120000,
    'gia_21_22': 130000,
    'createdAt': FieldValue.serverTimestamp(),
  };

  final ref = await FirebaseFirestore.instance
      .collection('san')
      .add(san);

  return ref;
}
/// thêm 1 slot sân
Future<DocumentReference<Map<String, dynamic>>> add_1_slot_san() async {
  final slot_san = {
    'san': 'LJvq4xM9UWk2nStHDXUk',
    'gia': 90000,
    'trang_thai': 'da_dat',
    'thoi_gian_bat_dau': '07:00',
    'thoi_gian_ket_thuc': '08:00',
    'ngay': '2025-10-29',
    'createdAt': FieldValue.serverTimestamp(),
  };

  final ref = await FirebaseFirestore.instance
      .collection('slot_san')
      .add(slot_san);

  return ref;
}

Future<DocumentReference<Map<String, dynamic>>> add_1_slot_san2() async {
  final slot_san = {
    'san': 'LJvq4xM9UWk2nStHDXUk',
    'gia': 90000,
    'trang_thai': 'da_dat',
    'thoi_gian_bat_dau': '10:00',
    'thoi_gian_ket_thuc': '11:00',
    'ngay': '2025-10-30',
    'createdAt': FieldValue.serverTimestamp(),
  };

  final ref = await FirebaseFirestore.instance
      .collection('slot_san')
      .add(slot_san);

  return ref;
}
/// thêm 1 đánh giá
Future<DocumentReference<Map<String, dynamic>>> add_1_danh_gia() async {
  final danh_gia = {
    'ma_nguoi_danh_giá': null,
    'nguoi_danh_gia': 'Nguyên văn ngố',
    'co_so_duoc_danh_gia': 'Stn9qQs4D9rx7Cq6bgE8',
    'noi_dung': 'Sân sạch, thoáng mát, chủ thân thiện. Sẽ quay lại!',
    'so_sao': 5,
    'createdAt': FieldValue.serverTimestamp(),
  };

  final ref = await FirebaseFirestore.instance
      .collection('danh_gia')
      .add(danh_gia);

  return ref;
}
