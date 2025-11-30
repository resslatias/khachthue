import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool _onlyUnread = false; // Mặc định hiển thị tất cả
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    // Lắng nghe thay đổi trạng thái đăng nhập
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header mới - tất cả trong một hàng
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black26,
                offset: Offset(0, 3),
              )
            ],
          ),
          child: Row(
            children: [
              // Tiêu đề
              Row(
                children: [
                  Icon(Icons.notifications, color: Color(0xFFC44536), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Các nút lọc và action
              Row(
                children: [
                  FilterChip(
                    label: Text('Chưa đọc', style: TextStyle(fontSize: 12)),
                    selected: _onlyUnread,
                    selectedColor: Color(0xFFC44536).withOpacity(0.2),
                    checkmarkColor: Color(0xFFC44536),
                    onSelected: _currentUser != null
                        ? (v) => setState(() => _onlyUnread = v)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  if (_currentUser != null)
                    TextButton.icon(
                      onPressed: _markAllAsRead,
                      icon: Icon(Icons.done_all, size: 16, color: Color(0xFFC44536)),
                      label: Text('Đánh dấu\nđã đọc',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFC44536),
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Danh sách thông báo
        Expanded(
          child: _buildNotificationList(),
        ),
      ],
    );
  }
  Widget _buildNotificationList() {
    return StreamBuilder<List<NotificationItem>>(
      stream: _getCombinedNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFFC44536)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Color(0xFFE74C3C)),
                  SizedBox(height: 16),
                  Text(
                    'Lỗi tải thông báo: ${snapshot.error}',
                    style: TextStyle(color: Color(0xFF7F8C8D)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        var notifications = snapshot.data ?? [];

        // LỌC Ở CLIENT THAY VÌ FIRESTORE (tránh cần composite index)
        if (_onlyUnread && _currentUser != null) {
          notifications = notifications.where((n) =>
          !n.isPublic && !n.daXem
          ).toList();
        }

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 60, color: Color(0xFFBDC3C7)),
                SizedBox(height: 16),
                Text(
                  'Không có thông báo',
                  style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final notif = notifications[i];
            return _NotifTile(
              notification: notif,
              onTap: () => _handleNotificationTap(notif),
            );
          },
        );
      },
    );
  }

  // Kết hợp stream từ cả 2 collection
  Stream<List<NotificationItem>> _getCombinedNotificationsStream() {
    final publicStream = _getPublicNotificationsStream();

    if (_currentUser == null) {
      // Chưa đăng nhập: chỉ hiện thông báo công khai
      return publicStream;
    }

    // Đã đăng nhập: kết hợp cả 2 loại thông báo
    final privateStream = _getPrivateNotificationsStream(_currentUser!.uid);

    return publicStream.asyncExpand((publicList) {
      return privateStream.map((privateList) {
        final combined = [...publicList, ...privateList];
        // Sắp xếp theo ngày tạo giảm dần
        combined.sort((a, b) => b.ngayTao.compareTo(a.ngayTao));
        return combined;
      });
    });
  }

  // Stream thông báo công khai (thong_bao2)
  Stream<List<NotificationItem>> _getPublicNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('thong_bao2')
        .orderBy('ngay_tao', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationItem(
          id: doc.id,
          tieuDe: data['tieu_de'] ?? '',
          noiDung: data['noi_dung'] ?? '',
          ngayTao: (data['ngay_tao'] as Timestamp?)?.toDate() ?? DateTime.now(),
          urlWeb: data['Urlweb'] ?? '',
          urlImage: data['Urlimage'] ?? '',
          daXem: true, // Thông báo công khai không có trạng thái đã xem
          isPublic: true,
          docRef: null,
        );
      }).toList();
    });
  }

  // Stream thông báo cá nhân (thong_bao) - BỎ WHERE da_xem_chua
  Stream<List<NotificationItem>> _getPrivateNotificationsStream(String userId) {
    // CHỈ QUERY THEO userId VÀ orderBy, KHÔNG WHERE da_xem_chua
    return FirebaseFirestore.instance
        .collection('thong_bao')
        .doc(userId)
        .collection('notifications')
        .orderBy('ngay_tao', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationItem(
          id: doc.id,
          tieuDe: data['tieu_de'] ?? '',
          noiDung: data['noi_dung'] ?? '',
          ngayTao: (data['ngay_tao'] as Timestamp?)?.toDate() ?? DateTime.now(),
          urlWeb: data['Urlweb'] ?? '',
          urlImage: data['Urlimage'] ?? '',
          daXem: data['da_xem_chua'] ?? false,
          isPublic: false,
          docRef: doc.reference,
        );
      }).toList();
    });
  }

  Future<void> _handleNotificationTap(NotificationItem notif) async {
    // Đánh dấu đã xem nếu là thông báo cá nhân
    if (!notif.isPublic && !notif.daXem && notif.docRef != null) {
      await notif.docRef!.update({'da_xem_chua': true});
    }

    if (!mounted) return;

    // Hiển thị chi tiết
    _showDetail(context, notification: notif);
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('thong_bao')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .where('da_xem_chua', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'da_xem_chua': true});
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã đánh dấu đã đọc tất cả'),
          backgroundColor: Color(0xFF2E8B57),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
    }
  }

  void _showDetail(BuildContext context, {required NotificationItem notification}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: notification.isPublic
                        ? Color(0xFF3498DB).withOpacity(0.1)
                        : Color(0xFFC44536).withOpacity(0.1),
                    child: Icon(
                      notification.isPublic ? Icons.campaign : Icons.person,
                      color: notification.isPublic ? Color(0xFF3498DB) : Color(0xFFC44536),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.tieuDe,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          notification.isPublic ? 'Thông báo chung' : 'Thông báo cá nhân',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmtTime(notification.ngayTao),
                    style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hiển thị ảnh nếu có
              if (notification.urlImage.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    notification.urlImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Nội dung
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Text(
                    notification.noiDung,
                    style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
                  ),
                ),
              ),

              // Nút mở link nếu có
              if (notification.urlWeb.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFC44536),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _launchUrl(notification.urlWeb),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở liên kết'),
                  ),
                ),
              ],

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở liên kết'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
    }
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

// Model cho thông báo
class NotificationItem {
  final String id;
  final String tieuDe;
  final String noiDung;
  final DateTime ngayTao;
  final String urlWeb;
  final String urlImage;
  final bool daXem;
  final bool isPublic; // true = thông báo công khai, false = cá nhân
  final DocumentReference? docRef;

  NotificationItem({
    required this.id,
    required this.tieuDe,
    required this.noiDung,
    required this.ngayTao,
    required this.urlWeb,
    required this.urlImage,
    required this.daXem,
    required this.isPublic,
    this.docRef,
  });
}

// Widget hiển thị item thông báo
class _NotifTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotifTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = !notification.isPublic && !notification.daXem
        ? Color(0xFFC44536)
        : Colors.transparent;

    return Container(
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar/icon
                CircleAvatar(
                  radius: 20,
                  backgroundColor: notification.isPublic
                      ? Color(0xFF3498DB).withOpacity(0.1)
                      : Color(0xFFC44536).withOpacity(0.1),
                  child: Icon(
                    notification.isPublic ? Icons.campaign : Icons.notifications,
                    color: notification.isPublic ? Color(0xFF3498DB) : Color(0xFFC44536),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Nội dung
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.tieuDe,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _fmtTime(notification.ngayTao),
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Badge loại thông báo
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: notification.isPublic
                              ? Color(0xFF3498DB).withOpacity(0.1)
                              : Color(0xFFC44536).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.isPublic ? 'Thông báo chung' : 'Cá nhân',
                          style: TextStyle(
                            fontSize: 10,
                            color: notification.isPublic ? Color(0xFF3498DB) : Color(0xFFC44536),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        notification.noiDung,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF2C3E50), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}';
  }
}