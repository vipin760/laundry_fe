import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/service_model.dart';
import '../providers/cart_provider.dart';
import '../providers/services_provider.dart';
import '../../checkout/screens/scheduling_screen.dart';

class ServicesView extends ConsumerStatefulWidget {
  const ServicesView({
    super.key,
    this.customerName,
    this.isAdmin = false,
    required this.onBack,
  });

  final String? customerName;
  final bool isAdmin;
  final VoidCallback onBack;

  @override
  ConsumerState<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends ConsumerState<ServicesView> {
  // Removed _selectedBottomIndex as navigation is now handled by the parent dashboard.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(servicesProvider);
    });
  }

  Future<void> _onServiceTap(ServiceModel service) async {
    final alreadyAdded = ref.read(cartProvider).quantityFor(service.id, 'instant') > 0;
    if (alreadyAdded) {
      return;
    }

    final added = await ref
        .read(cartProvider.notifier)
        .addToCartOptimistic(service, 'instant');
    if (!mounted) {
      return;
    }

    if (!added) {
      // Cart holds Scheduled services — only one order type at a time.
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: _ServiceText(
              ref.read(cartProvider).errorMessage ??
                  'You can order only one service type at a time.',
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFD92D20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: _ServiceText(
            '${_prettyServiceName(service.name)} added to cart',
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF111A46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _openCartSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final cartState = ref.watch(cartProvider);
            return _CartSheet(
              cartState: cartState,
              onRemove: (item) =>
                  ref.read(cartProvider.notifier).removeFromCart(item.service.id, item.category),
              onClear: () => ref.read(cartProvider.notifier).clearCart(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsyncValue = ref.watch(servicesProvider);
    final cartState = ref.watch(cartProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: widget.onBack,
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF2F4FCB),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _ServiceText(
                      'Select a Service',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0E1A48),
                    ),
                    const SizedBox(height: 2),
                    const _ServiceText(
                      'Which service would you like to book?',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7D86A5),
                    ),
                  ],
                ),
              ),
              _CartHeaderButton(cartState: cartState, onTap: _openCartSheet),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CartSummaryPill(cartState: cartState, onTap: _openCartSheet),
        ),
        Expanded(
          child: servicesAsyncValue.when(
            data: (services) => _ServicesListContent(
              services: services,
              onTap: _onServiceTap,
              onRefresh: () => ref.refresh(servicesProvider.future),
              cartState: cartState,
            ),
            loading: () => const _ServicesLoadingState(),
            error: (error, stackTrace) => _ServicesErrorState(
              message: error.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.refresh(servicesProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicesListContent extends StatelessWidget {
  const _ServicesListContent({
    required this.services,
    required this.onTap,
    required this.onRefresh,
    required this.cartState,
  });

  final List<ServiceModel> services;
  final ValueChanged<ServiceModel> onTap;
  final RefreshCallback onRefresh;
  final CartState cartState;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: const Color(0xFF3054D2),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: _ServiceText(
                'No services available right now.',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7781A3),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF3054D2),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: services.length + 1,
        itemBuilder: (context, index) {
          if (index == services.length) {
            return const _ItemLimitInfoCard();
          }

          final service = services[index];
          return _ServiceRowCard(
            service: service,
            quantity: cartState.quantityFor(service.id, 'instant'),
            isPending: cartState.isPending(service.id, 'instant'),
            onTap: () => onTap(service),
          );
        },
      ),
    );
  }
}

class _ServiceRowCard extends StatelessWidget {
  const _ServiceRowCard({
    required this.service,
    required this.quantity,
    required this.isPending,
    required this.onTap,
  });

  final ServiceModel service;
  final int quantity;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7ECFB)),
            ),
            child: Row(
              children: [
                _ServiceIcon(name: service.name),
                const SizedBox(width: 12),
                Expanded(
                  child: _ServiceText(
                    _prettyServiceName(service.name),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF3150C8),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ServiceText(
                      'From \u20B9${_displayPrice(service.price)}',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5B76E6),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isPending
                          ? const _CartStateChip(
                              key: ValueKey('pending'),
                              label: 'Updating...',
                              backgroundColor: Color(0xFFE8EEFF),
                              textColor: Color(0xFF3350C7),
                            )
                          : quantity > 0
                          ? const _CartStateChip(
                              key: ValueKey('added'),
                              label: 'Added',
                              backgroundColor: Color(0xFFE4F7EA),
                              textColor: Color(0xFF1C8A4D),
                            )
                          : const SizedBox(
                              key: ValueKey('empty'),
                              width: 1,
                              height: 1,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final normalized = name.toLowerCase().replaceAll('_', ' ').trim();

    IconData icon = Icons.local_laundry_service_rounded;
    Color iconColor = const Color(0xFF4A5A78);
    Color bgColor = const Color(0xFFF2F5FD);

    if (normalized.contains('dry clean')) {
      icon = Icons.dry_cleaning_rounded;
      iconColor = const Color(0xFF343C4E);
    } else if (normalized.contains('wash') && normalized.contains('fold')) {
      icon = Icons.inventory_2_rounded;
      iconColor = const Color(0xFF2460D3);
      bgColor = const Color(0xFFEAF1FF);
    } else if (normalized.contains('wash') && normalized.contains('iron')) {
      icon = Icons.checkroom_rounded;
      iconColor = const Color(0xFF4D70C9);
      bgColor = const Color(0xFFEDF2FF);
    } else if (normalized.contains('iron')) {
      icon = Icons.iron_rounded;
      iconColor = const Color(0xFF5A657A);
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 34, color: iconColor),
    );
  }
}

class _CartSummaryPill extends StatelessWidget {
  const _CartSummaryPill({required this.cartState, required this.onTap});

  final CartState cartState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: cartState.totalItemsCount == 0
          ? const SizedBox(
              key: ValueKey('cart_empty'),
              width: double.infinity,
              child: _ServiceText(
                'Tap any service to add to cart',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7D86A5),
              ),
            )
          : Material(
              key: const ValueKey('cart_filled'),
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_rounded,
                        size: 16,
                        color: Color(0xFF3054D2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ServiceText(
                          '${cartState.totalItemsCount} item(s) in cart',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2F4FCB),
                        ),
                      ),
                      _ServiceText(
                        '\u20B9${_displayPrice(cartState.totalPrice)}',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2F4FCB),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Color(0xFF3054D2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _CartHeaderButton extends StatelessWidget {
  const _CartHeaderButton({required this.cartState, required this.onTap});

  final CartState cartState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF2F4FCB),
              size: 24,
            ),
          ),
          if (cartState.totalItemsCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDB3B54),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDB3B54).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _ServiceText(
                    cartState.totalItemsCount > 99
                        ? '99+'
                        : cartState.totalItemsCount.toString(),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.cartState,
    required this.onRemove,
    required this.onClear,
  });

  final CartState cartState;
  final ValueChanged<CartLineItem> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.28,
      maxChildSize: 0.82,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE4F4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF66708F),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: _ServiceText(
                        'Cart',
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E1A48),
                      ),
                    ),
                    if (cartState.totalItemsCount > 0)
                      TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: const _ServiceText(
                          'Clear',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDB3B54),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDB3B54),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: cartState.lineItems.isEmpty
                    ? const Center(
                        child: _ServiceText(
                          'Your cart is empty.',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7D86A5),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          16 + safeBottom,
                        ),
                        itemCount: cartState.lineItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = cartState.lineItems[index];
                          return _CartLineTile(
                            item: item,
                            onRemove: () => onRemove(item),
                          );
                        },
                      ),
              ),
              if (cartState.totalItemsCount > 0)
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + safeBottom),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFDBE3FA).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ServiceText(
                              '${cartState.totalItemsCount} item(s)',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF66708F),
                            ),
                          ),
                          _ServiceText(
                            'Total \u20B9${_displayPrice(cartState.totalPrice)}',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2F4FCB),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close bottom sheet
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SchedulingScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2453FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const _ServiceText(
                            'Checkout',
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.item, required this.onRemove});

  final CartLineItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECFB)),
      ),
      child: Row(
        children: [
          _ServiceIcon(name: item.service.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceText(
                  _prettyServiceName(item.service.name),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0E1A48),
                ),
                const SizedBox(height: 3),
                _ServiceText(
                  '\u20B9${_displayPrice(item.service.price)} each',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF66708F),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CartStateChip(
                label: 'Qty ${item.quantity}',
                backgroundColor: const Color(0xFFEAF1FF),
                textColor: const Color(0xFF2F4FCB),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const _ServiceText(
                  'Remove',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDB3B54),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDB3B54),
                  minimumSize: const Size(0, 30),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartStateChip extends StatelessWidget {
  const _CartStateChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: _ServiceText(
        label,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}

class _ItemLimitInfoCard extends StatelessWidget {
  const _ItemLimitInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E9FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceText(
            'Do I need to list the items?',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF3654C6),
          ),
          SizedBox(height: 8),
          _ServiceText(
            'No item listing is required. Simply book the service required then pack one bag per service.',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6C78A0),
          ),
          SizedBox(height: 3),
          _ServiceText(
            'We will iron and take care of the rest.',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6C78A0),
          ),
        ],
      ),
    );
  }
}

class _ServicesLoadingState extends StatelessWidget {
  const _ServicesLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7ECFB)),
            ),
          ),
        );
      },
    );
  }
}

class _ServicesErrorState extends StatelessWidget {
  const _ServicesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 42,
              color: Color(0xFF8590B2),
            ),
            const SizedBox(height: 10),
            const _ServiceText(
              'Could not load services',
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            const SizedBox(height: 6),
            _ServiceText(
              message,
              textAlign: TextAlign.center,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6D779A),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3054D2),
              ),
              child: const _ServiceText(
                'Retry',
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceText extends StatelessWidget {
  const _ServiceText(
    this.value, {
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color = const Color(0xFF0E1A48),
    this.textAlign,
  });

  final String value;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.35,
      ),
    );
  }
}

String _prettyServiceName(String raw) {
  final key = raw.toLowerCase().replaceAll('_', ' ').trim();
  if (key == 'iron' || key == 'ironing') return 'Ironing';
  if (key == 'wash fold' || key == 'wash & fold') return 'Wash & Fold';
  if (key == 'wash iron' || key == 'wash & iron') return 'Wash & Iron';
  if (key == 'dry cleaning' || key == 'dry clean') return 'Dry Cleaning';

  final words = key.split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _displayPrice(double price) {
  if (price == price.roundToDouble()) {
    return price.toInt().toString();
  }
  return price.toStringAsFixed(2);
}

/// Standalone screen wrapper so [ServicesView] can be reached via go_router.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ServicesView(
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
