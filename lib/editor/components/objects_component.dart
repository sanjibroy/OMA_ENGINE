import 'dart:math' show pi, sin, cos;
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
      // Float
      final floatY = obj.floatEnabled
          ? obj.floatAmplitude * sin(2 * pi * obj.floatSpeed * _elapsedSec)
          : 0.0;
      // Projectile (loops over range with optional arc)
      double projDx = 0, projDy = 0;
      if (obj.projectileEnabled) {
        final speedPx = obj.projectileSpeed * ts;
        final rangePx = (obj.projectileRange * ts).clamp(0.01, double.infinity);
        final dist = (speedPx * _elapsedSec) % rangePx;
        final rad = obj.projectileAngle * pi / 180.0;
        projDx = dist * cos(rad);
        projDy = dist * sin(rad);
        if (obj.projectileArc > 0) {
          // Arc perpendicular to travel: rises to peak at midpoint, returns at end
          final progress = dist / rangePx;
          projDy -= obj.projectileArc * ts * sin(pi * progress);
        }
      }
      // Dash (smooth oscillation)
      double dashDx = 0, dashDy = 0;
      if (obj.dashEnabled) {
        final distPx = obj.dashDistance * ts;
        final period = obj.dashInterval +
            2.0 * obj.dashDistance / obj.dashSpeed.clamp(0.1, 100.0);
        final phase = (_elapsedSec % period.clamp(0.01, double.infinity)) /
            period.clamp(0.01, double.infinity);
        final prog = (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2)
            .clamp(0.0, 1.0);
        final rad = obj.dashAngle * pi / 180.0;
        dashDx = prog * distPx * cos(rad);
        dashDy = prog * distPx * sin(rad);
      }
      final cx = (obj.tileX + 0.5) * ts + projDx + dashDx;
      final cy = (obj.tileY + 0.5) * ts + floatY + projDy + dashDy;
      final center = Offset(cx, cy);

      // Combine hidden (50% tint) and alpha for the layer opacity
      final effectiveAlpha = obj.hidden ? 0.35 : obj.alpha;
      final needsLayer = effectiveAlpha < 1.0;
      if (needsLayer) {
        canvas.saveLayer(null,
            Paint()..color = Color.fromARGB((effectiveAlpha * 255).round().clamp(0, 255), 255, 255, 255));
      }

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
        _drawSprite(canvas, sprite, cx, cy, ts,
            flipH: obj.flipH, flipV: obj.flipV,
            scale: obj.scale, rotation: obj.rotation);
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

      if (needsLayer) canvas.restore();

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

  void _drawSprite(Canvas canvas, ui.Image image, double cx, double cy, double ts,
      {bool flipH = false, bool flipV = false,
      double scale = 1.0, double rotation = 0.0}) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.save();
    canvas.translate(cx, cy);
    if (rotation != 0.0) canvas.rotate(rotation * pi / 180.0);
    canvas.scale(flipH ? -scale : scale, flipV ? -scale : scale);
    canvas.drawImageRect(
      image, src,
      Rect.fromCenter(center: Offset.zero, width: ts, height: ts),
      Paint(),
    );
    canvas.restore();
  }
}
