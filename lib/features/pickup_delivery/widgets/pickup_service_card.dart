import 'dart:math' as math;

import 'package:flutter/material.dart';

const _kBlue = Color(0xFF2453FF);

/// Service card used on the Pickup & Delivery screen.
///
/// Presentation only — cart state and actions are passed in by the caller.
/// Cards share a minimum height ([minHeight]) so a list looks even, and grow
/// when the text needs more room (long names, large system font). The ADD,
/// REMOVE and loading states occupy exactly the same box, so toggling never
/// moves the text or changes the card height.
class PickupServiceCard extends StatelessWidget {
  const PickupServiceCard({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.selected,
    required this.pending,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;

  /// Free text from the catalogue. A trailing "Note : …" part is shown as its
  /// own block so it can't be cut off by a long price line.
  final String description;
  final String? imageUrl;
  final IconData fallbackIcon;
  final bool selected;
  final bool pending;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const double minHeight = 104;

  /// Splits "Prices start from 89\nNote : Minimum 4kg" into body and note.
  static (String, String?) splitNote(String text) {
    final match = RegExp(r'\bnote\s*:', caseSensitive: false).firstMatch(text);
    if (match == null) return (text.trim(), null);
    return (text.substring(0, match.start).trim(), text.substring(match.start).trim());
  }

  @override
  Widget build(BuildContext context) {
    final (body, note) = splitNote(description);
    // How much the user has enlarged system text (1.0 = default).
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0F1FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      // Painted on top, so the thicker "selected" border takes no layout space.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _kBlue : const Color(0xFFE9EDFA),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          final imageWidth = narrow ? 72.0 : 80.0;
          final buttonScale = textScale.clamp(1.0, 1.4);
          final buttonSize = Size((narrow ? 76.0 : 80.0) * buttonScale, 36.0 * buttonScale);
          // Width left for text if the button sits beside it. When that gets
          // too tight (small phone and/or large font) the button moves below.
          final besideWidth = constraints.maxWidth - imageWidth - buttonSize.width - 28;
          final stacked = besideWidth < 110 * math.max(1.0, textScale);

          final text = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A1645),
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                _Detail(body),
              ],
              if (note != null) ...[
                const SizedBox(height: 2),
                _Detail(note),
              ],
            ],
          );

          final action = _ActionButton(
            size: buttonSize,
            selected: selected,
            pending: pending,
            onAdd: onAdd,
            onRemove: onRemove,
          );

          // The image is positioned, so it stretches to whatever height the
          // content needs without influencing that height itself.
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: imageWidth,
                child: _ServiceImage(
                  url: imageUrl,
                  icon: fallbackIcon,
                  selected: selected,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: minHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(imageWidth + 10, 12, 10, 12),
                  child: stacked
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            text,
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerRight, child: action),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: text),
                            const SizedBox(width: 8),
                            action,
                          ],
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

class _Detail extends StatelessWidget {
  const _Detail(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        height: 1.4,
        color: Color(0xFF6B7280),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Fixed-width image area. The picture is contained (never stretched or
/// cropped) and centred on white, which matches the catalogue photos so no
/// bands show around them. A tinted icon is shown if there is no image or it
/// fails to load.
class _ServiceImage extends StatelessWidget {
  const _ServiceImage({required this.url, required this.icon, required this.selected});
  final String? url;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: selected ? _kBlue.withAlpha(28) : const Color(0xFFEEF0FF),
      child: Center(child: Icon(icon, color: _kBlue, size: 28)),
    );
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return fallback;
    return ColoredBox(
      color: Colors.white,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// ADD, REMOVE or a spinner — all inside the same [size].
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.size,
    required this.selected,
    required this.pending,
    required this.onAdd,
    required this.onRemove,
  });

  final Size size;
  final bool selected;
  final bool pending;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  static const _red = Color(0xFFE53E3E);

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return SizedBox.fromSize(
        size: size,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? onRemove : onAdd,
        child: Container(
          width: size.width,
          height: size.height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : _kBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _red : _kBlue, width: 1.5),
          ),
          // Shrinks rather than wraps if the label can't fit.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: selected
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
                      SizedBox(width: 4),
                      Text(
                        'REMOVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _red,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'ADD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
