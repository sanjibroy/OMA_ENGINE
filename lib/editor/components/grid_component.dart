import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';

class GridComponent extends Component {
  final MapData mapData;
  final SpriteCache spriteCache;
  bool showGrid = true;
  bool showCollision = false;

  GridComponent({required this.mapData, required this.spriteCache});

  static final _gridLinePaint = Paint()
    ..color = const Color(0xFF2A2A3A)
    ..strokeWidth = 0.5
    ..style = PaintingStyle.stroke;

  static final _borderPaint = Paint()
    ..color = const Color(0xFF444455)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final _passablePaint = Paint()
    ..color = const Color(0x9900CFFF); // bright cyan — visible on all tile types

  static final _solidPaint = Paint()
    ..color = const Color(0x99FF2222); // bright red

  @override
  void render(Canvas canvas) {
    final ts = mapData.tileSize.toDouble();
    final w = mapData.width;
    final h = mapData.height;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final tile = mapData.getTile(x, y);
        final variant = mapData.getTileVariant(x, y);
        // Expand right/bottom by 0.5px — subsequent tiles cover the overdraw,
        // filling any sub-pixel gaps between tiles (seam prevention).
        final rect = Rect.fromLTWH(x * ts, y * ts, ts + 0.5, ts + 0.5);

        final sprite = spriteCache.getTileImage(tile, variant);
        if (sprite != null) {
          _drawSprite(canvas, sprite, rect);
        } else {
          canvas.drawRect(rect, Paint()
            ..color = tile.color
            ..isAntiAlias = false);
        }

        // Collision overlay
        if (showCollision) {
          final col = mapData.getTileCollision(x, y);
          if (col == 1) {
            canvas.drawRect(rect, _passablePaint);
          } else if (col == 2) {
            canvas.drawRect(rect, _solidPaint);
          }
        }
      }
    }

    if (showGrid) {
      for (int x = 0; x <= w; x++) {
        canvas.drawLine(Offset(x * ts, 0), Offset(x * ts, h * ts), _gridLinePaint);
      }
      for (int y = 0; y <= h; y++) {
        canvas.drawLine(Offset(0, y * ts), Offset(w * ts, y * ts), _gridLinePaint);
      }
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, w * ts, h * ts), _borderPaint);
  }

  void _drawSprite(Canvas canvas, ui.Image image, Rect dst) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, src, dst, Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false);
  }
}
