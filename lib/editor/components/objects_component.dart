import 'dart:math' show pi, sin, cos;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../effects/particle_system.dart';
import '../../models/game_effect.dart';
import '../../models/game_object.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';

class ObjectsComponent extends Component {
  final MapData mapData;
  final SpriteCache spriteCache;
  String? selectedObjectId;
  bool hidden = false;
  double _elapsedSec = 0;

  final Set<String> _previewingIds = {};
  final Map<String, double> _previewElapsed = {};
  final ParticleSystem _previewParticles = ParticleSystem();

  ObjectsComponent({required this.mapData, required this.spriteCache});

  void resetClock() {
    _elapsedSec = 0;
    _previewElapsed.clear();
    _previewParticles.clear();
  }

  void startPreview(String id) {
    _previewingIds.add(id);
    _previewElapsed[id] = 0.0;
  }

  void stopPreview(String id) {
    _previewingIds.remove(id);
    _previewElapsed.remove(id);
  }

  void stopAllPreviews() {
    _previewingIds.clear();
    _previewElapsed.clear();
    _previewParticles.clear();
  }

  void spawnEffectPreview(double worldX, double worldY, GameEffect fx, double tileSize) {
    final spreadPx = fx.spread * tileSize;
    final speedPx = fx.speed * tileSize;
    final sm = fx.particleSize;
    switch (fx.type) {
      case 'blast':
        _previewParticles.spawnBlast(worldX, worldY,
            count: fx.count,
            radiusPx: fx.radius * tileSize,
            durationSec: fx.duration,
            theme: BlastThemeExt.fromId(fx.blastColor),
            sizeMultiplier: sm);
      case 'fire':
        _previewParticles.startFire(worldX, worldY,
            intensity: fx.intensity, spreadPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
      case 'snow':
        _previewParticles.startSnow(worldX, worldY,
            density: fx.intensity, areaPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
      case 'electric':
        _previewParticles.spawnElectric(worldX, worldY,
            arcCount: fx.intensity, rangePx: spreadPx,
            durationSec: fx.duration, sizeMultiplier: sm);
      case 'smoke':
        _previewParticles.startSmoke(worldX, worldY,
            density: fx.intensity, spreadPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
    }
  }

  bool isPreviewing(String id) => _previewingIds.contains(id);

  @override
  void update(double dt) {
    _elapsedSec += dt;
    for (final id in _previewingIds) {
      _previewElapsed[id] = (_previewElapsed[id] ?? 0.0) + dt;
    }
    _previewParticles.update(dt);
  }

  @override
  void render(Canvas canvas) {
    if (hidden) return;
    final ts = mapData.tileSize.toDouble();
    final r = ts * 0.32;

    // Water body overlays — drawn first, below everything
    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.waterBody) continue;
      _drawWaterTile(canvas, obj, ts);
    }

    for (final obj in mapData.objects) {
      if (obj.type == GameObjectType.waterBody) continue;
      // Float
      final floatY = obj.floatEnabled
          ? obj.floatAmplitude * sin(2 * pi * obj.floatSpeed * _elapsedSec)
          : 0.0;
      // Projectile preview — only when explicitly started via Preview button
      double projDx = 0, projDy = 0;
      if (obj.projectileEnabled && _previewingIds.contains(obj.id)) {
        final t = _previewElapsed[obj.id] ?? 0.0;
        final speedPx = obj.projectileSpeed * ts;
        final rangePx = (obj.projectileRange * ts).clamp(0.01, double.infinity);
        double dist;
        if (obj.projectileLoop) {
          final rawDist = speedPx * t;
          final cycle = rawDist % (rangePx * 2);
          dist = cycle <= rangePx ? cycle : rangePx * 2 - cycle;
        } else {
          final travelSec = rangePx / speedPx.clamp(0.01, double.infinity);
          final period = travelSec + 0.5;
          dist = ((t % period) * speedPx).clamp(0.0, rangePx);
        }
        final rad = obj.projectileAngle * pi / 180.0;
        projDx = dist * cos(rad);
        projDy = dist * sin(rad);
        if (obj.projectileArc > 0) {
          final progress = (dist / rangePx).clamp(0.0, 1.0);
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

    // Effect preview particles — on top of everything
    _previewParticles.render(canvas);
  }

  void _drawWaterTile(Canvas canvas, GameObject obj, double ts) {
    final opacity = (obj.properties['opacity'] as num?)?.toDouble() ?? 0.6;
    final colorName = obj.properties['waterColor'] as String? ?? 'blue';
    final animStyle = obj.properties['animStyle'] as String? ?? 'ripple';

    final baseColor = switch (colorName) {
      'green' => const Color(0xFF26A69A),
      'brown' => const Color(0xFF8D6E63),
      'red'   => const Color(0xFFEF5350),
      _       => const Color(0xFF29B6F6),
    };

    double alpha = opacity;
    if (animStyle == 'ripple' || animStyle == 'waves') {
      final pulse = sin(2 * pi * _elapsedSec * 0.8 + obj.tileX * 0.5 + obj.tileY * 0.3);
      alpha = (opacity + pulse * 0.08).clamp(0.0, 1.0);
    }

    final rect = Rect.fromLTWH(obj.tileX * ts, obj.tileY * ts, ts, ts);
    canvas.drawRect(rect, Paint()..color = baseColor.withOpacity(alpha));

    if (animStyle != 'still') {
      final lineOpacity = (alpha * 0.35).clamp(0.0, 1.0);
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(lineOpacity)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final phase = (_elapsedSec * 1.5 + obj.tileX * 0.2 + obj.tileY * 0.2) % 1.0;
      final y = rect.top + ts * phase;
      if (y < rect.bottom) {
        canvas.drawLine(
          Offset(rect.left + ts * 0.15, y),
          Offset(rect.left + ts * 0.85, y),
          linePaint,
        );
      }
    }

    // 'W' label in center
    final center = Offset(obj.tileX * ts + ts * 0.5, obj.tileY * ts + ts * 0.5);
    final tp = TextPainter(
      text: TextSpan(
        text: 'W',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: ts * 0.28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    // Selection ring
    if (obj.id == selectedObjectId) {
      canvas.drawRect(
        rect.inflate(2),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
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
