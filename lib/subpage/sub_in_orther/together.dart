import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// TOGETHER PAGE – Trang tìm người chơi cùng
class TogetherPage extends StatefulWidget {
  const TogetherPage({super.key});

  @override
  State<TogetherPage> createState() => _TogetherPageState();
}

class _TogetherPageState extends State<TogetherPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final List<String> _sessions = ['sang', 'chieu', 'toi'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Tìm người chơi cùng',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Color(0xFF3498DB),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(110),
          child: Column(
            children: [
              // Date selector
              Container(
                height: 50,
                child: _buildDateSelector(),
              ),
              // Tab bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFF3498DB),
                  unselectedLabelColor: Color(0xFF7F8C8D),
                  indicatorColor: Color(0xFF3498DB),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: '🌅 Sáng'),
                    Tab(text: '☀️ Chiều'),
                    Tab(text: '🌙 Tối'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _sessions.map((session) {
          return _buildPostList(session);
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostDialog(),
        backgroundColor: Color(0xFF3498DB),
        icon: Icon(Icons.add),
        label: Text('Tạo bài'),
      ),
    );
  }

  Widget _buildDateSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = DateTime.now().add(Duration(days: index));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final isSelected = dateStr == _selectedDate;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = dateStr;
            });
          },
          child: Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd/MM').format(date),
                  style: TextStyle(
                    color: isSelected ? Color(0xFF3498DB) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _getWeekday(date),
                  style: TextStyle(
                    color: isSelected ? Color(0xFF3498DB) : Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getWeekday(DateTime date) {
    const weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return weekdays[date.weekday % 7];
  }

  Widget _buildPostList(String session) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(_selectedDate)
          .collection(session)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Đã có lỗi xảy ra'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index].data() as Map<String, dynamic>;
            return _buildPostCard(post, posts[index].id);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_tennis,
            size: 80,
            color: Color(0xFF3498DB).withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            'Chưa có bài đăng nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7F8C8D),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Hãy tạo bài đăng đầu tiên!',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF95A5A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, String postId) {
    final creator = post['nguoi_tao'] as Map<String, dynamic>;
    final location = post['dia_chi'] as Map<String, dynamic>;
    final participants = post['nguoi_tham_gia'] as List<dynamic>? ?? [];
    final currentCount = post['so_nguoi_hien_tai'] ?? 0;
    final maxCount = post['so_nguoi'] ?? 4;
    final isFull = currentCount >= maxCount;

    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == creator['userId'];
    final isJoined = participants.any((p) => p['userId'] == currentUser?.uid);

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF3498DB),
                  child: Text(
                    creator['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator['name'] ?? 'Người dùng',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${location['Phuong']}, ${location['huyen']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFull ? Color(0xFFE74C3C).withOpacity(0.1) : Color(0xFF2ECC71).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$currentCount/$maxCount người',
                    style: TextStyle(
                      color: isFull ? Color(0xFFE74C3C) : Color(0xFF2ECC71),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Description
            Text(
              post['mo_ta'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                height: 1.5,
              ),
            ),
            SizedBox(height: 12),
            // Court info
            if (post['id_co_so'] != null)
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Color(0xFF3498DB)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post['id_co_so'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
            // Actions
            Row(
              children: [
                if (participants.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: -8,
                      children: participants.take(3).map((p) {
                        return CircleAvatar(
                          radius: 12,
                          backgroundColor: Color(0xFFE8F4F8),
                          child: Text(
                            p['name']?.substring(0, 1).toUpperCase() ?? '?',
                            style: TextStyle(fontSize: 10, color: Color(0xFF3498DB)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (isCreator)
                  TextButton.icon(
                    onPressed: () => _deletePost(postId),
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('Xóa'),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFFE74C3C),
                    ),
                  )
                else if (isJoined)
                  ElevatedButton.icon(
                    onPressed: () => _leavePost(post, postId),
                    icon: Icon(Icons.exit_to_app, size: 18),
                    label: Text('Rời khỏi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE74C3C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: isFull ? null : () => _joinPost(post, postId),
                    icon: Icon(Icons.add, size: 18),
                    label: Text(isFull ? 'Đã đầy' : 'Tham gia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: Color(0xFF95A5A6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    final formKey = GlobalKey<FormState>();
    final descController = TextEditingController();
    final courtController = TextEditingController();

    String selectedDate = _selectedDate;
    String selectedSession = _sessions[_tabController.index];
    int selectedMaxPeople = 4;

    String selectedWard = 'Dịch Vọng';
    String selectedDistrict = 'Cầu Giấy';
    String selectedProvince = 'Hà Nội';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: EdgeInsets.all(24),
                    children: [
                      Text(
                        'Tạo bài tìm người chơi',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Date picker
                      Text('Ngày chơi', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.parse(selectedDate),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 30)),
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Color(0xFFE0E0E0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Color(0xFF3498DB)),
                              SizedBox(width: 12),
                              Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(selectedDate))),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Session picker
                      Text('Buổi chơi', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(
                        children: _sessions.map((s) {
                          final labels = {'sang': 'Sáng', 'chieu': 'Chiều', 'toi': 'Tối'};
                          final isSelected = s == selectedSession;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: s != 'toi' ? 8 : 0),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedSession = s),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFF3498DB) : Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Color(0xFF3498DB) : Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Text(
                                    labels[s]!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Color(0xFF7F8C8D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),

                      // Max people
                      Text('Số người', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(
                        children: [2, 4, 6].map((n) {
                          final isSelected = n == selectedMaxPeople;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: n != 6 ? 8 : 0),
                              child: InkWell(
                                onTap: () => setModalState(() => selectedMaxPeople = n),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Color(0xFF2ECC71) : Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Color(0xFF2ECC71) : Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Text(
                                    '$n người',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Color(0xFF7F8C8D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),

                      // Location
                      Text('Địa điểm', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedWard,
                              decoration: InputDecoration(
                                labelText: 'Phường',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['Dịch Vọng', 'Mai Dịch', 'Nghĩa Tân', 'Quan Hoa'].map((w) {
                                return DropdownMenuItem(value: w, child: Text(w));
                              }).toList(),
                              onChanged: (v) => setModalState(() => selectedWard = v!),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedDistrict,
                              decoration: InputDecoration(
                                labelText: 'Quận',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['Cầu Giấy', 'Ba Đình', 'Đống Đa'].map((d) {
                                return DropdownMenuItem(value: d, child: Text(d));
                              }).toList(),
                              onChanged: (v) => setModalState(() => selectedDistrict = v!),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Court
                      TextFormField(
                        controller: courtController,
                        decoration: InputDecoration(
                          labelText: 'Tên sân (tùy chọn)',
                          hintText: 'VD: Sân cầu lông Cầu Giấy',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Mô tả',
                          hintText: 'Mô tả về buổi chơi...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Vui lòng nhập mô tả' : null,
                      ),
                      SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await _createPost(
                              selectedDate,
                              selectedSession,
                              selectedMaxPeople,
                              selectedWard,
                              selectedDistrict,
                              selectedProvince,
                              courtController.text,
                              descController.text,
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tạo bài đăng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
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

  Future<void> _createPost(
      String date,
      String session,
      int maxPeople,
      String ward,
      String district,
      String province,
      String court,
      String description,
      ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final postId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

      final postData = {
        'postId': postId,
        'ngay_choi': date,
        'buoi_choi': session,
        'nguoi_tao': {
          'userId': user.uid,
          'name': userData['name'] ?? user.displayName ?? 'Người dùng',
          'phone': userData['phone'] ?? '',
          'email': user.email ?? '',
        },
        'mo_ta': description,
        'dia_chi': {
          'Phuong': ward,
          'huyen': district,
          'tinh': province,
        },
        'id_co_so': court.isEmpty ? null : court,
        'so_nguoi': maxPeople,
        'so_nguoi_hien_tai': 1,
        'nguoi_tham_gia': [
          {
            'userId': user.uid,
            'name': userData['name'] ?? user.displayName ?? 'Người dùng',
            'phone': userData['phone'] ?? '',
            'email': user.email ?? '',
            'joinedAt': Timestamp.now(),
          }
        ],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(date)
          .collection(session)
          .doc(postId)
          .set(postData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã tạo bài đăng thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    }
  }

  Future<void> _joinPost(Map<String, dynamic> post, String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final participants = List<Map<String, dynamic>>.from(post['nguoi_tham_gia'] ?? []);
      participants.add({
        'userId': user.uid,
        'name': userData['name'] ?? user.displayName ?? 'Người dùng',
        'phone': userData['phone'] ?? '',
        'email': user.email ?? '',
        'joinedAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post['ngay_choi'])
          .collection(post['buoi_choi'])
          .doc(postId)
          .update({
        'nguoi_tham_gia': participants,
        'so_nguoi_hien_tai': participants.length,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã tham gia thành công!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    }
  }

  Future<void> _leavePost(Map<String, dynamic> post, String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final participants = List<Map<String, dynamic>>.from(post['nguoi_tham_gia'] ?? []);
      participants.removeWhere((p) => p['userId'] == user.uid);

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(post['ngay_choi'])
          .collection(post['buoi_choi'])
          .doc(postId)
          .update({
        'nguoi_tham_gia': participants,
        'so_nguoi_hien_tai': participants.length,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã rời khỏi bài đăng!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa bài đăng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(_selectedDate)
          .collection(_sessions[_tabController.index])
          .doc(postId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Đã xóa bài đăng!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $e')),
      );
    }
  }
}