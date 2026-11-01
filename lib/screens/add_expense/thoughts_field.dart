import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/motion.dart';
import '../../app/tokens.dart';
import '../../state/expense_draft.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';

final _textStyle = AppText.base.copyWith(fontSize: 16, height: 22 / 16);

/// "Bazar thoughts": free text about the day's shopping.
class ThoughtsField extends StatefulWidget {
  const ThoughtsField({super.key});

  @override
  State<ThoughtsField> createState() => _ThoughtsFieldState();
}

class _ThoughtsFieldState extends State<ThoughtsField> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = context.read<ExpenseDraft>().thoughtsFocus..addListener(_sync);
  }

  @override
  void dispose() {
    _focus.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Like the design's <label>, tapping the caption focuses the field.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focus.requestFocus,
          child: const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  LineIcon(
                    LineGlyph.note,
                    size: 14,
                    strokeWidth: 2.2,
                    color: AppColors.secondaryLabel,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'BAZAR THOUGHTS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: _focused ? 1 : 0),
          duration: Motion.snappy.duration,
          curve: Motion.snappy,
          builder: (context, t, child) => SizedBox(
            // The design's textarea is border-box: 128 tall in all.
            height: 128,
            child: LiquidBox(
              style: GlassStyle.lerp(Glass.field, Glass.fieldFocused, t),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: child,
            ),
          ),
          child: Semantics(
            label: 'Bazar thoughts',
            child: CupertinoTextField.borderless(
              controller: context.read<ExpenseDraft>().thoughts,
              focusNode: _focus,
              placeholder:
                  'How did shopping go today? Anything worth remembering — '
                  'a good price, a new shop, something you skipped…',
              padding: EdgeInsets.zero,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: _textStyle,
              placeholderStyle: _textStyle.copyWith(
                color: AppColors.placeholder,
              ),
              cursorColor: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}
