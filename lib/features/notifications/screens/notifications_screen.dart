import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_notification_model.dart';
import '../providers/notifications_provider.dart';

const _kPrimary = Color(0xFF2453FF);
const _kBg      = Color(0xFFF5F6FA);
const _kInk     = Color(0xFF0A1645);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh, then mark everything read once the list is shown.
    Future.microtask(() async {
      final notifier = ref.read(notificationsProvider.notifier);
      await notifier.refresh();
      await notifier.markAllRead();
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'order_created':
        return Icons.receipt_long_rounded;
      case 'pickup_assigned':
        return Icons.delivery_dining_rounded;
      case 'itemized':
      case 'clothes_received':
        return Icons.checklist_rounded;
      case 'processing':
      case 'washing_started':
        return Icons.local_laundry_service_rounded;
      case 'out_for_delivery':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.celebration_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'payment_success':
        return Icons.credit_card_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: _kInk),
        ),
      ),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: state.isLoading && state.items.isEmpty
            ? const Center(
                child:
                    CircularProgressIndicator(color: _kPrimary, strokeWidth: 2))
            : state.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.notifications_off_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'No notifications yet',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Order updates will appear here',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    itemCount: state.items.length,
                    itemBuilder: (context, i) =>
                        _NotificationTile(
                          n: state.items[i],
                          icon: _iconFor(state.items[i].type),
                          timeAgo: _timeAgo(state.items[i].createdAt),
                        ),
                  ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.n,
    required this.icon,
    required this.timeAgo,
  });

  final AppNotificationModel n;
  final IconData icon;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: n.isRead ? Colors.white : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: n.isRead ? const Color(0xFFE8EEFF) : const Color(0xFFD6E2FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _kInk),
                      ),
                    ),
                    if (!n.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _kPrimary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  n.body,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                      height: 1.35),
                ),
                const SizedBox(height: 5),
                Text(
                  timeAgo,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
