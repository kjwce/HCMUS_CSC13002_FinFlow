import 'package:flutter/material.dart';

/// Slides a post to the left while fading and collapsing it out of the feed.
class PostRemovalAnimation extends StatelessWidget {
  const PostRemovalAnimation({
    required this.removing,
    required this.child,
    super.key,
  });

  static const duration = Duration(milliseconds: 220);

  final bool removing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: removing ? 1 : 0),
      duration: duration,
      curve: removing ? Curves.easeInCubic : Curves.easeOutCubic,
      builder: (context, progress, animatedChild) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - progress,
            child: FractionalTranslation(
              translation: Offset(-1.08 * progress, 0),
              child: Opacity(
                opacity: 1 - progress,
                child: IgnorePointer(ignoring: removing, child: animatedChild),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
