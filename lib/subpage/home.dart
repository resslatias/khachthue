import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:khachthue/subpage/sub_in_home/CoSoDetailPage.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    _tinhController.dispose();
    _huyenController.dispose();
    _xaController.dispose();
    super.dispose();
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Tìm kiếm theo tên
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo tên sân...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchText = '');
                },
              )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => setState(() => _searchText = value.trim()),
          ),
          const SizedBox(height: 12),
          // Bộ lọc Tỉnh, Huyện, Xã
          Row(
            children: [
              Expanded(
                child: _buildFilterField(
                  controller: _tinhController,
                  hint: 'Tỉnh/TP',
                  value: _selectedTinh,
                  onChanged: (v) => setState(() {
                    _selectedTinh = v.trim();
                    _selectedHuyen = '';
                    _selectedXa = '';
                    _huyenController.clear();
                    _xaController.clear();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterField(
                  controller: _huyenController,
                  hint: 'Quận/Huyện',
                  value: _selectedHuyen,
                  onChanged: (v) => setState(() {
                    _selectedHuyen = v.trim();
                    _selectedXa = '';
                    _xaController.clear();
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterField(
                  controller: _xaController,
                  hint: 'Xã/Phường',
                  value: _selectedXa,
                  onChanged: (v) => setState(() => _selectedXa = v.trim()),
                ),
              ),
            ],
          ),
          if (_selectedTinh.isNotEmpty || _selectedHuyen.isNotEmpty || _selectedXa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () {
                  _tinhController.clear();
                  _huyenController.clear();
                  _xaController.clear();
                  setState(() {
                    _selectedTinh = '';
                    _selectedHuyen = '';
                    _selectedXa = '';
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Xóa bộ lọc'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterField({
    required TextEditingController controller,
    required String hint,
    required String value,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: value.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () {
            controller.clear();
            onChanged('');
          },
        )
            : null,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildCoSoList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('co_so').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Chưa có cơ sở nào'));
        }

        // Lọc dữ liệu
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
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

        if (docs.isEmpty) {
          return const Center(child: Text('Không tìm thấy cơ sở phù hợp'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
    final anh1 = data['anh1'] as String? ?? '';
    final ten = data['ten'] as String? ?? 'Chưa có tên';
    final diaChiChiTiet = data['dia_chi_chi_tiet'] as String? ?? '';
    final xa = data['xa'] as String? ?? '';
    final huyen = data['huyen'] as String? ?? '';
    final tinh = data['tinh'] as String? ?? '';
    final sdt = data['sdt'] as String? ?? '';
    final gioMo = data['gio_mo_cua'] as String? ?? '';
    final gioDong = data['gio_dong_cua'] as String? ?? '';
    final moTa = data['mo_ta'] as String? ?? '';

    final diaChi = [diaChiChiTiet, xa, huyen, tinh]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CoSoDetailPage(coSoId: id, coSoData: data),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: anh1.isNotEmpty
                    ? Image.network(
                  anh1,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(width: 12),
              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ten,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (diaChi.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              diaChi,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (sdt.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(sdt, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    if (gioMo.isNotEmpty || gioDong.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$gioMo - $gioDong',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    if (moTa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          moTa,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.sports_tennis, size: 40, color: Colors.grey),
    );
  }
}