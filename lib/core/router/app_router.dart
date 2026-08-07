import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/delivery/screens/delivery_partner_home_screen.dart';
import '../../features/dev/screens/screen_navigator.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/more/screens/about_screen.dart';
import '../../features/more/screens/blog_screen.dart';
import '../../features/more/screens/care_instructions_screen.dart';
import '../../features/more/screens/contact_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/more/screens/sustainability_screen.dart';
import '../../features/orders/screens/order_review_screen.dart';
import '../../features/orders/screens/order_success_screen.dart';
import '../../features/orders/screens/orders_screen.dart';
import '../../features/orders/tracking/screens/delivered_screen.dart';
import '../../features/orders/tracking/screens/ironing_tracking_screen.dart';
import '../../features/orders/tracking/screens/order_confirmed_screen.dart';
import '../../features/orders/tracking/screens/pickup_in_progress_screen.dart';
import '../../features/orders/tracking/screens/washing_screen.dart';
import '../../features/pickup_delivery/screens/delivery_slot_screen.dart';
import '../../features/pickup_delivery/screens/pickup_delivery_screen.dart';
import '../../features/pickup_delivery/screens/pickup_slot_screen.dart';
import '../../features/pricing/screens/pricing_screen.dart';
import '../../features/profile/screens/add_address_screen.dart';
import '../../features/profile/screens/addresses_screen.dart';
import '../../features/profile/screens/my_information_screen.dart';
import '../../features/profile/screens/notifications_screen.dart';
import '../../features/profile/screens/payment_methods_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/refer_earn_screen.dart';
import '../../features/profile/screens/secure_orders_screen.dart';
import '../../features/services/screens/dry_cleaning_screen.dart';
import '../../features/services/screens/ironing_screen.dart';
import '../../features/services/screens/premium_laundry_screen.dart';
import '../../features/services/screens/services_screen.dart';
import '../../features/services/screens/shoe_cleaning_screen.dart';
import '../../features/services/screens/wash_fold_screen.dart';
import '../../features/services/screens/wash_iron_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../features/support/screens/faqs_screen.dart';
import '../../features/support/screens/how_it_works_screen.dart';
import '../../features/support/screens/privacy_screen.dart';
import '../../features/support/screens/support_screen.dart';
import '../../features/support/screens/terms_screen.dart';
import '../../features/wallet/screens/add_money_screen.dart';
import '../../features/wallet/screens/transactions_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import 'app_routes.dart';

/// Riverpod provider so widgets can optionally watch router state.
final appRouterProvider = Provider<GoRouter>((ref) => _buildRouter(ref));

GoRouter _buildRouter(Ref ref) {
  // GoRouter only re-evaluates redirect when refreshListenable fires.
  // We bridge Riverpod → ChangeNotifier so every authProvider change
  // (login, logout, 401 force-logout) immediately triggers a redirect check.
  final notifier = _AuthChangeNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final isInit = auth.isInitialized;

      debugPrint(
        '[ROUTER] redirect: location=${state.matchedLocation} authenticated=$isAuth initialized=$isInit',
      );

      final loc = state.matchedLocation;

      // ── Global auth-initialization barrier ──────────────────────────────
      // On a fresh web load, GoRouter restores whatever URL is already in
      // the browser's address bar (e.g. /home after an F5 refresh) — it
      // does NOT route through `initialLocation` the way a cold native
      // launch does. Without this check, that restored route builds
      // immediately, and any provider it watches can fire an authenticated
      // API call before `authProvider._checkAuthStatus()` (async — it
      // awaits SharedPreferences) has had a chance to load the token and
      // attach it to Dio. That's the startup race that sends requests with
      // no Authorization header.
      //
      // So every route is held at splash until auth state is known, and
      // splash — which already listens for `isInitialized` — carries the
      // originally-requested location forward once it's safe to proceed.
      if (!isInit) {
        if (loc == AppRoutes.splash) return null;
        debugPrint('[ROUTER] Holding at splash - auth not initialized yet');
        return Uri(
          path: AppRoutes.splash,
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      final onAuthRoute =
          loc.startsWith('/auth') || loc == AppRoutes.splash;
      // Terms & Privacy must be readable pre-login (from the auth screen)
      // as well as from within the app, so they never bounce to /auth/login.
      final isPublicRoute =
          loc == AppRoutes.terms || loc == AppRoutes.privacy;

      final isPartner = auth.user?.isDeliveryPartner ?? false;

      if (!isAuth && !onAuthRoute && !isPublicRoute) {
        debugPrint('[ROUTER] Redirecting to login - not authenticated');
        return AppRoutes.login;
      }
      if (isAuth && onAuthRoute && loc != AppRoutes.splash) {
        final target = isPartner ? AppRoutes.deliveryPartnerHome : AppRoutes.home;
        debugPrint('[ROUTER] Redirecting to $target - authenticated on auth route');
        return target;
      }
      // Delivery partners only use their own view; keep customers out of it.
      if (isAuth && !onAuthRoute) {
        final onPartnerRoute = loc.startsWith(AppRoutes.deliveryPartnerHome);
        if (isPartner && !onPartnerRoute) {
          debugPrint('[ROUTER] Redirecting to delivery partner home - partner on wrong route');
          return AppRoutes.deliveryPartnerHome;
        }
        if (!isPartner && onPartnerRoute) {
          debugPrint('[ROUTER] Redirecting to home - customer on partner route');
          return AppRoutes.home;
        }
      }
      debugPrint('[ROUTER] No redirect needed');
      return null;
    },
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Authentication ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (_, __) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (_, __) => const CompleteProfileScreen(),
      ),

      // ── Home ───────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),

      // ── Pickup & Delivery ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.pickupDelivery,
        builder: (_, __) => const PickupDeliveryScreen(),
      ),
      GoRoute(
        path: AppRoutes.pickupSlot,
        builder: (_, __) => const PickupSlotScreen(),
      ),
      GoRoute(
        path: AppRoutes.deliverySlot,
        builder: (_, __) => const DeliverySlotScreen(),
      ),

      // ── Services ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.services,
        builder: (_, __) => const ServicesScreen(),
      ),
      GoRoute(
        path: AppRoutes.ironing,
        builder: (_, __) => const IroningScreen(),
      ),
      GoRoute(
        path: AppRoutes.washFold,
        builder: (_, __) => const WashFoldScreen(),
      ),
      GoRoute(
        path: AppRoutes.washIron,
        builder: (_, __) => const WashIronScreen(),
      ),
      GoRoute(
        path: AppRoutes.dryCleaning,
        builder: (_, __) => const DryCleaningScreen(),
      ),
      GoRoute(
        path: AppRoutes.shoeCleaning,
        builder: (_, __) => const ShoeCleaningScreen(),
      ),
      GoRoute(
        path: AppRoutes.premiumLaundry,
        builder: (_, __) => const PremiumLaundryScreen(),
      ),

      // ── Orders ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.orders,
        builder: (_, __) => const OrdersScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderReview,
        builder: (_, __) => const OrderReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.orderSuccess,
        builder: (_, __) => const OrderSuccessScreen(),
      ),

      // ── Order Tracking ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.trackingConfirmed,
        builder: (_, __) => const OrderConfirmedScreen(),
      ),
      GoRoute(
        path: AppRoutes.trackingPickup,
        builder: (_, __) => const PickupInProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.trackingWashing,
        builder: (_, __) => const WashingScreen(),
      ),
      GoRoute(
        path: AppRoutes.trackingIroning,
        builder: (_, __) => const IroningTrackingScreen(),
      ),
      GoRoute(
        path: AppRoutes.trackingDelivered,
        builder: (_, __) => const DeliveredScreen(),
      ),

      // ── Pricing ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.pricing,
        builder: (_, __) => const PricingScreen(),
      ),

      // ── Wallet ─────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, __) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.addMoney,
        builder: (_, __) => const AddMoneyScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (_, __) => const TransactionsScreen(),
      ),

      // ── Profile ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.myInformation,
        builder: (_, __) => const MyInformationScreen(),
      ),
      GoRoute(
        path: AppRoutes.addresses,
        builder: (_, __) => const AddressesScreen(),
      ),
      GoRoute(
        path: AppRoutes.addAddress,
        builder: (_, __) => const AddAddressScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentMethods,
        builder: (_, __) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: AppRoutes.referEarn,
        builder: (_, __) => const ReferEarnScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.secureOrders,
        builder: (_, __) => const SecureOrdersScreen(),
      ),

      // ── Support ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.support,
        builder: (_, __) => const SupportScreen(),
      ),
      GoRoute(
        path: AppRoutes.faqs,
        builder: (_, __) => const FaqsScreen(),
      ),
      GoRoute(
        path: AppRoutes.howItWorks,
        builder: (_, __) => const HowItWorksScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (_, __) => const TermsScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (_, __) => const PrivacyScreen(),
      ),

      // ── More ───────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.more,
        builder: (_, __) => const MoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.blog,
        builder: (_, __) => const BlogScreen(),
      ),
      GoRoute(
        path: AppRoutes.careInstructions,
        builder: (_, __) => const CareInstructionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sustainability,
        builder: (_, __) => const SustainabilityScreen(),
      ),
      GoRoute(
        path: AppRoutes.contact,
        builder: (_, __) => const ContactScreen(),
      ),

      // ── Delivery Partner ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.deliveryPartnerHome,
        builder: (_, __) => const DeliveryPartnerHomeScreen(),
      ),

      // ── Dev — remove before production ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.devScreens,
        builder: (_, __) => const ScreenNavigator(),
      ),
    ],
  );
}

// Bridges Riverpod authProvider → ChangeNotifier so GoRouter's
// refreshListenable fires on every auth state change (login / logout / 401).
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(authProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
