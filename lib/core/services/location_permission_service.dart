import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// ── Brand colours (kept local so this stays a drop-in, dependency-free util) ──
const _kBlue = Color(0xFF1A23CC);
const _kGrey = Color(0xFF6B7280);

/// Centralised "use current location" flow for every screen that offers a
/// GPS button (location selection, checkout address, map picker, add
/// address). Replaces the four near-identical copies of permission-handling
/// code that used to live in each screen.
///
/// Every call site that uses this already has a manual search / manual entry
/// path, so this never needs to dead-end the user — on any failure it either
/// offers a concrete next step (Open Settings) or nudges them to search
/// manually, and always returns `null` so the caller can fall back.
class LocationPermissionService {
  LocationPermissionService._();

  /// Runs the full flow: location-services check → permission check →
  /// permission request → GPS fix.
  ///
  /// - If services are off or permission is permanently denied, shows a
  ///   dialog with an "Open Settings" action (plus a "Search Manually" way
  ///   out).
  /// - If permission is denied, this triggers the real OS "Allow location
  ///   access?" prompt via [Geolocator.requestPermission] — the previous
  ///   implementations in some screens skipped straight to failing.
  /// - Returns `null` on any failure/cancellation; never throws.
  static Future<Position?> getCurrentPosition(
    BuildContext context, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!context.mounted) return null;
        final openSettings = await _showActionDialog(
          context,
          icon: Icons.location_off_rounded,
          title: 'Turn on location services',
          message:
              "Your device's location is switched off. Turn it on to use "
              'your current location, or search for your address instead.',
          actionLabel: 'Open Settings',
        );
        if (openSettings) await Geolocator.openLocationSettings();
        return null;
      }

      LocationPermission perm = await Geolocator.checkPermission();

      // First ask (or re-ask, if the OS still allows it) — this is the real
      // system permission prompt, not just a check.
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!context.mounted) return null;
        final openSettings = await _showActionDialog(
          context,
          icon: Icons.location_disabled_rounded,
          title: 'Location permission needed',
          message:
              "You've permanently denied location access, so we can't ask "
              'again automatically. Enable it from app settings, or search '
              'for your address instead.',
          actionLabel: 'Open Settings',
        );
        if (openSettings) await Geolocator.openAppSettings();
        return null;
      }

      if (perm == LocationPermission.denied) {
        if (context.mounted) {
          _showSnack(
              context, 'Location permission denied — search for your address instead.');
        }
        return null;
      }

      // ── Fresh GPS fix ──────────────────────────────────────────────────
      // LocationAccuracy.high asks for a satellite-grade fix, which can take
      // well over `timeout` indoors, in an urban canyon, or on a cold GPS
      // start right after app launch. Rather than surface that as a hard
      // failure, fall back to a cached fix and only then, plainly explain
      // what to do (open area / retry) instead of a generic error.
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings:
              LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
        );
      } on TimeoutException {
        if (!context.mounted) return null;
        final cached = await _fallbackToLastKnown(context);
        if (cached != null) return cached;
        if (context.mounted) {
          _showSnack(
            context,
            "GPS is taking too long — try moving near a window or outdoors, "
            'or search for your address instead.',
          );
        }
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('[Location] getCurrentPosition failed: $e\n$stackTrace');
      if (!context.mounted) return null;
      final cached = await _fallbackToLastKnown(context);
      if (cached != null) return cached;
      if (context.mounted) {
        _showSnack(context, 'Could not get your location. Try searching instead.');
      }
      return null;
    }
  }

  /// Cached fix from the OS (instant, no GPS wait). Used when a fresh
  /// high-accuracy fix times out or errors — a slightly-stale location the
  /// user can still confirm/adjust on the map beats a dead-end error.
  static Future<Position?> _fallbackToLastKnown(BuildContext context) async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      if (context.mounted) {
        _showSnack(
          context,
          'Using your last known location — move the pin to fine-tune it.',
        );
      }
      return last;
    } catch (e, stackTrace) {
      debugPrint('[Location] getLastKnownPosition failed: $e\n$stackTrace');
      return null;
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  static Future<bool> _showActionDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Icon(icon, color: _kBlue, size: 32),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: _kGrey),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Search Manually',
              style: TextStyle(color: _kGrey, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}
