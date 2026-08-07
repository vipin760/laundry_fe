import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delete_account_models.dart';
import '../providers/delete_account_provider.dart';
import 'delete_success_screen.dart';

/// Step 2 — identity verification (password OR OTP), then the final
/// irreversible confirmation. Deletion is not allowed without verification.
class DeleteVerificationScreen extends ConsumerStatefulWidget {
  const DeleteVerificationScreen({super.key});

  @override
  ConsumerState<DeleteVerificationScreen> createState() =>
      _DeleteVerificationScreenState();
}

class _DeleteVerificationScreenState
    extends ConsumerState<DeleteVerificationScreen> {
  VerificationMethod _method = VerificationMethod.password;
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountProvider);
    final notifier = ref.read(deleteAccountProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Identity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'For your security, please verify your identity before we delete '
            'your account.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          SegmentedButton<VerificationMethod>(
            segments: const [
              ButtonSegment(
                value: VerificationMethod.password,
                label: Text('Password'),
                icon: Icon(Icons.lock_outline),
              ),
              ButtonSegment(
                value: VerificationMethod.otp,
                label: Text('OTP'),
                icon: Icon(Icons.sms_outlined),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 20),

          // Animated switch between the two verification inputs.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _method == VerificationMethod.password
                ? _passwordField(theme)
                : _otpField(theme, notifier, state),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),

          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: state.isBusy ? null : () => _verifyAndDelete(context),
            child: state.isBusy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify & Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(ThemeData theme) => TextField(
        key: const ValueKey('password'),
        controller: _passwordCtrl,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Enter your password',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.lock_outline),
        ),
      );

  Widget _otpField(
    ThemeData theme,
    DeleteAccountNotifier notifier,
    DeleteAccountState state,
  ) =>
      Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_otpSent)
            OutlinedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () async {
                      final ok = await notifier.sendOtp();
                      if (ok) {
                        setState(() => _otpSent = true);
                      }
                    },
              icon: const Icon(Icons.send),
              label: const Text('Send OTP to my mobile'),
            )
          else
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              // iOS native OTP autofill from the SMS.
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                labelText: 'Enter 6-digit OTP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sms_outlined),
              ),
            ),
        ],
      );

  Future<void> _verifyAndDelete(BuildContext context) async {
    final notifier = ref.read(deleteAccountProvider.notifier);

    // 1. Verify identity.
    final verified = await notifier.verify(
      method: _method,
      password: _method == VerificationMethod.password
          ? _passwordCtrl.text
          : null,
      otp: _method == VerificationMethod.otp ? _otpCtrl.text : null,
    );
    if (!verified || !context.mounted) return;

    // 2. Final, explicit confirmation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This is your last chance. Your account and personal data will be '
          'permanently deleted. Continue?',
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
    if (confirmed != true || !context.mounted) return;

    // 3. Confirm deletion.
    final ok = await notifier.confirm();
    if (ok && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DeleteSuccessScreen()),
      );
    }
  }
}
