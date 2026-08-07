import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pricing_data.dart';
import '../models/cloth_type_model.dart';
import '../providers/cloth_types_provider.dart';
import '../widgets/pricing_widgets.dart';

// Brand colors
const _kPrimary = Color(0xFF2453FF);
const _kPrimaryDk = Color(0xFF1A3FD8);
const _kBg = Color(0xFFF5F6FA);
const _kTextPrimary = Color(0xFF0A1645);
const _kTextMuted = Color(0xFF6B7280);

// Category data with icons
final _categories = [
  {'name': 'Ironing', 'icon': '👕'},
  {'name': 'Wash & Fold', 'icon': '🧺'},
  {'name': 'Wash & Iron', 'icon': '🧼'},
  {'name': 'Shoe Cleaning', 'icon': '👟'},
  {'name': 'Dry Cleaning', 'icon': '✨'},
  {'name': 'Memberships', 'icon': '🎟'},
];

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  ServiceType _serviceType = ServiceType.instant;
  int _selectedCategory = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Pricing',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Service Type Segmented Control
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _ServiceTypeToggle(
              selected: _serviceType,
              onChanged: (type) => setState(() => _serviceType = type),
            ),
          ),
          // Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _CategoryChip(
                    icon: category['icon'] as String,
                    label: category['name'] as String,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedCategory = index),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Expanded(
            child: _buildCategoryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (_selectedCategory) {
      case 0:
        return _IroningTab(serviceType: _serviceType);
      case 1:
        return _WashFoldTab(serviceType: _serviceType);
      case 2:
        return _WashIronTab(serviceType: _serviceType);
      case 3:
        return _ShoeCleaningTab(serviceType: _serviceType);
      case 4:
        return _DryCleaningTab(serviceType: _serviceType);
      case 5:
        return const _MembershipsTab();
      default:
        return const SizedBox();
    }
  }
}

class _ServiceTypeToggle extends StatelessWidget {
  final ServiceType selected;
  final ValueChanged<ServiceType> onChanged;

  const _ServiceTypeToggle({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              label: 'Instant',
              isSelected: selected == ServiceType.instant,
              onTap: () => onChanged(ServiceType.instant),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              label: 'Scheduled',
              isSelected: selected == ServiceType.scheduled,
              onTap: () => onChanged(ServiceType.scheduled),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? _kPrimary : _kTextMuted,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : _kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared PricingRow builder for a cloth type, applying the discount (if any)
// for the currently selected Instant/Scheduled service type.
//
// A rate of 0 means the admin left it unset because that service type isn't
// offered for this cloth type (e.g. Dry Cleaning is Schedule-only) — show
// that plainly instead of a misleading "₹0".
PricingRow _pricingRowFor(ClothTypeModel item, ServiceType serviceType) {
  final isInstant = serviceType == ServiceType.instant;
  final rate = isInstant ? item.instantRate : item.scheduledRate;
  if (rate <= 0) {
    return PricingRow(
      name: item.name,
      price: 'Not available',
      serviceType: isInstant ? 'Scheduled only' : 'Instant only',
      unavailable: true,
    );
  }
  final hasDiscount = isInstant ? item.hasInstantDiscount : item.hasScheduledDiscount;
  final effective = isInstant ? item.effectiveInstantRate : item.effectiveScheduledRate;
  final original = isInstant ? item.instantRate : item.scheduledRate;
  return PricingRow(
    name: item.name,
    price: '₹${effective.toStringAsFixed(0)}',
    originalPrice: hasDiscount ? '₹${original.toStringAsFixed(0)}' : null,
    serviceType: 'Per Item',
  );
}

// Shared tab for a cloth-type category grouped into subcategory sections
// (Ironing, Dry Cleaning) — fetches live pricing from the backend.
class _ItemizedCategoryTab extends ConsumerWidget {
  final ServiceType serviceType;
  final String category;
  final List<String> subcategoryOrder;
  final Map<String, String> subcategoryLabels;

  const _ItemizedCategoryTab({
    required this.serviceType,
    required this.category,
    required this.subcategoryOrder,
    required this.subcategoryLabels,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clothTypesAsync = ref.watch(clothTypesProvider);
    return clothTypesAsync.when(
      data: (clothTypes) {
        final items = clothTypes.where((c) => c.category == category).toList();
        if (items.isEmpty) return const _PricingEmptyState();
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final sub in subcategoryOrder)
                if (items.any((i) => i.subcategory == sub))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubcategorySection(
                      title: subcategoryLabels[sub]!,
                      itemCount: items.where((i) => i.subcategory == sub).length,
                      initiallyExpanded: sub == subcategoryOrder.first,
                      children: items
                          .where((i) => i.subcategory == sub)
                          .map((item) => _pricingRowFor(item, serviceType))
                          .toList(),
                    ),
                  ),
            ],
          ),
        );
      },
      loading: () => const _PricingLoadingState(),
      error: (error, _) => _PricingErrorState(
        message: error.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.refresh(clothTypesProvider),
      ),
    );
  }
}

// IRONING TAB
class _IroningTab extends StatelessWidget {
  final ServiceType serviceType;

  const _IroningTab({required this.serviceType});

  static const _subcategoryOrder = ['unisex', 'men', 'women', 'kids', 'household'];
  static const _subcategoryLabels = {
    'unisex': 'Unisex',
    'men': 'Men',
    'women': 'Women',
    'kids': 'Kids',
    'household': 'Household',
  };

  @override
  Widget build(BuildContext context) {
    return _ItemizedCategoryTab(
      serviceType: serviceType,
      category: 'ironing',
      subcategoryOrder: _subcategoryOrder,
      subcategoryLabels: _subcategoryLabels,
    );
  }
}

// Shared tab body for a weight-tiered category (Wash & Fold / Wash & Iron):
// fetches live pricing from the backend and splits it into Packages (two
// rates: instant/scheduled) and Plans (a single bulk price) by subcategory.
class _WeightTieredCategoryTab extends ConsumerWidget {
  final ServiceType serviceType;
  final String category;
  final List<Widget> Function()? trailingSections;

  const _WeightTieredCategoryTab({
    required this.serviceType,
    required this.category,
    this.trailingSections,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clothTypesAsync = ref.watch(clothTypesProvider);
    return clothTypesAsync.when(
      data: (clothTypes) {
        final items = clothTypes.where((c) => c.category == category).toList();
        final packages = items.where((i) => i.subcategory == 'package').toList();
        final household = items.where((i) => i.subcategory == 'household').toList();
        final plans = items.where((i) => i.subcategory == 'plan').toList();
        final trailing = trailingSections?.call() ?? const [];
        if (packages.isEmpty && household.isEmpty && plans.isEmpty && trailing.isEmpty) {
          return const _PricingEmptyState();
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (packages.isNotEmpty) ...[
                _SubcategorySection(
                  title: 'Packages',
                  itemCount: packages.length,
                  initiallyExpanded: true,
                  children: packages
                      .map((item) => PackageCard(
                            name: item.name,
                            instantPrice: '₹${item.effectiveInstantRate.toStringAsFixed(0)}',
                            scheduledPrice: '₹${item.effectiveScheduledRate.toStringAsFixed(0)}',
                            instantOriginalPrice: item.hasInstantDiscount
                                ? '₹${item.instantRate.toStringAsFixed(0)}'
                                : null,
                            scheduledOriginalPrice: item.hasScheduledDiscount
                                ? '₹${item.scheduledRate.toStringAsFixed(0)}'
                                : null,
                            serviceType: serviceType,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (household.isNotEmpty) ...[
                _SubcategorySection(
                  title: 'Household',
                  itemCount: household.length,
                  initiallyExpanded: packages.isEmpty,
                  children: household
                      .map((item) => _pricingRowFor(item, serviceType))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (plans.isNotEmpty) ...[
                _SubcategorySection(
                  title: 'Plans',
                  itemCount: plans.length,
                  initiallyExpanded: packages.isEmpty && household.isEmpty,
                  children: plans
                      .map((item) => PlanCard(
                            name: item.name,
                            price: '₹${item.effectiveInstantRate.toStringAsFixed(0)}',
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              ...trailing,
            ],
          ),
        );
      },
      loading: () => const _PricingLoadingState(),
      error: (error, _) => _PricingErrorState(
        message: error.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.refresh(clothTypesProvider),
      ),
    );
  }
}

// WASH & FOLD TAB
class _WashFoldTab extends StatelessWidget {
  final ServiceType serviceType;

  const _WashFoldTab({required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return _WeightTieredCategoryTab(
      serviceType: serviceType,
      category: 'washFold',
      trailingSections: () => [
        _SubcategorySection(
          title: 'Notes',
          itemCount: PricingData.washFoldNotes.length,
          children: [
            NotesList(
              notes: PricingData.washFoldNotes.map((n) => n.text).toList(),
            ),
          ],
        ),
      ],
    );
  }
}

// WASH & IRON TAB
class _WashIronTab extends StatelessWidget {
  final ServiceType serviceType;

  const _WashIronTab({required this.serviceType});

  @override
  Widget build(BuildContext context) {
    return _WeightTieredCategoryTab(
      serviceType: serviceType,
      category: 'washIron',
    );
  }
}

// SHOE CLEANING TAB
class _ShoeCleaningTab extends ConsumerWidget {
  final ServiceType serviceType;

  const _ShoeCleaningTab({required this.serviceType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clothTypesAsync = ref.watch(clothTypesProvider);
    return clothTypesAsync.when(
      data: (clothTypes) {
        final items = clothTypes.where((c) => c.category == 'shoeCleaning').toList();
        if (items.isEmpty) return const _PricingEmptyState();
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                items.map((item) => _pricingRowFor(item, serviceType)).toList(),
          ),
        );
      },
      loading: () => const _PricingLoadingState(),
      error: (error, _) => _PricingErrorState(
        message: error.toString().replaceAll('Exception: ', ''),
        onRetry: () => ref.refresh(clothTypesProvider),
      ),
    );
  }
}

// DRY CLEANING TAB
class _DryCleaningTab extends StatelessWidget {
  final ServiceType serviceType;

  const _DryCleaningTab({required this.serviceType});

  static const _subcategoryOrder = ['unisex', 'men', 'women', 'kids', 'household', 'delicate'];
  static const _subcategoryLabels = {
    'unisex': 'Unisex',
    'men': 'Men',
    'women': 'Women',
    'kids': 'Kids',
    'household': 'Household',
    'delicate': 'Delicate',
  };

  @override
  Widget build(BuildContext context) {
    return _ItemizedCategoryTab(
      serviceType: serviceType,
      category: 'dryCleaning',
      subcategoryOrder: _subcategoryOrder,
      subcategoryLabels: _subcategoryLabels,
    );
  }
}

// MEMBERSHIPS TAB
// Memberships (Iron Pass / Smart Pass) are not launched yet — the listing is
// intentionally hidden behind a "coming soon" placeholder regardless of what
// the backend has configured, rather than rendering per-item availability.
class _MembershipsTab extends StatelessWidget {
  const _MembershipsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PricingEmptyState(
            message: "Memberships are coming soon. We'll notify you!",
          ),
          _SubcategorySection(
            title: 'Important Notes',
            itemCount: PricingData.importantNotes.length,
            children: [
              NotesList(
                notes: PricingData.importantNotes.map((n) => n.text).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// SUBCATEGORY SECTION HELPER
class _SubcategorySection extends StatelessWidget {
  final String title;
  final int itemCount;
  final List<Widget> children;
  final bool initiallyExpanded;

  const _SubcategorySection({
    required this.title,
    required this.itemCount,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: SectionHeader(title: title, itemCount: itemCount),
        iconColor: _kPrimary,
        collapsedIconColor: _kTextMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        children: children,
      ),
    );
  }
}

// Loading/error/empty states for network-backed pricing tabs
class _PricingLoadingState extends StatelessWidget {
  const _PricingLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: _kPrimary),
      ),
    );
  }
}

class _PricingEmptyState extends StatelessWidget {
  const _PricingEmptyState({
    this.message = 'Pricing for this category is coming soon.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _kTextMuted),
        ),
      ),
    );
  }
}

class _PricingErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PricingErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kTextMuted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(color: _kPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
