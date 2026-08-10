import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/checkout/screens/scheduling_screen.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';
import 'add_edit_address_screen.dart';

// ── Brand colours ─────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF1A23CC);
const _kBg     = Color(0xFFF5F6FA);
const _kDark   = Color(0xFF0A1645);
const _kGrey   = Color(0xFF6B7280);
const _kGreen  = Color(0xFF15803D);

// ── Address-type config ───────────────────────────────────────────────────────
const _typeConfig = {
  'Home': (icon: Icons.home_rounded, color: Color(0xFF1A23CC), bg: Color(0xFFEEF0FF)),
  'Work': (icon: Icons.work_rounded,  color: Color(0xFF7C3AED), bg: Color(0xFFF3E8FF)),
  'Other': (icon: Icons.place_rounded, color: Color(0xFFEA580C), bg: Color(0xFFFFF7ED)),
};

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key, this.autoFill});

  /// Pre-fill data from the map pin position (area, city, state, pincode, lat, lng).
  final AddressModel? autoFill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAddresses = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Address',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kDark,
          ),
        ),
        centerTitle: true,
      ),
      body: asyncAddresses.when(
        loading: () => const _AddressSkeleton(),
        error: (_, _) => _ErrorState(
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (addresses) => addresses.isEmpty
            ? _EmptyState(
                onAdd: () => _openAddAddress(context, ref),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Saved addresses ──────────────────────────────────────
                  const _SectionLabel(label: 'SAVED ADDRESSES'),
                  const SizedBox(height: 10),
                  ...addresses.map(
                    (addr) => _AddressCard(
                      address: addr,
                      onSelect: () => _selectAddress(context, ref, addr),
                      onEdit: () => _openEditAddress(context, ref, addr),
                      onDelete: () => _deleteAddress(context, ref, addr),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Add new address button ─────────────────────────────
                  _AddNewBtn(onTap: () => _openAddAddress(context, ref)),
                ],
              ),
      ),

      // ── FAB: add address ─────────────────────────────────────────────────
      floatingActionButton: asyncAddresses.value?.isNotEmpty == true
          ? FloatingActionButton.extended(
              backgroundColor: _kBlue,
              onPressed: () => _openAddAddress(context, ref),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Add Address',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _openAddAddress(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAddressScreen(autoFill: autoFill),
      ),
    );
  }

  void _openEditAddress(BuildContext context, WidgetRef ref, AddressModel addr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditAddressScreen(existing: addr),
      ),
    );
  }

  void _selectAddress(BuildContext context, WidgetRef ref, AddressModel addr) {
    ref.read(selectedAddressProvider.notifier).select(addr);
    // Navigate to checkout (SchedulingScreen)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SchedulingScreen()),
      (route) => route.isFirst,
    );
  }

  Future<void> _deleteAddress(
      BuildContext context, WidgetRef ref, AddressModel addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Address?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _kDark),
        ),
        content: Text(
          addr.line1.isNotEmpty ? addr.line1 : addr.line2,
          style: const TextStyle(color: _kGrey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _kGrey, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && addr.id != null) {
      try {
        await ref.read(addressesProvider.notifier).deleteAddress(addr.id!);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete address')),
          );
        }
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ADDRESS CARD
// ═════════════════════════════════════════════════════════════════════════════

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final AddressModel address;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[address.type] ?? _typeConfig['Other']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault
              ? _kBlue.withAlpha(100)
              : const Color(0xFFE9EDFA),
          width: address.isDefault ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cfg.icon, size: 14, color: cfg.color),
                      const SizedBox(width: 5),
                      Text(
                        address.type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cfg.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Default badge
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCF5E8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 12, color: _kGreen),
                        SizedBox(width: 3),
                        Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Edit button
                _CardIconBtn(
                  icon: Icons.edit_rounded,
                  color: _kBlue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
                // Delete button
                _CardIconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFDC2626),
                  onTap: onDelete,
                ),
              ],
            ),
          ),

          // ── Address lines ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.line1.isNotEmpty)
                  Text(
                    address.line1,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  address.line2,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kGrey,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                if (address.instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 13, color: _kGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address.instructions,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kGrey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ── Select button ────────────────────────────────────────────────
          GestureDetector(
            onTap: onSelect,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: _kBlue),
                  const SizedBox(width: 6),
                  const Text(
                    'Deliver Here',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardIconBtn extends StatelessWidget {
  const _CardIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: _kGrey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AddNewBtn extends StatelessWidget {
  const _AddNewBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EDFA)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 18, color: _kBlue),
            SizedBox(width: 8),
            Text(
              'Add New Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.location_off_rounded,
                  size: 40, color: _kBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'No saved addresses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an address to make\ncheckout faster next time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _kGrey,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _kBlue.withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Add Address',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _AddressSkeleton extends StatelessWidget {
  const _AddressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: List.generate(3, (_) => const _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmer(60, 22),
            const SizedBox(height: 12),
            _shimmer(double.infinity, 13),
            const SizedBox(height: 6),
            _shimmer(180, 13),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: _kGrey),
          const SizedBox(height: 12),
          const Text('Failed to load addresses',
              style: TextStyle(color: _kGrey, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
