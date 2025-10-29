import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});
  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  bool _onlyUnread = true; // lọc "Chưa đọc"

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.notifications_off, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Bạn chưa đăng nhập,\n nên không có thông báo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    // Query theo người nhận
    Query<Map<String, dynamic>> baseQ = FirebaseFirestore.instance
        .collection('thong_bao')
        .where('nguoi_nhan', isEqualTo: user.uid)
        .orderBy('ngay_tao', descending: true);

    if (_onlyUnread) {
      baseQ = baseQ.where('da_xem_chua', isEqualTo: false);
    }

    return Column(
      children: [
        // Thanh filter & actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Chưa đọc'),
                selected: _onlyUnread,
                onSelected: (v) => setState(() => _onlyUnread = v),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  // Đánh dấu đã đọc hết của user hiện tại
                  final snap = await FirebaseFirestore.instance
                      .collection('thong_bao')
                      .where('nguoi_nhan', isEqualTo: user.uid)
                      .where('da_xem_chua', isEqualTo: false)
                      .get();
                  final batch = FirebaseFirestore.instance.batch();
                  for (final d in snap.docs) {
                    batch.update(d.reference, {'da_xem_chua': true});
                  }
                  await batch.commit();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đánh dấu đã đọc hết')),
                  );
                },
                icon: const Icon(Icons.done_all),
                label: const Text('Đánh dấu đã đọc hết'),
              ),
            ],
          ),
        ),

        // Danh sách thông báo
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseQ.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Lỗi tải thông báo: ${snapshot.error}'),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Không có thông báo'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final tieuDe = (data['tieu_de'] ?? '') as String;
                  final noiDung = (data['noi_dung'] ?? '') as String;
                  final daXem = (data['da_xem_chua'] ?? false) as bool;
                  final ts = data['ngay_tao'];
                  final DateTime? createdAt =
                  ts is Timestamp ? ts.toDate() : null;

                  return _NotifTile(
                    title: tieuDe,
                    subtitle: noiDung,
                    timeText: _fmtTime(createdAt),
                    unread: !daXem,
                    onTap: () async {
                      // Đánh dấu đã xem & mở bottom sheet
                      if (!daXem) {
                        await d.reference.update({'da_xem_chua': true});
                      }
                      if (!mounted) return;
                      _showDetail(context,
                          title: tieuDe,
                          content: noiDung,
                          timeText: _fmtTime(createdAt));
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    // dd/MM, HH:mm
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
    // có thể thay bằng intl nếu bạn đã dùng package 'intl'
  }

  void _showDetail(BuildContext context,
      {required String title,
        required String content,
        required String timeText}) {
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
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    timeText,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _NotifTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeText;
  final bool unread;
  final VoidCallback onTap;

  const _NotifTile({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = unread ? Colors.green : Colors.transparent;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // avatar/icon thể hiện loại thông báo
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.notifications, color: Colors.black54),
              ),
              const SizedBox(width: 12),
              // nội dung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // tiêu đề + thời gian + chấm unread
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
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
                          timeText,
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
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
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
}
