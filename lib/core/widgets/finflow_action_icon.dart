import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared Phosphor action icons used instead of mismatched Material glyphs.
class FinFlowPencilIcon extends StatelessWidget {
  const FinFlowPencilIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/icons/phosphor-pencil-simple-regular.svg',
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    ),
  );
}

class FinFlowTrashIcon extends StatelessWidget {
  const FinFlowTrashIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        'assets/icons/phosphor-trash-regular.svg',
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    ),
  );
}

class FinFlowPauseIcon extends StatelessWidget {
  const FinFlowPauseIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _PhosphorActionIcon(
    asset: 'assets/icons/phosphor-pause-regular.svg',
    color: color,
    size: size,
  );
}

class FinFlowPlayIcon extends StatelessWidget {
  const FinFlowPlayIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _PhosphorActionIcon(
    asset: 'assets/icons/phosphor-play-regular.svg',
    color: color,
    size: size,
  );
}

class FinFlowSkipIcon extends StatelessWidget {
  const FinFlowSkipIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _PhosphorActionIcon(
    asset: 'assets/icons/phosphor-skip-forward-regular.svg',
    color: color,
    size: size,
  );
}

class FinFlowPrimaryIcon extends StatelessWidget {
  const FinFlowPrimaryIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _PhosphorActionIcon(
    asset: 'assets/icons/phosphor-star-regular.svg',
    color: color,
    size: size,
  );
}

class _PhosphorActionIcon extends StatelessWidget {
  const _PhosphorActionIcon({
    required this.asset,
    required this.color,
    required this.size,
  });

  final String asset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    widthFactor: 1,
    heightFactor: 1,
    child: SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    ),
  );
}
