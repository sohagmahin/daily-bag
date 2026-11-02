import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app/format.dart';
import '../../app/motion.dart';
import '../../app/strings.dart';
import '../../app/tokens.dart';
import '../../state/expense_draft.dart';
import '../../widgets/liquid_glass.dart';

final _nameStyle = AppText.base;
final _amountStyle = AppText.base.copyWith(
  fontWeight: FontWeight.w600,
  fontFeatures: AppText.tabular,
);
final _amountFormat = [
  // A Bangla keyboard types ০-৯; amounts are stored with ASCII digits.
  TextInputFormatter.withFunction(
    (_, value) => value.copyWith(text: asciiDigits(value.text)),
  ),
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// An item + amount line. Focus draws the blue rim and halo of the design,
/// morphing from the resting white rim.
class ExpenseRow extends StatefulWidget {
  const ExpenseRow({super.key, required this.row, required this.index});

  final DraftRow row;
  final int index;

  @override
  State<ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<ExpenseRow> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.row.nameFocus.addListener(_syncFocus);
    widget.row.amountFocus.addListener(_syncFocus);
  }

  @override
  void dispose() {
    widget.row.nameFocus.removeListener(_syncFocus);
    widget.row.amountFocus.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncFocus() {
    final focused =
        widget.row.nameFocus.hasFocus || widget.row.amountFocus.hasFocus;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final n = widget.index + 1;

    final fields = Row(
      children: [
        Expanded(
          child: Semantics(
            label: tr.item(n),
            child: CupertinoTextField.borderless(
              controller: row.name,
              focusNode: row.nameFocus,
              placeholder: tr.itemPlaceholder,
              padding: EdgeInsets.zero,
              style: _nameStyle.copyWith(color: context.palette.label),
              placeholderStyle: _nameStyle.copyWith(
                color: context.palette.placeholder,
              ),
              cursorColor: AppColors.accent,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => row.amountFocus.requestFocus(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: row.amountFocus.requestFocus,
          child: Container(
            // CSS content-box: 110 wide + 12 padding each side.
            width: 110 + 24,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.palette.fill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Text(
                    currencySymbol,
                    style: TextStyle(
                      fontSize: 17,
                      color: context.palette.secondaryLabelStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    label: tr.amountFor(n),
                    child: CupertinoTextField.borderless(
                      controller: row.amount,
                      focusNode: row.amountFocus,
                      placeholder: digits(0),
                      padding: EdgeInsets.zero,
                      textAlign: TextAlign.right,
                      style: _amountStyle.copyWith(
                        color: context.palette.label,
                      ),
                      placeholderStyle: _amountStyle.copyWith(
                        color: context.palette.placeholder,
                      ),
                      cursorColor: AppColors.accent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: _amountFormat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(end: _focused ? 1 : 0),
      duration: Motion.snappy.duration,
      curve: Motion.snappy,
      child: fields,
      builder: (context, t, child) => SizedBox(
        // Fixed so focusing (1.5px rim) never nudges the rows below.
        height: 56,
        child: LiquidBox(
          style: GlassStyle.lerp(
            context.palette.glass.field,
            context.palette.glass.fieldFocused,
            t,
          ),
          padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
          child: child,
        ),
      ),
    );
  }
}
