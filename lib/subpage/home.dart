import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khachthue/subpage/sub_in_home/CoSoDetailPage.dart';
import 'package:khachthue/subpage/sub_in_home/sub_coso_datsan/TrangThaiSan.dart';
import 'package:khachthue/subpage/sub_in_me/like.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePageContent();
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tinhController = TextEditingController();
  final TextEditingController _huyenController = TextEditingController();
  final TextEditingController _xaController = TextEditingController();

  String _searchText = '';
  String _selectedTinh = '';
  String _selectedHuyen = '';
  String _selectedXa = '';
  bool _showLocationFilters = false; // Trạng thái ẩn/hiện bộ lọc địa chỉ

  @override
  void dispose() {
    _searchController.dispose();
    _tinhController.dispose();
    _huyenController.dispose();
    _xaController.dispose();
    super.dispose();
  }

  // Hàm tạo text mô tả bộ lọc đang áp dụng
  String _getFilterDescription() {
    List<String> filters = [];

    if (_searchText.isNotEmpty) {
      filters.add('tên "$_searchText"');
    }
    if (_selectedXa.isNotEmpty) {
      filters.add('xã "$_selectedXa"');
    }
    if (_selectedHuyen.isNotEmpty) {
      filters.add('phường "$_selectedHuyen"');
    }
    if (_selectedTinh.isNotEmpty) {
      filters.add('tỉnh "$_selectedTinh"');
    }

    if (filters.isEmpty) {
      return 'Đang hiển thị tất cả cơ sở. Mở rộng menu tìm kiếm để tìm theo địa chỉ';
    }

    return 'Đang lọc theo: ${filters.join(", ")}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterSection(),
        Expanded(child: _buildCoSoList()),
      ],
    );
  }

  /// phần tìm kiêếm
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Hàng đầu tiên: ô tìm kiếm và các nút
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm tên sân...',
                      prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF7F8C8D)),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: Color(0xFF7F8C8D)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchText = '');
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFFBDC3C7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFFBDC3C7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFFC44536)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF95A5A6)),
                    ),
                    style: TextStyle(fontSize: 14),
                    onChanged: (value) => setState(() => _searchText = value.trim()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nút toggle bộ lọc địa chỉ
              Container(
                width: 36,
                height: 36,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showLocationFilters = !_showLocationFilters;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _showLocationFilters
                            ? Color(0xFFC44536).withOpacity(0.1)
                            : Color(0xFFECF0F1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showLocationFilters
                              ? Color(0xFFC44536)
                              : Color(0xFFBDC3C7),
                        ),
                      ),
                      child: Icon(
                        _showLocationFilters
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: _showLocationFilters
                            ? Color(0xFFC44536)
                            : Color(0xFF7F8C8D),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LikePage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFECF0F1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFBDC3C7)),
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: Color(0xFFC44536),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bộ lọc địa chỉ (ẩn/hiện) - NẰM DƯỚI Ô TÌM KIẾM
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallFilterField(
                        controller: _xaController,
                        hint: 'Xã',
                        value: _selectedXa,
                        onChanged: (v) => setState(() => _selectedXa = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallFilterField(
                        controller: _huyenController,
                        hint: 'Huyện',
                        value: _selectedHuyen,
                        onChanged: (v) => setState(() => _selectedHuyen = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallFilterField(
                        controller: _tinhController,
                        hint: 'Tỉnh',
                        value: _selectedTinh,
                        onChanged: (v) => setState(() => _selectedTinh = v.trim()),
                      ),
                    ),
                  ],
                ),
                if (_selectedTinh.isNotEmpty || _selectedHuyen.isNotEmpty || _selectedXa.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        _tinhController.clear();
                        _huyenController.clear();
                        _xaController.clear();
                        setState(() {
                          _selectedTinh = '';
                          _selectedHuyen = '';
                          _selectedXa = '';
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.clear_all, size: 16, color: Color(0xFFC44536)),
                          SizedBox(width: 4),
                          Text(
                            'Xóa bộ lọc địa chỉ',
                            style: TextStyle(
                              color: Color(0xFFC44536),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            crossFadeState: _showLocationFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 300),
          ),

          // Dòng thông báo bộ lọc - TOÀN CHIỀU NGANG, CHỮ GIỮA - NẰM DƯỚI BỘ LỌC ĐỊA CHỈ
          Container(
            width: double.infinity, // CHIẾM TOÀN BỘ CHIỀU NGANG
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Color(0xFFE9ECEF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // CHỮ Ở GIỮA
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Color(0xFF6C757D),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _getFilterDescription(),
                    textAlign: TextAlign.center, // CĂN GIỮA CHỮ
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFilterField({
    required TextEditingController controller,
    required String hint,
    required String value,
    required Function(String) onChanged,
  }) {
    return Container(
      height: 32,
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF95A5A6)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFBDC3C7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFBDC3C7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFC44536)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          suffixIcon: value.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, size: 16, color: Color(0xFF7F8C8D)),
            onPressed: () {
              controller.clear();
              onChanged('');
            },
          )
              : null,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCoSoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('co_so').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Lỗi: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyWidget('Chưa có cơ sở nào');
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isOke = data['is_oke'] as int? ?? 0;
          if (isOke <= 0) return false;

          final ten = (data['ten'] as String? ?? '').toLowerCase();
          final tinh = (data['tinh'] as String? ?? '').toLowerCase();
          final huyen = (data['huyen'] as String? ?? '').toLowerCase();
          final xa = (data['xa'] as String? ?? '').toLowerCase();

          final matchSearch = _searchText.isEmpty || ten.contains(_searchText.toLowerCase());
          final matchTinh = _selectedTinh.isEmpty || tinh.contains(_selectedTinh.toLowerCase());
          final matchHuyen = _selectedHuyen.isEmpty || huyen.contains(_selectedHuyen.toLowerCase());
          final matchXa = _selectedXa.isEmpty || xa.contains(_selectedXa.toLowerCase());

          return matchSearch && matchTinh && matchHuyen && matchXa;
        }).toList();

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aIsOke = aData['is_oke'] as int? ?? 0;
          final bIsOke = bData['is_oke'] as int? ?? 0;
          return bIsOke.compareTo(aIsOke);
        });

        if (docs.isEmpty) {
          return _buildEmptyWidget('Không tìm thấy cơ sở phù hợp');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildCoSoCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildCoSoCard(BuildContext context, String id, Map<String, dynamic> data) {
    final anh1 = data['anh_dai_dien'] as String? ?? '';
    final danhSachAnh = data['danh_sach_anh'] as List<dynamic>? ?? [];
    final anh2 = danhSachAnh.isNotEmpty ? danhSachAnh[0] as String : '';

    final ten = data['ten'] as String? ?? 'Chưa có tên';
    final diaChiChiTiet = data['dia_chi_chi_tiet'] as String? ?? '';
    final xa = data['xa'] as String? ?? '';
    final huyen = data['huyen'] as String? ?? '';
    final tinh = data['tinh'] as String? ?? '';
    final sdt = data['sdt'] as String? ?? '';
    final gioMo = data['gio_mo_cua'] as String? ?? '';
    final gioDong = data['gio_dong_cua'] as String? ?? '';
    final isOke = data['is_oke'] as int? ?? 0;

    final diaChi = [diaChiChiTiet, xa, huyen, tinh].where((s) => s.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CoSoDetailPage(coSoId: id, coSoData: data),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // PHẦN ẢNH
              Container(
                width: 140,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    if (anh2.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        child: Image.network(
                          anh2,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderBanner(),
                        ),
                      )
                    else
                      _buildPlaceholderBanner(),

                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: anh1.isNotEmpty
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            anh1,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholderLogo(),
                          ),
                        )
                            : _buildPlaceholderLogo(),
                      ),
                    ),

                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFC44536),
                              Color(0xFFE74C3C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 12),
                            SizedBox(width: 2),
                            Text(
                              '$isOke',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // PHẦN THÔNG TIN
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxHeight: 40), // THÊM DÒNG NÀY
                        child: Text(
                          ten,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),



                      if (diaChi.isNotEmpty)
                        Container(
                          constraints: BoxConstraints(maxHeight: 34), // THÊM DÒNG NÀY
                          child:
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on, size: 14, color: Color(0xFF7F8C8D)),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  diaChi,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F8C8D),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Thông tin liên hệ
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (sdt.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: Color(0xFF7F8C8D)),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          sdt,
                                          style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                if (gioMo.isNotEmpty || gioDong.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 12, color: Color(0xFF7F8C8D)),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '$gioMo - $gioDong',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // NÚT ĐẶT SÂN
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TrangThaiSan(
                                    coSoId: id,
                                    coSoData: data,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFC44536),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 2,
                              minimumSize: Size(0, 0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_tennis, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Đặt sân',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPlaceholderBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Icon(Icons.photo, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(Icons.sports_tennis, size: 20, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFC44536)),
          SizedBox(height: 16),
          Text(
            'Đang tải dữ liệu...',
            style: TextStyle(color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Color(0xFFBDC3C7)),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
          SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(color: Color(0xFF7F8C8D)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}