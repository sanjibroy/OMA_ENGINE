import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../editor/editor_game.dart'; // needed for _ZoomControls type ref
import '../../editor/editor_state.dart';
import '../../models/game_object.dart';
import '../../theme/app_theme.dart';

class CenterCanvas extends StatefulWidget {
  final EditorState editorState;

  const CenterCanvas({super.key, required this.editorState});

  @override
  State<CenterCanvas> createState() => _CenterCanvasState();
}

class _CenterCanvasState extends State<CenterCanvas> {
  late final EditorGame _game;
  final FocusNode _gameFocusNode = FocusNode();

  bool _isPanning = false;
  bool _isPainting = false;
  bool _isErasing = false;
  Offset _lastPanPos = Offset.zero;
  Offset? _rectStart;   // screen pos where rectangle fill drag began
  Offset? _rectCurrent; // current drag pos (for preview)
  bool _lastRectErase = false;
  MouseCursor _cursor = SystemMouseCursors.precise;

  // ─── Select tool state ─────────────────────────────────────────────────────
  Offset? _selDragStart;      // screen pos where selection drag started
  Offset? _selDragCurrent;    // current drag pos (for in-progress selection rect)
  bool _isMovingSelection = false;
  Offset? _moveDragStart;
  (int, int)? _moveSelectionOrigin; // tile top-left when move began
  TileRegionData? _moveSnapshot;
  (int, int)? _lastMoveTile;  // last tile position during move drag
  (int, int)? _lastPastePos;  // top-left of currently painted move preview
  GameObject? _draggedObject;      // object currently being dragged
  bool _dragUndoPushed = false;    // undo pushed lazily on first tile change
  EditorTool? _prePlayTool;        // tool active before entering play mode

  // HUD state (updated by game callbacks)
  int _health = 100;
  int _score = 0;
  int _coins = 0;
  int _gems = 0;
  int _items = 0;
  String? _message;
  String? _equippedItemName;
  bool _isGameOver = false;
  bool _isWin = false;
  bool _debugCollision = false;

  EditorState get _state => widget.editorState;

  @override
  void initState() {
    super.initState();
    _game = _state.game;
    _game.onHudUpdate = (h, s, c, g, i) => setState(() {
          _health = h;
          _score = s;
          _coins = c;
          _gems = g;
          _items = i;
        });
    _game.onEquippedItemChanged = (name) => setState(() => _equippedItemName = name);
    _game.onMessage = (msg) {
      setState(() => _message = msg);
      // Auto-clear message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _message = null);
      });
    };
    _game.onGameEvent = _handleGameEvent;

    _state.isPlayMode.addListener(_onPlayModeChanged);
    _state.showGrid.addListener(_onShowGridChanged);
    _state.activeTool.addListener(_onActiveToolChanged);
    _state.projectChanged.addListener(_onProjectChanged);
    _state.sortEditMode.addListener(_onSortEditModeChanged);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _state.isPlayMode.removeListener(_onPlayModeChanged);
    _state.showGrid.removeListener(_onShowGridChanged);
    _state.activeTool.removeListener(_onActiveToolChanged);
    _state.projectChanged.removeListener(_onProjectChanged);
    _state.sortEditMode.removeListener(_onSortEditModeChanged);
    _game.onHudUpdate = null;
    _game.onMessage = null;
    _game.onGameEvent = null;
    _game.onEquippedItemChanged = null;
    _gameFocusNode.dispose();
    super.dispose();
  }

  void _onProjectChanged() => setState(() {});

  void _onShowGridChanged() {
    _game.setShowGrid(_state.showGrid.value);
  }

  void _onActiveToolChanged() {
    _game.setShowCollision(_state.activeTool.value == EditorTool.collision);
    if (_state.activeTool.value != EditorTool.select) {
      _state.selectedMapRegion.value = null;
      setState(() {
        _selDragStart = null;
        _selDragCurrent = null;
        _isMovingSelection = false;
        _moveSnapshot = null;
      });
    }
  }

  void _onSortEditModeChanged() {
    _game.objectsComponent?.sortEditMode = _state.sortEditMode.value;
    setState(() {});
  }

  void _onPlayModeChanged() {
    if (_state.isPlayMode.value) {
      _prePlayTool = _state.activeTool.value;
      _state.sortEditMode.value = false;
      setState(() {
        _health = 100;
        _score = 0;
        _coins = 0;
        _gems = 0;
        _items = 0;
        _message = null;
        _isGameOver = false;
        _isWin = false;
        _equippedItemName = null;
      });
      _game.setShowCollision(false); // hide collision overlay during play
      _game.allowGameZoom = _state.project.allowZoom;
      _game.gameMaxZoom = _state.project.maxZoom;
      _game.allowCameraFollow = _state.project.cameraFollow;
      _game.setPixelArt(_state.project.pixelArt);
      _game.startPlay(
        viewportWidth: _state.project.viewportWidth,
        viewportHeight: _state.project.viewportHeight,
        effects: _state.project.effects,
        items: _state.project.items,
        keyBindings: _state.project.keyBindings,
        playerSpeed: _state.project.playerSpeed,
      );
      // Delay so panel rebuilds finish before we steal focus
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _gameFocusNode.requestFocus();
      });
    } else {
      _game.stopPlay();
      _state.audioManager.stopAll();
      // Clear stale selection — stopPlay() replaces mapData.objects with new
      // instances, so selectedObject would point to a dead reference.
      _state.selectedObject.value = null;
      _game.setSelectedObject(null);
      // Restore the tool that was active before entering play mode.
      _state.activeTool.value = _prePlayTool ?? EditorTool.tile;
      _prePlayTool = null;
      _game.setShowCollision(false);
      setState(() {
        _cursor = SystemMouseCursors.precise;
        _debugCollision = false;
      });
    }
  }

  void _handleGameEvent(String event) {
    if (event == 'gameOver') {
      setState(() => _isGameOver = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _state.isPlayMode.value = false;
      });
    } else if (event == 'win') {
      setState(() => _isWin = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _state.isPlayMode.value = false;
      });
    } else if (event.startsWith('loadMap:')) {
      final mapName = event.substring('loadMap:'.length).trim();
      _transitionToMap(mapName);
    } else if (event.startsWith('playMusic:')) {
      final name = event.substring('playMusic:'.length).trim();
      final path = _state.project.musicPaths[name];
      if (path != null) _state.audioManager.playMusic(path);
    } else if (event.startsWith('playSfx:')) {
      final name = event.substring('playSfx:'.length).trim();
      final path = _state.project.sfxPaths[name];
      if (path != null) _state.audioManager.playSfx(path);
    } else if (event == 'stopMusic') {
      _state.audioManager.stopMusic();
    }
  }

  Future<void> _transitionToMap(String mapName) async {
    // Find target map by name (case-insensitive)
    final maps = _state.project.maps;
    final target = maps.cast<dynamic>().firstWhere(
          (m) => (m.name as String).toLowerCase() == mapName.toLowerCase(),
          orElse: () => null,
        );
    if (target == null) {
      _game.onMessage?.call('Map "$mapName" not found');
      return;
    }

    // Stop current play session (restores original map objects)
    _game.stopPlay();

    // Switch to new map in-place (mutates mapData)
    await _state.switchToMap(target.id as String);

    if (!mounted) return;

    // Reset HUD and restart play on the new map
    setState(() {
      _health = 100;
      _score = 0;
      _coins = 0;
      _gems = 0;
      _items = 0;
      _message = null;
      _isGameOver = false;
      _isWin = false;
      _equippedItemName = null;
    });

    await _game.startPlay(
      viewportWidth: _state.project.viewportWidth,
      viewportHeight: _state.project.viewportHeight,
      effects: _state.project.effects,
      items: _state.project.items,
      keyBindings: _state.project.keyBindings,
    );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _gameFocusNode.requestFocus();
    });
  }

  // ─── Select tool helpers ───────────────────────────────────────────────────

  bool _isTileInSelection(int tx, int ty) {
    final sel = _state.selectedMapRegion.value;
    if (sel == null) return false;
    return tx >= sel.$1 && tx <= sel.$3 && ty >= sel.$2 && ty <= sel.$4;
  }

  void _clearSelection() {
    _state.selectedMapRegion.value = null;
    setState(() {
      _selDragStart = null;
      _selDragCurrent = null;
      _isMovingSelection = false;
      _moveDragStart = null;
      _moveSelectionOrigin = null;
      _moveSnapshot = null;
      _lastMoveTile = null;
      _lastPastePos = null;
    });
  }

  void _deleteSelection() {
    final sel = _state.selectedMapRegion.value;
    if (sel == null) return;
    _state.pushUndo();
    _game.eraseRegion(sel.$1, sel.$2, sel.$3, sel.$4,
        layerIndex: _state.activeLayerIndex.value);
    _state.notifyMapChanged();
    _clearSelection();
  }

  bool _onHardwareKey(KeyEvent event) {
    if (_state.isPlayMode.value) return false;
    if (_state.activeTool.value != EditorTool.select) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _deleteSelection();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clearSelection();
      return true;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_state.isPlayMode.value) {
      _gameFocusNode.requestFocus(); // ensure keys work after clicking canvas
      return;
    }

    if (e.buttons == kMiddleMouseButton) {
      _isPanning = true;
      _lastPanPos = e.localPosition;
      return;
    }

    final tool = _state.activeTool.value;

    if (tool == EditorTool.tile) {
      final brush = _state.selectedBrush.value;
      if (e.buttons == kPrimaryMouseButton) {
        _state.pushUndo();
        _isPainting = true;
        if (brush != null) {
          _game.paintTilesetBrush(e.localPosition, brush,
              layerIndex: _state.activeLayerIndex.value);
        } else {
          _game.paintTile(e.localPosition, _state.selectedPaintColor.value,
              layerIndex: _state.activeLayerIndex.value);
        }
      } else if (e.buttons == kSecondaryMouseButton) {
        _state.pushUndo();
        _isErasing = true;
        _game.eraseTile(e.localPosition, layerIndex: _state.activeLayerIndex.value);
      }
    } else if (tool == EditorTool.fill) {
      final brush = _state.selectedBrush.value;
      if (e.buttons == kPrimaryMouseButton) {
        _state.pushUndo();
        if (brush != null) {
          _game.floodFillTileset(e.localPosition, brush,
              layerIndex: _state.activeLayerIndex.value);
        } else {
          _game.floodFill(e.localPosition, _state.selectedPaintColor.value,
              layerIndex: _state.activeLayerIndex.value);
        }
        _state.notifyMapChanged();
      } else if (e.buttons == kSecondaryMouseButton) {
        _state.pushUndo();
        _game.floodFill(e.localPosition, const Color(0x00000000),
            layerIndex: _state.activeLayerIndex.value);
        _state.notifyMapChanged();
      }
    } else if (tool == EditorTool.erase) {
      if (e.buttons == kPrimaryMouseButton) {
        _state.pushUndo();
        _isErasing = true;
        _game.eraseTile(e.localPosition, layerIndex: _state.activeLayerIndex.value);
      }
    } else if (tool == EditorTool.rect) {
      if (e.buttons == kPrimaryMouseButton) {
        _rectStart = e.localPosition;
        _lastRectErase = false;
      } else if (e.buttons == kSecondaryMouseButton) {
        _rectStart = e.localPosition;
        _lastRectErase = true;
      }
    } else if (tool == EditorTool.collision) {
      _state.pushUndo();
      if (e.buttons == kPrimaryMouseButton) {
        _game.toggleCollision(e.localPosition, leftButton: true);
      } else if (e.buttons == kSecondaryMouseButton) {
        _game.toggleCollision(e.localPosition, leftButton: false);
      }
      _state.notifyMapChanged();
    } else if (tool == EditorTool.select) {
      if (e.buttons == kPrimaryMouseButton) {
        final tile = _game.screenToTile(e.localPosition);
        final sel = _state.selectedMapRegion.value;
        if (tile != null && sel != null && _isTileInSelection(tile.$1, tile.$2)) {
          // Begin moving the existing selection
          _isMovingSelection = true;
          _moveDragStart = e.localPosition;
          _moveSelectionOrigin = (sel.$1, sel.$2);
          _lastMoveTile = tile;
          _state.pushUndo();
          final li = _state.activeLayerIndex.value;
          _moveSnapshot = _game.copyRegion(sel.$1, sel.$2, sel.$3, sel.$4, layerIndex: li);
          // Erase original, paste at same spot so it looks unchanged
          _game.eraseRegion(sel.$1, sel.$2, sel.$3, sel.$4, layerIndex: li);
          _game.pasteRegion(_moveSnapshot!, sel.$1, sel.$2);
          _lastPastePos = (sel.$1, sel.$2);
          _state.notifyMapChanged();
        } else {
          // Start a new marquee selection
          _isMovingSelection = false;
          _moveSnapshot = null;
          _lastMoveTile = null;
          _lastPastePos = null;
          _state.selectedMapRegion.value = null;
          setState(() {
            _selDragStart = e.localPosition;
            _selDragCurrent = e.localPosition;
          });
        }
      } else if (e.buttons == kSecondaryMouseButton) {
        _clearSelection();
      }
    } else {
      // object tool
      if (_state.sortEditMode.value) {
        // Sort edit: left click adds polygon point, right click removes nearest
        // Works for props (sort region), player, enemy, and NPC (collider polygon)
        final sel = _state.selectedObject.value;
        if (sel != null && _supportsPolygonEdit(sel)) {
          if (e.buttons == kPrimaryMouseButton) {
            _addSortPoint(e.localPosition, sel);
          } else if (e.buttons == kSecondaryMouseButton) {
            _removeSortPoint(e.localPosition, sel);
          }
        }
        return;
      }
      if (e.buttons == kPrimaryMouseButton) {
        final existing = _game.objectAt(e.localPosition);
        if (existing != null) {
          // Select and begin drag
          _state.selectedObject.value = existing;
          _game.setSelectedObject(existing.id);
          _draggedObject = existing;
          _dragUndoPushed = false;
          if (!_supportsPolygonEdit(existing)) {
            _state.sortEditMode.value = false;
          }
        } else {
          // Place new object
          final placed = _game.placeObject(
              e.localPosition, _state.selectedObjectType.value, _state,
              inheritFrom: _state.selectedObject.value);
          _state.selectedObject.value = placed;
          _game.setSelectedObject(placed?.id);
        }
      } else if (e.buttons == kSecondaryMouseButton) {
        _game.removeObjectAt(e.localPosition, _state);
        _state.selectedObject.value = null;
        _game.setSelectedObject(null);
        _draggedObject = null;
      }
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_state.isPlayMode.value) return;

    if (_isPanning) {
      final delta = e.localPosition - _lastPanPos;
      _lastPanPos = e.localPosition;
      _game.pan(-delta);
    }
    if (_isPainting) {
      final brush = _state.selectedBrush.value;
      if (brush != null) {
        _game.paintTilesetBrush(e.localPosition, brush,
            layerIndex: _state.activeLayerIndex.value);
      } else {
        _game.paintTile(e.localPosition, _state.selectedPaintColor.value,
            layerIndex: _state.activeLayerIndex.value);
      }
    }
    if (_isErasing) {
      _game.eraseTile(e.localPosition, layerIndex: _state.activeLayerIndex.value);
    }
    if (_rectStart != null) {
      setState(() => _rectCurrent = e.localPosition);
    }
    // Select tool — drag new selection or move existing
    if (_state.activeTool.value == EditorTool.select) {
      if (_isMovingSelection && _moveSnapshot != null) {
        final curTile = _game.screenToTile(e.localPosition);
        final startTile = _moveDragStart != null ? _game.screenToTile(_moveDragStart!) : null;
        if (curTile != null && startTile != null &&
            _moveSelectionOrigin != null && curTile != _lastMoveTile) {
          _lastMoveTile = curTile;
          final dx = curTile.$1 - startTile.$1;
          final dy = curTile.$2 - startTile.$2;
          final newX = _moveSelectionOrigin!.$1 + dx;
          final newY = _moveSelectionOrigin!.$2 + dy;
          final w = _moveSnapshot!.width;
          final h = _moveSnapshot!.height;
          // Erase previous preview, paste at new position
          final li = _moveSnapshot!.layerIndex;
          if (_lastPastePos != null) {
            _game.eraseRegion(_lastPastePos!.$1, _lastPastePos!.$2,
                _lastPastePos!.$1 + w - 1, _lastPastePos!.$2 + h - 1,
                layerIndex: li);
          }
          _game.pasteRegion(_moveSnapshot!, newX, newY);
          _lastPastePos = (newX, newY);
          _state.selectedMapRegion.value = (newX, newY, newX + w - 1, newY + h - 1);
          _state.notifyMapChanged();
        }
      } else if (_selDragStart != null) {
        setState(() => _selDragCurrent = e.localPosition);
        final a = _game.screenToTile(_selDragStart!);
        final b = _game.screenToTile(e.localPosition);
        if (a != null && b != null) {
          final x1 = a.$1 < b.$1 ? a.$1 : b.$1;
          final y1 = a.$2 < b.$2 ? a.$2 : b.$2;
          final x2 = a.$1 < b.$1 ? b.$1 : a.$1;
          final y2 = a.$2 < b.$2 ? b.$2 : a.$2;
          _state.selectedMapRegion.value = (x1, y1, x2, y2);
        }
      }
    }

    // Drag selected object to new tile
    if (_draggedObject != null) {
      final tile = _game.screenToTile(e.localPosition);
      if (tile != null &&
          (tile.$1 != _draggedObject!.tileX || tile.$2 != _draggedObject!.tileY)) {
        if (!_dragUndoPushed) {
          _state.pushUndo();
          _dragUndoPushed = true;
        }
        _draggedObject!.tileX = tile.$1;
        _draggedObject!.tileY = tile.$2;
        _state.notifyMapChanged();
      }
    }
    _state.hoverTile.value = _game.screenToTile(e.localPosition);
    _updateCursor(e.localPosition);
  }

  void _updateCursor(Offset pos) {
    final tool = _state.activeTool.value;
    MouseCursor next;
    if (_state.sortEditMode.value) {
      next = SystemMouseCursors.precise;
    } else if (tool == EditorTool.object) {
      next = (_draggedObject != null || _game.objectAt(pos) != null)
          ? SystemMouseCursors.move
          : SystemMouseCursors.click;
    } else if (tool == EditorTool.select) {
      final tile = _game.screenToTile(pos);
      final inSel = tile != null && _isTileInSelection(tile.$1, tile.$2);
      next = (_isMovingSelection || inSel)
          ? SystemMouseCursors.move
          : SystemMouseCursors.precise;
    } else {
      next = SystemMouseCursors.precise;
    }
    if (next != _cursor) setState(() => _cursor = next);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_state.activeTool.value == EditorTool.select) {
      if (_isMovingSelection) {
        // Move committed — just clear transient state
        _isMovingSelection = false;
        _moveDragStart = null;
        _moveSelectionOrigin = null;
        _moveSnapshot = null;
        _lastMoveTile = null;
        _lastPastePos = null;
      } else if (_selDragStart != null) {
        // Finalise marquee selection
        final a = _game.screenToTile(_selDragStart!);
        final b = _game.screenToTile(e.localPosition);
        if (a != null && b != null) {
          final x1 = a.$1 < b.$1 ? a.$1 : b.$1;
          final y1 = a.$2 < b.$2 ? a.$2 : b.$2;
          final x2 = a.$1 < b.$1 ? b.$1 : a.$1;
          final y2 = a.$2 < b.$2 ? b.$2 : a.$2;
          _state.selectedMapRegion.value = (x1, y1, x2, y2);
        } else {
          _state.selectedMapRegion.value = null;
        }
        setState(() { _selDragStart = null; _selDragCurrent = null; });
      }
    }
    if (_rectStart != null && _state.activeTool.value == EditorTool.rect) {
      _state.pushUndo();
      if (_lastRectErase) {
        _game.fillRect(_rectStart!, e.localPosition, const Color(0x00000000),
            layerIndex: _state.activeLayerIndex.value);
      } else {
        final brush = _state.selectedBrush.value;
        if (brush != null) {
          _game.fillRectTileset(_rectStart!, e.localPosition, brush,
              layerIndex: _state.activeLayerIndex.value);
        } else {
          _game.fillRect(_rectStart!, e.localPosition, _state.selectedPaintColor.value,
              layerIndex: _state.activeLayerIndex.value);
        }
      }
      _state.notifyMapChanged();
      setState(() {
        _rectStart = null;
        _rectCurrent = null;
      });
    }
    _isPanning = false;
    _isPainting = false;
    _isErasing = false;
    _draggedObject = null;
  }

  void _onPointerExit(PointerExitEvent e) {
    _isPanning = false;
    _isPainting = false;
    _isErasing = false;
    setState(() {
      _rectStart = null;
      _rectCurrent = null;
      _selDragStart = null;
      _selDragCurrent = null;
    });
    _state.hoverTile.value = null;
  }

  /// Returns true for object types that support polygon editing via sortEditMode.
  bool _supportsPolygonEdit(GameObject obj) =>
      obj.type == GameObjectType.prop ||
      obj.type == GameObjectType.playerSpawn ||
      obj.type == GameObjectType.enemy ||
      obj.type == GameObjectType.npc;

  void _addSortPoint(Offset screenPos, GameObject obj) {
    final cam = _game.editorCamera;
    if (cam == null) return;
    final ts = _state.mapData.tileSize.toDouble();
    final wx = cam.viewfinder.position.x + screenPos.dx / cam.viewfinder.zoom;
    final wy = cam.viewfinder.position.y + screenPos.dy / cam.viewfinder.zoom;
    final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
    final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
    final dx = (wx - cx) / ts;
    final dy = (wy - cy) / ts;
    _state.pushUndo();
    final pts = _getSortPoints(obj);
    pts.add([dx, dy]);
    obj.properties['sortPoints'] = pts;
    _state.notifyMapChanged();
  }

  void _removeSortPoint(Offset screenPos, GameObject obj) {
    final cam = _game.editorCamera;
    if (cam == null) return;
    final ts = _state.mapData.tileSize.toDouble();
    final wx = cam.viewfinder.position.x + screenPos.dx / cam.viewfinder.zoom;
    final wy = cam.viewfinder.position.y + screenPos.dy / cam.viewfinder.zoom;
    final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
    final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
    final pts = _getSortPoints(obj);
    if (pts.isEmpty) return;
    double minDist = double.infinity;
    int minIdx = -1;
    for (int i = 0; i < pts.length; i++) {
      final px = cx + pts[i][0] * ts;
      final py = cy + pts[i][1] * ts;
      final d = (Offset(px, py) - Offset(wx, wy)).distance;
      if (d < minDist) { minDist = d; minIdx = i; }
    }
    if (minIdx >= 0) {
      _state.pushUndo();
      pts.removeAt(minIdx);
      obj.properties['sortPoints'] = pts;
      _state.notifyMapChanged();
    }
  }

  List<List<double>> _getSortPoints(GameObject obj) {
    final raw = obj.properties['sortPoints'];
    if (raw is List) {
      return raw.map<List<double>>((p) {
        if (p is List && p.length >= 2) {
          return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
        }
        return [0.0, 0.0];
      }).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _state.isPlayMode,
      builder: (_, isPlay, __) {
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) {
            _isPanning = _isPainting = _isErasing = false;
            _draggedObject = null;
            setState(() {
              _rectStart = null;
              _rectCurrent = null;
            });
            _state.hoverTile.value = null;
          },
          child: MouseRegion(
            onExit: _onPointerExit,
            cursor: isPlay ? SystemMouseCursors.basic : _cursor,
            child: Column(
              children: [
                // ── HUD strip (top position) ─────────────────
                if (isPlay && !_state.project.hudAtBottom)
                  _PlayHudStrip(
                    health: _health, score: _score,
                    coins: _coins, gems: _gems, items: _items,
                    coinLabel: _state.project.coinLabel,
                    gemLabel: _state.project.gemLabel,
                    itemLabel: _state.project.collectibleLabel,
                    equippedItemName: _equippedItemName,
                  ),

                // ── Game canvas ──────────────────────────────
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      children: [
                        GameWidget(
                          game: _game,
                          focusNode: _gameFocusNode,
                          autofocus: true,
                        ),

                        // ── Play Mode overlays ────────────────
                        if (isPlay) ...[
                          // Message — centred in canvas, no HUD blocking it
                          if (_message != null)
                            Positioned(
                              top: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.surfaceBg.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.borderColor),
                                  ),
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                            ),

                          // Debug collision toggle button
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Tooltip(
                              message: 'Toggle collision debug',
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _debugCollision = !_debugCollision);
                                  _game.playSession?.debugCollision = _debugCollision;
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _debugCollision
                                        ? const Color(0xFF00E5FF).withOpacity(0.25)
                                        : Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _debugCollision
                                          ? const Color(0xFF00E5FF)
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.bug_report_outlined,
                                    size: 18,
                                    color: _debugCollision
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Game over / win full-screen overlay
                          if (_isGameOver || _isWin)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  _isWin ? '🏆  You Win!' : '💀  Game Over',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],

                        // ── Rectangle fill preview ────────────
                        if (!isPlay && _rectStart != null && _rectCurrent != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _RectPreviewPainter(
                                  game: _game,
                                  start: _rectStart!,
                                  end: _rectCurrent!,
                                ),
                              ),
                            ),
                          ),

                        // ── Select tool overlay ───────────────
                        if (!isPlay)
                          ValueListenableBuilder<(int, int, int, int)?>(
                            valueListenable: _state.selectedMapRegion,
                            builder: (_, sel, __) {
                              if (sel == null) return const SizedBox.shrink();
                              return Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SelectionOverlayPainter(
                                      game: _game,
                                      selection: sel,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // ── Editor zoom controls ──────────────
                        if (!isPlay)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _ZoomControls(game: _game),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── HUD strip (bottom position) ──────────────
                if (isPlay && _state.project.hudAtBottom)
                  _PlayHudStrip(
                    health: _health, score: _score,
                    coins: _coins, gems: _gems, items: _items,
                    coinLabel: _state.project.coinLabel,
                    gemLabel: _state.project.gemLabel,
                    itemLabel: _state.project.collectibleLabel,
                    equippedItemName: _equippedItemName,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Play HUD Strip ───────────────────────────────────────────────────────────

class _PlayHudStrip extends StatelessWidget {
  final int health;
  final int score;
  final int coins;
  final int gems;
  final int items;
  final String coinLabel;
  final String gemLabel;
  final String itemLabel;
  final String? equippedItemName;

  const _PlayHudStrip({
    required this.health,
    required this.score,
    required this.coins,
    required this.gems,
    required this.items,
    required this.coinLabel,
    required this.gemLabel,
    required this.itemLabel,
    this.equippedItemName,
  });

  Widget _divider() => Container(
      width: 1, height: 14, color: AppColors.borderColor,
      margin: const EdgeInsets.symmetric(horizontal: 10));

  Widget _counter(IconData icon, Color color, int count, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text('$count $label',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.panelBg,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          // Health
          const Icon(Icons.favorite, color: Color(0xFFF87171), size: 12),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            height: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: health / 100,
                backgroundColor: AppColors.borderColor,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF87171)),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text('$health',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),

          // Score (if > 0)
          if (score > 0) ...[
            _divider(),
            _counter(Icons.star, const Color(0xFFFBBF24), score, 'pts'),
          ],

          // Coins (if > 0)
          if (coins > 0) ...[
            _divider(),
            _counter(Icons.monetization_on, const Color(0xFFFBBF24), coins, coinLabel),
          ],

          // Gems (if > 0)
          if (gems > 0) ...[
            _divider(),
            _counter(Icons.diamond, const Color(0xFF818CF8), gems, gemLabel),
          ],

          // Items (if > 0)
          if (items > 0) ...[
            _divider(),
            _counter(Icons.category, const Color(0xFF34D399), items, itemLabel),
          ],

          const Spacer(),

          // Equipped weapon slot
          if (equippedItemName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_martial_arts,
                      size: 11, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(equippedItemName!,
                      style: const TextStyle(
                          color: AppColors.accent, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],

          const Text(
            'WASD / ↑↓←→  ·  Space = Attack',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Zoom Controls ────────────────────────────────────────────────────────────

class _ZoomControls extends StatefulWidget {
  final EditorGame game;
  const _ZoomControls({required this.game});

  @override
  State<_ZoomControls> createState() => _ZoomControlsState();
}

class _ZoomControlsState extends State<_ZoomControls> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomBtn(Icons.add, () {
            widget.game.zoomBy(1.2);
            setState(() {});
          }),
          Container(height: 1, color: AppColors.borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              '${(widget.game.currentZoom * 100).round()}%',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          Container(height: 1, color: AppColors.borderColor),
          _zoomBtn(Icons.remove, () {
            widget.game.zoomBy(0.8);
            setState(() {});
          }),
        ],
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
      );
}

// ─── Selection Overlay Painter ────────────────────────────────────────────────

class _SelectionOverlayPainter extends CustomPainter {
  final EditorGame game;
  final (int, int, int, int) selection; // x1,y1,x2,y2 (inclusive)

  const _SelectionOverlayPainter({required this.game, required this.selection});

  @override
  void paint(Canvas canvas, Size size) {
    final (x1, y1, x2, y2) = selection;
    final topLeft = game.tileToScreen(x1, y1);
    final bottomRight = game.tileToScreen(x2 + 1, y2 + 1);
    if (topLeft == null || bottomRight == null) return;

    final rect = Rect.fromPoints(topLeft, bottomRight);

    // Tinted fill
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF60A5FA).withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );

    // Dashed border
    final borderPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(_dashedRectPath(rect), borderPaint);

    // Corner handles
    final handlePaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.fill;
    const r = 3.5;
    for (final pt in [
      topLeft,
      Offset(bottomRight.dx, topLeft.dy),
      bottomRight,
      Offset(topLeft.dx, bottomRight.dy),
    ]) {
      canvas.drawCircle(pt, r, handlePaint);
    }
  }

  Path _dashedRectPath(Rect rect) {
    const dash = 6.0;
    const gap = 4.0;
    final path = Path();

    void addDashed(Offset from, Offset to) {
      final d = (to - from).distance;
      if (d == 0) return;
      final dx = (to.dx - from.dx) / d;
      final dy = (to.dy - from.dy) / d;
      double pos = 0;
      bool draw = true;
      while (pos < d) {
        final end = (pos + (draw ? dash : gap)).clamp(0.0, d);
        if (draw) {
          path.moveTo(from.dx + dx * pos, from.dy + dy * pos);
          path.lineTo(from.dx + dx * end, from.dy + dy * end);
        }
        pos = end;
        draw = !draw;
      }
    }

    addDashed(rect.topLeft, rect.topRight);
    addDashed(rect.topRight, rect.bottomRight);
    addDashed(rect.bottomRight, rect.bottomLeft);
    addDashed(rect.bottomLeft, rect.topLeft);
    return path;
  }

  @override
  bool shouldRepaint(_SelectionOverlayPainter old) =>
      old.selection != selection;
}

// ─── Rectangle Fill Preview Painter ──────────────────────────────────────────

class _RectPreviewPainter extends CustomPainter {
  final EditorGame game;
  final Offset start;
  final Offset end;

  const _RectPreviewPainter({
    required this.game,
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final a = game.screenToTile(start);
    final b = game.screenToTile(end);
    if (a == null || b == null) return;

    final minX = a.$1 < b.$1 ? a.$1 : b.$1;
    final maxX = a.$1 < b.$1 ? b.$1 : a.$1;
    final minY = a.$2 < b.$2 ? a.$2 : b.$2;
    final maxY = a.$2 < b.$2 ? b.$2 : a.$2;

    final topLeft = game.tileToScreen(minX, minY);
    final bottomRight = game.tileToScreen(maxX + 1, maxY + 1);
    if (topLeft == null || bottomRight == null) return;

    final rect = Rect.fromPoints(topLeft, bottomRight);

    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF60A5FA).withOpacity(0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF60A5FA).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RectPreviewPainter old) =>
      old.start != start || old.end != end;
}
