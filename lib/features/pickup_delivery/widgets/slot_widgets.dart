import 'package:flutter/material.dart';

import '../../checkout/models/checkout_models.dart';

const kSlotBlue  = Color(0xFF0137B5);
const kSlotAmber = Color(0xFFD97706);
const kSlotDark  = Color(0xFF0A1645);
const kSlotGrey  = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
// SLOT CARD  (Instant or standard)
// ─────────────────────────────────────────────────────────────────────────────

class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.selected,
    required this.onTap,
    this.isDelivery = false,
  });

  final CheckoutSlot slot;
  final bool selected;
  final VoidCallback onTap;
  final bool isDelivery;

  @override
  Widget build(BuildContext context) {
    return slot.isInstant
        ? _InstantCard(slot: slot, selected: selected, onTap: onTap,
              isDelivery: isDelivery)
        : _StandardCard(slot: slot, selected: selected, onTap: onTap,
              isDelivery: isDelivery);
  }
}

class _InstantCard extends StatelessWidget {
  const _InstantCard({
    required this.slot, required this.selected,
    required this.onTap, required this.isDelivery,
  });
  final CheckoutSlot slot;
  final bool selected;
  final VoidCallback onTap;
  final bool isDelivery;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kSlotAmber.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kSlotAmber : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected ? kSlotAmber : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bolt_rounded, size: 18,
                color: selected ? Colors.white : kSlotAmber),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Instant',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                        color: selected ? kSlotAmber : kSlotDark)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: kSlotAmber,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('~15 min',
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                isDelivery
                    ? 'Delivered in ~15 minutes after processing'
                    : 'Pickup partner reaches you in ~15 minutes',
                style: const TextStyle(fontSize: 12, color: kSlotGrey),
              ),
            ],
          )),
          SlotRadioDot(selected: selected, color: kSlotAmber),
        ]),
      ),
    );
  }
}

class _StandardCard extends StatelessWidget {
  const _StandardCard({
    required this.slot, required this.selected,
    required this.onTap, required this.isDelivery,
  });
  final CheckoutSlot slot;
  final bool selected;
  final VoidCallback onTap;
  final bool isDelivery;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kSlotBlue : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected ? kSlotBlue : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDelivery ? Icons.home_rounded : Icons.local_shipping_rounded,
              size: 18,
              color: selected ? Colors.white : kSlotBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot.label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: selected ? kSlotBlue : kSlotDark)),
              const SizedBox(height: 2),
              Text('${slot.startTime} – ${slot.endTime}',
                  style: const TextStyle(fontSize: 12, color: kSlotGrey)),
              if (slot.expectedTurnaround != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 12,
                      color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(slot.expectedTurnaround!,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: selected
                              ? kSlotBlue.withAlpha(180)
                              : const Color(0xFF9CA3AF))),
                ]),
              ],
            ],
          )),
          SlotRadioDot(selected: selected, color: kSlotBlue),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RADIO DOT
// ─────────────────────────────────────────────────────────────────────────────

class SlotRadioDot extends StatelessWidget {
  const SlotRadioDot({super.key, required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 20, height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? color : const Color(0xFFD1D5DB),
        width: selected ? 6 : 2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class SlotSectionLabel extends StatelessWidget {
  const SlotSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
          color: kSlotBlue, letterSpacing: 0.5));
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class SlotEmptyView extends StatelessWidget {
  const SlotEmptyView(this.type, {super.key, this.dateLabel});
  final String type;
  /// e.g. 'Today', 'Tomorrow', 'Thu, 16 Jul' — shown in the message so it
  /// reads naturally for whichever date the user has selected.
  final String? dateLabel;

  @override
  Widget build(BuildContext context) {
    final suffix = dateLabel == null
        ? ''
        : dateLabel!.toLowerCase() == 'today'
            ? ' today'
            : ' on $dateLabel';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_busy_rounded, size: 44,
              color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text('Scheduled $type unavailable$suffix',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  color: kSlotDark)),
          const SizedBox(height: 4),
          const Text('Try selecting another date',
              style: TextStyle(fontSize: 13, color: kSlotGrey)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RETRY VIEW
// ─────────────────────────────────────────────────────────────────────────────

class SlotRetryView extends StatelessWidget {
  const SlotRetryView({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, size: 40,
          color: Color(0xFFD1D5DB)),
      const SizedBox(height: 12),
      const Text('Schedule not available',
          style: TextStyle(fontWeight: FontWeight.w700, color: kSlotDark)),
      const SizedBox(height: 4),
      const Text("We couldn't load time slots right now",
          style: TextStyle(fontSize: 13, color: kSlotGrey)),
      const SizedBox(height: 8),
      TextButton(
        onPressed: onRetry,
        child: const Text('Retry',
            style: TextStyle(color: kSlotBlue, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM BAR
// ─────────────────────────────────────────────────────────────────────────────

class SlotConfirmBar extends StatelessWidget {
  const SlotConfirmBar({
    super.key,
    required this.slot,
    required this.label,
    required this.onConfirm,
  });
  final CheckoutSlot? slot;
  final String label;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000),
            blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Row(children: [
        if (slot != null) ...[
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selected',
                  style: TextStyle(fontSize: 11, color: kSlotGrey,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                slot!.isInstant
                    ? 'Instant (~15 min)'
                    : '${slot!.label} · ${slot!.startTime}–${slot!.endTime}',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800, color: kSlotDark),
              ),
            ],
          )),
          const SizedBox(width: 12),
        ],
        GestureDetector(
          onTap: onConfirm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              color: onConfirm != null ? kSlotBlue : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE CHIP ROW  (Today / Tomorrow / +2 days)
// ─────────────────────────────────────────────────────────────────────────────

class SlotDateChips extends StatelessWidget {
  const SlotDateChips({
    super.key,
    required this.dateIndex,
    required this.label,
    required this.onChanged,
  });

  final int dateIndex;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: List.generate(3, (i) {
          final sel = i == dateIndex;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? kSlotBlue : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label(i),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
