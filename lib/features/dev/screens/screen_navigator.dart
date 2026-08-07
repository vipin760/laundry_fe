// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

/// ⚠️ DEVELOPMENT ONLY — Remove before production release.
///
/// Lists every application screen and lets developers navigate to each
/// placeholder page without going through the real app flow.
class ScreenNavigator extends StatelessWidget {
  const ScreenNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F36),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LaundryBrew Screen Navigator',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'DEV ONLY — Remove before production',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Banner ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD980)),
            ),
            child: const Row(
              children: [
                Text('🚧', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Temporary page for navigating all application screens '
                    'during development. Remove before production release.',
                    style: TextStyle(
                      color: Color(0xFF7A5800),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Categories ────────────────────────────────────────────────────
          ..._categories(context).map(_buildSection),
        ],
      ),
    );
  }

  Widget _buildSection(_NavCategory cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: cat.icon, title: cat.title, color: cat.color),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < cat.items.length; i++) ...[
                _NavTile(
                  item: cat.items[i],
                  isLast: i == cat.items.length - 1,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<_NavCategory> _categories(BuildContext context) => [
        _NavCategory(
          title: 'Authentication',
          icon: Icons.lock_outline_rounded,
          color: const Color(0xFF7C5CBF),
          items: [
            _NavItem('Splash Screen', AppRoutes.splash, context),
            _NavItem('Login / Signup', AppRoutes.login, context),
            _NavItem('OTP Verification', AppRoutes.otpVerification, context),
            _NavItem('Complete Profile', AppRoutes.completeProfile, context),
          ],
        ),
        _NavCategory(
          title: 'Home',
          icon: Icons.home_rounded,
          color: const Color(0xFF2453FF),
          items: [
            _NavItem('Home Dashboard', AppRoutes.home, context),
          ],
        ),
        _NavCategory(
          title: 'Pickup & Delivery',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF00A878),
          items: [
            _NavItem('Select Pickup & Delivery', AppRoutes.pickupDelivery, context),
            _NavItem('Pickup Slot Selection', AppRoutes.pickupSlot, context),
            _NavItem('Delivery Slot Selection', AppRoutes.deliverySlot, context),
          ],
        ),
        _NavCategory(
          title: 'Services',
          icon: Icons.local_laundry_service_rounded,
          color: const Color(0xFF0EA5E9),
          items: [
            _NavItem('Service List', AppRoutes.services, context),
            _NavItem('Ironing Service', AppRoutes.ironing, context),
            _NavItem('Wash & Fold Service', AppRoutes.washFold, context),
            _NavItem('Wash & Iron Service', AppRoutes.washIron, context),
            _NavItem('Dry Cleaning Service', AppRoutes.dryCleaning, context),
            _NavItem('Shoe Cleaning Service', AppRoutes.shoeCleaning, context),
            _NavItem('Premium Laundry Service', AppRoutes.premiumLaundry, context),
          ],
        ),
        _NavCategory(
          title: 'Orders',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFF59E0B),
          items: [
            _NavItem('Order Review', AppRoutes.orderReview, context),
            _NavItem('Order Success', AppRoutes.orderSuccess, context),
            _NavItem('Orders List', AppRoutes.orders, context),
          ],
        ),
        _NavCategory(
          title: 'Order Tracking',
          icon: Icons.track_changes_rounded,
          color: const Color(0xFFEF4444),
          items: [
            _NavItem('Order Confirmed', AppRoutes.trackingConfirmed, context),
            _NavItem('Pickup In Progress', AppRoutes.trackingPickup, context),
            _NavItem('Washing / Itemized', AppRoutes.trackingWashing, context),
            _NavItem('Ironing / Brewing', AppRoutes.trackingIroning, context),
            _NavItem('Delivered', AppRoutes.trackingDelivered, context),
          ],
        ),
        _NavCategory(
          title: 'Pricing',
          icon: Icons.local_offer_rounded,
          color: const Color(0xFF10B981),
          items: [
            _NavItem('Pricing Page', AppRoutes.pricing, context),
          ],
        ),
        _NavCategory(
          title: 'Wallet',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF8B5CF6),
          items: [
            _NavItem('Wallet Dashboard', AppRoutes.wallet, context),
            _NavItem('Add Money', AppRoutes.addMoney, context),
            _NavItem('Transactions', AppRoutes.transactions, context),
          ],
        ),
        _NavCategory(
          title: 'Profile',
          icon: Icons.person_rounded,
          color: const Color(0xFFEC4899),
          items: [
            _NavItem('Profile', AppRoutes.profile, context),
            _NavItem('My Information', AppRoutes.myInformation, context),
            _NavItem('Addresses', AppRoutes.addresses, context),
            _NavItem('Add Address', AppRoutes.addAddress, context),
            _NavItem('Payment Methods', AppRoutes.paymentMethods, context),
            _NavItem('Refer & Earn', AppRoutes.referEarn, context),
            _NavItem('Notifications', AppRoutes.notifications, context),
            _NavItem('Secure Orders', AppRoutes.secureOrders, context),
          ],
        ),
        _NavCategory(
          title: 'Support',
          icon: Icons.support_agent_rounded,
          color: const Color(0xFF06B6D4),
          items: [
            _NavItem('Help & Support', AppRoutes.support, context),
            _NavItem('FAQs', AppRoutes.faqs, context),
            _NavItem('How It Works', AppRoutes.howItWorks, context),
            _NavItem('Terms & Conditions', AppRoutes.terms, context),
            _NavItem('Privacy Policy', AppRoutes.privacy, context),
          ],
        ),
        _NavCategory(
          title: 'More',
          icon: Icons.more_horiz_rounded,
          color: const Color(0xFF64748B),
          items: [
            _NavItem('More Menu', AppRoutes.more, context),
            _NavItem('About Us', AppRoutes.about, context),
            _NavItem('Blog', AppRoutes.blog, context),
            _NavItem('Care Instructions', AppRoutes.careInstructions, context),
            _NavItem('Sustainability', AppRoutes.sustainability, context),
            _NavItem('Contact Us', AppRoutes.contact, context),
          ],
        ),
      ];
}

// ── Data models ──────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem(this.label, this.route, this.context);
  final String label;
  final String route;
  final BuildContext context;
}

class _NavCategory {
  const _NavCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<_NavItem> items;
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.isLast});

  final _NavItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.vertical(
            top: isLast ? Radius.zero : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          onTap: () => context.push(item.route),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: Color(0xFF1A1F36),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.route,
                        style: const TextStyle(
                          color: Color(0xFF8892A4),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFBCC4D0),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF0F2F5),
          ),
      ],
    );
  }
}
