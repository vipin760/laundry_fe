import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/models/address_model.dart';
import '../../location/providers/address_provider.dart';
import '../../location/screens/add_edit_address_screen.dart';

const _kBlue   = Color(0xFF2453FF);
const _kBlueBg = Color(0xFFEEF1FF);

// ─── List Screen ──────────────────────────────────────────────────────────────

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'My Addresses',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kBlue)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 52, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Could not load addresses',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(addressesProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (addresses) => addresses.isEmpty
            ? _EmptyState(onAdd: () => _openAdd(context, ref))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: addresses.length,
                itemBuilder: (_, i) => _AddressCard(
                  address: addresses[i],
                  onEdit:       () => _openEdit(context, ref, addresses[i]),
                  onDelete:     () => _confirmDelete(context, ref, addresses[i]),
                  onSetDefault: addresses[i].isDefault
                      ? null
                      : () => ref.read(addressesProvider.notifier).setDefault(addresses[i].id!),
                ),
              ),
      ),
      floatingActionButton: state.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _openAdd(context, ref),
              backgroundColor: _kBlue,
              elevation: 2,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Address',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<void> _openAdd(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditAddressScreen()),
    );
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref, AddressModel addr) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditAddressScreen(existing: addr)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AddressModel addr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Address?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Remove "${addr.type}" address?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref.read(addressesProvider.notifier).deleteAddress(addr.id!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    this.onSetDefault,
  });

  final AddressModel  address;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;
  final VoidCallback? onSetDefault;

  IconData get _icon {
    switch (address.type.toLowerCase()) {
      case 'work':
      case 'office':
        return Icons.work_outline_rounded;
      case 'other':
        return Icons.place_outlined;
      default:
        return Icons.home_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _kBlueBg,
                    borderRadius: BorderRadius.circular(9)),
                child: Icon(_icon, size: 18, color: _kBlue),
              ),
              const SizedBox(width: 10),
              Text(address.type,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black87)),
              const SizedBox(width: 8),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Default',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: _kBlue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Edit',
                      style: TextStyle(
                          color: _kBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Address text
            Text(
              address.fullAddress.isNotEmpty
                  ? address.fullAddress
                  : 'No address details',
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 13.5, height: 1.45),
            ),
            if (address.landmark.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Near: ${address.landmark}',
                  style:
                      TextStyle(color: Colors.grey[400], fontSize: 12.5)),
            ],
            const SizedBox(height: 12),
            // Footer
            Row(children: [
              if (onSetDefault != null)
                GestureDetector(
                  onTap: onSetDefault,
                  child: const Text('Set as Default',
                      style: TextStyle(
                          color: _kBlue,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ),
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.redAccent),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 80, color: Colors.grey[200]),
              const SizedBox(height: 18),
              const Text('No saved addresses',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              const SizedBox(height: 8),
              Text(
                'Add your home, work or other addresses\nfor faster checkout.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Address',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ],
          ),
        ),
      );
}
