import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DecoratedPhoneScaffold extends StatelessWidget {
  const DecoratedPhoneScaffold({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.mintSoft,
    this.showCorners = true,
  });

  final Widget child;
  final Color backgroundColor;
  final bool showCorners;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(children: [if (showCorners) const _CornerBlobs(), child]),
      ),
    );
  }
}

class _CornerBlobs extends StatelessWidget {
  const _CornerBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            left: -38,
            top: -32,
            child: _Blob(size: 120, alignment: Alignment.bottomRight),
          ),
          Positioned(
            right: -44,
            bottom: -36,
            child: _Blob(size: 140, alignment: Alignment.topLeft),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alignment});

  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.55),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(alignment == Alignment.topLeft ? size : 24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(
            alignment == Alignment.bottomRight ? size : 24,
          ),
        ),
      ),
    );
  }
}
