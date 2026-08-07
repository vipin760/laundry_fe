import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../checkout/models/checkout_models.dart';
import '../providers/standard_slots_provider.dart';
import '../widgets/slot_widgets.dart';

const _kBlue = Color(0xFF0137B5);
const _kBg   = Color(0xFFF5F6FA);
const _kDark = Color(0xFF0A1645);

class DeliverySlotScreen extends ConsumerStatefulWidget {
  const DeliverySlotScreen({super.key});

  @override
  ConsumerState<DeliverySlotScreen> createState() => _DeliverySlotScreenState();
}

class _DeliverySlotScreenState extends ConsumerState<DeliverySlotScreen> {
  int _dateIndex = 0;
  CheckoutSlot? _selected;

  DateTime get _date    => DateTime.now().add(Duration(days: _dateIndex));
  String   get _dateKey => formatDate(_date);

  String _label(int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM')
        .format(DateTime.now().add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(standardTimeSlotsProvider(_dateKey));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Delivery Time',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: _kDark)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9EDFA)),
        ),
      ),
      body: Column(children: [
        SlotDateChips(
          dateIndex: _dateIndex,
          label: _label,
          onChanged: (i) => setState(() { _dateIndex = i; _selected = null; }),
        ),
        Expanded(child: slotsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: _kBlue)),
          error: (_, __) => SlotRetryView(
              onRetry: () =>
                  ref.invalidate(standardTimeSlotsProvider(_dateKey))),
          data: (result) {
            // The backend injects a "Full Day" placeholder only when the
            // admin hasn't configured real slots for this day — never a
            // real bookable slot, so it must not be rendered as one.
            final slots = (result?.deliverySlots ?? [])
                .where((s) => !s.isFallback)
                .toList();
            if (slots.isEmpty) {
              return SlotEmptyView('delivery', dateLabel: _label(_dateIndex));
            }
            final hasScheduled = slots.any((s) => !s.isInstant);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const SlotSectionLabel('AVAILABLE DELIVERY SLOTS'),
                const SizedBox(height: 12),
                ...slots.map((s) => SlotCard(
                  slot: s,
                  selected: _selected?.label == s.label,
                  isDelivery: true,
                  onTap: () => setState(() => _selected = s),
                )),
                if (!hasScheduled)
                  SlotEmptyView('delivery', dateLabel: _label(_dateIndex)),
              ],
            );
          },
        )),
      ]),
      bottomNavigationBar: SlotConfirmBar(
        slot: _selected,
        label: 'Confirm Delivery Slot',
        onConfirm: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
      ),
    );
  }
}
