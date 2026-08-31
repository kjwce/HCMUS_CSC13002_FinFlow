import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class PostMediaGrid extends StatelessWidget {
  const PostMediaGrid({super.key, required this.urls, this.detailMode = false});

  final List<String> urls;
  final bool detailMode;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) return _singleImage(context);
    final visible = urls.take(4).toList();
    final height = Responsive.h(context, detailMode ? 250 : 210);

    return SizedBox(
      height: height * .92,
      child: switch (visible.length) {
        2 => Row(
          children: [
            Expanded(child: _tile(context, visible[0], 0)),
            _gap(context, vertical: true),
            Expanded(child: _tile(context, visible[1], 1)),
          ],
        ),
        3 => Row(
          children: [
            Expanded(flex: 6, child: _tile(context, visible[0], 0)),
            _gap(context, vertical: true),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(child: _tile(context, visible[1], 1)),
                  _gap(context),
                  Expanded(child: _tile(context, visible[2], 2)),
                ],
              ),
            ),
          ],
        ),
        _ => Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, visible[0], 0)),
                  _gap(context, vertical: true),
                  Expanded(child: _tile(context, visible[1], 1)),
                ],
              ),
            ),
            _gap(context),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, visible[2], 2)),
                  _gap(context, vertical: true),
                  Expanded(
                    child: _tile(
                      context,
                      visible[3],
                      3,
                      hiddenCount: urls.length - 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }

  Widget _singleImage(BuildContext context) {
    final cacheWidth = _cacheWidth(context);
    return Semantics(
      button: true,
      label: 'Open image 1 of 1',
      child: GestureDetector(
        onTap: () => _openViewer(context, 0),
        child: Image.network(
          urls.first,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          cacheWidth: cacheWidth,
          errorBuilder: (_, _, _) => SizedBox(
            height: Responsive.h(context, 180),
            child: ColoredBox(
              color: context.finFlowColors.elevatedSurface,
              child: Icon(
                Icons.broken_image_outlined,
                color: context.finFlowColors.secondaryText,
              ),
            ),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: Responsive.h(context, 180),
              child: ColoredBox(
                color: context.finFlowColors.elevatedSurface,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _gap(BuildContext context, {bool vertical = false}) {
    final size = Responsive.w(context, 3);
    return SizedBox(width: vertical ? size : 0, height: vertical ? 0 : size);
  }

  Widget _tile(
    BuildContext context,
    String url,
    int index, {
    int hiddenCount = 0,
  }) {
    final cacheWidth = _cacheWidth(context);
    return Semantics(
      button: true,
      label: 'Open image ${index + 1} of ${urls.length}',
      child: Material(
        color: context.finFlowColors.elevatedSurface,
        child: InkWell(
          onTap: () => _openViewer(context, index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: context.finFlowColors.elevatedSurface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: context.finFlowColors.secondaryText,
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: context.finFlowColors.elevatedSurface,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
              if (hiddenCount > 0)
                ColoredBox(
                  color: Colors.black.withValues(alpha: .56),
                  child: Center(
                    child: Text(
                      '+$hiddenCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Manrope',
                        fontSize: Responsive.sp(context, 28),
                        fontWeight: FontWeight.w700,
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

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _PostMediaViewer(urls: urls, initialIndex: initialIndex),
      ),
    );
  }

  int _cacheWidth(BuildContext context) {
    final logicalWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return (logicalWidth * pixelRatio).round().clamp(1, 2048);
  }
}

class _PostMediaViewer extends StatefulWidget {
  const _PostMediaViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<_PostMediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07130F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.urls[index],
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
