import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/wallet_transaction_model.dart';
import '../providers/wallet_provider.dart';

const _kBlue = Color(0xFF2453FF);
const _kBg   = Color(0xFFF5F6FA);

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  // 'all' | 'credit' | 'debit'
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allTransactionsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Transactions',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kBlue),
            onPressed: () => ref.refresh(allTransactionsProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kBlue)),
        error: (e, _) => _ErrorView(
            error: e.toString(),
            onRetry: () => ref.refresh(allTransactionsProvider)),
        data: (txns) {
          final filtered = _filter == 'all'
              ? txns
              : txns.where((t) => t.type == _filter).toList();

          return Column(
            children: [
              // ── Filter bar ────────────────────────────────────────────────
              _FilterBar(
                  current: _filter,
                  onChange: (f) => setState(() => _filter = f)),

              // ── List ──────────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        color: _kBlue,
                        onRefresh: () async =>
                            ref.refresh(allTransactionsProvider),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 40),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _TxnCard(txn: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChange});
  final String current;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        _Chip(label: 'All',    value: 'all',    current: current, onChange: onChange),
        const SizedBox(width: 8),
        _Chip(label: 'Added',  value: 'credit', current: current, onChange: onChange),
        const SizedBox(width: 8),
        _Chip(label: 'Spent',  value: 'debit',  current: current, onChange: onChange),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.current,
    required this.onChange,
  });
  final String label, value, current;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onChange(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: selected ? _kBlue : const Color(0xFFD1D5DB)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.black54,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13),
        ),
      ),
    );
  }
}

// ── Transaction card ───────────────────────────────────────────────────────────

class _TxnCard extends StatelessWidget {
  const _TxnCard({required this.txn});
  final WalletTransactionModel txn;

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final amtColor =
        isCredit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final iconBg =
        isCredit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fmt = NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final dateFmt =
        DateFormat('dd MMM yyyy').format(txn.createdAt.toLocal());
    final timeFmt =
        DateFormat('hh:mm a').format(txn.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Icon circle
        Container(
          width: 46,
          height: 46,
          decoration:
              BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(
            isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            color: amtColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),

        // Middle: description + date-time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(txn.description,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(dateFmt,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade500)),
                const SizedBox(width: 8),
                Icon(Icons.access_time_rounded,
                    size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(timeFmt,
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade500)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Right: amount + status
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${isCredit ? '+' : '-'}${fmt.format(txn.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: amtColor),
          ),
          const SizedBox(height: 5),
          _StatusBadge(status: txn.status),
        ]),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    late String label;
    late IconData icon;
    switch (status) {
      case 'completed':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Success';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Failed';
        icon = Icons.cancel_outlined;
        break;
      default:
        // Pending transactions are excluded server-side (GET /wallet/transactions)
        // — this branch is a defensive fallback for any unexpected status value.
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        label = 'Unknown';
        icon = Icons.help_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('No transactions found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          Text('Try a different filter',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Could not load transactions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
