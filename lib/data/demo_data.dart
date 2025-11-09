import 'package:cloud_firestore/cloud_firestore.dart';



Future<void> updateBangGia({
  required String coSoId, // ví dụ '9ok6mAN7tDH0bjcTpGiG'
  List<int>? newPrices,   // mảng 24 giá mới, nếu null thì dùng mặc định
}) async {
  final coSoRef = FirebaseFirestore.instance
      .collection('co_so')
      .doc(coSoId);

  try {
    // Tạo mảng mặc định 24 phần tử (giá = 24000)
    final defaultPrices = List<int>.filled(24, 24000);

    // Nếu người dùng có truyền newPrices thì dùng, không thì dùng mặc định
    final bangGia = newPrices ?? defaultPrices;

    // Kiểm tra document có tồn tại không
    final doc = await coSoRef.get();

    if (doc.exists) {
      // Nếu có rồi thì ghi đè
      await coSoRef.update({
        'bang_gia': bangGia,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Đã cập nhật bảng giá thành công.');
    } else {
      // Nếu chưa có document → tạo mới
      await coSoRef.set({
        'bang_gia': bangGia,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Đã tạo mới document với bảng giá mặc định.');
    }
  } catch (e) {
    print('❌ Lỗi khi cập nhật bảng giá: $e');
  }
}





Future<void> addSanData() async {
  // tham chiếu tới tài liệu cha
  final coSoRef = FirebaseFirestore.instance
      .collection('san')
      .doc('9ok6mAN7tDH0bjcTpGiG') // ID tài liệu cha
      .collection('san'); // subcollection 'san'

  await coSoRef.add({
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
  });

  print('✅ Thêm dữ liệu sân thành công!');
}
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
/// ════════════════════════════════════════════════════════════════
/// THÊM THÔNG BÁO CÁ NHÂN (thong_bao)
/// Cấu trúc: thong_bao/{userId}/notifications/{notificationId}
/// ════════════════════════════════════════════════════════════════

/// Thêm 1 thông báo cá nhân cho user
Future<DocumentReference<Map<String, dynamic>>> add_1_thong_bao_ca_nhan({
  required String userId,
}) async {
  final thongBao = {
    'tieu_de': 'Đặt sân thành công',
    'noi_dung': 'Bạn đã đặt sân Thường tại Eaxe bát min tòn vào lúc 07:00 - 08:00 ngày 29/10/2025. Vui lòng đến đúng giờ!',
    'ngay_tao': FieldValue.serverTimestamp(),
    'da_xem_chua': false,
    'Urlweb': 'https://example.com/booking/123',
    'Urlimage': 'https://picsum.photos/400/200?random=1',
  };

  final ref = await FirebaseFirestore.instance
      .collection('thong_bao')
      .doc(userId)
      .collection('notifications')
      .add(thongBao);

  return ref;
}

/// Thêm nhiều thông báo cá nhân demo cho 1 user
Future<void> add_nhieu_thong_bao_ca_nhan({
  required String userId,
  int soLuong = 5,
}) async {
  final danhSachThongBao = [
    {
      'tieu_de': 'Đặt sân thành công',
      'noi_dung': 'Bạn đã đặt sân Thường tại Eaxe bát min tòn vào lúc 07:00 - 08:00 ngày 29/10/2025. Vui lòng đến đúng giờ!',
      'da_xem_chua': false,
      'Urlweb': 'https://example.com/booking/123',
      'Urlimage': 'https://picsum.photos/400/200?random=1',
    },
    {
      'tieu_de': 'Nhắc nhở đặt sân',
      'noi_dung': 'Bạn có lịch đặt sân vào 10:00 - 11:00 ngày mai. Hãy chuẩn bị sẵn sàng nhé!',
      'da_xem_chua': false,
      'Urlweb': '',
      'Urlimage': 'https://picsum.photos/400/200?random=2',
    },
    {
      'tieu_de': 'Hủy đặt sân thành công',
      'noi_dung': 'Bạn đã hủy lịch đặt sân VIP lúc 18:00 - 19:00. Số tiền đã được hoàn vào ví của bạn.',
      'da_xem_chua': true,
      'Urlweb': 'https://example.com/wallet',
      'Urlimage': '',
    },
    {
      'tieu_de': 'Giảm giá đặc biệt cho bạn!',
      'noi_dung': 'Nhận ngay mã giảm giá 20% cho lần đặt sân tiếp theo. Mã: TENNIS20. Áp dụng từ 06:00 - 09:00.',
      'da_xem_chua': true,
      'Urlweb': 'https://example.com/promotion',
      'Urlimage': 'https://picsum.photos/400/200?random=3',
    },
    {
      'tieu_de': 'Đánh giá trải nghiệm',
      'noi_dung': 'Bạn vừa hoàn thành buổi chơi tại Eaxe bát min tòn. Hãy để lại đánh giá để giúp người khác nhé!',
      'da_xem_chua': true,
      'Urlweb': 'https://example.com/review/456',
      'Urlimage': '',
    },
    {
      'tieu_de': 'Thanh toán thành công',
      'noi_dung': 'Bạn đã thanh toán 180.000đ cho đơn đặt sân #456789. Cảm ơn bạn đã sử dụng dịch vụ!',
      'da_xem_chua': false,
      'Urlweb': 'https://example.com/invoice/456789',
      'Urlimage': 'https://picsum.photos/400/200?random=4',
    },
    {
      'tieu_de': 'Điểm thưởng mới',
      'noi_dung': 'Bạn vừa nhận được 50 điểm thưởng từ đơn đặt sân gần nhất. Tổng điểm hiện tại: 350 điểm.',
      'da_xem_chua': false,
      'Urlweb': 'https://example.com/rewards',
      'Urlimage': '',
    },
    {
      'tieu_de': 'Cập nhật lịch đặt sân',
      'noi_dung': 'Sân Thường đã thay đổi giờ mở cửa. Vui lòng kiểm tra lại lịch đặt của bạn.',
      'da_xem_chua': true,
      'Urlweb': 'https://example.com/schedule',
      'Urlimage': 'https://picsum.photos/400/200?random=5',
    },
  ];

  final batch = FirebaseFirestore.instance.batch();
  final collectionRef = FirebaseFirestore.instance
      .collection('thong_bao')
      .doc(userId)
      .collection('notifications');

  // Lấy số lượng thông báo cần thêm
  final soLuongThuc = soLuong > danhSachThongBao.length
      ? danhSachThongBao.length
      : soLuong;

  for (int i = 0; i < soLuongThuc; i++) {
    final docRef = collectionRef.doc();
    final thongBao = {
      ...danhSachThongBao[i],
      'ngay_tao': Timestamp.fromDate(
        DateTime.now().subtract(Duration(hours: i * 2)),
      ),
    };
    batch.set(docRef, thongBao);
  }

  await batch.commit();
  print('✅ Đã thêm $soLuongThuc thông báo cá nhân cho user: $userId');
}

/// ════════════════════════════════════════════════════════════════
/// THÊM THÔNG BÁO CÔNG KHAI (thong_bao2)
/// Cấu trúc: thong_bao2/{notificationId}
/// ════════════════════════════════════════════════════════════════

/// Thêm 1 thông báo công khai
Future<DocumentReference<Map<String, dynamic>>> add_1_thong_bao_cong_khai() async {
  final thongBao = {
    'tieu_de': 'Bảo trì hệ thống',
    'noi_dung': 'Hệ thống sẽ tạm ngưng hoạt động vào 02:00 - 04:00 ngày 15/11/2025 để bảo trì và nâng cấp. Xin lỗi vì sự bất tiện này!',
    'ngay_tao': FieldValue.serverTimestamp(),
    'Urlweb': 'https://example.com/maintenance',
    'Urlimage': 'https://picsum.photos/400/200?random=10',
  };

  final ref = await FirebaseFirestore.instance
      .collection('thong_bao2')
      .add(thongBao);

  return ref;
}

/// Thêm nhiều thông báo công khai demo
Future<void> add_nhieu_thong_bao_cong_khai({
  int soLuong = 5,
}) async {
  final danhSachThongBao = [
    {
      'tieu_de': 'Chào mừng đến với ứng dụng!',
      'noi_dung': 'Cảm ơn bạn đã tải ứng dụng đặt sân tennis của chúng tôi. Khám phá các sân tennis tốt nhất trong thành phố và đặt lịch dễ dàng!',
      'Urlweb': 'https://example.com/welcome',
      'Urlimage': 'https://picsum.photos/400/200?random=11',
    },
    {
      'tieu_de': 'Bảo trì hệ thống',
      'noi_dung': 'Hệ thống sẽ tạm ngưng hoạt động vào 02:00 - 04:00 ngày 15/11/2025 để bảo trì và nâng cấp. Xin lỗi vì sự bất tiện này!',
      'Urlweb': 'https://example.com/maintenance',
      'Urlimage': 'https://picsum.photos/400/200?random=12',
    },
    {
      'tieu_de': 'Giải Tennis mùa thu 2025',
      'noi_dung': 'Đăng ký tham gia giải Tennis mùa thu 2025! Giải thưởng hấp dẫn lên đến 50 triệu đồng. Hạn đăng ký: 30/11/2025.',
      'Urlweb': 'https://example.com/tournament',
      'Urlimage': 'https://picsum.photos/400/200?random=13',
    },
    {
      'tieu_de': 'Cập nhật tính năng mới',
      'noi_dung': 'Phiên bản mới đã có! Thêm tính năng đặt sân định kỳ, tìm bạn chơi cùng và nhiều cải tiến khác. Cập nhật ngay!',
      'Urlweb': 'https://example.com/update',
      'Urlimage': 'https://picsum.photos/400/200?random=14',
    },
    {
      'tieu_de': 'Flash Sale cuối tuần',
      'noi_dung': 'Flash Sale 50% tất cả sân tennis từ 6h-9h sáng thứ 7 & chủ nhật. Số lượng có hạn, đặt ngay!',
      'Urlweb': 'https://example.com/flashsale',
      'Urlimage': 'https://picsum.photos/400/200?random=15',
    },
    {
      'tieu_de': 'Chính sách mới',
      'noi_dung': 'Chúng tôi đã cập nhật chính sách hủy đặt sân. Hủy trước 24h được hoàn 100%, trước 12h được hoàn 50%. Vui lòng xem chi tiết.',
      'Urlweb': 'https://example.com/policy',
      'Urlimage': '',
    },
    {
      'tieu_de': 'Khai trương sân mới',
      'noi_dung': 'Chúc mừng khai trương sân tennis VIP tại Eaxe bát min tòn! Giảm giá 30% trong tuần đầu. Đặt ngay để trải nghiệm!',
      'Urlweb': 'https://example.com/new-court',
      'Urlimage': 'https://picsum.photos/400/200?random=16',
    },
    {
      'tieu_de': 'Mẹo chơi tennis hiệu quả',
      'noi_dung': 'Khám phá 10 mẹo chơi tennis giúp bạn cải thiện kỹ năng nhanh chóng. Từ cách cầm vợt đến chiến thuật thi đấu!',
      'Urlweb': 'https://example.com/tips',
      'Urlimage': 'https://picsum.photos/400/200?random=17',
    },
    {
      'tieu_de': 'Khảo sát ý kiến người dùng',
      'noi_dung': 'Hãy giúp chúng tôi cải thiện dịch vụ bằng cách tham gia khảo sát ngắn (2 phút). Có quà tặng hấp dẫn!',
      'Urlweb': 'https://example.com/survey',
      'Urlimage': '',
    },
    {
      'tieu_de': 'Thông báo nghỉ lễ',
      'noi_dung': 'Thông báo lịch nghỉ lễ 30/4 - 1/5. Các sân có thể đông khách, đặt sớm để có vị trí tốt nhất!',
      'Urlweb': 'https://example.com/holiday',
      'Urlimage': 'https://picsum.photos/400/200?random=18',
    },
  ];

  final batch = FirebaseFirestore.instance.batch();
  final collectionRef = FirebaseFirestore.instance.collection('thong_bao2');

  // Lấy số lượng thông báo cần thêm
  final soLuongThuc = soLuong > danhSachThongBao.length
      ? danhSachThongBao.length
      : soLuong;

  for (int i = 0; i < soLuongThuc; i++) {
    final docRef = collectionRef.doc();
    final thongBao = {
      ...danhSachThongBao[i],
      'ngay_tao': Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: i)),
      ),
    };
    batch.set(docRef, thongBao);
  }

  await batch.commit();
  print('✅ Đã thêm $soLuongThuc thông báo công khai');
}

/// ════════════════════════════════════════════════════════════════
/// HÀM TIỆN ÍCH - THÊM ĐẦY ĐỦ DỮ LIỆU DEMO
/// ════════════════════════════════════════════════════════════════

/// Thêm đầy đủ dữ liệu demo cho 1 user (thông báo cá nhân + công khai)
Future<void> tao_du_lieu_demo_day_du({
  required String userId,
  int soThongBaoCaNhan = 8,
  int soThongBaoCongKhai = 10,
}) async {
  print('🚀 Bắt đầu tạo dữ liệu demo...');

  try {
    // 1. Thêm thông báo cá nhân
    await add_nhieu_thong_bao_ca_nhan(
      userId: userId,
      soLuong: soThongBaoCaNhan,
    );

    // 2. Thêm thông báo công khai
    await add_nhieu_thong_bao_cong_khai(
      soLuong: soThongBaoCongKhai,
    );

    print('🎉 Hoàn thành! Đã tạo dữ liệu demo thành công.');
    print('   - $soThongBaoCaNhan thông báo cá nhân');
    print('   - $soThongBaoCongKhai thông báo công khai');
  } catch (e) {
    print('❌ Lỗi khi tạo dữ liệu demo: $e');
  }
}
/*
/// ════════════════════════════════════════════════════════════════
/// CÁCH SỬ DỤNG
/// ════════════════════════════════════════════════════════════════

// 1. Thêm 1 thông báo cá nhân:
await add_1_thong_bao_ca_nhan(userId: 'user123');

// 2. Thêm nhiều thông báo cá nhân:
await add_nhieu_thong_bao_ca_nhan(userId: 'user123', soLuong: 5);

// 3. Thêm 1 thông báo công khai:
await add_1_thong_bao_cong_khai();

// 4. Thêm nhiều thông báo công khai:
await add_nhieu_thong_bao_cong_khai(soLuong: 10);

// 5. Thêm đầy đủ (khuyến nghị):
await tao_du_lieu_demo_day_du(
  userId: 'user123',
  soThongBaoCaNhan: 8,
  soThongBaoCongKhai: 10,
);
*/


