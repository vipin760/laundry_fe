# Razorpay Web Integration — Current State

There is exactly one Razorpay integration in this app: **`lib/core/payments/`** (plural), used by every payment screen.

- `app_razorpay.dart` — cross-platform `AppRazorpay` API (mirrors `package:razorpay_flutter`'s own class shape).
- `app_razorpay_mobile.dart` — wraps the native `razorpay_flutter` plugin on Android/iOS.
- `app_razorpay_web.dart` — drives Razorpay's hosted Checkout.js via `dart:js_interop`, since `razorpay_flutter` has no web implementation. Options are marshalled via `JSON.parse(jsonEncode(options))`, which is why this path works correctly where the old one didn't (see below).

**Every payment screen uses it:**
- `lib/features/orders/screens/orders_screen.dart` (order payment)
- `lib/features/orders/screens/order_detail_screen.dart` (order payment)
- `lib/features/wallet/screens/add_money_screen.dart` (wallet top-up)

## What used to exist here (now deleted)

An earlier, separate implementation — `lib/core/payment/` (singular: `payment_handler.dart`, `payment_handler_impl.dart`, `payment_handler_web_impl.dart`, plus unused leftovers `payment_handler_mobile.dart`, `payment_handler_web.dart`, `razorpay_stub.dart`) and `web/razorpay_handler.js` — was built independently and never fully replaced. Its web path used legacy `dart:js`, which does not correctly marshal a Dart `Map` into a real JS object across the interop boundary: `options.key` (and every other field) read as `undefined` on the JS side, so Razorpay's SDK rejected it with `"No key passed"`.

`add_money_screen.dart` was the last screen still wired to it. It's been migrated to `AppRazorpay`, and the entire legacy implementation has been deleted — there is nothing left to avoid touching.

## If you're adding a new payment screen

Use `AppRazorpay` (see `orders_screen.dart` or `add_money_screen.dart` for the pattern): construct it, register `on(EVENT_PAYMENT_SUCCESS, ...)` / `on(EVENT_PAYMENT_ERROR, ...)` in `initState()`, call `.clear()` in `dispose()`, and `.open({...})` with a plain `Map<String, dynamic>` of Razorpay Checkout options. Do not build a second implementation.
