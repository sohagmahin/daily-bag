import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/liquid_glass.dart';

/// Colours that read the same in light and dark. Everything else lives on
/// [Palette], looked up with `context.palette`.
abstract final class AppColors {
  static const accent = Color(0xFF0A84FF);
  static const white = Color(0xFFFFFFFF);
  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);
}

abstract final class AppText {
  static const _display = 'CupertinoSystemDisplay';
  static const tabular = [FontFeature.tabularFigures()];

  /// The root style. Its colour is the light label; the app replaces it
  /// with the palette's label (see [Palette.text]).
  static const base = TextStyle(
    inherit: false,
    fontFamily: 'CupertinoSystemText',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: Color(0xFF1C1C1E),
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
  );
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 17);
  static const callout = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  static const subhead = TextStyle(fontSize: 15);
  static const subheadBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const footnote = TextStyle(fontSize: 13);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
}

Color _white(double a) => Color.fromRGBO(255, 255, 255, a);
Color _black(double a) => Color.fromRGBO(0, 0, 0, a);
Color _navy(double a) => Color.fromRGBO(30, 40, 80, a);
Color _ink(double a) => Color.fromRGBO(20, 30, 70, a);
Color _slate(double a) => Color.fromRGBO(20, 30, 60, a);
Color _greyLabel(double a) => Color.fromRGBO(60, 60, 67, a);
Color _paleLabel(double a) => Color.fromRGBO(235, 235, 245, a);
Color _greyFill(double a) => Color.fromRGBO(118, 118, 128, a);
Color _blue(double a) => Color.fromRGBO(10, 132, 255, a);

CssShadow _rim(double alpha) => CssShadow.inset(dy: 1, color: _white(alpha));

/// Every colour and glass material that changes between light and dark,
/// lifted 1:1 from the "Daily Bag — Liquid Glass" canvas and its dark row.
@immutable
class Palette {
  const Palette._({
    required this.isDark,
    required this.background,
    required this.settingsBackground,
    required this.blobOpacity,
    required this.label,
    required this.secondaryLabel,
    required this.secondaryLabelStrong,
    required this.amountLabel,
    required this.weekdayLabel,
    required this.chevron,
    required this.grabber,
    required this.separator,
    required this.separatorSoft,
    required this.fill,
    required this.quietFill,
    required this.placeholder,
    required this.red,
    required this.destructive,
    required this.destructiveTint,
    required this.accentText,
    required this.menuCheck,
    required this.accentWash,
    required this.accentTint,
    required this.accentIconTint,
    required this.accentRing,
    required this.sheetScrim,
    required this.menuScrim,
    required this.pickerScrim,
    required this.thoughtsScrim,
    required this.pillLabel,
    required this.checkRing,
    required this.checkWell,
    required this.badgeRing,
    required this.homeFade,
    required this.bazarFade,
    required this.segmentFill,
    required this.segmentOn,
    required this.panelEdge,
    required this.optionRing,
    required this.glass,
  });

  final bool isDark;
  final Color background;
  final Color settingsBackground;

  /// Overrides each colour field's own opacity; null keeps the light values.
  final double? blobOpacity;

  final Color label;
  final Color secondaryLabel;
  final Color secondaryLabelStrong;
  final Color amountLabel;
  final Color weekdayLabel;
  final Color chevron;
  final Color grabber;
  final Color separator;
  final Color separatorSoft;
  final Color fill;
  final Color quietFill;
  final Color placeholder;
  final Color red;
  final Color destructive;
  final Color destructiveTint;
  final Color accentText;

  /// The tick beside the chosen menu option.
  final Color menuCheck;
  final Color accentWash;
  final Color accentTint;
  final Color accentIconTint;
  final Color accentRing;
  final Color sheetScrim;
  final Color menuScrim;
  final Color pickerScrim;
  final Color thoughtsScrim;
  final Color pillLabel;
  final Color checkRing;
  final Color checkWell;
  final Color badgeRing;

  /// Opacity of the canvas colour where content fades under the button.
  final double homeFade;
  final double bazarFade;

  /// Settings' segmented controls: the track and the chosen option.
  final Color segmentFill;
  final Color segmentOn;

  /// Settings' currency panel: its rim and the empty radio rings.
  final Color panelEdge;
  final Color optionRing;
  final GlassSet glass;

  static final light = Palette._(
    isDark: false,
    background: const Color(0xFFEEF1F7),
    settingsBackground: const Color(0xFFEEF1F7),
    blobOpacity: null,
    label: const Color(0xFF1C1C1E),
    secondaryLabel: _greyLabel(0.78),
    secondaryLabelStrong: _greyLabel(0.8),
    amountLabel: _greyLabel(0.85),
    weekdayLabel: _greyLabel(0.7),
    chevron: _greyLabel(0.6),
    grabber: _greyLabel(0.3),
    separator: _greyLabel(0.14),
    separatorSoft: _greyLabel(0.12),
    fill: _greyFill(0.12),
    quietFill: _greyFill(0.10),
    placeholder: const Color(0xFF757575),
    red: const Color(0xFFFF3B30),
    destructive: const Color(0xFFD70015),
    destructiveTint: const Color.fromRGBO(255, 59, 48, 0.14),
    accentText: const Color(0xFF0A6ED1),
    menuCheck: AppColors.accent,
    accentWash: _blue(0.10),
    accentTint: _blue(0.12),
    accentIconTint: _blue(0.14),
    accentRing: _blue(0.15),
    sheetScrim: const Color.fromRGBO(20, 24, 40, 0.28),
    menuScrim: const Color.fromRGBO(238, 241, 247, 0.18),
    pickerScrim: const Color.fromRGBO(238, 241, 247, 0.12),
    thoughtsScrim: const Color.fromRGBO(226, 231, 242, 0.45),
    pillLabel: const Color(0xFF3A3A3C),
    checkRing: _greyLabel(0.35),
    checkWell: _white(0.5),
    badgeRing: _white(0.95),
    homeFade: 0.7,
    bazarFade: 0.8,
    segmentFill: _greyFill(0.13),
    segmentOn: _white(0.96),
    panelEdge: _white(0.6),
    optionRing: _greyLabel(0.28),
    glass: GlassSet._light(),
  );

  static final dark = Palette._(
    isDark: true,
    background: const Color(0xFF07080C),
    settingsBackground: const Color(0xFF0B0C10),
    blobOpacity: 0.3,
    label: const Color(0xFFF5F5F7),
    secondaryLabel: _paleLabel(0.64),
    secondaryLabelStrong: _paleLabel(0.66),
    amountLabel: _paleLabel(0.78),
    weekdayLabel: _paleLabel(0.6),
    chevron: _paleLabel(0.5),
    grabber: _paleLabel(0.3),
    separator: const Color.fromRGBO(84, 84, 88, 0.6),
    separatorSoft: const Color.fromRGBO(84, 84, 88, 0.5),
    fill: _greyFill(0.26),
    quietFill: _greyFill(0.26),
    placeholder: _paleLabel(0.36),
    red: const Color(0xFFFF6961),
    destructive: const Color(0xFFFF6961),
    destructiveTint: const Color.fromRGBO(255, 105, 97, 0.18),
    accentText: const Color(0xFF4DA3FF),
    menuCheck: const Color(0xFF4DA3FF),
    accentWash: _blue(0.2),
    accentTint: _blue(0.22),
    accentIconTint: _blue(0.22),
    accentRing: _blue(0.22),
    sheetScrim: _black(0.5),
    menuScrim: _black(0.3),
    pickerScrim: _black(0.25),
    thoughtsScrim: _black(0.45),
    pillLabel: const Color(0xFFE5E5EA),
    checkRing: _paleLabel(0.35),
    checkWell: _white(0.04),
    badgeRing: const Color(0xFF1C1D24),
    homeFade: 0.85,
    bazarFade: 0.88,
    segmentFill: _greyFill(0.26),
    segmentOn: const Color.fromRGBO(110, 110, 118, 0.85),
    panelEdge: _white(0.06),
    optionRing: _paleLabel(0.3),
    glass: GlassSet._dark(),
  );

  /// [AppText.base] in this palette's label colour.
  TextStyle get text => AppText.base.copyWith(color: label);
  TextStyle get eyebrow => AppText.eyebrow.copyWith(color: secondaryLabel);
  TextStyle get footnote => AppText.footnote.copyWith(color: secondaryLabel);

  SystemUiOverlayStyle get statusBar =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}

/// Hands the current [Palette] down the tree.
class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});

  final Palette palette;

  static Palette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ??
      Palette.light;

  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      oldWidget.palette != palette;
}

extension PaletteContext on BuildContext {
  Palette get palette => PaletteScope.of(this);
}

/// Glass materials, one per surface in the design.
@immutable
class GlassSet {
  const GlassSet._({
    required this.menuButton,
    required this.card,
    required this.cardRaised,
    required this.menu,
    required this.sheet,
    required this.dateBadge,
    required this.pill,
    required this.calendar,
    required this.field,
    required this.fieldFocused,
    required this.chartBar,
    required this.chartBarSelected,
    required this.daySelected,
    required this.thoughtsCard,
    required this.contextMenu,
    required this.bazarField,
    required this.bazarList,
    required this.movedCard,
    required this.settingsCard,
    required this.settingsButton,
    required this.toast,
    required double primaryBorder,
    required double primaryRim,
  }) : _primaryBorder = primaryBorder,
       _primaryRim = primaryRim;

  final GlassStyle menuButton;
  final GlassStyle card;
  final GlassStyle cardRaised;
  final GlassStyle menu;
  final GlassStyle sheet;
  final GlassStyle dateBadge;
  final GlassStyle pill;
  final GlassStyle calendar;

  /// Input rows. Both states carry the same shadow slots so they morph.
  final GlassStyle field;
  final GlassStyle fieldFocused;
  final GlassStyle chartBar;
  final GlassStyle chartBarSelected;
  final GlassStyle daySelected;

  /// The lifted "Bazar thoughts" card shown on long press.
  final GlassStyle thoughtsCard;

  /// The action menu under the thoughts card.
  final GlassStyle contextMenu;

  /// The Bazar Note's "Add an item to buy…" field.
  final GlassStyle bazarField;

  /// The card holding the shopping list.
  final GlassStyle bazarList;

  /// "Added to Daily Bag" confirmation.
  final GlassStyle movedCard;

  /// Settings' grouped rows, its back button, and the export toast.
  final GlassStyle settingsCard;
  final GlassStyle settingsButton;
  final GlassStyle toast;

  final double _primaryBorder;
  final double _primaryRim;

  GlassStyle get chart => card.copyWith(radius: 26);

  GlassStyle primaryButton({double glow = 0.38}) => GlassStyle(
    radius: 28,
    color: AppColors.accent,
    borderColor: _white(_primaryBorder),
    shadows: [
      _rim(_primaryRim),
      CssShadow.inset(dy: -8, blur: 16, color: _black(0.08)),
      CssShadow(
        dy: 12,
        blur: 28,
        color: AppColors.accent.withValues(alpha: glow),
      ),
    ],
  );

  static GlassStyle _chartBarSelected() => GlassStyle(
    radius: 12,
    color: AppColors.accent,
    borderColor: _white(0),
    borderWidth: 0,
    shadows: [
      CssShadow(
        dy: 6,
        blur: 16,
        color: AppColors.accent.withValues(alpha: 0.35),
      ),
    ],
  );

  static GlassStyle _daySelected() => GlassStyle(
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

  static GlassStyle _field(
    Color color,
    Color border,
    double rim,
    Color shadow,
  ) => GlassStyle(
    radius: 20,
    color: color,
    borderColor: border,
    shadows: [
      _rim(rim),
      CssShadow(dy: 4, blur: 14, color: shadow),
      CssShadow(spread: 4, color: _blue(0)),
    ],
  );

  static GlassStyle _fieldFocused(Color color, double halo) => GlassStyle(
    radius: 20,
    color: color,
    borderColor: AppColors.accent,
    borderWidth: 1.5,
    shadows: [
      _rim(0),
      CssShadow(dy: 4, blur: 14, color: _navy(0)),
      CssShadow(spread: 4, color: _blue(halo)),
    ],
  );

  factory GlassSet._light() => GlassSet._(
    menuButton: GlassStyle(
      radius: 22,
      color: _white(0.45),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.7),
      shadows: [
        _rim(0.9),
        CssShadow(dy: 6, blur: 18, color: _navy(0.12)),
      ],
    ),
    card: GlassStyle(
      radius: 22,
      color: _white(0.42),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.65),
      shadows: [
        _rim(0.85),
        CssShadow(dy: 8, blur: 24, color: _navy(0.08)),
      ],
    ),
    cardRaised: GlassStyle(
      radius: 24,
      color: _white(0.62),
      blur: 28,
      saturation: 1.9,
      borderColor: _white(0.8),
      shadows: [
        _rim(0.95),
        CssShadow(dy: 14, blur: 34, color: _navy(0.14)),
      ],
    ),
    menu: GlassStyle(
      radius: 26,
      color: _white(0.58),
      blur: 30,
      saturation: 2,
      borderColor: _white(0.85),
      shadows: [
        _rim(0.95),
        CssShadow(dy: 20, blur: 50, color: _navy(0.22)),
      ],
    ),
    sheet: GlassStyle(
      radius: 40,
      color: const Color.fromRGBO(246, 248, 252, 0.72),
      blur: 40,
      saturation: 2,
      borderColor: _white(0.85),
      shadows: [
        _rim(0.95),
        const CssShadow(
          dy: -10,
          blur: 40,
          color: Color.fromRGBO(20, 24, 40, 0.18),
        ),
      ],
    ),
    dateBadge: GlassStyle(
      radius: 29,
      color: _white(0.55),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.9),
      shadows: [
        _rim(1),
        CssShadow(dy: 6, blur: 18, color: _navy(0.14)),
      ],
    ),
    pill: GlassStyle(
      radius: 24,
      color: _white(0.6),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.95),
      shadows: [
        _rim(1),
        CssShadow(dy: 6, blur: 18, color: _navy(0.12)),
      ],
    ),
    calendar: GlassStyle(
      radius: 30,
      color: _white(0.62),
      blur: 34,
      saturation: 2,
      borderColor: _white(0.9),
      shadows: [
        _rim(1),
        CssShadow(dy: 24, blur: 60, color: _ink(0.25)),
      ],
    ),
    field: _field(_white(0.7), _white(0.95), 1, _navy(0.06)),
    fieldFocused: _fieldFocused(_white(0.7), 0.14),
    chartBar: GlassStyle(
      radius: 12,
      color: _blue(0.28),
      borderColor: _white(0.7),
      shadows: [CssShadow(dy: 6, blur: 16, color: _blue(0))],
    ),
    chartBarSelected: _chartBarSelected(),
    daySelected: _daySelected(),
    thoughtsCard: GlassStyle(
      radius: 28,
      color: _white(0.78),
      blur: 36,
      saturation: 2,
      borderColor: _white(0.95),
      shadows: [
        _rim(1),
        CssShadow(dy: 30, blur: 60, color: _ink(0.22)),
      ],
    ),
    contextMenu: GlassStyle(
      radius: 22,
      color: _white(0.7),
      blur: 30,
      saturation: 2,
      borderColor: _white(0.9),
      shadows: [
        _rim(1),
        CssShadow(dy: 18, blur: 40, color: _ink(0.18)),
      ],
    ),
    bazarField: GlassStyle(
      radius: 22,
      color: _white(0.55),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.85),
      shadows: [
        _rim(0.95),
        CssShadow(dy: 8, blur: 24, color: _navy(0.08)),
      ],
    ),
    bazarList: GlassStyle(
      radius: 26,
      color: _white(0.45),
      blur: 26,
      saturation: 1.8,
      borderColor: _white(0.75),
      shadows: [
        _rim(0.9),
        CssShadow(dy: 10, blur: 28, color: _navy(0.10)),
      ],
    ),
    movedCard: GlassStyle(
      radius: 32,
      color: _white(0.8),
      blur: 36,
      saturation: 2,
      borderColor: _white(0.95),
      shadows: [
        _rim(1),
        CssShadow(dy: 30, blur: 60, color: _ink(0.22)),
      ],
    ),
    settingsCard: GlassStyle(
      radius: 26,
      color: _white(0.5),
      blur: 26,
      saturation: 1.8,
      borderColor: _white(0.78),
      shadows: [
        _rim(0.9),
        CssShadow(dy: 8, blur: 24, color: _slate(0.08)),
      ],
    ),
    settingsButton: GlassStyle(
      radius: 22,
      color: _white(0.5),
      blur: 24,
      saturation: 1.8,
      borderColor: _white(0.78),
      shadows: [
        _rim(0.9),
        CssShadow(dy: 6, blur: 18, color: _slate(0.12)),
      ],
    ),
    toast: GlassStyle(
      radius: 26,
      color: _white(0.82),
      blur: 30,
      saturation: 2,
      borderColor: _white(0.78),
      shadows: [
        _rim(0.9),
        CssShadow(dy: 16, blur: 36, color: _slate(0.22)),
      ],
    ),
    primaryBorder: 0.45,
    primaryRim: 0.55,
  );

  factory GlassSet._dark() {
    const glass = Color.fromRGBO(38, 40, 52, 0.52);
    const glassStrong = Color.fromRGBO(48, 50, 64, 0.66);
    const pop = Color.fromRGBO(44, 46, 58, 0.82);
    const chip = Color.fromRGBO(58, 60, 74, 0.6);
    const fieldColor = Color.fromRGBO(58, 60, 74, 0.55);
    return GlassSet._(
      menuButton: GlassStyle(
        radius: 22,
        color: glass,
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.10),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 6, blur: 18, color: _black(0.35)),
        ],
      ),
      card: GlassStyle(
        radius: 22,
        color: glass,
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.10),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 8, blur: 24, color: _black(0.35)),
        ],
      ),
      cardRaised: GlassStyle(
        radius: 24,
        color: glassStrong,
        blur: 28,
        saturation: 1.9,
        borderColor: _white(0.16),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 14, blur: 34, color: _black(0.5)),
        ],
      ),
      menu: GlassStyle(
        radius: 26,
        color: pop,
        blur: 30,
        saturation: 2,
        borderColor: _white(0.14),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 20, blur: 50, color: _black(0.55)),
        ],
      ),
      sheet: GlassStyle(
        radius: 40,
        color: const Color.fromRGBO(26, 27, 34, 0.82),
        blur: 40,
        saturation: 2,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: -10, blur: 40, color: _black(0.25)),
        ],
      ),
      dateBadge: GlassStyle(
        radius: 29,
        color: chip,
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 6, blur: 18, color: _black(0.3)),
        ],
      ),
      pill: GlassStyle(
        radius: 24,
        color: chip,
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 6, blur: 18, color: _black(0.3)),
        ],
      ),
      calendar: GlassStyle(
        radius: 30,
        color: const Color.fromRGBO(44, 46, 58, 0.85),
        blur: 34,
        saturation: 2,
        borderColor: _white(0.14),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 24, blur: 60, color: _black(0.6)),
        ],
      ),
      field: _field(fieldColor, _white(0.12), 0.10, _black(0.3)),
      fieldFocused: _fieldFocused(fieldColor, 0.18),
      chartBar: GlassStyle(
        radius: 12,
        color: _blue(0.32),
        borderColor: _white(0.10),
        shadows: [CssShadow(dy: 6, blur: 16, color: _blue(0))],
      ),
      chartBarSelected: _chartBarSelected(),
      daySelected: _daySelected(),
      thoughtsCard: GlassStyle(
        radius: 28,
        color: pop,
        blur: 36,
        saturation: 2,
        borderColor: _white(0.16),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 30, blur: 60, color: _black(0.6)),
        ],
      ),
      contextMenu: GlassStyle(
        radius: 22,
        color: pop,
        blur: 30,
        saturation: 2,
        borderColor: _white(0.16),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 18, blur: 40, color: _black(0.6)),
        ],
      ),
      bazarField: GlassStyle(
        radius: 22,
        color: glassStrong,
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 8, blur: 24, color: _black(0.35)),
        ],
      ),
      bazarList: GlassStyle(
        radius: 26,
        color: glass,
        blur: 26,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 10, blur: 28, color: _black(0.35)),
        ],
      ),
      movedCard: GlassStyle(
        radius: 32,
        color: const Color.fromRGBO(44, 46, 58, 0.85),
        blur: 36,
        saturation: 2,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 30, blur: 60, color: _black(0.6)),
        ],
      ),
      settingsCard: GlassStyle(
        radius: 26,
        color: const Color.fromRGBO(44, 46, 58, 0.55),
        blur: 26,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 8, blur: 24, color: _slate(0.08)),
        ],
      ),
      settingsButton: GlassStyle(
        radius: 22,
        color: const Color.fromRGBO(44, 46, 58, 0.55),
        blur: 24,
        saturation: 1.8,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 6, blur: 18, color: _slate(0.12)),
        ],
      ),
      toast: GlassStyle(
        radius: 26,
        color: const Color.fromRGBO(52, 54, 66, 0.8),
        blur: 30,
        saturation: 2,
        borderColor: _white(0.12),
        shadows: [
          _rim(0.10),
          CssShadow(dy: 16, blur: 36, color: _slate(0.22)),
        ],
      ),
      primaryBorder: 0.35,
      primaryRim: 0.5,
    );
  }
}
