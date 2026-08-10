import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/referral_models.dart';
import '../providers/referral_provider.dart';
import 'referral_details_screen.dart';

/// Full, paginated list of the user's referrals with status + reward info.
class MyReferralsScreen extends ConsumerStatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  ConsumerState<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends ConsumerState<MyReferralsScreen> {
  final _scroll = ScrollController();
  int _page = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    // Load first page after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(referralProvider.notifier).loadHistory(page: 1);
    });
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (_loadingMore) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadingMore = true;
      _page += 1;
      await ref.read(referralProvider.notifier).loadHistory(page: _page);
      _loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(referralProvider.select((s) => s.history));

    return Scaffold(
      appBar: AppBar(title: const Text('My Referrals')),
      body: RefreshIndicator(
        onRefresh: () async {
          _page = 1;
          await ref.read(referralProvider.notifier).loadHistory(page: 1);
        },
        child: history.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('You have no referrals yet.')),
                ],
              )
            : ListView.separated(
                controller: _scroll,
                itemCount: history.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) =>
                    _HistoryTile(item: history[i]),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});
  final ReferralHistoryItem item;

  Color _statusColor() {
    switch (item.status) {
      case ReferralStatus.rewardReleased:
        return Colors.green;
      case ReferralStatus.rejected:
      case ReferralStatus.expired:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(item.refereeName.isNotEmpty
            ? item.refereeName[0].toUpperCase()
            : '?'),
      ),
      title: Text(item.refereeName),
      subtitle: Text(
        item.joinedDate != null
            ? 'Joined ${_fmt(item.joinedDate!)}'
            : 'Not joined yet',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(item.status.label,
                style: TextStyle(color: _statusColor(), fontSize: 12)),
          ),
          const SizedBox(height: 4),
          if (item.rewardAmount > 0)
            Text('₹${item.rewardAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReferralDetailsScreen(item: item),
        ),
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
