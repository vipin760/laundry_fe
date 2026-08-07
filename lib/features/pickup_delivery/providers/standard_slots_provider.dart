import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../checkout/models/checkout_models.dart';
import '../../checkout/services/payment_service.dart';

/// Formats a DateTime as 'yyyy-MM-dd' for the API.
String formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// FutureProvider.family — keyed by date string ('yyyy-MM-dd').
/// Fetches admin-managed standard time slots for that date.
/// Returns null if the API is unavailable (graceful degradation).
final standardTimeSlotsProvider =
    FutureProvider.family<StandardSlotsResult?, String>((ref, date) async {
  final svc = PaymentService();
  return svc.getStandardTimeSlots(date: date);
});
