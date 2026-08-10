import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delete_account_models.dart';
import '../providers/delete_account_provider.dart';
import 'delete_verification_screen.dart';
import 'delete_success_screen.dart';

/// Step 1 of the deletion flow.
/// Clearly explains what data is deleted vs retained (Google Play requirement),
/// collects a reason + optional comment, and requires explicit confirmation
/// before proceeding to identity verification.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  static const _deleted = [
    'Personal profile',
    'Saved addresses',
    'Saved preferences',
    'Notifications',
    'Referral information',
    'Wallet (only if balance is ₹0)',
    'Login sessions',
  ];

  static const _retained = [
    'Completed orders',
    'Payment records',
    'GST invoices',
    'Tax records',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deleteAccountProvider);
    final notifier = ref.read(deleteAccountProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── What gets deleted ──────────────────────────────────────────
          _SectionCard(
            icon: Icons.delete_outline,
            iconColor: theme.colorScheme.error,
            title: 'Deleting your account will permanently remove:',
            items: _deleted,
            bullet: Icons.close_rounded,
            bulletColor: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          // ── What may be retained ───────────────────────────────────────
          _SectionCard(
            icon: Icons.shield_outlined,
            iconColor: Colors.blueGrey,
            title: 'The following may be retained if legally required:',
            items: _retained,
            bullet: Icons.check_rounded,
            bulletColor: Colors.blueGrey,
          ),
          const SizedBox(height: 16),

          // ── Warning banner ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This action cannot be undone.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Reason selection ───────────────────────────────────────────
          Text('Why are you leaving?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<DeleteReason>(
            groupValue: state.reason,
            onChanged: (v) => notifier.setReason(v!),
            child: Column(
              children: DeleteReason.values
                  .map(
                    (r) => RadioListTile<DeleteReason>(
                      value: r,
                      title: Text(r.label),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            maxLength: 500,
            onChanged: notifier.setComment,
            decoration: const InputDecoration(
              labelText: 'Additional comments (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),

          // ── Actions ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isBusy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  onPressed: state.isBusy
                      ? null
                      : () => _onDeletePressed(context, ref),
                  child: state.isBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Delete My Account'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _onDeletePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(deleteAccountProvider.notifier);
    final confirmed = await _showConfirmDialog(context);
    if (confirmed != true) return;

    final ok = await notifier.submitRequest();
    if (!ok || !context.mounted) return;

    if (ref.read(deleteAccountProvider).verificationRequired) {
      // Re-verification enabled → collect password/OTP first.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeleteVerificationScreen()),
      );
    } else {
      // User is already logged in → delete directly, no OTP/password.
      final deleted = await notifier.confirm();
      if (deleted && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DeleteSuccessScreen()),
        );
      }
    }
  }

  /// Explicit confirmation dialog (Google Play requirement).
  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\n'
          'You will lose access to:\n'
          '• Orders\n• Wallet\n• Referral rewards\n• Saved addresses\n'
          '• Preferences\n• Notifications',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.bullet,
    required this.bulletColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final IconData bullet;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(bullet, size: 16, color: bulletColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
