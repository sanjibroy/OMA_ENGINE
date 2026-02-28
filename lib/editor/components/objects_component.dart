import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/game_object.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';

class ObjectsComponent extends Component {
  final MapData mapData;
  final SpriteCache spriteCache;
  String? selectedObjectId;
  bool hidden = false;
  double _elapsedSec = 0;

  ObjectsComponent({required this.mapData, required this.spriteCache});

  @override
  void update(double dt) {
    _elapsedSec += dt;
  }

  @override
  void render(Canvas canvas) {
    if (hidden) return;
    final ts = mapData.tileSize.toDouble();
    final r = ts * 0.32;

    for (final obj in mapData.objects) {
      final cx = (obj.tileX + 0.5) * ts;
      final cy = (obj.tileY + 0.5) * ts;
      final center = Offset(cx, cy);

      // Prefer animation, then static sprite, then colored circle
      ui.Image? sprite;
      if (spriteCache.isAnimated(obj.type)) {
        final animName = spriteCache.defaultAnim(obj.type);
        if (animName.isNotEmpty) {
          final fps = spriteCache.getAnimFps(obj.type, animName);
          final frameCount = spriteCache.animFrameCount(obj.type, animName);
          if (frameCount > 0) {
            final frameIndex = (_elapsedSec * fps).floor() % frameCount;
            sprite = spriteCache.getAnimFrame(obj.type, animName, frameIndex);
          }
        }
      } else {
        sprite = spriteCache.getImage(obj.type);
      }
      if (sprite != null) {
        _drawSprite(canvas, sprite, cx, cy, ts);
      } else {
        // Shadow
        canvas.drawCircle(
          center + const Offset(1, 2),
          r,
          Paint()..color = Colors.black.withOpacity(0.3),
        );
        // Fill
        canvas.drawCircle(center, r, Paint()..color = obj.type.color);
        // Symbol letter
        final tp = TextPainter(
          text: TextSpan(
            text: obj.type.symbol,
            style: TextStyle(
              color: Colors.white,
              fontSize: r * 0.9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
      }

      // Selection ring
      if (obj.id == selectedObjectId) {
        canvas.drawRect(
          Rect.fromCenter(center: center, width: ts, height: ts).inflate(2),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawSprite(Canvas canvas, ui.Image image, double cx, double cy, double ts) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset(cx, cy), width: ts, height: ts);
    canvas.drawImageRect(image, src, dst, Paint());
  }
}
