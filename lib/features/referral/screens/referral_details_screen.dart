import 'package:flutter/material.dart';
import '../models/referral_models.dart';

/// Read-only detail view for a single referral, including the reward outcome
/// and any rejection reason. Also renders the milestone timeline.
class ReferralDetailsScreen extends StatelessWidget {
  const ReferralDetailsScreen({super.key, required this.item});
  final ReferralHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(item.refereeName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Friend', item.refereeName),
          _row('Status', item.status.label),
          _row(
            'Joined',
            item.joinedDate != null ? _fmt(item.joinedDate!) : '—',
          ),
          _row('Reward', '₹${item.rewardAmount.toStringAsFixed(0)}'),
          _row('Reward status', item.rewardStatus),
          _row(
            'Released',
            item.releasedDate != null ? _fmt(item.releasedDate!) : '—',
          ),
          if (item.pendingReward > 0)
            _row('Pending reward',
                '₹${item.pendingReward.toStringAsFixed(0)}'),
          if (item.rejectedReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.rejectedReason!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Progress', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Timeline(status: item.status),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

/// Simple vertical stepper reflecting the referral status flow.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final ReferralStatus status;

  static const _steps = [
    ReferralStatus.registered,
    ReferralStatus.firstOrderCompleted,
    ReferralStatus.paymentCompleted,
    ReferralStatus.rewardReleased,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexWhere((s) => s == status);
    final reached = status == ReferralStatus.rewardReleased
        ? _steps.length
        : (currentIndex < 0 ? 0 : currentIndex + 1);

    return Column(
      children: List.generate(_steps.length, (i) {
        final done = i < reached;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Colors.green : Colors.grey,
                  size: 22,
                ),
                if (i != _steps.length - 1)
                  Container(
                    width: 2,
                    height: 28,
                    color: done ? Colors.green : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_steps[i].label),
            ),
          ],
        );
      }),
    );
  }
}
