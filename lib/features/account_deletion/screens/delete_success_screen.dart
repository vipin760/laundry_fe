import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/delete_account_provider.dart';

/// Final screen — confirms deletion, then automatically logs the user out and
/// returns them to the login screen (Google Play UX requirement).
class DeleteSuccessScreen extends ConsumerStatefulWidget {
  const DeleteSuccessScreen({super.key});

  @override
  ConsumerState<DeleteSuccessScreen> createState() =>
      _DeleteSuccessScreenState();
}

class _DeleteSuccessScreenState extends ConsumerState<DeleteSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Log out locally and navigate to login after a short confirmation pause.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // The server has already invalidated the session; force a local logout
      // (skips the /auth/logout API call which would now 401).
      await ref.read(authProvider.notifier).forceLogout();
      ref.read(deleteAccountProvider.notifier).reset();
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.go(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = ref.watch(
      deleteAccountProvider.select((s) => s.successMessage),
    );

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 64),
                ),
              ),
              const SizedBox(height: 24),
              Text('Account Deleted',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                message ??
                    'Your account has been deleted. We are sorry to see you go.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Signing you out…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
