import 'dart:ui' as ui;
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../../models/game_object.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';

class GridComponent extends Component {
  final MapData mapData;
  final SpriteCache spriteCache;
  bool showGrid = true;
  bool showCollision = false;
  bool showViewport = true; // shows game-viewport boundary in edit mode
  bool pixelArt = true;    // nearest-neighbor filtering for crisp pixel art
  /// Set by EditorGame after onLoad so the renderer can snap tile edges to
  /// integer screen pixels using the live camera position and zoom.
  CameraComponent? camera;

  GridComponent({required this.mapData, required this.spriteCache});

  static final _gridLinePaint = Paint()
    ..color = const Color(0xFF333333)
    ..strokeWidth = 0.5
    ..style = PaintingStyle.stroke;

  static final _borderPaint = Paint()
    ..color = const Color(0xFF4A4A4A)
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;

  static final _passablePaint = Paint()
    ..color = const Color(0x9900CFFF);

  static final _solidPaint = Paint()
    ..color = const Color(0x99FF2222);

  static final _outsidePaint = Paint()
    ..color = const Color(0xAA000000);

  @override
  void render(Canvas canvas) {
    final ts = mapData.tileSize.toDouble();
    final w = mapData.width;
    final h = mapData.height;

    // pixelArt=true → nearest-neighbor (crisp, no blur at any zoom).
    // pixelArt=false → bilinear (smoother edges for non-pixel-art sprites).
    final tilePaint = Paint()
      ..filterQuality = pixelArt ? FilterQuality.none : FilterQuality.low;

    // ── Pixel-perfect tile snapping ────────────────────────────────────────
    // With Anchor.topLeft, the camera maps world → screen as:
    //   screen = (world − camPos) × zoom
    // Snapping a world coordinate to the nearest integer screen pixel and
    // converting back ensures every tile edge lands on an exact screen pixel.
    // Adjacent tiles call snapX for the same boundary world value, so they
    // receive the identical canvas coordinate → zero gap between tiles.
    final cam = camera;
    final z    = (cam?.viewfinder.zoom ?? 1.0).clamp(0.001, 100.0);
    final camX = cam?.viewfinder.position.x ?? 0.0;
    final camY = cam?.viewfinder.position.y ?? 0.0;

    // Snap to physical pixels (accounts for Windows DPI scaling e.g. 125%, 150%)
    final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    final zd = z * dpr;
    double snapX(double wx) => ((wx - camX) * zd).roundToDouble() / zd + camX;
    double snapY(double wy) => ((wy - camY) * zd).roundToDouble() / zd + camY;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final l = snapX(x * ts);
        final t = snapY(y * ts);
        final r = snapX((x + 1) * ts);
        final b = snapY((y + 1) * ts);
        final pr = Rect.fromLTRB(l, t, r, b);

        // 1. Base color tile layer
        final colorVal = mapData.getTileColor(x, y);
        if (colorVal != 0) {
          canvas.drawRect(pr, Paint()
            ..color = Color(colorVal)
            ..isAntiAlias = false);
        }

        // 2. Each visible tile layer, bottom-to-top
        for (final layer in mapData.layers) {
          if (!layer.visible) continue;
          final tsCell = layer.cells[y][x];
          if (tsCell == null) continue;
          if (tsCell.isColor) {
            canvas.drawRect(pr, Paint()
              ..color = Color(tsCell.colorArgb)
              ..isAntiAlias = false);
            continue;
          }
          final img = spriteCache.getTilesetImage(tsCell.tilesetId);
          if (img == null) {
            canvas.drawRect(pr, Paint()..color = const Color(0xFF444444));
            continue;
          }
          final def = mapData.tilesets
              .where((t) => t.id == tsCell.tilesetId)
              .firstOrNull;
          if (def == null) {
            canvas.drawRect(pr, Paint()..color = const Color(0xFF444444));
            continue;
          }
          final src = Rect.fromLTWH(
            tsCell.tileX * def.tileWidth.toDouble(),
            tsCell.tileY * def.tileHeight.toDouble(),
            def.tileWidth.toDouble(),
            def.tileHeight.toDouble(),
          );
          canvas.drawImageRect(img, src, pr, tilePaint);
        }

        // 3. Collision overlay
        if (showCollision) {
          final col = mapData.getTileCollision(x, y);
          if (col == 1) {
            canvas.drawRect(pr, _passablePaint);
          } else if (col == 2) {
            canvas.drawRect(pr, _solidPaint);
          }
        }
      }
    }

    if (showGrid) {
      for (int x = 0; x <= w; x++) {
        final sx = snapX(x * ts);
        canvas.drawLine(Offset(sx, snapY(0)), Offset(sx, snapY(h * ts)), _gridLinePaint);
      }
      for (int y = 0; y <= h; y++) {
        final sy = snapY(y * ts);
        canvas.drawLine(Offset(snapX(0), sy), Offset(snapX(w * ts), sy), _gridLinePaint);
      }
      canvas.drawRect(
        Rect.fromLTRB(snapX(0), snapY(0), snapX(w * ts), snapY(h * ts)),
        _borderPaint,
      );
    }

    // ── Viewport boundary overlay ────────────────────────────────────────
    if (showViewport && cam != null) {
      _renderViewportBoundary(canvas, ts, w, h, snapX, snapY, z, cam);
    }
  }

  void _renderViewportBoundary(
    Canvas canvas,
    double ts,
    int w,
    int h,
    double Function(double) snapX,
    double Function(double) snapY,
    double z,
    CameraComponent cam,
  ) {
    // Find player spawn object
    GameObject? spawn;
    for (final obj in mapData.objects) {
      if (obj.type == GameObjectType.playerSpawn) {
        spawn = obj;
        break;
      }
    }
    if (spawn == null) return;

    // Viewport size in world units (canvas pixels / zoom)
    final vpScreenW = cam.viewport.size.x;
    final vpScreenH = cam.viewport.size.y;
    if (vpScreenW <= 0 || vpScreenH <= 0) return;

    final vpW = vpScreenW / z;
    final vpH = vpScreenH / z;
    final mapW = w * ts;
    final mapH = h * ts;

    // Center viewport on player spawn tile center, clamped to map bounds
    final spawnCx = (spawn.tileX + 0.5) * ts;
    final spawnCy = (spawn.tileY + 0.5) * ts;

    double vpLeft = (spawnCx - vpW / 2).clamp(0.0, (mapW - vpW).clamp(0.0, mapW));
    double vpTop  = (spawnCy - vpH / 2).clamp(0.0, (mapH - vpH).clamp(0.0, mapH));
    final vpRight  = (vpLeft + vpW).clamp(0.0, mapW);
    final vpBottom = (vpTop  + vpH).clamp(0.0, mapH);

    // Snap viewport edges to the same grid for crisp rendering
    final sl = snapX(0),      sr = snapX(mapW);
    final st = snapY(0),      sb = snapY(mapH);
    final vl = snapX(vpLeft), vr = snapX(vpRight);
    final vt = snapY(vpTop),  vb = snapY(vpBottom);

    // Dark overlay on the four regions outside the viewport
    if (vpTop > 0)
      canvas.drawRect(Rect.fromLTRB(sl, st, sr, vt), _outsidePaint);
    if (vpBottom < mapH)
      canvas.drawRect(Rect.fromLTRB(sl, vb, sr, sb), _outsidePaint);
    if (vpLeft > 0)
      canvas.drawRect(Rect.fromLTRB(sl, vt, vl, vb), _outsidePaint);
    if (vpRight < mapW)
      canvas.drawRect(Rect.fromLTRB(vr, vt, sr, vb), _outsidePaint);

    // Gold viewport border
    canvas.drawRect(
      Rect.fromLTRB(vl, vt, vr, vb),
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 2.0 / z
        ..style = PaintingStyle.stroke,
    );

  }

}
