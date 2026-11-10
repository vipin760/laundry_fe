import 'package:flutter/widgets.dart';

/// Anchor rect for the native share sheet (`share_plus`'s `sharePositionOrigin`).
///
/// On iOS, share_plus rejects the call with
/// `PlatformException(error, sharePositionOrigin: argument must be set ...)`
/// whenever the UIActivityViewController has a popover presentation
/// controller and no (or an off-screen) origin is passed. That has always been
/// true on iPad, and newer iOS versions do it on iPhone too — so every
/// `Share.*` call must pass this.
///
/// Pass the context of the widget that was tapped. The rect is clamped to the
/// screen (share_plus also rejects a rect outside the root view), and falls
/// back to a 1×1 rect at the screen centre if the widget has no usable size.
Rect shareOriginFor(BuildContext context) {
  final screen = Offset.zero & MediaQuery.sizeOf(context);
  final fallback = Rect.fromCenter(center: screen.center, width: 1, height: 1);

  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return fallback;

  final rect = (box.localToGlobal(Offset.zero) & box.size).intersect(screen);
  if (rect.isEmpty) return fallback;
  return rect;
}
