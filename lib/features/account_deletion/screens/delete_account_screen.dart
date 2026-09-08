import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delete_account_models.dart';
import '../providers/delete_account_provider.dart';
import 'delete_verification_screen.dart';
import 'delete_success_screen.dart';

/// True only in the native iOS app. On iOS, App Store policy is satisfied with
/// a request-then-admin-approval flow, so the screen submits a deletion
/// *request* and shows a pending state — it never runs the immediate
/// OTP/confirm/force-logout path. Android and Web keep the existing flow.
bool get _isIosApprovalFlow =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
    // iOS: request-for-approval flow (no OTP / confirm / force-logout here).
    if (_isIosApprovalFlow) return const _IosApprovalDeleteView();

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

// ═══════════════════════════════════════════════════════════════════════════
// iOS: submit a deletion REQUEST for admin approval, then show pending state.
// Nothing is deleted here. No OTP / confirm / force-logout.
// ═══════════════════════════════════════════════════════════════════════════

class _IosApprovalDeleteView extends ConsumerWidget {
  const _IosApprovalDeleteView();

  static const _deleted = [
    'Personal profile',
    'Saved addresses',
    'Saved preferences',
    'Notifications',
    'Referral information',
    'Wallet balance (forfeited — cannot be recovered)',
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
    final theme = Theme.of(context);
    final statusAsync = ref.watch(deleteRequestStatusProvider);
    final localStep = ref.watch(
      deleteAccountProvider.select((s) => s.step),
    );

    final serverPending = statusAsync.maybeWhen(
      data: (s) => s.isPendingApproval,
      orElse: () => false,
    );
    final isPending =
        serverPending || localStep == DeleteStep.pendingApproval;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPending ? 'Deletion Pending' : 'Delete Account'),
      ),
      body: statusAsync.isLoading && !isPending
          ? const Center(child: CircularProgressIndicator())
          : isPending
              ? _pendingBody(context, theme)
              : _requestBody(context, ref, theme),
    );
  }

  // ── Pending state ────────────────────────────────────────────────────────
  Widget _pendingBody(BuildContext context, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Account Deletion Pending',
                          style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your account deletion request is currently being reviewed. '
                  'You will be notified when the deletion is completed. Until '
                  'then, your account stays active and you can keep using the app.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  // ── Request form ─────────────────────────────────────────────────────────
  Widget _requestBody(BuildContext context, WidgetRef ref, ThemeData theme) {
    final state = ref.watch(deleteAccountProvider);
    final notifier = ref.read(deleteAccountProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          icon: Icons.delete_outline,
          iconColor: theme.colorScheme.error,
          title: 'Once approved, this permanently removes:',
          items: _deleted,
          bullet: Icons.close_rounded,
          bulletColor: theme.colorScheme.error,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.shield_outlined,
          iconColor: Colors.blueGrey,
          title: 'The following may be retained if legally required:',
          items: _retained,
          bullet: Icons.check_rounded,
          bulletColor: Colors.blueGrey,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Deletion happens only after an admin approves your request. '
                  'This action cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
                onPressed:
                    state.isBusy ? null : () => _onRequestPressed(context, ref),
                child: state.isBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Request Deletion'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _onRequestPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'Your account will be permanently deleted after your request is '
          'approved. Any remaining wallet balance will be forfeited and cannot '
          'be recovered. This action cannot be undone.',
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
            child: const Text('Request Deletion'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok =
        await ref.read(deleteAccountProvider.notifier).submitApprovalRequest();
    if (!context.mounted) return;

    if (!ok) return; // error is shown inline; the button re-enables for retry

    // Refresh the backend-owned status so the Profile row + this screen reflect
    // the pending state on the next build.
    ref.invalidate(deleteRequestStatusProvider);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletion Request Submitted'),
        content: const Text(
          'Your account deletion request has been submitted successfully. Your '
          'account will be permanently deleted after the request is approved. '
          'We will notify you when the deletion is completed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (context.mounted) Navigator.pop(context); // back to Profile
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
