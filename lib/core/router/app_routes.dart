/// Central registry of every named route in the application.
///
/// Use these constants everywhere instead of raw strings so that
/// renaming a route is a one-line change.
abstract final class AppRoutes {
  // ── Authentication ─────────────────────────────────────────────────────────
  static const splash = '/splash';
  static const login = '/auth/login';
  static const otpVerification = '/auth/verify-otp';
  static const completeProfile = '/auth/complete-profile';

  // ── Home ───────────────────────────────────────────────────────────────────
  static const home = '/home';

  // ── Pickup & Delivery ──────────────────────────────────────────────────────
  static const pickupDelivery = '/pickup-delivery';
  static const pickupSlot = '/pickup-slot';
  static const deliverySlot = '/delivery-slot';

  // ── Services ───────────────────────────────────────────────────────────────
  static const services = '/services';
  static const ironing = '/services/ironing';
  static const washFold = '/services/wash-fold';
  static const washIron = '/services/wash-iron';
  static const dryCleaning = '/services/dry-cleaning';
  static const shoeCleaning = '/services/shoe-cleaning';
  static const premiumLaundry = '/services/premium-laundry';

  // ── Orders ─────────────────────────────────────────────────────────────────
  static const orderReview = '/orders/review';
  static const orderSuccess = '/orders/success';
  static const orders = '/orders';

  // ── Order Tracking ─────────────────────────────────────────────────────────
  static const trackingConfirmed = '/orders/tracking/confirmed';
  static const trackingPickup = '/orders/tracking/pickup';
  static const trackingWashing = '/orders/tracking/washing';
  static const trackingIroning = '/orders/tracking/ironing';
  static const trackingDelivered = '/orders/tracking/delivered';

  // ── Pricing ────────────────────────────────────────────────────────────────
  static const pricing = '/pricing';

  // ── Wallet ─────────────────────────────────────────────────────────────────
  static const wallet = '/wallet';
  static const addMoney = '/wallet/add-money';
  static const transactions = '/wallet/transactions';

  // ── Profile ────────────────────────────────────────────────────────────────
  static const profile = '/profile';
  static const myInformation = '/profile/information';
  static const addresses = '/profile/addresses';
  static const addAddress = '/profile/addresses/add';
  static const paymentMethods = '/profile/payment-methods';
  static const referEarn = '/profile/refer-earn';
  static const notifications = '/profile/notifications';
  static const secureOrders = '/profile/secure-orders';

  // ── Support ────────────────────────────────────────────────────────────────
  static const support = '/support';
  static const faqs = '/support/faqs';
  static const howItWorks = '/support/how-it-works';
  static const terms = '/support/terms';
  static const privacy = '/support/privacy';

  // ── More ───────────────────────────────────────────────────────────────────
  static const more = '/more';
  static const about = '/more/about';
  static const blog = '/more/blog';
  static const careInstructions = '/more/care-instructions';
  static const sustainability = '/more/sustainability';
  static const contact = '/more/contact';

  // ── Delivery Partner ───────────────────────────────────────────────────────
  static const deliveryPartnerHome = '/delivery-partner';

  // ── Dev (remove before production) ────────────────────────────────────────
  static const devScreens = '/dev/screens';
}
