import 'package:flutter/widgets.dart';

import '../../app/format.dart';
import '../../app/haptics.dart';
import '../../app/tokens.dart';
import '../../state/bazar_store.dart';
import '../../widgets/line_icon.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/liquid_overlay_route.dart';
import '../../widgets/liquid_pressable.dart';

/// "Added to Daily Bag": confirms a move over a frosted Bazar Note.
/// Pops true for "View Daily Bag", null for "Keep listing".
class MovedCard extends StatelessWidget {
  const MovedCard({super.key, required this.move, required this.animation});

  final BazarMove move;
  final Animation<double> animation;

  static Route<bool> route(BazarMove move) => LiquidOverlayRoute<bool>(
    builder: (context, animation) =>
        MovedCard(move: move, animation: animation),
  );

  static final _bead = GlassStyle(
    radius: 32,
    color: AppColors.green,
    borderWidth: 0,
    shadows: [
      const CssShadow.inset(dy: 1, color: Color.fromRGBO(255, 255, 255, 0.5)),
      CssShadow(
        dy: 10,
        blur: 24,
        color: AppColors.green.withValues(alpha: 0.35),
      ),
    ],
  );

  void _close(BuildContext context, [bool? view]) {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop(view);
  }

  @override
  Widget build(BuildContext context) {
    final line =
        '${plural(move.count, 'item')} · ${formatTaka(move.total)} added to '
        'today’s expenses. Unticked items stay in your Bazar Note.';

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          children: [
            Positioned.fill(
              child: GlassScrim(
                progress: t,
                color: AppColors.thoughtsScrim,
                blur: 16,
                saturation: 1.4,
                semanticLabel: 'Keep listing',
                onTap: () => _close(context),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassFade(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * t,
                    child: Semantics(
                      scopesRoute: true,
                      namesRoute: true,
                      explicitChildNodes: true,
                      label: 'Added to Daily Bag',
                      child: _card(context, line),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, String line) {
    return LiquidBox(
      style: Glass.movedCard,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: LiquidBox(
              style: _bead,
              width: 64,
              height: 64,
              child: const Center(
                child: LineIcon(
                  LineGlyph.tick,
                  size: 30,
                  strokeWidth: 3,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeWithGlass(
            child: Column(
              children: [
                const Text(
                  'Added to Daily Bag',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: AppText.subhead.copyWith(
                    height: 21 / 15,
                    color: AppColors.amountLabel,
                  ),
                ),
                const SizedBox(height: 22),
                _CardButton(
                  label: 'View Daily Bag',
                  color: AppColors.accent,
                  textColor: AppColors.white,
                  onTap: () => _close(context, true),
                ),
                const SizedBox(height: 8),
                _CardButton(
                  label: 'Keep listing',
                  color: AppColors.accentTint,
                  textColor: AppColors.accentText,
                  onTap: () => _close(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LiquidPressable(
      onTap: onTap,
      haptic: HapticKind.light,
      pressedScale: 0.97,
      borderRadius: 25,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(label, style: AppText.headline.copyWith(color: textColor)),
      ),
    );
  }
}
