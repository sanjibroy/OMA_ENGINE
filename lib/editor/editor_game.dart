import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Viewport;
import '../models/game_object.dart';
import '../models/map_data.dart';
import '../services/sprite_cache.dart';
import 'components/grid_component.dart';
import 'components/objects_component.dart';
import 'editor_state.dart';
import 'play_session.dart';

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
  Viewport? _savedViewport;

  // Play mode HUD callbacks — set by CenterCanvas
  void Function(int health, int score)? onHudUpdate;
  void Function(String msg)? onMessage;
  void Function(String event)? onGameEvent;

  EditorGame({required this.mapData, required this.spriteCache});

  @override
  Color backgroundColor() => const Color(0xFF0F0F13);

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
    _objectsComponent = objectsComp;
  }

  // ─── Play Mode ───────────────────────────────────────────────────────────────

  Future<void> startPlay({int viewportWidth = 0, int viewportHeight = 0}) async {
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
            ))
        .toList();

    // Hide editor overlays (save user's grid preference, always hide in play)
    _gridComponent?.showGrid = false;
    _objectsComponent?.hidden = true;

    // Save camera state and apply viewport
    _savedCameraPos = _camera!.viewfinder.position.clone();
    _savedZoom = _camera!.viewfinder.zoom;
    _savedViewport = _camera!.viewport;

    if (_vpW > 0 && _vpH > 0) {
      _camera!.viewport = FixedResolutionViewport(
          resolution: Vector2(_vpW.toDouble(), _vpH.toDouble()));
      _camera!.viewfinder.zoom = 1.0;
    } else {
      _camera!.viewfinder.zoom = 2.0;
    }

    // Create play session as plain Dart class (no Component lifecycle)
    _playSession = PlaySession(
      mapData: mapData,
      spriteCache: spriteCache,
      rules: List.from(mapData.rules),
      onHudUpdate: (h, s) => onHudUpdate?.call(h, s),
      onMessage: (msg) => onMessage?.call(msg),
      onGameEvent: (event) => onGameEvent?.call(event),
    );
    _playSession!.init();

    // Add a render-only Component to the World for world-space drawing
    _playRenderer = PlayRenderer()..session = _playSession;
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
    _objectsComponent?.hidden = false;

    // Restore objects removed during play (coins picked up, etc.)
    if (_savedObjects != null) {
      mapData.objects
        ..clear()
        ..addAll(_savedObjects!);
      _savedObjects = null;
    }

    // Restore camera and viewport
    if (_camera != null) {
      if (_savedViewport != null) {
        _camera!.viewport = _savedViewport!;
        _savedViewport = null;
      }
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

  @override
  void update(double dt) {
    super.update(dt);
    if (_playSession != null) {
      try {
        _playSession!.update(dt);
      } catch (e, st) {
        print('[GAME] PlaySession.update() threw: $e\n$st');
      }
      _followPlayer();
    }
  }

  void _followPlayer() {
    if (_camera == null || _playSession == null) return;
    final cam = _camera!;
    final z = cam.viewfinder.zoom;
    final ts = mapData.tileSize.toDouble();
    final mapW = mapData.width * ts;
    final mapH = mapData.height * ts;

    // Use viewport dimensions if set, otherwise canvas size
    final visW = _vpW > 0 ? _vpW.toDouble() / z : canvasSize.x / z;
    final visH = _vpH > 0 ? _vpH.toDouble() / z : canvasSize.y / z;

    double cx = _playSession!.playerPos.x - visW / 2;
    double cy = _playSession!.playerPos.y - visH / 2;

    cx = cx.clamp(0, (mapW - visW).clamp(0.0, mapW));
    cy = cy.clamp(0, (mapH - visH).clamp(0.0, mapH));

    // Snap to pixel grid to prevent sub-pixel tile seams
    final snap = 1.0 / z;
    cx = (cx / snap).roundToDouble() * snap;
    cy = (cy / snap).roundToDouble() * snap;

    cam.viewfinder.position = Vector2(cx, cy);
  }

  // ─── Camera ─────────────────────────────────────────────────────────────────

  @override
  void onScroll(PointerScrollInfo info) {
    if (_camera == null || _playSession != null) return; // no zoom in play mode
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

  // ─── Tile Painting ──────────────────────────────────────────────────────────

  void paintTile(Offset screenPos, TileType type, {int variant = 0}) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    mapData.setTile(tile.$1, tile.$2, type, variant: variant);
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

  // ─── Object Placement ───────────────────────────────────────────────────────

  GameObject? placeObject(Offset screenPos, GameObjectType type, EditorState es) {
    final tile = screenToTile(screenPos);
    if (tile == null) return null;

    es.pushUndo();

    if (type.isUnique) {
      mapData.objects.removeWhere((o) => o.type == type);
    }
    mapData.objects.removeWhere(
        (o) => o.tileX == tile.$1 && o.tileY == tile.$2);

    final obj = GameObject(type: type, tileX: tile.$1, tileY: tile.$2);
    mapData.objects.add(obj);
    return obj;
  }

  GameObject? objectAt(Offset screenPos) {
    final tile = screenToTile(screenPos);
    if (tile == null) return null;
    try {
      return mapData.objects
          .firstWhere((o) => o.tileX == tile.$1 && o.tileY == tile.$2);
    } catch (_) {
      return null;
    }
  }

  void removeObjectAt(Offset screenPos, EditorState es) {
    final tile = screenToTile(screenPos);
    if (tile == null) return;
    es.pushUndo();
    mapData.objects
        .removeWhere((o) => o.tileX == tile.$1 && o.tileY == tile.$2);
  }

  void setSelectedObject(String? id) {
    _objectsComponent?.selectedObjectId = id;
  }
}
