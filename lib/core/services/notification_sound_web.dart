import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Plays the bundled notification chime via an HTML `<audio>` element.
///
/// Browsers have no "default system notification sound" hook the way
/// Android/iOS do, so Flutter Web needs an actual bundled audio asset. The
/// asset is declared under `assets/sounds/` in pubspec.yaml, which Flutter's
/// web asset bundler serves under the `assets/assets/...` path (same
/// doubling as any other bundled asset on web).
void playNotificationSound() {
  try {
    final audio = web.HTMLAudioElement()
      ..src = 'assets/assets/sounds/notification.mp3'
      ..volume = 0.6;

    // play() returns a JS Promise that rejects if the browser's autoplay
    // policy blocks it (e.g. no prior user gesture on the page yet). The
    // notification itself has already been delivered by this point — sound
    // is a best-effort enhancement, so a rejected promise is swallowed
    // rather than surfaced anywhere.
    audio.play().toDart.catchError((_) => null);
  } catch (_) {
    // Never let a sound-playback failure affect notification delivery.
  }
}
