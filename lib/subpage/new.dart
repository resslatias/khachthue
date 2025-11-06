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
        // Thanh filter & actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Chỉ hiện chưa đọc'),
                selected: _onlyUnread,
                onSelected: _currentUser != null
                    ? (v) => setState(() => _onlyUnread = v)
                    : null,
              ),
              const Spacer(),
              if (_currentUser != null)
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Đánh dấu đã đọc'),
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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Lỗi tải thông báo: ${snapshot.error}'),
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
              children: const [
                Icon(Icons.notifications_off, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Không có thông báo',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
        const SnackBar(content: Text('Đã đánh dấu đã đọc tất cả')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
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
                    child: Icon(
                      notification.isPublic ? Icons.campaign : Icons.person,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.tieuDe,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          notification.isPublic ? 'Thông báo chung' : 'Thông báo cá nhân',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _fmtTime(notification.ngayTao),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
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
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),

              // Nút mở link nếu có
              if (notification.urlWeb.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
        const SnackBar(content: Text('Không thể mở liên kết')),
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
        ? Colors.green
        : Colors.transparent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
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
                    ? Colors.blue.shade100
                    : Colors.green.shade100,
                child: Icon(
                  notification.isPublic ? Icons.campaign : Icons.notifications,
                  color: notification.isPublic ? Colors.blue : Colors.green,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmtTime(notification.ngayTao),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
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
                            ? Colors.blue.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notification.isPublic ? 'Thông báo chung' : 'Cá nhân',
                        style: TextStyle(
                          fontSize: 10,
                          color: notification.isPublic ? Colors.blue : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      notification.noiDung,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
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