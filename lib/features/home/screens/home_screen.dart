import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/screens/orders_screen.dart';
import '../../pickup_delivery/screens/pickup_delivery_screen.dart';
import '../../profile/screens/addresses_screen.dart';
import '../../profile/screens/my_information_screen.dart';
import '../../referral/screens/refer_earn_home_screen.dart';
import '../../account_deletion/screens/privacy_security_screen.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../services/models/service_model.dart';
import '../../services/providers/services_provider.dart';
import '../../support/screens/support_chat_screen.dart';
import '../../wallet/models/wallet_transaction_model.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../pricing/screens/pricing_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFF2453FF);
const _kPrimaryDk = Color(0xFF1A3FD8);
const _kBg        = Color(0xFFF5F6FA);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  // ── Bottom nav items ───────────────────────────────────────────────────────
  static const _navItems = [
    _NavItem(label: 'Home',     selected: Icons.home_rounded,                   unselected: Icons.home_outlined),
    _NavItem(label: 'Price',    selected: Icons.local_offer_rounded,             unselected: Icons.local_offer_outlined),
    _NavItem(label: 'Payments', selected: Icons.account_balance_wallet_rounded,  unselected: Icons.account_balance_wallet_outlined),
    _NavItem(label: 'Profile',  selected: Icons.person_rounded,                 unselected: Icons.person_outline_rounded),
  ];

  String _firstName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Rohan';
    return name.trim().split(' ').first;
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Do you want to logout from this account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.invalidate(walletProvider);
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = ref.watch(authProvider).user;
    final firstName = _firstName(user?.name);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _HomeTab(firstName: firstName),
            _PricingTab(),
            _PaymentsTab(),
            _ProfileTab(name: user?.name, email: user?.email, mobile: user?.mobileNumber, photoUrl: user?.photoUrl, onLogout: _logout),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        items: _navItems,
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HOME TAB
// ══════════════════════════════════════════════════════════════════════════════

/// Opens the pickup/delivery flow on the tab matching the service type.
/// Instant (or both / untagged) → Instant tab; scheduled-only → Scheduled tab.
void _openServiceFlow(BuildContext context, ServiceModel s) {
  final tab = (s.isScheduled && !s.isInstant) ? 'scheduled' : 'instant';
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => PickupDeliveryScreen(initialTab: tab)),
  );
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularServicesProvider);
    final allServices  = ref.watch(paginatedServicesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _Header(firstName: firstName),
          const SizedBox(height: 20),

          // ── Delivery hero card ───────────────────────────────────────────────
          _DeliveryHeroCard(),
          const SizedBox(height: 16),

          // ── Express / Standard cards ─────────────────────────────────────────
          IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WashIronCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PickupDeliveryScreen(initialTab: 'instant'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ScheduledCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PickupDeliveryScreen(initialTab: 'scheduled'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 24),

          // ── Popular Services (admin-selected top 3, admin order) ────────────
          popularAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)),
            ),
            error: (err, _) => _ServicesErrorBanner(
              message: err.toString().replaceFirst('Exception: ', ''),
              onRetry: () {
                ref.invalidate(popularServicesProvider);
                ref.invalidate(servicesProvider);
              },
            ),
            data: (services) => _PopularServicesSection(
              services: services,
              total: allServices.total,
              onViewAll: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PickupDeliveryScreen())),
              onServiceTap: (s) => _openServiceFlow(context, s),
            ),
          ),
          const SizedBox(height: 24),

          // ── All Services (lazy horizontal scroll, 8 at a time) ──────────────
          _AllServicesSection(
            onViewAll: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PickupDeliveryScreen())),
            onServiceTap: (s) => _openServiceFlow(context, s),
          ),
          const SizedBox(height: 24),

          // ── Why LaundryBrew ──────────────────────────────────────────────────
          const Text(
            'Why LaundryBrew?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1645),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _WhyCard(
                  icon: Icons.sell_rounded,
                  iconBg: Color(0xFFEDE7FF),
                  iconColor: Color(0xFF7C3AED),
                  label: 'Plastic-Free\nPackaging',
                  info: 'Eco-friendly wraps for every order.',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WhyCard(
                  icon: Icons.water_drop_rounded,
                  iconBg: Color(0xFFEEF2FF),
                  iconColor: Color(0xFF2453FF),
                  label: 'Safe Cleaning\nOnly',
                  info: 'Gentle care for every fabric.',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WhyCard(
                  icon: Icons.local_shipping_rounded,
                  iconBg: Color(0xFFDCF5E8),
                  iconColor: Color(0xFF15803D),
                  label: 'Fast, Reliable\nDelivery',
                  info: 'On-time pickup & doorstep delivery.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      notificationsProvider.select((s) => s.unread),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $firstName 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A1645),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Welcome to LaundryBrew',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        // Notification bell (opens the notification bar)
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF0A1645),
                  size: 22,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Home page banner ──────────────────────────────────────────────────────────

class _DeliveryHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1600 / 771,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home_page_image.png',
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            // ── "Lowest prices guaranteed" badge ─────────────────────────
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 17, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Lowest Prices Guaranteed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
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

// ── Instant Service card (blue) ───────────────────────────────────────────────

class _WashIronCard extends StatelessWidget {
  const _WashIronCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular white icon container with lightning icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: _kPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'Instant Service',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),   // GestureDetector child (Container)
    );   // GestureDetector
  }
}

// ── Standard Service card (white) ────────────────────────────────────────────

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular outlined calendar icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF0A1645),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Title
          const Text(
            'Scheduled Service',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1645),
              height: 1.2,
            ),
          ),
        ],
      ),
    ),   // GestureDetector child
    );   // GestureDetector
  }
}

// ── Why card ──────────────────────────────────────────────────────────────────

class _WhyCard extends StatelessWidget {
  const _WhyCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.info,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String info;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDFA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1645).withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0A1645),
              height: 1.4,
            ),
          ),
        ],
      ),
        ),
        // Small "i" info icon — tap (mobile) or hover (desktop) shows the note.
        Positioned(
          top: 6,
          right: 6,
          child: Tooltip(
            message: info,
            triggerMode: TooltipTriggerMode.tap,
            preferBelow: false,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1645),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 15,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WALLET TAB
// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// PRICING TAB
// ══════════════════════════════════════════════════════════════════════════════

class _PricingTab extends StatelessWidget {
  const _PricingTab();

  @override
  Widget build(BuildContext context) {
    return const PricingScreen();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PAYMENTS TAB
// ══════════════════════════════════════════════════════════════════════════════

class _PaymentsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final fmt    = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: () => ref.read(walletProvider.notifier).refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payments & Wallet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A1645))),
            const SizedBox(height: 20),

            // ── Balance card ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2453FF), Color(0xFF1A3FD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF2453FF).withAlpha(70),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('LaundryBrew Wallet',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 16),
                  wallet.isLoading
                      ? const SizedBox(
                          height: 40,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5)),
                        )
                      : Text(
                          fmt.format(wallet.balance),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900),
                        ),
                  const SizedBox(height: 4),
                  const Text('Available Balance',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(children: [
                    _WalletAction(
                      icon: Icons.add_rounded,
                      label: 'Add Money',
                      onTap: () async {
                        await context.push(AppRoutes.addMoney);
                        ref.read(walletProvider.notifier).refresh();
                      },
                    ),
                    const SizedBox(width: 12),
                    _WalletAction(
                      icon: Icons.history_rounded,
                      label: 'History',
                      onTap: () => context.push(AppRoutes.transactions),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Recent transactions ─────────────────────────────────────────
            if (wallet.isLoading)
              const Center(child: CircularProgressIndicator(color: _kPrimary))
            else if (wallet.error != null)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Text('Could not load transactions',
                        style: TextStyle(color: Colors.grey[500])),
                    TextButton(
                      onPressed: () => ref.read(walletProvider.notifier).refresh(),
                      child: const Text('Retry', style: TextStyle(color: _kPrimary)),
                    ),
                  ],
                ),
              )
            else if (wallet.transactions.isEmpty)
              const _NoTxns()
            else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Recent Transactions',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A1645))),
                TextButton(
                  onPressed: () => context.push(AppRoutes.transactions),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('View All',
                      style: TextStyle(
                          color: _kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              ...wallet.transactions.map((t) => _HomeTxnRow(txn: t)),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(50)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HomeTxnRow extends StatelessWidget {
  const _HomeTxnRow({required this.txn});
  final WalletTransactionModel txn;

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final amtColor =
        isCredit ? const Color(0xFF10B981) : const Color(0xFF0A1645);
    final fmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final date =
        DateFormat('dd MMM').format(txn.createdAt.toLocal());
    final statusLabel = txn.isSuccess
        ? 'Success'
        : txn.isFailed
            ? 'Failed'
            : 'Pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 18,
            color: isCredit ? const Color(0xFF16A34A) : _kPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(txn.description,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1645)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('$date · $statusLabel',
                style: const TextStyle(fontSize: 11, color: Color(0xFF7D86A5))),
          ]),
        ),
        Text(
          '${isCredit ? '+' : '-'}${fmt.format(txn.amount)}',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: amtColor),
        ),
      ]),
    );
  }
}

class _NoTxns extends StatelessWidget {
  const _NoTxns();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 14),
            const Text('No transactions yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
            const SizedBox(height: 4),
            Text('Add money to get started',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.name, required this.email, required this.mobile, required this.onLogout, this.photoUrl});
  final String? name;
  final String? email;
  final String? mobile;
  final String? photoUrl;
  final VoidCallback onLogout;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _notificationsEnabled = true;

  String get _displayName => (widget.name?.trim().isNotEmpty ?? false) ? widget.name! : 'Customer';
  String get _displayEmail => (widget.email?.trim().isNotEmpty ?? false) ? widget.email! : (widget.mobile ?? '');

  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';
  }

  Future<void> _onNotificationToggle(bool value) async {
    if (value) {
      // Request OS permission and register FCM token with the backend.
      final granted = await NotificationService.instance
          .requestPermissionAndRegister(ApiClient.instance);

      setState(() => _notificationsEnabled = granted);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Notifications enabled. You\'ll be notified on every order update.'
              : 'Notification permission denied. You can enable it in your device settings.'),
          backgroundColor: granted ? const Color(0xFF12B76A) : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      setState(() => _notificationsEnabled = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications disabled.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
      child: Column(
        children: [
          // ── Avatar + name + email ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x080A1645), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                _ProfileAvatar(
                  photoUrl: widget.photoUrl,
                  initials: _initials,
                  size: 72,
                ),
                const SizedBox(height: 12),
                Text(_displayName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A1645))),
                const SizedBox(height: 4),
                Text(_displayEmail,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF7D86A5))),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Menu items ────────────────────────────────────────────────────
          _ProfileMenuGroup(
            items: [
              _ProfileMenuItem(
                icon: Icons.receipt_long_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'My Orders',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
              ),
              _ProfileMenuItem(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'My Information',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyInformationScreen())),
              ),
              _ProfileMenuItem(
                icon: Icons.location_on_outlined,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'Addresses',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesScreen())),
              ),
              _ProfileMenuItem(
                icon: Icons.card_giftcard_rounded,
                iconBg: const Color(0xFFEAF7EE),
                iconColor: Color(0xFF12B76A),
                label: 'Refer & Earn',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReferEarnHomeScreen())),
              ),
              _ProfileMenuItem(
                icon: Icons.notifications_none_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'Notifications',
                trailing: Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: _onNotificationToggle,
                  activeColor: _kPrimary,
                ),
                onTap: null,
              ),
              _ProfileMenuItem(
                icon: Icons.chat_bubble_outline_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'Chat with Support',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen())),
              ),
              _ProfileMenuItem(
                icon: Icons.shield_outlined,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: _kPrimary,
                label: 'Privacy & Security',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Logout ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFE4E4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFD92D20), size: 20),
                  SizedBox(width: 14),
                  Text('Logout',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFD92D20))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.items});
  final List<_ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x060A1645), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 52, endIndent: 16, color: Color(0xFFF0F4FF)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Profile avatar (photo or initials gradient) ───────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.initials, this.size = 72});
  final String? photoUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto
            ? null
            : const LinearGradient(
                colors: [Color(0xFF2453FF), Color(0xFF6B8EFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasPhoto ? const Color(0xFFE5E7EB) : null,
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2340))),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BAD5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAVIGATION
// ══════════════════════════════════════════════════════════════════════════════

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.current, required this.onTap});
  final List<_NavItem> items;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1645).withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Row(
          children: List.generate(items.length, (i) {
            final sel = i == current;
            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      sel ? item.selected : item.unselected,
                      size: 24,
                      color: sel ? _kPrimary : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _kPrimary : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.selected, required this.unselected});
  final String label;
  final IconData selected;
  final IconData unselected;
}

// ══════════════════════════════════════════════════════════════════════════════
// POPULAR SERVICES SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _PopularServicesSection extends StatelessWidget {
  const _PopularServicesSection({
    required this.services,
    required this.total,
    required this.onViewAll,
    required this.onServiceTap,
  });

  final List<ServiceModel> services;
  final int total;
  final VoidCallback onViewAll;
  final void Function(ServiceModel) onServiceTap;

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('iron'))    return Icons.iron_rounded;
    if (n.contains('fold'))    return Icons.local_laundry_service_rounded;
    if (n.contains('dry'))     return Icons.dry_cleaning_rounded;
    if (n.contains('shoe'))    return Icons.shopping_bag_rounded;
    if (n.contains('saree') || n.contains('curtain') || n.contains('blanket'))
                               return Icons.curtains_rounded;
    if (n.contains('carpet'))  return Icons.cleaning_services_rounded;
    if (n.contains('bag'))     return Icons.shopping_bag_outlined;
    if (n.contains('premium')) return Icons.star_rounded;
    return Icons.local_laundry_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    // Backend already returns max 3, sorted by the admin-chosen position.
    final popular = services;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──────────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(
              child: Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A1645),
                ),
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                children: [
                  Text(
                    total > 0 ? 'View all ($total+)' : 'View all',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: _kPrimary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Service list (top 3) ─────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EDFA)),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: popular.asMap().entries.map((e) {
              final s      = e.value;
              final isLast = e.key == popular.length - 1;
              final isExpress = s.isInstant || (!s.isScheduled);
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => onServiceTap(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          // ── Thumbnail (admin image, falls back to icon) ────
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (s.imageUrl != null && s.imageUrl!.isNotEmpty)
                                ? Image.network(
                                    s.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        _iconFor(s.name),
                                        color: _kPrimary,
                                        size: 30),
                                  )
                                : Icon(_iconFor(s.name),
                                    color: _kPrimary, size: 30),
                          ),
                          const SizedBox(width: 12),
                          // ── Info ───────────────────────────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A1645),
                                  ),
                                ),
                                if (s.descriptionFor(isExpress ? ServiceCategory.instant : ServiceCategory.scheduled).isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    s.descriptionFor(isExpress ? ServiceCategory.instant : ServiceCategory.scheduled),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (s.durationFor(isExpress ? ServiceCategory.instant : ServiceCategory.scheduled) != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.local_laundry_service_rounded,
                                                size: 11, color: Color(0xFF6B7280)),
                                            const SizedBox(width: 3),
                                            Text(
                                              s.durationFor(isExpress ? ServiceCategory.instant : ServiceCategory.scheduled)!,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    // Express / Standard badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isExpress
                                            ? const Color(0xFFEEF9F0)
                                            : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isExpress
                                                ? Icons.bolt_rounded
                                                : Icons.calendar_month_rounded,
                                            size: 11,
                                            color: isExpress
                                                ? const Color(0xFF15803D)
                                                : _kPrimary,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            isExpress ? 'Instant' : 'Scheduled',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isExpress
                                                  ? const Color(0xFF15803D)
                                                  : _kPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 20, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 14, endIndent: 14,
                        color: Color(0xFFF3F4F6)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ALL SERVICES SECTION
// ══════════════════════════════════════════════════════════════════════════════

class _AllServicesSection extends ConsumerStatefulWidget {
  const _AllServicesSection({
    required this.onViewAll,
    required this.onServiceTap,
  });

  final VoidCallback onViewAll;
  final void Function(ServiceModel) onServiceTap;

  @override
  ConsumerState<_AllServicesSection> createState() =>
      _AllServicesSectionState();
}

class _AllServicesSectionState extends ConsumerState<_AllServicesSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Load the next page when the user scrolls near the end of the row.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      ref.read(paginatedServicesProvider.notifier).loadMore();
    }
  }

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('iron'))    return Icons.iron_rounded;
    if (n.contains('fold'))    return Icons.local_laundry_service_rounded;
    if (n.contains('dry'))     return Icons.dry_cleaning_rounded;
    if (n.contains('shoe'))    return Icons.shopping_bag_rounded;
    if (n.contains('saree') || n.contains('curtain') || n.contains('blanket'))
                               return Icons.curtains_rounded;
    if (n.contains('carpet'))  return Icons.cleaning_services_rounded;
    if (n.contains('bag'))     return Icons.shopping_bag_outlined;
    if (n.contains('premium')) return Icons.star_rounded;
    return Icons.local_laundry_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedServicesProvider);
    final services = state.services;

    if (state.isLoading && services.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)),
      );
    }
    if (services.isEmpty) return const SizedBox.shrink();

    // +1 slot for the trailing loader while the next page is fetched
    final itemCount = services.length + (state.hasMore ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──────────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(
              child: Text(
                'All Services',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A1645),
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onViewAll,
              child: Row(
                children: [
                  Text(
                    'View all (${state.total > 0 ? state.total : services.length}+)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: _kPrimary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Lazy horizontal list: 8 per page, more load as you scroll ────────
        SizedBox(
          height: 132,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index >= services.length) {
                // Trailing loader chip
                return const SizedBox(
                  width: 60,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: _kPrimary, strokeWidth: 2),
                    ),
                  ),
                );
              }
              final s = services[index];
              return GestureDetector(
                onTap: () => widget.onServiceTap(s),
                child: _ServiceChip(
                  icon: _iconFor(s.name),
                  imageUrl: s.imageUrl,
                  label: s.name,
                  isInstant: s.isInstant || !s.isScheduled,
                  isScheduled: s.isScheduled,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.icon,
    required this.label,
    this.imageUrl,
    this.isInstant = false,
    this.isScheduled = false,
  });

  final IconData icon;
  final String? imageUrl;
  final String label;
  final bool isInstant;
  final bool isScheduled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDFA)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, color: _kPrimary, size: 22),
                  )
                : Icon(icon, color: _kPrimary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A1645),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          // Instant / Scheduled type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isInstant
                  ? const Color(0xFFEEF9F0)
                  : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isInstant ? Icons.bolt_rounded : Icons.calendar_month_rounded,
                  size: 10,
                  color: isInstant ? const Color(0xFF15803D) : _kPrimary,
                ),
                const SizedBox(width: 2),
                Text(
                  isInstant ? 'Instant' : 'Scheduled',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isInstant ? const Color(0xFF15803D) : _kPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Services error banner ──────────────────────────────────────────────────────

class _ServicesErrorBanner extends StatelessWidget {
  const _ServicesErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.isNotEmpty ? message : 'Could not load services.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
