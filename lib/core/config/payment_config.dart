class PaymentConfig {
  static const String razorpayKeyId = 'rzp_live_TBjyNKnkf74MlW';

  /// Builds Razorpay's `prefill` block from the signed-in user's own details.
  ///
  /// Fields the profile doesn't have are omitted rather than sent as
  /// placeholder values — Razorpay simply collects them in the checkout sheet,
  /// which is correct behaviour and avoids putting fake contact details on a
  /// real transaction.
  static Map<String, String> prefillFor({String? contact, String? email}) {
    final trimmedContact = contact?.trim() ?? '';
    final trimmedEmail = email?.trim() ?? '';
    return {
      if (trimmedContact.isNotEmpty) 'contact': trimmedContact,
      if (trimmedEmail.isNotEmpty) 'email': trimmedEmail,
    };
  }
}
