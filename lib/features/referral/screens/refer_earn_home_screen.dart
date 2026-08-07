import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_text.dart';
import '../../support/screens/terms_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../models/referral_models.dart';
import '../providers/referral_provider.dart';
import 'my_referrals_screen.dart';

// ── Colour palette ────────────────────────────────────────────────────────────
const _kPurple     = Color(0xFF6C4EE0);
const _kPurpleDark = Color(0xFF4A2FC7);
const _kPurpleBg   = Color(0xFFF3F0FD);
const _kGreen      = Color(0xFF12B76A);
const _kGreenBg    = Color(0xFFECFDF5);
const _kOrange     = Color(0xFFF79009);
const _kOrangeBg   = Color(0xFFFFF4E5);
const _kRed        = Color(0xFFD92D20);
const _kRedBg      = Color(0xFFFEF3F2);
const _kBlue       = Color(0xFF2453FF);
const _kBlueBg     = Color(0xFFEEF2FF);
const _kBg         = Color(0xFFF7F8FC);
const _kText       = Color(0xFF0A1645);
const _kMuted      = Color(0xFF7D86A5);

/// One of the 4 "how it works" steps — shared between the bottom-of-page
/// icon row and the "How it works?" info sheet.
class _HowItWorksStep {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  const _HowItWorksStep({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
  });
}

const _kHowItWorksSteps = [
  _HowItWorksStep(
    icon: Icons.person_add_alt_1_rounded,
    color: _kBlue,
    bg: _kBlueBg,
    title: 'Invite Friends',
    subtitle: 'Share your code with friends',
  ),
  _HowItWorksStep(
    icon: Icons.phone_android_rounded,
    color: _kPurple,
    bg: _kPurpleBg,
    title: 'They Sign Up',
    subtitle: 'Your friend creates an account',
  ),
  _HowItWorksStep(
    icon: Icons.shopping_bag_outlined,
    color: _kOrange,
    bg: _kOrangeBg,
    title: 'They Order',
    subtitle: 'They place their first order',
  ),
  _HowItWorksStep(
    icon: Icons.card_giftcard_rounded,
    color: _kGreen,
    bg: _kGreenBg,
    title: 'You Both Earn',
    subtitle: 'You both get rewarded',
  ),
];

/// Refer & Earn home — shows the user's code, share link, live stats and a
/// preview of recent referrals. Pull-to-refresh reloads from the backend.
class ReferEarnHomeScreen extends StatelessWidget {
  const ReferEarnHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        title: const AppText('Refer & Earn',
            fontSize: 19, fontWeight: FontWeight.w900, color: _kText),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _HowItWorksButton(),
          ),
        ],
      ),
      body: const ReferralHomeBody(),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 17, color: _kText),
      ),
    );
  }
}

class _HowItWorksButton extends StatelessWidget {
  const _HowItWorksButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHowItWorksSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _kText),
            SizedBox(width: 6),
            AppText('How it works?', fontSize: 12.5, fontWeight: FontWeight.w700, color: _kText),
          ],
        ),
      ),
    );
  }
}

void _showHowItWorksSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('How it works', fontSize: 18, fontWeight: FontWeight.w900, color: _kText),
          const SizedBox(height: 18),
          for (final step in _kHowItWorksSteps) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: step.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(step.icon, color: step.color, size: 19),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(step.title, fontSize: 14.5, fontWeight: FontWeight.w800, color: _kText),
                      const SizedBox(height: 2),
                      AppText(step.subtitle, fontSize: 12.5, color: _kMuted),
                    ],
                  ),
                ),
              ],
            ),
            if (step != _kHowItWorksSteps.last) const SizedBox(height: 18),
          ],
        ],
      ),
    ),
  );
}

/// The reusable Refer & Earn content (no Scaffold), so it can live both in
/// [ReferEarnHomeScreen] and embedded contexts like the profile Referral tab.
class ReferralHomeBody extends ConsumerWidget {
  const ReferralHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(referralProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPurple));
    }

    return Container(
      color: _kBg,
      child: RefreshIndicator(
        color: _kPurple,
        onRefresh: () => ref.read(referralProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null) _ErrorBanner(message: state.error!),
            _HeroCard(program: state.program, my: state.my),
            const SizedBox(height: 16),
            // Post-registration entry point: users who were never referred can
            // still apply a friend's code here (e.g. skipped it at sign-up).
            if (!state.hasReferrer && state.program.enabled) ...[
              const _ApplyCodeCard(),
              const SizedBox(height: 16),
            ],
            _StatsRow(my: state.my),
            const SizedBox(height: 16),
            _ProgressCard(my: state.my, program: state.program),
            const SizedBox(height: 16),
            _CodeCard(code: state.my.code, link: state.my.link),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AppText('Recent referrals', fontSize: 16, fontWeight: FontWeight.w800, color: _kText),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyReferralsScreen()),
                  ),
                  child: const AppText('View all', fontSize: 13, fontWeight: FontWeight.w700, color: _kPurple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.recent.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Center(
                  child: AppText('No referrals yet. Share your code!', color: _kMuted),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < state.recent.length; i++)
                      _ReferralTimelineTile(
                        item: state.recent[i],
                        isLast: i == state.recent.length - 1,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const _HowItWorksRow(),
            const SizedBox(height: 16),
            const _SafeFooter(),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HERO CARD
// ═════════════════════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.program, required this.my});
  final ReferralProgram program;
  final MyReferral my;

  @override
  Widget build(BuildContext context) {
    if (!program.enabled) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('Referral programme paused', fontSize: 17, fontWeight: FontWeight.w800, color: _kText),
            SizedBox(height: 8),
            AppText(
              'Refer & Earn is temporarily unavailable. Your existing rewards are safe — check back soon!',
              fontSize: 13,
              color: _kMuted,
            ),
          ],
        ),
      );
    }

    final youGet = program.referrerReward.toStringAsFixed(0);
    final theyGet = program.refereeReward.toStringAsFixed(0);
    final minOrder = program.minimumOrderValue.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurple, _kPurpleDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _kPurple.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('Invite friends,\nearn rewards',
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                    const SizedBox(height: 10),
                    AppText(
                      'You get ₹$youGet when your friend completes their first order of ₹$minOrder or more. They get ₹$theyGet too!',
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 5, child: _HeroIllustration(youGet: youGet, theyGet: theyGet)),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReferralsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText('Total Rewards Earned', fontSize: 11, color: Colors.white70),
                        AppText('₹${my.totalEarned.toStringAsFixed(0)}',
                            fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight emoji/icon-based approximation of the "two friends celebrating"
/// illustration — no real illustration asset is available, so this composes
/// existing Material icons/emoji to convey the same "you get / they get" idea.
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.youGet, required this.theyGet});
  final String youGet;
  final String theyGet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            right: 4,
            child: _speechBubble('YOU GET\n₹$youGet', _kPurpleDark),
          ),
          Positioned(
            bottom: 18,
            left: 0,
            child: _speechBubble('THEY GET\n₹$theyGet', _kPurple),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _personAvatar('🙋🏻‍♀️', const Color(0xFFFFD166)),
                const SizedBox(width: 6),
                const Text('🎁', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                _personAvatar('🙋🏻‍♂️', const Color(0xFF8ECAE6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personAvatar(String emoji, Color bg) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _speechBubble(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color, height: 1.2),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// APPLY CODE CARD
// ═════════════════════════════════════════════════════════════════════════════

/// "Have a referral code?" — apply a friend's code after registration.
/// Only rendered when the backend says this user was never referred.
class _ApplyCodeCard extends ConsumerStatefulWidget {
  const _ApplyCodeCard();

  @override
  ConsumerState<_ApplyCodeCard> createState() => _ApplyCodeCardState();
}

class _ApplyCodeCardState extends ConsumerState<_ApplyCodeCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(referralProvider.notifier);
    final ok = await notifier.apply(code);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Referral applied! Rewards unlock after your first order.'),
          backgroundColor: _kGreen,
        ),
      );
    } else {
      final reason = ref.read(referralProvider).error ?? 'Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply code: $reason'), backgroundColor: _kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApplying = ref.watch(referralProvider.select((s) => s.isApplying));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('Have a referral code?', fontSize: 15, fontWeight: FontWeight.w800, color: _kText),
                const SizedBox(height: 3),
                const AppText('Enter your friend\'s code to unlock your welcome bonus',
                    fontSize: 12, color: _kMuted),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !isApplying,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          LengthLimitingTextInputFormatter(16),
                        ],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText),
                        decoration: InputDecoration(
                          hintText: 'e.g. T5K8EVG',
                          hintStyle: const TextStyle(fontSize: 13, color: _kMuted),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Icon(Icons.sell_outlined, size: 17, color: _kMuted),
                          filled: true,
                          fillColor: _kBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: isApplying ? null : _apply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                        decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(12)),
                        child: isApplying
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const AppText('Apply', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('🎁', style: TextStyle(fontSize: 34)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STATS ROW
// ═════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.my});
  final MyReferral my;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: Icons.people_alt_rounded,
            iconColor: _kPurple,
            iconBg: _kPurpleBg,
            value: '${my.totalReferrals}',
            label: 'Invited',
            actionLabel: 'View all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReferralsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.check_circle_rounded,
            iconColor: _kGreen,
            iconBg: _kGreenBg,
            value: '${my.successfulReferrals}',
            label: 'Successful',
            actionLabel: 'View all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReferralsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.schedule_rounded,
            iconColor: _kOrange,
            iconBg: _kOrangeBg,
            value: '${my.pendingReferrals}',
            label: 'Pending',
            actionLabel: 'View all',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReferralsScreen()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: _kBlue,
            iconBg: _kBlueBg,
            value: '₹${my.totalEarned.toStringAsFixed(0)}',
            label: 'Earned',
            actionLabel: 'Withdraw',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(height: 8),
          AppText(value, fontSize: 17, fontWeight: FontWeight.w900, color: _kText),
          AppText(label, fontSize: 11, color: _kMuted),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(actionLabel, fontSize: 10.5, fontWeight: FontWeight.w700, color: _kPurple),
                const Icon(Icons.chevron_right_rounded, size: 13, color: _kPurple),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PROGRESS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.my, required this.program});
  final MyReferral my;
  final ReferralProgram program;

  static const int _milestone = 5;

  @override
  Widget build(BuildContext context) {
    final completed = my.successfulReferrals.clamp(0, _milestone);
    final remaining = _milestone - completed;
    final progress = completed / _milestone;
    final bonusEstimate = remaining * program.referrerReward;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText('Your progress', fontSize: 15, fontWeight: FontWeight.w800, color: _kText),
                    SizedBox(height: 3),
                    AppText('Complete 5 successful referrals and earn bonus rewards!',
                        fontSize: 11.5, color: _kMuted),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _kPurpleBg, borderRadius: BorderRadius.circular(10)),
                child: AppText('$completed / $_milestone Completed',
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: _kPurple),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: _kBg,
              valueColor: const AlwaysStoppedAnimation(_kPurple),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎁', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: AppText(
                  remaining > 0
                      ? 'You are just $remaining successful referral${remaining == 1 ? '' : 's'} away from earning ₹${bonusEstimate.toStringAsFixed(0)} more!'
                      : 'Milestone reached — keep referring to earn even more!',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REFERRAL CODE CARD
// ═════════════════════════════════════════════════════════════════════════════

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.link});
  final String code;
  final String link;

  Future<void> _share() {
    return Share.share(
      'Join me on LaundryBrew! Use my referral code $code to get a welcome '
      'bonus on your first order.\n$link',
      subject: 'LaundryBrew referral',
    );
  }

  Future<void> _shareOnWhatsApp() async {
    final text = Uri.encodeComponent(
      'Join me on LaundryBrew! Use my referral code $code to get a welcome '
      'bonus on your first order.\n$link',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied'), backgroundColor: _kGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Your referral code', fontSize: 15, fontWeight: FontWeight.w800, color: _kText),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _copy(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppText(
                                code.isEmpty ? '—' : code,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _kText,
                              ),
                            ),
                            const Icon(Icons.copy_rounded, size: 18, color: _kMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 13, color: _kGreen),
                        SizedBox(width: 4),
                        AppText('Your code is unique and secure', fontSize: 11, color: _kMuted),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: QrImageView(
                  data: link.isEmpty ? code : link,
                  version: QrVersions.auto,
                  size: 84,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _share,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        AppText('Share link', fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _shareOnWhatsApp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF25D366), width: 1.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF25D366)),
                        SizedBox(width: 8),
                        AppText('WhatsApp', fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF128C7E)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RECENT REFERRALS — TIMELINE TILE
// ═════════════════════════════════════════════════════════════════════════════

class _ReferralVisualStyle {
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final Color avatarColor;
  const _ReferralVisualStyle(this.badge, this.badgeColor, this.badgeBg, this.avatarColor);
}

_ReferralVisualStyle _styleFor(ReferralStatus status) {
  switch (status) {
    case ReferralStatus.rewardReleased:
    case ReferralStatus.paymentCompleted:
      return const _ReferralVisualStyle('Completed first order', _kGreen, _kGreenBg, _kGreen);
    case ReferralStatus.firstOrderCompleted:
      return const _ReferralVisualStyle('First order placed', _kGreen, _kGreenBg, _kGreen);
    case ReferralStatus.expired:
    case ReferralStatus.rejected:
      return const _ReferralVisualStyle('Expired', _kRed, _kRedBg, _kOrange);
    case ReferralStatus.registered:
    case ReferralStatus.pending:
    case ReferralStatus.unknown:
      return const _ReferralVisualStyle('Joined', _kGreen, _kGreenBg, _kGreen);
  }
}

String _formatReferralDate(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final justDate = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(justDate).inDays;
  final time = DateFormat('h:mm a').format(d);
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Yesterday, $time';
  return DateFormat('dd MMM yyyy').format(d);
}

class _ReferralTimelineTile extends StatelessWidget {
  const _ReferralTimelineTile({required this.item, required this.isLast});
  final ReferralHistoryItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(item.status);
    final initial = item.refereeName.isNotEmpty ? item.refereeName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: style.avatarColor, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: AppText(initial, fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 34,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0xFFE5E7EB),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AppText(item.refereeName, fontSize: 14, fontWeight: FontWeight.w800, color: _kText),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: style.badgeBg, borderRadius: BorderRadius.circular(8)),
                      child: AppText(style.badge, fontSize: 10, fontWeight: FontWeight.w700, color: style.badgeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                AppText(_formatReferralDate(item.joinedDate), fontSize: 11.5, color: _kMuted),
              ],
            ),
          ),
          _ReferralTrailing(item: item),
        ],
      ),
    );
  }
}

class _ReferralTrailing extends StatelessWidget {
  const _ReferralTrailing({required this.item});
  final ReferralHistoryItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.status) {
      case ReferralStatus.rewardReleased:
      case ReferralStatus.paymentCompleted:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText('+ ₹${item.rewardAmount.toStringAsFixed(0)}',
                fontSize: 13.5, fontWeight: FontWeight.w800, color: _kGreen),
            const AppText('Reward earned', fontSize: 10.5, color: _kMuted),
          ],
        );
      case ReferralStatus.expired:
      case ReferralStatus.rejected:
        return const AppText('Expired', fontSize: 12.5, fontWeight: FontWeight.w700, color: _kRed);
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time_rounded, size: 13, color: _kOrange),
            SizedBox(width: 4),
            AppText('Pending first order', fontSize: 11.5, fontWeight: FontWeight.w700, color: _kOrange),
          ],
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HOW IT WORKS ROW
// ═════════════════════════════════════════════════════════════════════════════

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _kHowItWorksSteps.length; i++) ...[
          Expanded(child: _HowItWorksIcon(step: _kHowItWorksSteps[i])),
          if (i != _kHowItWorksSteps.length - 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: _kMuted),
            ),
        ],
      ],
    );
  }
}

class _HowItWorksIcon extends StatelessWidget {
  const _HowItWorksIcon({required this.step});
  final _HowItWorksStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: step.bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(step.icon, color: step.color, size: 21),
        ),
        const SizedBox(height: 8),
        AppText(step.title, fontSize: 11, fontWeight: FontWeight.w800, color: _kText, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        AppText(step.subtitle, fontSize: 9.5, color: _kMuted, textAlign: TextAlign.center),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SAFE & SECURE FOOTER
// ═════════════════════════════════════════════════════════════════════════════

class _SafeFooter extends StatelessWidget {
  const _SafeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kPurpleBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.shield_rounded, size: 16, color: _kPurple),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Safe & Secure', fontSize: 13, fontWeight: FontWeight.w800, color: _kText),
                AppText('Your data and referrals are 100% safe with us', fontSize: 10.5, color: _kMuted),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText('Terms', fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ERROR BANNER
// ═════════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kRedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(child: AppText(message, fontSize: 12.5, color: _kRed)),
        ],
      ),
    );
  }
}
