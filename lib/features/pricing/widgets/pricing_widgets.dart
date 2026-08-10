import 'package:flutter/material.dart';
import '../models/pricing_data.dart';

// Brand colors
const _kPrimary = Color(0xFF2453FF);
const _kPrimaryDk = Color(0xFF1A3FD8);
const _kTextPrimary = Color(0xFF0A1645);
const _kTextMuted = Color(0xFF6B7280);

// PricingRow - Modern card-based row for individual items
class PricingRow extends StatelessWidget {
  final String name;
  final String price;
  final String? originalPrice;
  final String serviceType;
  final bool unavailable;

  const PricingRow({
    super.key,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.serviceType,
    this.unavailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (originalPrice != null)
                Text(
                  originalPrice!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                price,
                style: TextStyle(
                  fontSize: unavailable ? 13 : 17,
                  fontWeight: unavailable ? FontWeight.w600 : FontWeight.w800,
                  fontStyle: unavailable ? FontStyle.italic : FontStyle.normal,
                  color: unavailable
                      ? _kTextMuted
                      : (originalPrice != null ? Colors.green.shade700 : _kPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// PackageCard - Card for KG packages
class PackageCard extends StatelessWidget {
  final String name;
  final String instantPrice;
  final String scheduledPrice;
  final String? instantOriginalPrice;
  final String? scheduledOriginalPrice;
  final ServiceType serviceType;

  const PackageCard({
    super.key,
    required this.name,
    required this.instantPrice,
    required this.scheduledPrice,
    this.instantOriginalPrice,
    this.scheduledOriginalPrice,
    required this.serviceType,
  });

  @override
  Widget build(BuildContext context) {
    final isInstant = serviceType == ServiceType.instant;
    final price = isInstant ? instantPrice : scheduledPrice;
    final originalPrice = isInstant ? instantOriginalPrice : scheduledOriginalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Per KG Package',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (originalPrice != null)
                Text(
                  originalPrice,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kTextMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: originalPrice != null ? Colors.green.shade700 : _kPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// PlanCard - Card for bulk plans
class PlanCard extends StatelessWidget {
  final String name;
  final String price;

  const PlanCard({
    super.key,
    required this.name,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Bulk Plan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// MembershipCard - Highlighted card for memberships
class MembershipCard extends StatelessWidget {
  final Membership membership;

  const MembershipCard({
    super.key,
    required this.membership,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Membership',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                membership.price,
                style: TextStyle(
                  fontSize: membership.unavailable ? 13 : 18,
                  fontWeight: membership.unavailable ? FontWeight.w600 : FontWeight.w900,
                  fontStyle: membership.unavailable ? FontStyle.italic : FontStyle.normal,
                  color: membership.unavailable ? Colors.white70 : Colors.white,
                ),
              ),
            ],
          ),
          if (membership.conditions != null && membership.conditions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: membership.conditions!.map((condition) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              condition,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// SmartPassCard - Detailed card for Smart Pass
class SmartPassCard extends StatelessWidget {
  final SmartPass pass;

  const SmartPassCard({
    super.key,
    required this.pass,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'LaundryBrew Smart Pass',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Membership',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionTitle('Includes'),
          const SizedBox(height: 6),
          ...pass.includes.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          _SectionTitle('Coverage'),
          const SizedBox(height: 4),
          Text(
            pass.coverage,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('Validity'),
          const SizedBox(height: 4),
          Text(
            '${pass.validityDays} Days',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _SectionTitle('Excluded Items'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pass.excluded.map((item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
    );
  }
}

// NotesList - Bullet-point list for policies
class NotesList extends StatelessWidget {
  final List<String> notes;

  const NotesList({
    super.key,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD980)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.map((note) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A6400),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8A6400),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
      ),
    );
  }
}

// ExcludedItemsList - List of excluded items
class ExcludedItemsList extends StatelessWidget {
  final List<String> items;

  const ExcludedItemsList({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Excluded Items',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )).toList(),
          ),
        ],
      ),
    );
  }
}

// SectionHeader - Header for expandable sections
class SectionHeader extends StatelessWidget {
  final String title;
  final int itemCount;

  const SectionHeader({
    super.key,
    required this.title,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$itemCount',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
