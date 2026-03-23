import 'dart:math' show max, min;
import 'dart:ui' as ui;
import '../models/game_effect.dart';
import '../models/item_def.dart';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Viewport;
import '../models/game_object.dart';
import '../models/map_data.dart';
import '../models/tileset_def.dart';
import '../services/sprite_cache.dart';
import 'components/grid_component.dart';
import 'components/objects_component.dart';
import 'editor_state.dart';
import 'play_session.dart';

/// Snapshot of tile data copied from a rectangular map region (single layer).
class TileRegionData {
  final int width, height;
  final List<List<int>> tileColors;
  final List<List<TileCell?>> layerCells; // cells from the active layer
  final List<List<int>> collision;
  final int layerIndex; // which layer these cells belong to

  TileRegionData({
    required this.width,
    required this.height,
    required this.tileColors,
    required this.layerCells,
    required this.collision,
    required this.layerIndex,
  });
}

class EditorGame extends FlameGame with ScrollDetector {
  final MapData mapData;
  final SpriteCache spriteCache;

  CameraComponent? _camera;
  World? _world;
  GridComponent? _gridComponent;
  ObjectsComponent? _objectsComponent;

  PlaySession? _playSession;
  PlayRenderer? _playRenderer;
  List<GameObject>? _savedObjects; // restored on stop
  bool _userShowGrid = true;

  // Viewport (set at startPlay, cleared at stopPlay)
  int _vpW = 0, _vpH = 0;

  // Play mode HUD callbacks — set by CenterCanvas
  void Function(int health, int score, int coins, int gems, int items)? onHudUpdate;
  void Function(String msg)? onMessage;
  void Function(String event)? onGameEvent;
  void Function(String? name)? onEquippedItemChanged;

  bool allowGameZoom = false;    // set from project.allowZoom before startPlay
  double gameMaxZoom = 2.0;     // set from project.maxZoom before startPlay
  bool allowCameraFollow = true; // set from project.cameraFollow before startPlay
  bool pixelArt = true;          // set from project.pixelArt before startPlay

  EditorGame({required this.mapData, required this.spriteCache});

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {
    final world = World();
    _world = world;

    final camera = CameraComponent(world: world);
    camera.viewfinder.anchor = Anchor.topLeft;

    final mapPixelW = mapData.width * mapData.tileSize.toDouble();
    final mapPixelH = mapData.height * mapData.tileSize.toDouble();
    camera.viewfinder.position = Vector2(
      -canvasSize.x / 2 + mapPixelW / 2,
      -canvasSize.y / 2 + mapPixelH / 2,
    );

    final gridComp = GridComponent(mapData: mapData, spriteCache: spriteCache);
    final objectsComp = ObjectsComponent(mapData: mapData, spriteCache: spriteCache);

    await addAll([world, camera]);
    await world.add(gridComp);
    await world.add(objectsComp);

    _camera = camera;
    _gridComponent = gridComp;
    _gridComponent!.camera = camera; // needed for pixel-perfect tile snapping
    _gridComponent!.pixelArt = pixelArt;
    _objectsComponent = objectsComp;
  }

  // ─── Play Mode ───────────────────────────────────────────────────────────────

  Future<void> startPlay({int viewportWidth = 0, int viewportHeight = 0, List<dynamic>? effects, List<dynamic>? items, Map<String, String>? keyBindings, double playerSpeed = 4.0}) async {
    if (_world == null || _camera == null) return;
    _vpW = viewportWidth;
    _vpH = viewportHeight;

    // Save objects so we can restore them on stop
    _savedObjects = mapData.objects
        .map((o) => GameObject(
              id: o.id,
              type: o.type,
              tileX: o.tileX,
              tileY: o.tileY,
              name: o.name,
              flipH: o.flipH,
              flipV: o.flipV,
              scale: o.scale,
              rotation: o.rotation,
              hidden: o.hidden,
              alpha: o.alpha,
              tag: o.tag,
              floatEnabled: o.floatEnabled,
              floatAmplitude: o.floatAmplitude,
              floatSpeed: o.floatSpeed,
              projectileEnabled: o.projectileEnabled,
              projectileAngle: o.projectileAngle,
              projectileSpeed: o.projectileSpeed,
              projectileRange: o.projectileRange,
              projectileArc: o.projectileArc,
              dashEnabled: o.dashEnabled,
              dashAngle: o.dashAngle,
              dashDistance: o.dashDistance,
              dashSpeed: o.dashSpeed,
              dashInterval: o.dashInterval,
              zOrder: o.zOrder,
              offsetX: o.offsetX,
              offsetY: o.offsetY,
              sortAnchorY: o.sortAnchorY,
              useAnimation: o.useAnimation,
              variantIndex: o.variantIndex,
              properties: Map<String, dynamic>.from(o.properties),
            ))
        .toList();

    // Hide editor overlays (save user's grid preference, always hide in play)
    _gridComponent?.showGrid = false;
    _gridComponent?.showViewport = false;
    _objectsComponent?.hidden = true;
    _objectsComponent?.stopAllPreviews();

    // Save camera state
    _savedCameraPos = _camera!.viewfinder.position.clone();
    _savedZoom = _camera!.viewfinder.zoom;

    final ts = mapData.tileSize.toDouble();
    final mapW = mapData.width * ts;
    final mapH = mapData.height * ts;
    final minZ = max(canvasSize.x / mapW, canvasSize.y / mapH);
    final maxZ = max(minZ, gameMaxZoom);
    if (_vpW > 0 && _vpH > 0) {
      // Derive zoom from canvas/viewport ratio instead of FixedResolutionViewport.
      // FixedResolutionViewport adds a non-integer scale factor (canvas/vpW) on top
      // of the world render, which maps tile boundaries to fractional screen pixels
      // and causes visible gaps between tiles. By computing zoom directly from the
      // canvas and target resolution, world→screen mapping stays integer-friendly.
      final vpZoom = min(canvasSize.x / _vpW.toDouble(), canvasSize.y / _vpH.toDouble());
      _camera!.viewfinder.zoom = vpZoom.clamp(minZ, maxZ);
    } else {
      final adaptive = canvasSize.y / (ts * 10.0);
      _camera!.viewfinder.zoom = adaptive.clamp(minZ, maxZ);
    }

    // Create play session as plain Dart class (no Component lifecycle)
    _playSession = PlaySession(
      mapData: mapData,
      spriteCache: spriteCache,
      rules: List.from(mapData.rules),
      effects: effects?.cast<GameEffect>() ?? [],
      items: items?.cast<ItemDef>() ?? [],
      keyBindings: keyBindings ?? {},
      playerSpeed: playerSpeed,
      onHudUpdate: (h, s, c, g, i) => onHudUpdate?.call(h, s, c, g, i),
      onMessage: (msg) => onMessage?.call(msg),
      onGameEvent: (event) => onGameEvent?.call(event),
      onEquippedItemChanged: (name) => onEquippedItemChanged?.call(name),
    );
    _playSession!.init();

    // Add a render-only Component to the World for world-space drawing
    _playRenderer = PlayRenderer()
      ..session = _playSession
      ..camera = _camera;
    await _world!.add(_playRenderer!);
  }

  Vector2? _savedCameraPos;
  double? _savedZoom;

  void stopPlay() {
    _playRenderer?.removeFromParent();
    _playRenderer = null;
    _playSession = null;

    // Restore editor overlays
    _gridComponent?.showGrid = _userShowGrid;
    _gridComponent?.showViewport = true;
    _objectsComponent?.hidden = false;
    _objectsComponent?.resetClock();

    // Restore objects removed during play (coins picked up, etc.)
    if (_savedObjects != null) {
      mapData.objects
        ..clear()
        ..addAll(_savedObjects!);
      _savedObjects = null;
    }

    // Restore camera
    if (_camera != null) {
      if (_savedCameraPos != null) {
        _camera!.viewfinder.position = _savedCameraPos!;
        _savedCameraPos = null;
      }
      _camera!.viewfinder.zoom = _savedZoom ?? 1.0;
      _savedZoom = null;
    }
    _vpW = 0;
    _vpH = 0;
  }

  void setShowGrid(bool value) {
    _userShowGrid = value;
    if (_playSession == null) _gridComponent?.showGrid = value;
  }

  void setShowCollision(bool value) {
    _gridComponent?.showCollision = value;
  }

  void setPixelArt(bool value) {
    pixelArt = value;
    _gridComponent?.pixelArt = value;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_playSession != null) {
      try {
        _playSession!.update(dt);
      } catch (e, st) {
        print('[GAME] PlaySession.update() threw: $e\n$st');
      }
      if (allowCameraFollow) _followPlayer();
    }
  }

  void _followPlayer() {
    if (_camera == null || _playSession == null) return;
    final cam = _camera!;
    final z = cam.viewfinder.zoom;
    final ts = mapData.tileSize.toDouble();
    final mapW = mapData.width * ts;
    final mapH = mapData.height * ts;

    // Visible world area = canvas / zoom (zoom already encodes the viewport resolution)
    final visW = canvasSize.x / z;
    final visH = canvasSize.y / z;

    double cx = _playSession!.playerPos.x - visW / 2;
    double cy = _playSession!.playerPos.y - visH / 2;

    cx = cx.clamp(0, (mapW - visW).clamp(0.0, mapW));
    cy = cy.clamp(0, (mapH - visH).clamp(0.0, mapH));

    // Snap to pixel grid to prevent sub-pixel tile seams
    final snap = 1.0 / z;
    cx = (cx / snap).roundToDouble() * snap;
    cy = (cy / snap).roundToDouble() * snap;

    cam.viewfinder.position = Vector2(
      cx + _playSession!.cameraShakeX,
      cy + _playSession!.cameraShakeY,
    );
  }

  // ─── Camera ─────────────────────────────────────────────────────────────────

  @override
  void onScroll(PointerScrollInfo info) {
    if (_camera == null) return;
    if (_playSession != null) {
      // In play mode: only zoom if the project allows it
      if (!allowGameZoom) return;
      final ts2 = mapData.tileSize.toDouble();
      final mapW2 = mapData.width * ts2;
      final mapH2 = mapData.height * ts2;
      final minZoom = max(canvasSize.x / mapW2, canvasSize.y / mapH2);
      final maxZoom = max(minZoom, gameMaxZoom);
      _camera!.viewfinder.zoom =
          (_camera!.viewfinder.zoom * (info.scrollDelta.global.y < 0 ? 1.1 : 0.9))
              .clamp(minZoom, maxZoom);
      return;
    }
    // Editor mode: always allow zoom
    final factor = info.scrollDelta.global.y < 0 ? 1.1 : 0.9;
    _camera!.viewfinder.zoom =
        (_camera!.viewfinder.zoom * factor).clamp(0.15, 8.0);
  }

  void pan(Offset screenDelta) {
    if (_camera == null || _playSession != null) return;
    _camera!.viewfinder.position += Vector2(
      screenDelta.dx / _camera!.viewfinder.zoom,
      screenDelta.dy / _camera!.viewfinder.zoom,
    );
  }

  double get currentZoom => _camera?.viewfinder.zoom ?? 1.0;
  CameraComponent? get editorCamera => _camera;
  ObjectsComponent? get objectsComponent => _objectsComponent;
  PlaySession? get playSession => _playSession;

  void zoomBy(double factor) {
    if (_camera == null) return;
    _camera!.viewfinder.zoom =
        (_camera!.viewfinder.zoom * factor).clamp(0.15, 8.0);
  }

  // ─── Coordinates ────────────────────────────────────────────────────────────

  (int, int)? screenToTile(Offset screenPos) {
    if (_camera == null) return null;
    final cam = _camera!;
    final worldX =
        cam.viewfinder.position.x + screenPos.dx / cam.viewfinder.zoom;
    final worldY =
        cam.viewfinder.position.y + screenPos.dy / cam.viewfinder.zoom;
    final tx = (worldX / mapData.tileSize).floor();
    final ty = (worldY / mapData.tileSize).floor();
    if (!mapData.inBounds(tx, ty)) return null;
    return (tx, ty);
  }

  /// Converts tile grid coords to canvas screen position (top-left of that tile).
  Offset? tileToScreen(int tx, int ty) {
    if (_camera == null) return null;
    final cam = _camera!;
    final worldX = tx * mapData.tileSize.toDouble();
    final worldY = ty * mapData.tileSize.toDouble();
    return Offset(
      (worldX - cam.viewfinder.position.x) * cam.viewfinder.zoom,
      (worldY - cam.viewfinder.position.y) * cam.viewfinder.zoom,
    );
  }

  // ─── Tile Painting ──────────────────────────────────────────────────────────

  void paintTile(Offset screenPos, Color color, {int layerIndex = 0}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    mapData.setLayerColor(layerIndex, tile.$1, tile.$2, color.value);
  }

  /// Erases the active layer cell at [screenPos].
  void eraseTile(Offset screenPos, {int layerIndex = 0}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    mapData.setTileColor(tile.$1, tile.$2, 0); // also clear legacy color
    mapData.setLayerCell(layerIndex, tile.$1, tile.$2, null);
  }

  void floodFill(Offset screenPos, Color color, {int layerIndex = 0}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    mapData.floodFillLayerColor(tile.$1, tile.$2, color.value, layerIndex: layerIndex);
  }

  void fillRect(Offset startScreen, Offset endScreen, Color color, {int layerIndex = 0}) {
    final a = screenToTile(startScreen);
    final b = screenToTile(endScreen);
    if (a == null || b == null) return;
    mapData.fillRectLayerColor(a.$1, a.$2, b.$1, b.$2, color.value, layerIndex: layerIndex);
  }

  /// Erases all base tile colors AND clears all cells across every layer.
  void eraseAllLayers() {
    mapData.fillAll(0);
    for (int li = 0; li < mapData.layers.length; li++) {
      for (int ty = 0; ty < mapData.height; ty++) {
        for (int tx = 0; tx < mapData.width; tx++) {
          mapData.setLayerCell(li, tx, ty, null);
        }
      }
    }
  }

  void fillAll(Color color) {
    mapData.fillAll(color.value);
  }

  // ─── Tileset Brush Painting ──────────────────────────────────────────────────

  /// Stamps the full brush region onto the map with its top-left at [screenPos].
  void paintTilesetBrush(Offset screenPos, TilesetBrush brush, {int layerIndex = 0}) {
    final anchor = screenToTile(screenPos);
    if (anchor == null) return;
    for (int dy = 0; dy < brush.height; dy++) {
      for (int dx = 0; dx < brush.width; dx++) {
        final tx = anchor.$1 + dx;
        final ty = anchor.$2 + dy;
        mapData.setLayerCell(layerIndex, tx, ty, brush.cellAt(dx, dy));
      }
    }
  }

  void floodFillTileset(Offset screenPos, TilesetBrush brush, {int layerIndex = 0}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    mapData.floodFillTileset(tile.$1, tile.$2, brush.cellAt(0, 0), layerIndex: layerIndex);
  }

  void fillRectTileset(Offset startScreen, Offset endScreen, TilesetBrush brush, {int layerIndex = 0}) {
    final a = screenToTile(startScreen);
    final b = screenToTile(endScreen);
    if (a == null || b == null) return;
    final minX = a.$1 < b.$1 ? a.$1 : b.$1;
    final maxX = a.$1 < b.$1 ? b.$1 : a.$1;
    final minY = a.$2 < b.$2 ? a.$2 : b.$2;
    final maxY = a.$2 < b.$2 ? b.$2 : a.$2;
    for (int ty = minY; ty <= maxY; ty++) {
      for (int tx = minX; tx <= maxX; tx++) {
        if (!mapData.inBounds(tx, ty)) continue;
        final dx = (tx - minX) % brush.width;
        final dy = (ty - minY) % brush.height;
        mapData.setLayerCell(layerIndex, tx, ty, brush.cellAt(dx, dy));
      }
    }
  }

  void fillAllTileset(TilesetBrush brush, {int layerIndex = 0}) {
    for (int ty = 0; ty < mapData.height; ty++) {
      for (int tx = 0; tx < mapData.width; tx++) {
        final dx = tx % brush.width;
        final dy = ty % brush.height;
        mapData.setLayerCell(layerIndex, tx, ty, brush.cellAt(dx, dy));
      }
    }
  }

  // ─── Tile Region Selection (cut/move/erase) ──────────────────────────────────

  /// Snapshot of tile data for a rectangular region (tileColors + active layer cells).
  TileRegionData copyRegion(int x1, int y1, int x2, int y2, {int layerIndex = 0}) {
    final w = x2 - x1 + 1;
    final h = y2 - y1 + 1;
    return TileRegionData(
      width: w,
      height: h,
      layerIndex: layerIndex,
      tileColors: List.generate(h, (dy) =>
          List.generate(w, (dx) => mapData.tileColors[y1 + dy][x1 + dx])),
      layerCells: List.generate(h, (dy) =>
          List.generate(w, (dx) => mapData.getLayerCell(layerIndex, x1 + dx, y1 + dy))),
      collision: List.generate(h, (dy) =>
          List.generate(w, (dx) => mapData.tileCollision[y1 + dy][x1 + dx])),
    );
  }

  void eraseRegion(int x1, int y1, int x2, int y2, {int layerIndex = 0}) {
    for (int ty = y1; ty <= y2; ty++) {
      for (int tx = x1; tx <= x2; tx++) {
        if (!mapData.inBounds(tx, ty)) continue;
        mapData.tileColors[ty][tx] = 0;
        mapData.setLayerCell(layerIndex, tx, ty, null);
      }
    }
  }

  void pasteRegion(TileRegionData data, int destX, int destY) {
    for (int dy = 0; dy < data.height; dy++) {
      for (int dx = 0; dx < data.width; dx++) {
        final tx = destX + dx;
        final ty = destY + dy;
        if (!mapData.inBounds(tx, ty)) continue;
        mapData.tileColors[ty][tx] = data.tileColors[dy][dx];
        mapData.setLayerCell(data.layerIndex, tx, ty, data.layerCells[dy][dx]);
        mapData.tileCollision[ty][tx] = data.collision[dy][dx];
      }
    }
  }

  // ─── Collision Toggle ────────────────────────────────────────────────────────
  // Call with button: 0=left(force passable), 1=right(force solid); toggles back to 0 on repeat

  void toggleCollision(Offset screenPos, {bool leftButton = true}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    final current = mapData.getTileCollision(tile.$1, tile.$2);
    if (leftButton) {
      // left click: 0→2 (force solid/red), 2→0 (reset)
      mapData.setTileCollision(tile.$1, tile.$2, current == 2 ? 0 : 2);
    } else {
      // right click: 0→1 (force passable/cyan), 1→0 (reset)
      mapData.setTileCollision(tile.$1, tile.$2, current == 1 ? 0 : 1);
    }
  }

  void paintCollision(Offset screenPos, {required bool leftButton}) {
    final cam = editorCamera;
    if (cam == null) return;
    final ts = mapData.tileSize.toDouble();
    final wx = cam.viewfinder.position.x + screenPos.dx / cam.viewfinder.zoom;
    final wy = cam.viewfinder.position.y + screenPos.dy / cam.viewfinder.zoom;
    final tx = (wx / ts).floor().clamp(0, mapData.width - 1);
    final ty = (wy / ts).floor().clamp(0, mapData.height - 1);
    if (leftButton) {
      mapData.setTileCollision(tx, ty, 2); // always SET, never toggle
    } else {
      mapData.setTileCollision(tx, ty, 0); // always CLEAR, never toggle
    }
  }

  // ─── Object Placement ───────────────────────────────────────────────────────

  GameObject? placeObject(Offset screenPos, GameObjectType type, EditorState es,
      {GameObject? inheritFrom}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return null;

    es.pushUndo();

    if (type.isUnique) {
      // Move the existing unique object rather than deleting and recreating —
      // this preserves its scale, rotation, flip, and custom properties.
      final existing =
          mapData.objects.where((o) => o.type == type).firstOrNull;
      if (existing != null) {
        mapData.objects.removeWhere(
            (o) => o != existing && o.tileX == tile.$1 && o.tileY == tile.$2);
        existing.tileX = tile.$1;
        existing.tileY = tile.$2;
        return existing;
      }
    }

    mapData.objects.removeWhere(
        (o) => o.tileX == tile.$1 && o.tileY == tile.$2);

    // Inherit transforms from the previously selected object of the same type
    // so that placing multiple similar objects feels consistent.
    final ref = inheritFrom?.type == type ? inheritFrom : null;
    final obj = GameObject(
      type: type,
      tileX: tile.$1,
      tileY: tile.$2,
      name: _autoName(type, es.selectedVariantIndex[type] ?? 0),
      scale: ref?.scale ?? 1.0,
      rotation: ref?.rotation ?? 0.0,
      flipH: ref?.flipH ?? false,
      flipV: ref?.flipV ?? false,
      useAnimation: false, // set via instance properties in right panel if needed
      variantIndex: es.selectedVariantIndex[type] ?? 0,
    );
    mapData.objects.add(obj);
    return obj;
  }

  /// Returns the topmost object whose sprite AABB contains the screen position.
  /// Water-body objects use tile-based hit-testing (they fill exactly one tile).
  GameObject? objectAt(Offset screenPos) {
    if (_camera == null) return null;
    final cam = _camera!;
    final ts = mapData.tileSize.toDouble();
    final wx = cam.viewfinder.position.x + screenPos.dx / cam.viewfinder.zoom;
    final wy = cam.viewfinder.position.y + screenPos.dy / cam.viewfinder.zoom;

    // Water bodies: tile-based
    final tx = (wx / ts).floor();
    final ty = (wy / ts).floor();
    for (final obj in mapData.objects.reversed) {
      if (obj.type == GameObjectType.waterBody &&
          obj.tileX == tx && obj.tileY == ty) return obj;
    }

    // All other objects: AABB using actual sprite dimensions.
    // Iterate in reverse render order so the topmost sprite is checked first.
    final sorted = mapData.objects
        .where((o) => o.type != GameObjectType.waterBody)
        .toList()
      ..sort((a, b) {
          final zCmp = a.zOrder.compareTo(b.zOrder);
          if (zCmp != 0) return zCmp;
          return mapData.ySortEnabled ? a.tileY.compareTo(b.tileY) : 0;
        });
    for (final obj in sorted.reversed) {
      final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
      ui.Image? img;
      if (obj.useAnimation && spriteCache.isAnimated(obj.type, obj.variantIndex)) {
        final animName = spriteCache.defaultAnim(obj.type, obj.variantIndex);
        if (animName.isNotEmpty &&
            spriteCache.animFrameCount(obj.type, obj.variantIndex, animName) > 0) {
          img = spriteCache.getAnimFrame(obj.type, obj.variantIndex, animName, 0);
        }
      }
      img ??= spriteCache.getImage(obj.type);
      final halfW = (img != null ? img.width * obj.scale : ts) / 2;
      final halfH = (img != null ? img.height * obj.scale : ts) / 2;
      if (wx >= cx - halfW && wx <= cx + halfW &&
          wy >= cy - halfH && wy <= cy + halfH) {
        return obj;
      }
    }
    return null;
  }

  void removeObjectAt(Offset screenPos, EditorState es) {
    final obj = objectAt(screenPos);
    if (obj == null) return;
    es.pushUndo();
    mapData.objects.remove(obj);
  }

  /// Duplicates [src], placing the copy one tile to the right (or below if at
  /// the map edge). Returns the new object so the caller can select it.
  GameObject duplicateObject(GameObject src, EditorState es) {
    es.pushUndo();
    final newTileX = (src.tileX + 1).clamp(0, mapData.width  - 1);
    final newTileY = newTileX == src.tileX
        ? (src.tileY + 1).clamp(0, mapData.height - 1)
        : src.tileY;
    final copy = GameObject(
      type: src.type,
      tileX: newTileX,
      tileY: newTileY,
      name: _autoName(src.type, src.variantIndex),
      flipH: src.flipH,
      flipV: src.flipV,
      scale: src.scale,
      rotation: src.rotation,
      hidden: src.hidden,
      alpha: src.alpha,
      tag: src.tag,
      floatEnabled: src.floatEnabled,
      floatAmplitude: src.floatAmplitude,
      floatSpeed: src.floatSpeed,
      projectileEnabled: src.projectileEnabled,
      projectileLoop: src.projectileLoop,
      projectileAngle: src.projectileAngle,
      projectileSpeed: src.projectileSpeed,
      projectileRange: src.projectileRange,
      projectileArc: src.projectileArc,
      dashEnabled: src.dashEnabled,
      dashAngle: src.dashAngle,
      dashDistance: src.dashDistance,
      dashSpeed: src.dashSpeed,
      dashInterval: src.dashInterval,
      zOrder: src.zOrder,
      offsetX: src.offsetX,
      offsetY: src.offsetY,
      properties: Map<String, dynamic>.from(src.properties),
    );
    mapData.objects.add(copy);
    return copy;
  }

  String _autoName(GameObjectType type, [int variantIndex = 0]) {
    final base = mapData.getVariantName(type, variantIndex);
    final existing = mapData.objects.map((o) => o.name).toSet();
    int n = 1;
    while (existing.contains('$base $n')) n++;
    return '$base $n';
  }

  void setSelectedObject(String? id) {
    _objectsComponent?.selectedObjectId = id;
  }

  void startProjectilePreview(String id) => _objectsComponent?.startPreview(id);
  void stopProjectilePreview(String id) => _objectsComponent?.stopPreview(id);
  bool isProjectilePreviewing(String id) => _objectsComponent?.isPreviewing(id) ?? false;

  void previewEffect(double worldX, double worldY, GameEffect fx) {
    // Clear any running preview first so effects don't stack
    _objectsComponent?.stopAllPreviews();
    _objectsComponent?.spawnEffectPreview(worldX, worldY, fx, mapData.tileSize.toDouble());
  }

  void clearEffectPreview() => _objectsComponent?.stopAllPreviews();
}
