import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

/// A Material 3 *enter the screen* transition: fade in while rising from below.
///
/// MD3 uses the emphasized-decelerate pair for content entering the screen, so
/// a card that appears as the result of an action does not pop into place. The
/// animation runs once, when the widget is first built, and is a no-op on every
/// later rebuild.
class M3EnterTransition extends StatelessWidget {
  /// Wraps [child] in the enter transition.
  const M3EnterTransition({
    super.key,
    required this.child,
    this.offset = M3Spacing.small,
    this.duration = M3Motion.medium2,
  });

  /// The content that enters the screen.
  final Widget child;

  /// How far the content rises, in logical pixels.
  final double offset;

  /// Length of the transition.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: M3Motion.emphasizedDecelerate,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
