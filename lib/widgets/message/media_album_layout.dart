import 'package:flutter/material.dart';
import '../../models/media_album.dart';

/// Position and corner radii for an item inside an album mosaic
class AlbumTilePosition {
  final double left;
  final double top;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const AlbumTilePosition({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.borderRadius,
  });
}

/// Calculates Telegram-style mosaic layout for 2 to 10 media items.
class MediaAlbumLayoutCalculator {
  static const double spacing = 2.0;
  static const double outerRadius = 14.0;

  /// Computes tile positions for [items] within [totalWidth] x [totalHeight].
  static List<AlbumTilePosition> computePositions({
    required List<MediaAlbumItem> items,
    required double totalWidth,
    required double totalHeight,
    required bool isMe,
  }) {
    final count = items.length.clamp(2, 10);
    final List<AlbumTilePosition> result = [];

    // Helper to build tile with appropriate corner radii
    AlbumTilePosition makeTile({
      required double x,
      required double y,
      required double w,
      required double h,
      bool isTop = false,
      bool isBottom = false,
      bool isLeft = false,
      bool isRight = false,
    }) {
      return AlbumTilePosition(
        left: x,
        top: y,
        width: w,
        height: h,
        borderRadius: BorderRadius.only(
          topLeft: (isTop && isLeft) ? const Radius.circular(outerRadius) : Radius.zero,
          topRight: (isTop && isRight) ? const Radius.circular(outerRadius) : Radius.zero,
          bottomLeft: (isBottom && isLeft) ? const Radius.circular(outerRadius) : Radius.zero,
          bottomRight: (isBottom && isRight) ? const Radius.circular(outerRadius) : Radius.zero,
        ),
      );
    }

    if (count == 2) {
      final firstAspect = items.first.aspectRatio;
      final secondAspect = items.last.aspectRatio;
      final bothLandscape = firstAspect > 1.2 && secondAspect > 1.2;

      if (bothLandscape) {
        // 2 horizontal rows
        final h = (totalHeight - spacing) / 2;
        result.add(makeTile(
          x: 0,
          y: 0,
          w: totalWidth,
          h: h,
          isTop: true,
          isLeft: true,
          isRight: true,
        ));
        result.add(makeTile(
          x: 0,
          y: h + spacing,
          w: totalWidth,
          h: h,
          isBottom: true,
          isLeft: true,
          isRight: true,
        ));
      } else {
        // 2 vertical columns
        final w = (totalWidth - spacing) / 2;
        result.add(makeTile(
          x: 0,
          y: 0,
          w: w,
          h: totalHeight,
          isTop: true,
          isBottom: true,
          isLeft: true,
        ));
        result.add(makeTile(
          x: w + spacing,
          y: 0,
          w: w,
          h: totalHeight,
          isTop: true,
          isBottom: true,
          isRight: true,
        ));
      }
      return result;
    }

    if (count == 3) {
      // 1 large on left, 2 stacked on right
      final leftW = (totalWidth - spacing) * 0.62;
      final rightW = totalWidth - spacing - leftW;
      final rightH = (totalHeight - spacing) / 2;

      result.add(makeTile(
        x: 0,
        y: 0,
        w: leftW,
        h: totalHeight,
        isTop: true,
        isBottom: true,
        isLeft: true,
      ));
      result.add(makeTile(
        x: leftW + spacing,
        y: 0,
        w: rightW,
        h: rightH,
        isTop: true,
        isRight: true,
      ));
      result.add(makeTile(
        x: leftW + spacing,
        y: rightH + spacing,
        w: rightW,
        h: rightH,
        isBottom: true,
        isRight: true,
      ));
      return result;
    }

    if (count == 4) {
      // 2x2 grid
      final w = (totalWidth - spacing) / 2;
      final h = (totalHeight - spacing) / 2;

      result.add(makeTile(x: 0, y: 0, w: w, h: h, isTop: true, isLeft: true));
      result.add(makeTile(x: w + spacing, y: 0, w: w, h: h, isTop: true, isRight: true));
      result.add(makeTile(x: 0, y: h + spacing, w: w, h: h, isBottom: true, isLeft: true));
      result.add(makeTile(x: w + spacing, y: h + spacing, w: w, h: h, isBottom: true, isRight: true));
      return result;
    }

    if (count == 5) {
      // 2 on top, 3 on bottom
      final topH = (totalHeight - spacing) * 0.52;
      final bottomH = totalHeight - spacing - topH;
      final topW = (totalWidth - spacing) / 2;
      final bottomW = (totalWidth - 2 * spacing) / 3;

      // Top row
      result.add(makeTile(x: 0, y: 0, w: topW, h: topH, isTop: true, isLeft: true));
      result.add(makeTile(x: topW + spacing, y: 0, w: topW, h: topH, isTop: true, isRight: true));

      // Bottom row
      result.add(makeTile(x: 0, y: topH + spacing, w: bottomW, h: bottomH, isBottom: true, isLeft: true));
      result.add(makeTile(x: bottomW + spacing, y: topH + spacing, w: bottomW, h: bottomH, isBottom: true));
      result.add(makeTile(x: (bottomW + spacing) * 2, y: topH + spacing, w: bottomW, h: bottomH, isBottom: true, isRight: true));
      return result;
    }

    if (count == 6) {
      // 3 on top, 3 on bottom
      final rowH = (totalHeight - spacing) / 2;
      final colW = (totalWidth - 2 * spacing) / 3;

      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 3; c++) {
          result.add(makeTile(
            x: c * (colW + spacing),
            y: r * (rowH + spacing),
            w: colW,
            h: rowH,
            isTop: r == 0,
            isBottom: r == 1,
            isLeft: c == 0,
            isRight: c == 2,
          ));
        }
      }
      return result;
    }

    if (count == 7) {
      // 1 large top, 3 middle, 3 bottom
      final topH = (totalHeight - 2 * spacing) * 0.44;
      final restH = (totalHeight - 2 * spacing - topH) / 2;
      final colW = (totalWidth - 2 * spacing) / 3;

      result.add(makeTile(
        x: 0,
        y: 0,
        w: totalWidth,
        h: topH,
        isTop: true,
        isLeft: true,
        isRight: true,
      ));

      for (int r = 0; r < 2; r++) {
        for (int c = 0; c < 3; c++) {
          result.add(makeTile(
            x: c * (colW + spacing),
            y: topH + spacing + r * (restH + spacing),
            w: colW,
            h: restH,
            isBottom: r == 1,
            isLeft: c == 0,
            isRight: c == 2,
          ));
        }
      }
      return result;
    }

    if (count == 8) {
      // 2 top, 3 middle, 3 bottom
      final topH = (totalHeight - 2 * spacing) * 0.36;
      final restH = (totalHeight - 2 * spacing - topH) / 2;
      final topW = (totalWidth - spacing) / 2;
      final restW = (totalWidth - 2 * spacing) / 3;

      // Top row (2 items)
      result.add(makeTile(x: 0, y: 0, w: topW, h: topH, isTop: true, isLeft: true));
      result.add(makeTile(x: topW + spacing, y: 0, w: topW, h: topH, isTop: true, isRight: true));

      // Middle row (3 items)
      for (int c = 0; c < 3; c++) {
        result.add(makeTile(
          x: c * (restW + spacing),
          y: topH + spacing,
          w: restW,
          h: restH,
          isLeft: c == 0,
          isRight: c == 2,
        ));
      }

      // Bottom row (3 items)
      for (int c = 0; c < 3; c++) {
        result.add(makeTile(
          x: c * (restW + spacing),
          y: topH + 2 * spacing + restH,
          w: restW,
          h: restH,
          isBottom: true,
          isLeft: c == 0,
          isRight: c == 2,
        ));
      }
      return result;
    }

    if (count == 9) {
      // 3x3 grid
      final h = (totalHeight - 2 * spacing) / 3;
      final w = (totalWidth - 2 * spacing) / 3;

      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          result.add(makeTile(
            x: c * (w + spacing),
            y: r * (h + spacing),
            w: w,
            h: h,
            isTop: r == 0,
            isBottom: r == 2,
            isLeft: c == 0,
            isRight: c == 2,
          ));
        }
      }
      return result;
    }

    // count == 10
    // 1 large top, 3 middle, 3 lower-middle, 3 bottom (or 2 top, 4 middle, 4 bottom)
    final topH = (totalHeight - 2 * spacing) * 0.36;
    final rowH = (totalHeight - 2 * spacing - topH) / 2;
    final topW = (totalWidth - spacing) / 2;
    final quadW = (totalWidth - 3 * spacing) / 4;

    // Top row (2 items)
    result.add(makeTile(x: 0, y: 0, w: topW, h: topH, isTop: true, isLeft: true));
    result.add(makeTile(x: topW + spacing, y: 0, w: topW, h: topH, isTop: true, isRight: true));

    // Middle row (4 items)
    for (int c = 0; c < 4; c++) {
      result.add(makeTile(
        x: c * (quadW + spacing),
        y: topH + spacing,
        w: quadW,
        h: rowH,
        isLeft: c == 0,
        isRight: c == 3,
      ));
    }

    // Bottom row (4 items)
    for (int c = 0; c < 4; c++) {
      result.add(makeTile(
        x: c * (quadW + spacing),
        y: topH + 2 * spacing + rowH,
        w: quadW,
        h: rowH,
        isBottom: true,
        isLeft: c == 0,
        isRight: c == 3,
      ));
    }

    return result;
  }
}
