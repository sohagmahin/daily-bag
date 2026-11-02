import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../data/excel_export.dart';
import '../../state/expense_store.dart';
import '../../state/settings_store.dart';
import '../../widgets/entrance.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';
import 'settings_strings.dart';

/// "Settings": theme, language, currency, haptics and the Excel export.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      CupertinoPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _currencyOpen = false;
  String? _toast;
  Timer? _toastTimer;
  final _exportKey = GlobalKey();

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _export() async {
    final days = context.read<ExpenseStore>().days;
    final currency = context.read<SettingsStore>().currency;
    final box = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final file = await ExcelExport.write(days, currency: currency.code);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        sharePositionOrigin: origin,
      ),
    );
    if (!mounted || result.status != ShareResultStatus.success) return;
    Haptics.play(HapticKind.success);
    _toastTimer?.cancel();
    setState(() => _toast = ExcelExport.fileName(DateTime.now()));
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final s = SettingsStrings.of(settings.language);
    final palette = context.palette;
    final safeTop = MediaQuery.paddingOf(context).top;
    final bottom = math.max(MediaQuery.paddingOf(context).bottom, 20.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.statusBar,
      child: Stack(
        children: [
          const Positioned.fill(child: LiquidBackground.settings()),
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(16, safeTop + 11, 16, 120),
              child: Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LiquidPressable(
                        onTap: () => Navigator.of(context).maybePop(),
                        haptic: HapticKind.light,
                        pressedScale: 0.9,
                        borderRadius: 23,
                        semanticLabel: s.back,
                        child: LiquidBox(
                          style: palette.glass.settingsButton,
                          width: 44,
                          height: 44,
                          child: const Center(
                            child: LineIcon(
                              LineGlyph.back,
                              size: 18,
                              strokeWidth: 2.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeWithGlass(
                      child: Semantics(
                        header: true,
                        child: Text(s.title, style: AppText.largeTitle),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionTitle(s.appearance),
                    const SizedBox(height: 10),
                    _Group(
                      children: [
                        _Row(
                          height: 58,
                          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                          tile: const _Tile(
                            color: Color(0xFF5E5CE6),
                            glyph: LineGlyph.moon,
                            strokeWidth: 2.2,
                          ),
                          title: s.theme,
                          trailing: _Segmented<ThemeChoice>(
                            label: s.theme,
                            padding: 11,
                            value: settings.theme,
                            options: {
                              for (final t in ThemeChoice.values)
                                t: s.themeName(t),
                            },
                            onChanged: (t) => settings.theme = t,
                          ),
                        ),
                        _Row(
                          height: 58,
                          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                          tile: const _Tile(
                            color: AppColors.accent,
                            glyph: LineGlyph.globe,
                          ),
                          title: s.language,
                          trailing: _Segmented<AppLanguage>(
                            label: s.language,
                            padding: 12,
                            value: settings.language,
                            options: const {
                              AppLanguage.en: 'English',
                              AppLanguage.bn: 'বাংলা',
                            },
                            onChanged: (l) => settings.language = l,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(s.preferences),
                    const SizedBox(height: 10),
                    _Group(
                      children: [
                        _CurrencyRow(
                          strings: s,
                          open: _currencyOpen,
                          onToggle: () =>
                              setState(() => _currencyOpen = !_currencyOpen),
                          onPick: (c) {
                            settings.currency = c;
                            setState(() => _currencyOpen = false);
                          },
                        ),
                        _Row(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          tile: const _Tile(
                            color: AppColors.orange,
                            glyph: LineGlyph.haptic,
                          ),
                          title: s.haptics,
                          subtitle: s.hapticsSub,
                          trailing: _Switch(
                            label: s.haptics,
                            value: settings.haptics,
                            onChanged: (v) {
                              settings.haptics = v;
                              // Confirms the switch turning on.
                              Haptics.play(HapticKind.selection);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(s.data),
                    const SizedBox(height: 10),
                    _Group(
                      children: [
                        LiquidPressable(
                          key: _exportKey,
                          onTap: _export,
                          haptic: HapticKind.light,
                          pressedScale: 0.98,
                          borderRadius: 26,
                          semanticLabel: '${s.export}, ${s.exportSub}',
                          child: ExcludeSemantics(
                            child: _Row(
                              height: 64,
                              padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
                              tile: const _Tile(
                                color: Color(0xFF1D9E52),
                                glyph: LineGlyph.sheet,
                              ),
                              title: s.export,
                              subtitle: s.exportSub,
                              trailing: Opacity(
                                opacity: 0.55,
                                child: LineIcon(
                                  LineGlyph.download,
                                  size: 18,
                                  strokeWidth: 2.2,
                                  color: palette.label,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FadeWithGlass(
                      child: Text(
                        s.version,
                        textAlign: TextAlign.center,
                        style: palette.footnote,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: bottom + 6,
            child: _Toast(text: _toast == null ? null : s.exported(_toast!)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FadeWithGlass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(), style: context.palette.eyebrow),
        ),
      ),
    );
  }
}

/// A rounded glass card of rows, hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separator = context.palette.separator;
    return LiquidBox(
      style: context.palette.glass.settingsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: SizedBox(height: 1, child: ColoredBox(color: separator)),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.color, required this.glyph, this.strokeWidth = 2});

  final Color color;
  final LineGlyph glyph;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: LineIcon(
        glyph,
        size: 17,
        strokeWidth: strokeWidth,
        color: AppColors.white,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.height,
    required this.padding,
    required this.tile,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final double height;
  final EdgeInsets padding;
  final Widget tile;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            tile,
            const SizedBox(width: 12),
            Expanded(
              child: FadeWithGlass(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(subtitle!, style: palette.footnote),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A pill of options; the chosen one sits on a raised chip.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.label,
    required this.padding,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final double padding;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: label,
      container: true,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: palette.segmentFill,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final MapEntry(key: option, value: text) in options.entries)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: option == value,
                child: LiquidPressable(
                  onTap: option == value ? null : () => onChanged(option),
                  haptic: HapticKind.selection,
                  pressedScale: 0.94,
                  semanticLabel: text,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 30,
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: option == value
                          ? palette.segmentOn
                          : palette.segmentOn.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                          color: Color.fromRGBO(
                            0,
                            0,
                            0,
                            option == value ? 0.12 : 0,
                          ),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: option == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.strings,
    required this.open,
    required this.onToggle,
    required this.onPick,
  });

  final SettingsStrings strings;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Currency> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = context.select<SettingsStore, Currency>((s) => s.currency);
    return AnimatedSize(
      duration: Motion.smooth.duration,
      curve: Motion.smooth,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidPressable(
            onTap: onToggle,
            haptic: HapticKind.light,
            pressedScale: 0.98,
            borderRadius: 26,
            semanticLabel:
                '${strings.currency}, ${current.symbol} ${current.code}',
            child: ExcludeSemantics(
              child: _Row(
                height: 58,
                padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
                tile: const _Tile(
                  color: AppColors.green,
                  glyph: LineGlyph.cash,
                ),
                title: strings.currency,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${current.symbol} ${current.code}',
                      style: AppText.body.copyWith(
                        color: palette.secondaryLabel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: open ? 0.25 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: Opacity(
                        opacity: 0.45,
                        child: LineIcon(
                          LineGlyph.chevronRight,
                          size: 14,
                          strokeWidth: 2.6,
                          color: palette.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Entrance(
                offset: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: palette.segmentFill,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (final c in Currency.values)
                        _CurrencyOption(
                          currency: c,
                          name: strings.currencyName(c),
                          selected: c == current,
                          onTap: () => onPick(c),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: LiquidPressable(
        onTap: onTap,
        haptic: HapticKind.selection,
        pressedScale: 0.97,
        borderRadius: 14,
        semanticLabel: '$name, ${currency.code}',
        child: ExcludeSemantics(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? palette.segmentOn : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    currency.symbol,
                    textAlign: TextAlign.center,
                    style: AppText.headline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: AppText.subhead)),
                const SizedBox(width: 12),
                Text(currency.code, style: palette.footnote),
                if (selected) ...[
                  const SizedBox(width: 12),
                  const LineIcon(
                    LineGlyph.tick,
                    size: 16,
                    strokeWidth: 3,
                    color: AppColors.accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The iOS switch as drawn in the design: green when on, a white knob that
/// overshoots a little as it slides.
class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  static const _overshoot = Cubic(0.34, 1.56, 0.64, 1);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: 51,
          height: 31,
          decoration: BoxDecoration(
            color: value ? AppColors.green : context.palette.segmentFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: _overshoot,
                top: 2,
                left: value ? 22 : 2,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, 3),
                        blurRadius: 8,
                        color: Color.fromRGBO(0, 0, 0, 0.18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.smooth.duration,
      switchInCurve: Motion.smooth,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => GlassFade(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 30),
            child: child,
          ),
        ),
      ),
      child: text == null
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              child: LiquidBox(
                key: ValueKey(text),
                style: context.palette.glass.toast,
                height: 52,
                padding: const EdgeInsets.fromLTRB(12, 0, 18, 0),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const LineIcon(
                        LineGlyph.tick,
                        size: 15,
                        strokeWidth: 3,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FadeWithGlass(
                        child: Text(
                          text!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
