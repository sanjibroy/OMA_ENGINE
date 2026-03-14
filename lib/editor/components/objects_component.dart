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

  bool sortEditMode = false;

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
      case 'rain':
        _previewParticles.startRain(worldX, worldY - tileSize * 8,
            density: fx.intensity,
            areaPx: tileSize * 20,
            speedPx: speedPx > 0 ? speedPx : 220,
            duration: fx.duration,
            sizeMultiplier: sm,
            maxParticles: fx.maxParticles > 0 ? fx.maxParticles : 300,
            angleDeg: fx.radius.toDouble());
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

    final sorted = mapData.objects
        .where((o) => o.type != GameObjectType.waterBody)
        .toList()
      ..sort((a, b) {
          final zCmp = a.zOrder.compareTo(b.zOrder);
          if (zCmp != 0) return zCmp;
          if (!mapData.ySortEnabled) return 0;
          final ts = mapData.tileSize.toDouble();
          final ay = (a.tileY + 0.5) * ts + a.offsetY + a.sortAnchorY * ts;
          final by = (b.tileY + 0.5) * ts + b.offsetY + b.sortAnchorY * ts;
          return ay.compareTo(by);
        });

    for (final obj in sorted) {
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
      final cx = (obj.tileX + 0.5) * ts + obj.offsetX + projDx + dashDx;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY + floatY + projDy + dashDy;
      final center = Offset(cx, cy);

      // Combine hidden (50% tint) and alpha for the layer opacity
      final effectiveAlpha = obj.hidden ? 0.35 : obj.alpha;
      final needsLayer = effectiveAlpha < 1.0;
      if (needsLayer) {
        canvas.saveLayer(null,
            Paint()..color = Color.fromARGB((effectiveAlpha * 255).round().clamp(0, 255), 255, 255, 255));
      }

      // Resolve sprite: animation frame → static variant → colored circle
      ui.Image? sprite;
      final useAnim = mapData.getVariantUseAnimation(obj.type, obj.variantIndex);
      if (useAnim && spriteCache.isAnimated(obj.type, obj.variantIndex)) {
        final animName = spriteCache.defaultAnim(obj.type, obj.variantIndex);
        if (animName.isNotEmpty) {
          final fps = spriteCache.getAnimFps(obj.type, obj.variantIndex, animName);
          final frameCount = spriteCache.animFrameCount(obj.type, obj.variantIndex, animName);
          if (frameCount > 0) {
            final frameIndex = (_elapsedSec * fps).floor() % frameCount;
            sprite = spriteCache.getAnimFrame(obj.type, obj.variantIndex, animName, frameIndex);
          }
        }
      }
      // Fall back to static sprite if animation gave nothing (or useAnim is off)
      sprite ??= spriteCache.getVariantImage(obj.type, obj.variantIndex);
      // If still nothing but there ARE animation frames, use frame 0 as static preview
      if (sprite == null && spriteCache.isAnimated(obj.type, obj.variantIndex)) {
        final animName = spriteCache.defaultAnim(obj.type, obj.variantIndex);
        if (animName.isNotEmpty) {
          sprite = spriteCache.getAnimFrame(obj.type, obj.variantIndex, animName, 0);
        }
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
        // Material icon glyph
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(obj.type.icon.codePoint),
            style: TextStyle(
              fontFamily: obj.type.icon.fontFamily,
              package: obj.type.icon.fontPackage,
              color: Colors.white,
              fontSize: r * 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
      }

      if (needsLayer) canvas.restore();

      // Collision shape outline for player, enemy, NPC and solid props
      if (obj.type == GameObjectType.playerSpawn ||
          obj.type == GameObjectType.enemy ||
          obj.type == GameObjectType.npc ||
          (obj.type == GameObjectType.prop &&
              (obj.properties['solid'] as bool? ?? true))) {
        final isSelected = obj.id == selectedObjectId;
        _drawCollisionShape(canvas, obj, center, ts, isSelected);
      }

      // Sort region marker — only for props, when selected or editing
      if (obj.type == GameObjectType.prop) {
        final isSelected = obj.id == selectedObjectId;
        if (isSelected) {
          _drawSortRegion(canvas, obj, center, ts, sortEditMode && isSelected);
        }
      }

      // Selection ring — sized to actual sprite if one is loaded
      if (obj.id == selectedObjectId) {
        double selW = ts, selH = ts;
        final img = sprite ?? spriteCache.getVariantImage(obj.type, obj.variantIndex);
        if (img != null) {
          selW = img.width.toDouble() * obj.scale;
          selH = img.height.toDouble() * obj.scale;
        }
        canvas.drawRect(
          Rect.fromCenter(center: center, width: selW, height: selH).inflate(2),
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

  void _drawCollisionShape(
      Canvas canvas, GameObject obj, Offset center, double ts, bool selected) {
    final shape = obj.properties['blockShape'] as String? ?? 'rect';
    const fillColor   = Color(0xFF00E5FF); // cyan
    final fillOpacity  = selected ? 0.12 : 0.06;
    final strokeOpacity = selected ? 0.85 : 0.35;
    final strokeWidth   = selected ? 1.5 : 1.0;

    final fillPaint = Paint()
      ..color = fillColor.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = fillColor.withOpacity(strokeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    switch (shape) {
      case 'circle':
        final r = ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.5) * ts;
        canvas.drawCircle(center, r, fillPaint);
        _drawDashedCircle(canvas, center, r, strokePaint);
      case 'ellipse':
        final rx = ((obj.properties['blockRX'] as num?)?.toDouble() ?? 0.5) * ts;
        final ry = ((obj.properties['blockRY'] as num?)?.toDouble() ?? 0.5) * ts;
        final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
        canvas.drawOval(rect, fillPaint);
        _drawDashedOval(canvas, rect, strokePaint);
      case 'custom':
        // Uses sortPoints polygon as the collision boundary.
        final worldPts = _sortWorldPoints(obj, center, ts);
        if (worldPts.length >= 2) {
          final poly = Path()..moveTo(worldPts.first.dx, worldPts.first.dy);
          for (int i = 1; i < worldPts.length; i++) {
            poly.lineTo(worldPts[i].dx, worldPts[i].dy);
          }
          poly.close();
          canvas.drawPath(poly, fillPaint);
          canvas.drawPath(poly, strokePaint);
          if (selected) {
            for (final pt in worldPts) {
              canvas.drawCircle(pt, sortEditMode ? 5.0 : 3.0,
                  Paint()..color = fillColor.withOpacity(0.8));
              canvas.drawCircle(pt, sortEditMode ? 5.0 : 3.0, strokePaint);
            }
          }
        } else if (selected) {
          // No points yet — draw a dotted placeholder rect as hint
          final hw = ts / 2, hh = ts / 2;
          final rect = Rect.fromCenter(center: center, width: hw * 2, height: hh * 2);
          _drawDashedRect(canvas, rect,
              Paint()..color = fillColor.withOpacity(0.25)
                     ..style = PaintingStyle.stroke
                     ..strokeWidth = 1.0);
        }
      default: // 'rect'
        final hw = ((obj.properties['blockW'] as num?)?.toDouble() ?? 1.0) * ts / 2;
        final hh = ((obj.properties['blockH'] as num?)?.toDouble() ?? 1.0) * ts / 2;
        final rect = Rect.fromCenter(center: center, width: hw * 2, height: hh * 2);
        canvas.drawRect(rect, fillPaint);
        _drawDashedRect(canvas, rect, strokePaint);
    }
  }

  /// Converts sortPoints (tile-unit offsets) to world-space Offsets.
  List<Offset> _sortWorldPoints(GameObject obj, Offset center, double ts) {
    final raw = obj.properties['sortPoints'];
    if (raw is! List) return [];
    final result = <Offset>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        result.add(Offset(
          center.dx + (p[0] as num).toDouble() * ts,
          center.dy + (p[1] as num).toDouble() * ts,
        ));
      }
    }
    return result;
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final path = Path();
    void addDashedLine(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      double t = 0;
      bool drawing = true;
      while (t < len) {
        final seg = drawing ? dash : gap;
        final end = (t + seg).clamp(0.0, len);
        if (drawing) {
          path.moveTo(a.dx + dir.dx * t, a.dy + dir.dy * t);
          path.lineTo(a.dx + dir.dx * end, a.dy + dir.dy * end);
        }
        t += seg;
        drawing = !drawing;
      }
    }
    addDashedLine(rect.topLeft, rect.topRight);
    addDashedLine(rect.topRight, rect.bottomRight);
    addDashedLine(rect.bottomRight, rect.bottomLeft);
    addDashedLine(rect.bottomLeft, rect.topLeft);
    canvas.drawPath(path, paint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const segments = 40;
    const dash = 0.18, gap = 0.08; // arc fraction
    final path = Path();
    bool drawing = true;
    double angle = 0;
    while (angle < 2 * pi) {
      final seg = drawing ? dash : gap;
      final endAngle = (angle + seg * 2 * pi).clamp(0.0, 2 * pi);
      if (drawing) {
        path.moveTo(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        for (int i = 1; i <= segments; i++) {
          final t = angle + (endAngle - angle) * i / segments;
          path.lineTo(center.dx + radius * cos(t), center.dy + radius * sin(t));
        }
      }
      angle += seg * 2 * pi;
      drawing = !drawing;
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashedOval(Canvas canvas, Rect rect, Paint paint) {
    final rx = rect.width / 2, ry = rect.height / 2;
    final cx = rect.center.dx, cy = rect.center.dy;
    const segments = 40;
    const dash = 0.18, gap = 0.08;
    final path = Path();
    bool drawing = true;
    double angle = 0;
    while (angle < 2 * pi) {
      final seg = drawing ? dash : gap;
      final endAngle = (angle + seg * 2 * pi).clamp(0.0, 2 * pi);
      if (drawing) {
        path.moveTo(cx + rx * cos(angle), cy + ry * sin(angle));
        for (int i = 1; i <= segments; i++) {
          final t = angle + (endAngle - angle) * i / segments;
          path.lineTo(cx + rx * cos(t), cy + ry * sin(t));
        }
      }
      angle += seg * 2 * pi;
      drawing = !drawing;
    }
    canvas.drawPath(path, paint);
  }

  void _drawSortRegion(Canvas canvas, GameObject obj, Offset center, double ts,
      bool editMode) {
    final rawPoints = obj.properties['sortPoints'];
    final List<List<double>> points = [];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is List && p.length >= 2) {
          points.add([(p[0] as num).toDouble(), (p[1] as num).toDouble()]);
        }
      }
    }

    // Sort anchor Y position
    final anchorWorldY = center.dy + obj.sortAnchorY * ts;
    final linePaint = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.85) // amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fillPaint = Paint()
      ..color = const Color(0xFFFFB300).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final isCustomCollision =
        (obj.properties['blockShape'] as String? ?? '') == 'custom';

    // Always draw the sort anchor line (shows where the depth threshold is)
    _drawDashedHLine(canvas, center.dx - ts, center.dx + ts, anchorWorldY, linePaint);
    final tri = Path()
      ..moveTo(center.dx - 5, anchorWorldY - 4)
      ..lineTo(center.dx + 5, anchorWorldY - 4)
      ..lineTo(center.dx, anchorWorldY + 4)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFFFFB300).withOpacity(0.9));

    // If blockShape == 'custom', the polygon is already drawn in cyan as collision.
    // Only draw it in amber when it's a pure sort polygon (not used for collision).
    if (!isCustomCollision && points.isNotEmpty) {
      final worldPts = points.map((p) =>
          Offset(center.dx + p[0] * ts, center.dy + p[1] * ts)).toList();
      if (worldPts.length >= 2) {
        final polyPath = Path()..moveTo(worldPts.first.dx, worldPts.first.dy);
        for (int i = 1; i < worldPts.length; i++) {
          polyPath.lineTo(worldPts[i].dx, worldPts[i].dy);
        }
        polyPath.close();
        canvas.drawPath(polyPath, fillPaint);
        canvas.drawPath(polyPath, linePaint);
      }
      for (final pt in worldPts) {
        canvas.drawCircle(pt, editMode ? 5.0 : 3.0, Paint()
          ..color = const Color(0xFFFFB300).withOpacity(editMode ? 0.9 : 0.7));
        canvas.drawCircle(pt, editMode ? 5.0 : 3.0, linePaint);
      }
    }
  }

  void _drawDashedHLine(Canvas canvas, double x1, double x2, double y, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final path = Path();
    double x = x1;
    bool drawing = true;
    while (x < x2) {
      final end = (x + (drawing ? dash : gap)).clamp(x1, x2);
      if (drawing) { path.moveTo(x, y); path.lineTo(end, y); }
      x = end;
      drawing = !drawing;
    }
    canvas.drawPath(path, paint);
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
    canvas.scale(flipH ? -1.0 : 1.0, flipV ? -1.0 : 1.0);
    final drawW = image.width.toDouble() * scale;
    final drawH = image.height.toDouble() * scale;
    canvas.drawImageRect(
      image, src,
      Rect.fromCenter(center: Offset.zero, width: drawW, height: drawH),
      Paint(),
    );
    canvas.restore();
  }
}
