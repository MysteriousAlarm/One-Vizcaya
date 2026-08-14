import 'package:flutter/material.dart';

/// Colour-contrast helpers for the municipality theming.
///
/// Each municipality has an accent (`appBarColor`) that ranges from very dark
/// (Bambang maroon `#800000`, Bayombong dark green `#006400`) to lighter tones.
/// Those accents read fine as text on a light surface, but become unreadable
/// when placed as a font/icon colour on a dark surface (dark mode, dark cards).
/// These helpers keep the accent's identity while guaranteeing it stays legible
/// against whatever background it sits on.
class ColorUtils {
  ColorUtils._();

  /// Black or white — whichever is readable **on top of** [background].
  /// Use for text/icons drawn over a municipality-coloured fill (app bars,
  /// filled buttons, chips).
  static Color readableTextOn(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  /// Returns [accent] adjusted so it is legible when used **as** a font/icon
  /// colour on the current surface [brightness].
  ///
  /// - On a **dark** surface a too-dark accent is lightened (maroon → soft red,
  ///   dark green → soft green) so it no longer disappears into the background.
  /// - On a **light** surface a too-light accent is darkened so it does not wash
  ///   out. Accents already in the legible range are returned unchanged, so the
  ///   municipality's colour identity is preserved wherever possible.
  static Color readableAccent(Color accent, Brightness brightness) {
    final hsl = HSLColor.fromColor(accent);
    if (brightness == Brightness.dark) {
      if (hsl.lightness < 0.62) {
        return hsl
            .withLightness(0.72)
            .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
            .toColor();
      }
    } else {
      if (hsl.lightness > 0.62) {
        return hsl.withLightness(0.34).toColor();
      }
    }
    return accent;
  }

  /// Convenience: [readableAccent] resolved from a [BuildContext]'s theme.
  static Color readableAccentOf(BuildContext context, Color accent) =>
      readableAccent(accent, Theme.of(context).brightness);
}
