import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../models/expense.dart';
import '../../state/bazar_store.dart';
import '../../state/expense_store.dart';
import '../../widgets/entrance.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_background.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_pressable.dart';
import 'moved_card.dart';

final _priceFormat = [
  // A Bangla keyboard types ০-৯; amounts are stored with ASCII digits.
  TextInputFormatter.withFunction(
    (_, value) => value.copyWith(text: asciiDigits(value.text)),
  ),
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// "Bazar Note": the shopping list. Items are ticked off with a price as
/// they are bought, then "Move to Daily Bag" files them under today.
/// Pops with the day they were added to, if any.
class BazarNoteScreen extends StatefulWidget {
  const BazarNoteScreen({super.key});

  static Route<DateTime?> route() =>
      CupertinoPageRoute<DateTime?>(builder: (_) => const BazarNoteScreen());

  @override
  State<BazarNoteScreen> createState() => _BazarNoteScreenState();
}

class _BazarNoteScreenState extends State<BazarNoteScreen> {
  // 56px button + 1px border top and bottom, as the design renders it.
  static const _buttonHeight = 58.0;

  final _scroll = ScrollController();
  final _draft = TextEditingController();
  final _draftFocus = FocusNode();

  /// Rows added while this screen is open rise in; the rest are just there.
  final _fresh = <int>{};

  @override
  void dispose() {
    _scroll.dispose();
    _draft.dispose();
    _draftFocus.dispose();
    super.dispose();
  }

  void _add() {
    final item = context.read<BazarStore>().add(_draft.text);
    if (item == null) return;
    Haptics.play(HapticKind.light);
    setState(() => _fresh.add(item.id));
    _draft.clear();
    _draftFocus.requestFocus();
  }

  Future<void> _move() async {
    FocusScope.of(context).unfocus();
    final move = context.read<BazarStore>().moveBought(
      context.read<ExpenseStore>(),
      date: DateTime.now(),
    );
    if (move == null) return;
    Haptics.play(HapticKind.success);
    final view = await Navigator.of(context).push(MovedCard.route(move));
    if (mounted && view == true) Navigator.of(context).pop(move.date);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final buttonInset = math.max(mq.padding.bottom, 20.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.palette.statusBar,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            const Positioned.fill(child: LiquidBackground.bazarNote()),
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  safeTop + 11,
                  16,
                  // Clears the total line and button; the keyboard, when up.
                  math.max(
                    buttonInset + _buttonHeight + 64,
                    mq.viewInsets.bottom + 16,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entrance(
                      child: _Header(
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Entrance(
                      delay: const Duration(milliseconds: 60),
                      child: _DraftField(
                        controller: _draft,
                        focusNode: _draftFocus,
                        onAdd: _add,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Entrance(
                      delay: const Duration(milliseconds: 120),
                      child: _ItemList(fresh: _fresh),
                    ),
                    const SizedBox(height: 14),
                    Entrance(
                      delay: Duration(milliseconds: 160),
                      child: FadeWithGlass(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            tr.bazarNoteHelp,
                            style: TextStyle(
                              fontSize: 13,
                              height: 18 / 13,
                              color: context.palette.secondaryLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content scrolling under the status bar fades into the canvas.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: safeTop + 20,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _scroll,
                  builder: (context, _) {
                    final shown = _scroll.hasClients
                        ? (_scroll.offset / 24).clamp(0.0, 1.0)
                        : 0.0;
                    return Opacity(
                      opacity: shown,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              context.palette.background.withValues(
                                alpha: 0.85,
                              ),
                              context.palette.background.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.palette.background.withValues(alpha: 0),
                        context.palette.background.withValues(
                          alpha: context.palette.bazarFade,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: buttonInset,
              child: Entrance(
                delay: const Duration(milliseconds: 220),
                offset: 40,
                child: _MoveBar(onMove: _move),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BazarStore>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            LiquidPressable(
              onTap: onBack,
              haptic: HapticKind.light,
              pressedScale: 0.9,
              borderRadius: 23,
              semanticLabel: tr.backToDailyBag,
              child: LiquidBox(
                style: context.palette.glass.menuButton,
                width: 44,
                height: 44,
                child: const Center(
                  child: LineIcon(LineGlyph.back, size: 18, strokeWidth: 2.6),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FadeWithGlass(
              child: Text(
                tr.shoppingList.toUpperCase(),
                style: context.palette.eyebrow,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FadeWithGlass(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(tr.bazarNote, style: AppText.largeTitle),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  tr.progress(store.boughtCount, store.items.length),
                  style: AppText.subhead.copyWith(
                    color: context.palette.secondaryLabelStrong,
                    fontFeatures: AppText.tabular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LiquidBox(
      style: context.palette.glass.bazarField,
      height: 52,
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: tr.newItem,
              child: CupertinoTextField.borderless(
                controller: controller,
                focusNode: focusNode,
                placeholder: tr.addItemPlaceholder,
                padding: EdgeInsets.zero,
                style: context.palette.text,
                placeholderStyle: AppText.base.copyWith(
                  color: context.palette.placeholder,
                ),
                cursorColor: AppColors.accent,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                // Keeps the keyboard up so items can be typed one after another.
                onEditingComplete: onAdd,
              ),
            ),
          ),
          const SizedBox(width: 10),
          LiquidPressable(
            onTap: onAdd,
            haptic: HapticKind.none,
            pressedScale: 0.88,
            borderRadius: 20,
            semanticLabel: tr.addItem,
            child: LiquidBox(
              style: GlassStyle(
                radius: 20,
                color: AppColors.accent,
                borderWidth: 0,
                shadows: [
                  const CssShadow.inset(
                    dy: 1,
                    color: Color.fromRGBO(255, 255, 255, 0.5),
                  ),
                  CssShadow(
                    dy: 4,
                    blur: 12,
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ],
              ),
              width: 40,
              height: 40,
              child: const Center(
                child: LineIcon(
                  LineGlyph.plus,
                  size: 18,
                  strokeWidth: 2.8,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.fresh});

  final Set<int> fresh;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<BazarStore>().items;
    return LiquidBox(
      style: context.palette.glass.bazarList,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedSize(
        duration: Motion.smooth.duration,
        curve: Motion.smooth,
        alignment: Alignment.topCenter,
        child: items.isEmpty
            ? SizedBox(
                height: 54,
                child: Center(
                  child: FadeWithGlass(
                    child: Text(
                      tr.nothingToBuy,
                      style: context.palette.footnote,
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    _RemovableRow(
                      key: ValueKey(item.id),
                      item: item,
                      fresh: fresh.contains(item.id),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RemovableRow extends StatelessWidget {
  const _RemovableRow({super.key, required this.item, required this.fresh});

  final BazarItem item;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final row = _ItemRow(item: item);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      onUpdate: (d) {
        if (d.reached != d.previousReached) Haptics.play(HapticKind.light);
      },
      onDismissed: (_) => context.read<BazarStore>().remove(item.id),
      background: ColoredBox(
        color: context.palette.destructiveTint,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              tr.remove,
              style: AppText.subheadBold.copyWith(color: context.palette.red),
            ),
          ),
        ),
      ),
      child: fresh ? Entrance(offset: 10, child: row) : row,
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({required this.item});

  final BazarItem item;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  static final _priceStyle = AppText.subheadBold.copyWith(
    fontFeatures: AppText.tabular,
  );

  late final _price = TextEditingController(
    text: widget.item.price == null ? '' : editableAmount(widget.item.price!),
  );
  final _priceFocus = FocusNode();

  @override
  void dispose() {
    _price.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _setPrice(String text) {
    context.read<BazarStore>().setPrice(widget.item.id, double.tryParse(text));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
        child: Row(
          children: [
            LiquidPressable(
              onTap: () => context.read<BazarStore>().toggle(item.id),
              haptic: HapticKind.selection,
              pressedScale: 0.85,
              semanticLabel: item.checked
                  ? tr.markNotBought(item.name)
                  : tr.markBought(item.name),
              selected: item.checked,
              child: SizedBox.square(
                dimension: 44,
                child: Center(child: _CheckMark(checked: item.checked)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: Motion.snappy.duration,
                curve: Curves.easeOut,
                style: AppText.base.copyWith(
                  color: item.checked
                      ? context.palette.chevron
                      : context.palette.label,
                ),
                child: Text(
                  item.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _priceFocus.requestFocus,
              child: Container(
                // CSS content-box: 92 wide + 10 padding each side.
                width: 92 + 20,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: context.palette.fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        currencySymbol,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.palette.secondaryLabelStrong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Semantics(
                        label: tr.priceFor(item.name),
                        child: CupertinoTextField.borderless(
                          controller: _price,
                          focusNode: _priceFocus,
                          placeholder: digits(0),
                          padding: EdgeInsets.zero,
                          textAlign: TextAlign.right,
                          style: _priceStyle,
                          placeholderStyle: _priceStyle.copyWith(
                            color: context.palette.placeholder,
                            fontWeight: FontWeight.w400,
                          ),
                          cursorColor: AppColors.accent,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _priceFormat,
                          onChanged: _setPrice,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round tick: a green bead when bought, an empty ring when not.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.checked});

  final bool checked;

  static final _bead = GlassStyle(
    radius: 13,
    color: AppColors.green,
    borderWidth: 0,
    shadows: [
      const CssShadow.inset(dy: 1, color: Color.fromRGBO(255, 255, 255, 0.5)),
      CssShadow(dy: 3, blur: 8, color: AppColors.green.withValues(alpha: 0.35)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // CSS content-box: 24 inside a 2px ring, so 28 across.
    final ring = GlassStyle(
      radius: 14,
      color: palette.checkWell,
      borderColor: palette.checkRing,
      borderWidth: 2,
    );
    return AnimatedSwitcher(
      duration: Motion.bouncy.duration,
      switchInCurve: Motion.bouncy,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: checked
          ? LiquidBox(
              key: const ValueKey(true),
              style: _bead,
              width: 26,
              height: 26,
              child: const Center(
                child: LineIcon(
                  LineGlyph.tick,
                  size: 14,
                  strokeWidth: 3.2,
                  color: AppColors.white,
                ),
              ),
            )
          : LiquidBox(
              key: const ValueKey(false),
              style: ring,
              width: 24,
              height: 24,
            ),
    );
  }
}

class _MoveBar extends StatelessWidget {
  const _MoveBar({required this.onMove});

  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BazarStore>();
    final n = store.boughtCount;
    final total = store.boughtTotal;
    final whole = total == total.roundToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeWithGlass(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  tr.boughtCount(n),
                  style: AppText.subhead.copyWith(
                    color: context.palette.amountLabel,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: total),
                  duration: Motion.snappy.duration,
                  // No overshoot: a total must never read below its target.
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    formatMoney(whole ? value.roundToDouble() : value),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppText.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // The button is opaque (no backdrop), so plain opacity is safe.
        AnimatedOpacity(
          opacity: n == 0 ? 0.45 : 1,
          duration: Motion.snappy.duration,
          child: LiquidPressable(
            onTap: n == 0 ? null : onMove,
            haptic: HapticKind.none,
            pressedScale: 0.97,
            borderRadius: 29,
            child: LiquidBox(
              style: context.palette.glass.primaryButton(glow: 0.35),
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LineIcon(
                    LineGlyph.bag,
                    size: 20,
                    strokeWidth: 2.2,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr.moveToDailyBag,
                    style: AppText.headline.copyWith(color: AppColors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
