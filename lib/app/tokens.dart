import 'package:flutter/widgets.dart';

import '../widgets/liquid_glass.dart';

/// Colours lifted 1:1 from the "Expense Tracker — Liquid Glass" canvas.
abstract final class AppColors {
  static const accent = Color(0xFF0A84FF);
  static const accentText = Color(0xFF0A6ED1);
  static const background = Color(0xFFEEF1F7);
  static const label = Color(0xFF1C1C1E);
  static const secondaryLabel = Color.fromRGBO(60, 60, 67, 0.78);
  static const secondaryLabelStrong = Color.fromRGBO(60, 60, 67, 0.8);
  static const amountLabel = Color.fromRGBO(60, 60, 67, 0.85);
  static const weekdayLabel = Color.fromRGBO(60, 60, 67, 0.7);
  static const chevron = Color.fromRGBO(60, 60, 67, 0.6);
  static const grabber = Color.fromRGBO(60, 60, 67, 0.3);
  static const separator = Color.fromRGBO(60, 60, 67, 0.14);
  static const fill = Color.fromRGBO(118, 118, 128, 0.12);
  static const placeholder = Color(0xFF757575);
  static const red = Color(0xFFFF3B30);
  static const white = Color(0xFFFFFFFF);

  static const accentWash = Color.fromRGBO(10, 132, 255, 0.10);
  static const accentTint = Color.fromRGBO(10, 132, 255, 0.12);
  static const accentIconTint = Color.fromRGBO(10, 132, 255, 0.14);
  static const accentRing = Color.fromRGBO(10, 132, 255, 0.15);
  static const destructiveTint = Color.fromRGBO(255, 59, 48, 0.14);

  static const sheetScrim = Color.fromRGBO(20, 24, 40, 0.28);
  static const menuScrim = Color.fromRGBO(238, 241, 247, 0.18);
  static const pickerScrim = Color.fromRGBO(238, 241, 247, 0.12);
  static const thoughtsScrim = Color.fromRGBO(226, 231, 242, 0.45);

  static const pillLabel = Color(0xFF3A3A3C);
  static const quietFill = Color.fromRGBO(118, 118, 128, 0.10);
  static const separatorSoft = Color.fromRGBO(60, 60, 67, 0.12);
  static const destructive = Color(0xFFD70015);

  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);
  static const checkRing = Color.fromRGBO(60, 60, 67, 0.35);
  static const checkWell = Color.fromRGBO(255, 255, 255, 0.5);
}

abstract final class AppText {
  static const _display = 'CupertinoSystemDisplay';
  static const tabular = [FontFeature.tabularFigures()];

  static const base = TextStyle(
    inherit: false,
    fontFamily: 'CupertinoSystemText',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.label,
    leadingDistribution: TextLeadingDistribution.even,
    decoration: TextDecoration.none,
  );

  static const largeTitle = TextStyle(
    fontFamily: _display,
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
  );
  static const title1 = TextStyle(
    fontFamily: _display,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.36,
  );
  static const title3 = TextStyle(
    fontFamily: _display,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.38,
  );
  static const eyebrow = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.secondaryLabel,
  );
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 17);
  static const callout = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const subhead = TextStyle(fontSize: 15);
  static const subheadBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const footnote = TextStyle(
    fontSize: 13,
    color: AppColors.secondaryLabel,
  );
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
}

const _white45 = Color.fromRGBO(255, 255, 255, 0.45);
const _white0 = Color.fromRGBO(255, 255, 255, 0);
const _navy = Color.fromRGBO(30, 40, 80, 1);

CssShadow _rim(double alpha) =>
    CssShadow.inset(dy: 1, color: Color.fromRGBO(255, 255, 255, alpha));

/// Glass materials, one per surface in the design.
abstract final class Glass {
  static final menuButton = GlassStyle(
    radius: 22,
    color: const Color.fromRGBO(255, 255, 255, 0.45),
    blur: 24,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.7),
    shadows: [
      _rim(0.9),
      CssShadow(dy: 6, blur: 18, color: _navy.withValues(alpha: 0.12)),
    ],
  );

  static final card = GlassStyle(
    radius: 22,
    color: const Color.fromRGBO(255, 255, 255, 0.42),
    blur: 24,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.65),
    shadows: [
      _rim(0.85),
      CssShadow(dy: 8, blur: 24, color: _navy.withValues(alpha: 0.08)),
    ],
  );

  static final cardRaised = GlassStyle(
    radius: 24,
    color: const Color.fromRGBO(255, 255, 255, 0.62),
    blur: 28,
    saturation: 1.9,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.8),
    shadows: [
      _rim(0.95),
      CssShadow(dy: 14, blur: 34, color: _navy.withValues(alpha: 0.14)),
    ],
  );

  static final chart = GlassStyle(
    radius: 26,
    color: card.color,
    blur: card.blur,
    saturation: card.saturation,
    borderColor: card.borderColor,
    shadows: card.shadows,
  );

  static final menu = GlassStyle(
    radius: 26,
    color: const Color.fromRGBO(255, 255, 255, 0.58),
    blur: 30,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.85),
    shadows: [
      _rim(0.95),
      CssShadow(dy: 20, blur: 50, color: _navy.withValues(alpha: 0.22)),
    ],
  );

  static final sheet = GlassStyle(
    radius: 40,
    color: const Color.fromRGBO(246, 248, 252, 0.72),
    blur: 40,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.85),
    shadows: [
      _rim(0.95),
      const CssShadow(
        dy: -10,
        blur: 40,
        color: Color.fromRGBO(20, 24, 40, 0.18),
      ),
    ],
  );

  static final dateBadge = GlassStyle(
    radius: 29,
    color: const Color.fromRGBO(255, 255, 255, 0.55),
    blur: 24,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.9),
    shadows: [
      _rim(1),
      CssShadow(dy: 6, blur: 18, color: _navy.withValues(alpha: 0.14)),
    ],
  );

  static final pill = GlassStyle(
    radius: 24,
    color: const Color.fromRGBO(255, 255, 255, 0.6),
    blur: 24,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.95),
    shadows: [
      _rim(1),
      CssShadow(dy: 6, blur: 18, color: _navy.withValues(alpha: 0.12)),
    ],
  );

  static final calendar = GlassStyle(
    radius: 30,
    color: const Color.fromRGBO(255, 255, 255, 0.62),
    blur: 34,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.9),
    shadows: [
      _rim(1),
      const CssShadow(
        dy: 24,
        blur: 60,
        color: Color.fromRGBO(20, 30, 70, 0.25),
      ),
    ],
  );

  /// Input rows. Both states carry the same shadow slots so they morph.
  static final field = GlassStyle(
    radius: 20,
    color: const Color.fromRGBO(255, 255, 255, 0.7),
    borderColor: const Color.fromRGBO(255, 255, 255, 0.95),
    shadows: [
      _rim(1),
      CssShadow(dy: 4, blur: 14, color: _navy.withValues(alpha: 0.06)),
      const CssShadow(spread: 4, color: Color.fromRGBO(10, 132, 255, 0)),
    ],
  );

  static final fieldFocused = GlassStyle(
    radius: 20,
    color: const Color.fromRGBO(255, 255, 255, 0.7),
    borderColor: AppColors.accent,
    borderWidth: 1.5,
    shadows: [
      _rim(0),
      CssShadow(dy: 4, blur: 14, color: _navy.withValues(alpha: 0)),
      const CssShadow(spread: 4, color: Color.fromRGBO(10, 132, 255, 0.14)),
    ],
  );

  static GlassStyle primaryButton({double glow = 0.38}) => GlassStyle(
    radius: 28,
    color: AppColors.accent,
    borderColor: _white45,
    shadows: [
      _rim(0.55),
      const CssShadow.inset(
        dy: -8,
        blur: 16,
        color: Color.fromRGBO(0, 0, 0, 0.08),
      ),
      CssShadow(
        dy: 12,
        blur: 28,
        color: AppColors.accent.withValues(alpha: glow),
      ),
    ],
  );

  static final chartBar = GlassStyle(
    radius: 12,
    color: const Color.fromRGBO(10, 132, 255, 0.28),
    borderColor: const Color.fromRGBO(255, 255, 255, 0.7),
    shadows: [
      CssShadow(dy: 6, blur: 16, color: AppColors.accent.withValues(alpha: 0)),
    ],
  );

  static final chartBarSelected = GlassStyle(
    radius: 12,
    color: AppColors.accent,
    borderColor: _white0,
    borderWidth: 0,
    shadows: [
      CssShadow(
        dy: 6,
        blur: 16,
        color: AppColors.accent.withValues(alpha: 0.35),
      ),
    ],
  );

  static final daySelected = GlassStyle(
    radius: 20,
    color: AppColors.accent,
    borderWidth: 0,
    shadows: [
      _rim(0.5),
      CssShadow(
        dy: 6,
        blur: 14,
        color: AppColors.accent.withValues(alpha: 0.35),
      ),
    ],
  );

  /// The lifted "Bazar thoughts" card shown on long press.
  static final thoughtsCard = GlassStyle(
    radius: 28,
    color: const Color.fromRGBO(255, 255, 255, 0.78),
    blur: 36,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.95),
    shadows: [
      _rim(1),
      const CssShadow(
        dy: 30,
        blur: 60,
        color: Color.fromRGBO(20, 30, 70, 0.22),
      ),
    ],
  );

  /// The Bazar Note's "Add an item to buy…" field.
  static final bazarField = GlassStyle(
    radius: 22,
    color: const Color.fromRGBO(255, 255, 255, 0.55),
    blur: 24,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.85),
    shadows: [
      _rim(0.95),
      CssShadow(dy: 8, blur: 24, color: _navy.withValues(alpha: 0.08)),
    ],
  );

  /// The card holding the shopping list.
  static final bazarList = GlassStyle(
    radius: 26,
    color: const Color.fromRGBO(255, 255, 255, 0.45),
    blur: 26,
    saturation: 1.8,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.75),
    shadows: [
      _rim(0.9),
      CssShadow(dy: 10, blur: 28, color: _navy.withValues(alpha: 0.10)),
    ],
  );

  /// "Added to Daily Bag" confirmation.
  static final movedCard = GlassStyle(
    radius: 32,
    color: const Color.fromRGBO(255, 255, 255, 0.8),
    blur: 36,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.95),
    shadows: [
      _rim(1),
      const CssShadow(
        dy: 30,
        blur: 60,
        color: Color.fromRGBO(20, 30, 70, 0.22),
      ),
    ],
  );

  /// The action menu under the thoughts card.
  static final contextMenu = GlassStyle(
    radius: 22,
    color: const Color.fromRGBO(255, 255, 255, 0.7),
    blur: 30,
    saturation: 2,
    borderColor: const Color.fromRGBO(255, 255, 255, 0.9),
    shadows: [
      _rim(1),
      const CssShadow(
        dy: 18,
        blur: 40,
        color: Color.fromRGBO(20, 30, 70, 0.18),
      ),
    ],
  );
}
