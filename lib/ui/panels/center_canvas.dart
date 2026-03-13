import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../editor/editor_game.dart'; // needed for _ZoomControls type ref
import '../../editor/editor_state.dart';
import '../../models/map_data.dart';
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
  }

  @override
  void dispose() {
    _state.isPlayMode.removeListener(_onPlayModeChanged);
    _state.showGrid.removeListener(_onShowGridChanged);
    _state.activeTool.removeListener(_onActiveToolChanged);
    _state.projectChanged.removeListener(_onProjectChanged);
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
  }

  void _onPlayModeChanged() {
    if (_state.isPlayMode.value) {
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
      _game.startPlay(
        viewportWidth: _state.project.viewportWidth,
        viewportHeight: _state.project.viewportHeight,
        effects: _state.project.effects,
        items: _state.project.items,
        keyBindings: _state.project.keyBindings,
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
      // Restore collision overlay if collision tool is still active
      _game.setShowCollision(_state.activeTool.value == EditorTool.collision);
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
      if (e.buttons == kPrimaryMouseButton) {
        _state.pushUndo();
        _isPainting = true;
        _game.paintTile(e.localPosition, _state.selectedTile.value,
            variant: _state.selectedTileVariant.value);
      } else if (e.buttons == kSecondaryMouseButton) {
        _state.pushUndo();
        _isErasing = true;
        _game.paintTile(e.localPosition, TileType.empty);
      }
    } else if (tool == EditorTool.fill) {
      if (e.buttons == kPrimaryMouseButton) {
        _state.pushUndo();
        _game.floodFill(e.localPosition, _state.selectedTile.value,
            variant: _state.selectedTileVariant.value);
        _state.notifyMapChanged();
      } else if (e.buttons == kSecondaryMouseButton) {
        _state.pushUndo();
        _game.floodFill(e.localPosition, TileType.empty);
        _state.notifyMapChanged();
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
    } else {
      // object tool
      if (e.buttons == kPrimaryMouseButton) {
        final existing = _game.objectAt(e.localPosition);
        if (existing != null) {
          _state.selectedObject.value = existing;
          _game.setSelectedObject(existing.id);
        } else {
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
      _game.paintTile(e.localPosition, _state.selectedTile.value,
          variant: _state.selectedTileVariant.value);
    }
    if (_isErasing) {
      _game.paintTile(e.localPosition, TileType.empty);
    }
    if (_rectStart != null) {
      setState(() => _rectCurrent = e.localPosition);
    }
    _state.hoverTile.value = _game.screenToTile(e.localPosition);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_rectStart != null && _state.activeTool.value == EditorTool.rect) {
      _state.pushUndo();
      if (_lastRectErase) {
        _game.fillRect(_rectStart!, e.localPosition, TileType.empty);
      } else {
        _game.fillRect(_rectStart!, e.localPosition, _state.selectedTile.value,
            variant: _state.selectedTileVariant.value);
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
  }

  void _onPointerExit(PointerExitEvent e) {
    _isPanning = false;
    _isPainting = false;
    _isErasing = false;
    setState(() {
      _rectStart = null;
      _rectCurrent = null;
    });
    _state.hoverTile.value = null;
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
            setState(() {
              _rectStart = null;
              _rectCurrent = null;
            });
            _state.hoverTile.value = null;
          },
          child: MouseRegion(
            onExit: _onPointerExit,
            cursor: isPlay
                ? SystemMouseCursors.basic
                : SystemMouseCursors.precise,
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
