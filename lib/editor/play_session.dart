import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import '../models/game_object.dart';
import '../models/game_rule.dart';
import '../models/map_data.dart';
import '../services/sprite_cache.dart';

// ─── Enemy runtime state ──────────────────────────────────────────────────────

enum _EnemyBehavior { idle, patrol, chase }

class _Enemy {
  final GameObject source;
  Vector2 pos;

  _EnemyBehavior behavior = _EnemyBehavior.idle;
  double pixelSpeed = 0;
  double chaseRangePx = 0;

  Vector2? patrolStart;
  Vector2? patrolEnd;
  bool _forward = true;

  _Enemy({required this.source, required this.pos});

  void setPatrol(double speedTiles, double distTiles, double ts, double maxX) {
    if (behavior == _EnemyBehavior.patrol) return;
    behavior = _EnemyBehavior.patrol;
    pixelSpeed = speedTiles * ts;
    patrolStart = pos.clone();
    patrolEnd = Vector2((pos.x + distTiles * ts).clamp(0.0, maxX), pos.y);
  }

  void setChase(double speedTiles, double rangeTiles, double ts) {
    if (behavior == _EnemyBehavior.chase) return;
    behavior = _EnemyBehavior.chase;
    pixelSpeed = speedTiles * ts;
    chaseRangePx = rangeTiles * ts;
  }

  void setIdle() => behavior = _EnemyBehavior.idle;

  void update(double dt, Vector2 playerPos, double maxX, double maxY) {
    switch (behavior) {
      case _EnemyBehavior.idle:
        break;
      case _EnemyBehavior.patrol:
        if (patrolStart == null || patrolEnd == null) break;
        final target = _forward ? patrolEnd! : patrolStart!;
        final dir = target - pos;
        if (dir.length < 2) {
          _forward = !_forward;
        } else {
          pos += dir.normalized() * pixelSpeed * dt;
        }
      case _EnemyBehavior.chase:
        final dir = playerPos - pos;
        final dist = dir.length;
        if (dist > 4 && dist < chaseRangePx) {
          pos += dir.normalized() * pixelSpeed * dt;
        }
    }
    pos.x = pos.x.clamp(0, maxX);
    pos.y = pos.y.clamp(0, maxY);
  }
}

// ─── Play Session (plain Dart class — no Flame Component lifecycle) ────────────

class PlaySession {
  final MapData mapData;
  final SpriteCache spriteCache;
  final List<GameRule> rules;

  final void Function(int health, int score) onHudUpdate;
  final void Function(String msg) onMessage;
  final void Function(String event) onGameEvent;

  late Vector2 _playerPos;
  int _health = 100;
  int _score = 0;
  double _playerSpeedTiles = 4.0;
  double _elapsedSec = 0;

  final List<_Enemy> _enemies = [];
  final Map<String, double> _cooldowns = {};
  static const double _hitCooldown = 1.5;

  Vector2 get playerPos => _playerPos;
  int get health => _health;
  int get score => _score;

  PlaySession({
    required this.mapData,
    required this.spriteCache,
    required this.rules,
    required this.onHudUpdate,
    required this.onMessage,
    required this.onGameEvent,
  });

  // Called once synchronously before the first update()
  void init() {
    final ts = mapData.tileSize.toDouble();

    // Read player speed from any movePlayer action
    for (final rule in rules.where((r) => r.enabled)) {
      for (final action in rule.actions) {
        if (action.type == ActionType.movePlayer) {
          _playerSpeedTiles = ((action.params['speed'] as int?) ?? 4).toDouble();
          break;
        }
      }
    }

    // Place player at spawn, or top-left corner
    final spawns = mapData.objects.where((o) => o.type == GameObjectType.playerSpawn);
    final spawn = spawns.isNotEmpty ? spawns.first : null;
    _playerPos = spawn != null
        ? Vector2((spawn.tileX + 0.5) * ts, (spawn.tileY + 0.5) * ts)
        : Vector2(ts * 1.5, ts * 1.5);

    // Init enemies from map objects
    for (final obj in mapData.objects.where((o) => o.type == GameObjectType.enemy)) {
      _enemies.add(_Enemy(
        source: obj,
        pos: Vector2((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts),
      ));
    }

    _applyStartRules();
    onHudUpdate(_health, _score);
  }

  void _applyStartRules() {
    final ts = mapData.tileSize.toDouble();
    final maxX = mapData.width * ts;
    for (final rule in rules.where((r) => r.enabled && r.trigger == TriggerType.gameStart)) {
      // Enemy-specific setup (patrol/chase require access to _enemies list)
      for (final action in rule.actions) {
        final speed = ((action.params['speed'] as int?) ?? 2).toDouble();
        switch (action.type) {
          case ActionType.enemyPatrol:
            final dist = ((action.params['distance'] as int?) ?? 4).toDouble();
            for (final e in _enemies) {
              e.setPatrol(speed, dist, ts, maxX);
            }
          case ActionType.enemyChasePlayer:
            final range = ((action.params['range'] as int?) ?? 5).toDouble();
            for (final e in _enemies) {
              e.setChase(speed, range, ts);
            }
          default:
            break;
        }
      }
      // Fire all other actions (audio, messages, health adjustments, etc.)
      _executeActions(rule.actions);
    }
  }

  void update(double dt) {
    _elapsedSec += dt;
    _tickCooldowns(dt);
    _checkKeyTriggers(dt); // fires key rules + handles movement
    _moveEnemies(dt);
    _checkCollisions();
    _checkProximityRules();
  }

  void _tickCooldowns(double dt) {
    final keys = _cooldowns.keys.toList();
    for (final k in keys) {
      _cooldowns[k] = _cooldowns[k]! - dt;
      if (_cooldowns[k]! <= 0) _cooldowns.remove(k);
    }
  }

  void _checkKeyTriggers(double dt) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ts = mapData.tileSize.toDouble();
    final spd = _playerSpeedTiles * ts * dt;

    // Fire key trigger rules (move player, score, messages, etc.)
    bool up    = keys.contains(LogicalKeyboardKey.arrowUp)    || keys.contains(LogicalKeyboardKey.keyW);
    bool down  = keys.contains(LogicalKeyboardKey.arrowDown)  || keys.contains(LogicalKeyboardKey.keyS);
    bool left  = keys.contains(LogicalKeyboardKey.arrowLeft)  || keys.contains(LogicalKeyboardKey.keyA);
    bool right = keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(LogicalKeyboardKey.keyD);
    bool space = keys.contains(LogicalKeyboardKey.space);

    if (up)    _fireKey(TriggerType.keyUpPressed,    dt, dirX:  0, dirY: -1);
    if (down)  _fireKey(TriggerType.keyDownPressed,  dt, dirX:  0, dirY:  1);
    if (left)  _fireKey(TriggerType.keyLeftPressed,  dt, dirX: -1, dirY:  0);
    if (right) _fireKey(TriggerType.keyRightPressed, dt, dirX:  1, dirY:  0);
    if (space) _fireKey(TriggerType.keySpacePressed, dt, dirX:  0, dirY:  0);

    // Fallback: if no movement rules exist, move with default speed
    final hasMovementRules = rules.any((r) =>
        r.enabled &&
        (r.trigger == TriggerType.keyUpPressed ||
         r.trigger == TriggerType.keyDownPressed ||
         r.trigger == TriggerType.keyLeftPressed ||
         r.trigger == TriggerType.keyRightPressed) &&
        r.actions.any((a) => a.type == ActionType.movePlayer));

    if (!hasMovementRules) {
      double dx = 0, dy = 0;
      if (up)    dy -= spd;
      if (down)  dy += spd;
      if (left)  dx -= spd;
      if (right) dx += spd;
      _movePlayer(dx, dy);
    }
  }

  // ─── Collision ────────────────────────────────────────────────────────────

  /// Returns true if a point (px, py) in world-space is inside a solid tile.
  bool _solidAt(double px, double py) {
    final ts = mapData.tileSize.toDouble();
    final tx = (px / ts).floor().clamp(0, mapData.width - 1);
    final ty = (py / ts).floor().clamp(0, mapData.height - 1);
    final col = mapData.getTileCollision(tx, ty);
    if (col == 1) return false; // force passable
    if (col == 2) return true;  // force solid
    return mapData.getTile(tx, ty).isSolid;
  }

  /// Returns true if the player bounding box at (cx, cy) overlaps a solid tile.
  bool _collidesAt(double cx, double cy) {
    final r = mapData.tileSize * 0.38; // slightly smaller than half a tile
    return _solidAt(cx - r, cy - r) ||
        _solidAt(cx + r, cy - r) ||
        _solidAt(cx - r, cy + r) ||
        _solidAt(cx + r, cy + r);
  }

  /// Move the player by (dx, dy) with sliding collision against solid tiles.
  void _movePlayer(double dx, double dy) {
    final ts = mapData.tileSize.toDouble();
    final maxX = mapData.width * ts;
    final maxY = mapData.height * ts;

    final nx = (_playerPos.x + dx).clamp(0.0, maxX);
    final ny = (_playerPos.y + dy).clamp(0.0, maxY);

    // Try full diagonal move
    if (!_collidesAt(nx, ny)) {
      _playerPos.x = nx;
      _playerPos.y = ny;
      return;
    }
    // Slide along X
    if (!_collidesAt(nx, _playerPos.y)) {
      _playerPos.x = nx;
      return;
    }
    // Slide along Y
    if (!_collidesAt(_playerPos.x, ny)) {
      _playerPos.y = ny;
    }
  }

  /// Fire a key trigger and execute its actions (continuous — no cooldown).
  void _fireKey(TriggerType trigger, double dt, {double dirX = 0, double dirY = 0}) {
    final ts = mapData.tileSize.toDouble();
    for (final rule in rules.where((r) => r.enabled && r.trigger == trigger)) {
      _executeActions(rule.actions, dt: dt, dirX: dirX, dirY: dirY, ts: ts);
    }
  }

  void _moveEnemies(double dt) {
    final ts = mapData.tileSize.toDouble();
    for (final e in _enemies) {
      e.update(dt, _playerPos, mapData.width * ts, mapData.height * ts);
    }
  }

  void _checkCollisions() {
    final ts = mapData.tileSize.toDouble();
    final px = (_playerPos.x / ts).floor().clamp(0, mapData.width - 1);
    final py = (_playerPos.y / ts).floor().clamp(0, mapData.height - 1);

    final toRemove = <GameObject>[];
    for (final obj in List.of(mapData.objects)) {
      if (obj.tileX != px || obj.tileY != py) continue;
      switch (obj.type) {
        case GameObjectType.coin:
        case GameObjectType.chest:
          toRemove.add(obj);
          _fire(TriggerType.playerTouchesCollectible, triggerObj: obj, cooldownKey: obj.id);
        case GameObjectType.door:
          _fire(TriggerType.playerTouchesDoor, triggerObj: obj, cooldownKey: 'door_${obj.id}');
        case GameObjectType.npc:
          if (HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.space)) {
            _fire(TriggerType.playerTouchesNpc, triggerObj: obj, cooldownKey: 'npc_${obj.id}');
          }
        default:
          break;
      }
    }
    for (final obj in toRemove) {
      mapData.objects.remove(obj);
    }

    for (final e in _enemies) {
      if ((e.pos - _playerPos).length < ts * 0.55) {
        _fire(TriggerType.playerTouchesEnemy, cooldownKey: 'enemy_${e.source.id}');
      }
    }
  }

  void _checkProximityRules() {
    final ts = mapData.tileSize.toDouble();
    for (final rule in rules.where((r) => r.enabled && r.trigger == TriggerType.enemyNearPlayer)) {
      for (final action in rule.actions) {
        switch (action.type) {
          case ActionType.enemyChasePlayer:
            final speed = ((action.params['speed'] as int?) ?? 2).toDouble();
            final range = ((action.params['range'] as int?) ?? 5).toDouble();
            final rangePx = range * ts;
            for (final e in _enemies) {
              if ((e.pos - _playerPos).length < rangePx) {
                e.setChase(speed, range, ts);
              }
            }
          case ActionType.enemyStopMoving:
            for (final e in _enemies) {
              if ((e.pos - _playerPos).length < ts * 2) e.setIdle();
            }
          default:
            break;
        }
      }
    }
  }

  void _fire(TriggerType trigger, {GameObject? triggerObj, String? cooldownKey}) {
    final key = cooldownKey ?? trigger.name;
    if (_cooldowns.containsKey(key)) return;

    bool anyFired = false;
    for (final rule in rules.where((r) => r.enabled && r.trigger == trigger)) {
      _executeActions(rule.actions, triggerObj: triggerObj);
      anyFired = true;
    }
    if (anyFired) _cooldowns[key] = _hitCooldown;
  }

  void _executeActions(List<RuleAction> actions,
      {GameObject? triggerObj, double dt = 0, double dirX = 0, double dirY = 0, double ts = 32}) {
    for (final a in actions) {
      switch (a.type) {
        case ActionType.movePlayer:
          final speed = ((a.params['speed'] as int?) ?? 4).toDouble();
          final spd = speed * ts * dt;
          _movePlayer(dirX * spd, dirY * spd);
        case ActionType.adjustHealth:
          final delta = (a.params['value'] as int?) ?? 0;
          _health = (_health + delta).clamp(0, 100);
          onHudUpdate(_health, _score);
          if (_health <= 0) _fire(TriggerType.playerHealthZero);
        case ActionType.adjustScore:
          _score += (a.params['value'] as int?) ?? 0;
          onHudUpdate(_health, _score);
        case ActionType.showMessage:
          onMessage(a.params['text'] as String? ?? '');
        case ActionType.destroyTriggerObject:
          if (triggerObj != null) mapData.objects.remove(triggerObj);
        case ActionType.gameOver:
          onGameEvent('gameOver');
        case ActionType.winGame:
          onGameEvent('win');
        case ActionType.loadMap:
          onGameEvent('loadMap:${a.params['mapName'] ?? ''}');
        case ActionType.playMusic:
          onGameEvent('playMusic:${a.params['trackName'] ?? ''}');
        case ActionType.playSfx:
          onGameEvent('playSfx:${a.params['sfxName'] ?? ''}');
        case ActionType.stopMusic:
          onGameEvent('stopMusic');
        default:
          break;
      }
    }
  }

  void render(Canvas canvas) {
    final ts = mapData.tileSize.toDouble();
    final r = ts * 0.32;

    for (final obj in mapData.objects) {
      if (obj.type == GameObjectType.playerSpawn || obj.type == GameObjectType.enemy) continue;
      _drawObject(canvas, Offset((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts),
          ts, r, obj.type);
    }

    for (final e in _enemies) {
      _drawObject(canvas, Offset(e.pos.x, e.pos.y), ts, r, e.source.type);
    }

    // Player
    final playerSprite = _resolveSprite(GameObjectType.playerSpawn);
    if (playerSprite != null) {
      _drawSprite(canvas, playerSprite, _playerPos.x, _playerPos.y, ts);
    } else {
      _drawCircle(canvas, Offset(_playerPos.x, _playerPos.y), r,
          const Color(0xFF4ADE80), 'P');
    }
  }

  void _drawObject(Canvas canvas, Offset center, double ts, double r, GameObjectType type) {
    final sprite = _resolveSprite(type);
    if (sprite != null) {
      _drawSprite(canvas, sprite, center.dx, center.dy, ts);
    } else {
      _drawCircle(canvas, center, r, type.color, type.symbol);
    }
  }

  ui.Image? _resolveSprite(GameObjectType type) {
    if (spriteCache.isAnimated(type)) {
      final animName = spriteCache.defaultAnim(type);
      if (animName.isNotEmpty) {
        final fps = spriteCache.getAnimFps(type, animName);
        final frameCount = spriteCache.animFrameCount(type, animName);
        if (frameCount > 0) {
          final frameIndex = (_elapsedSec * fps).floor() % frameCount;
          return spriteCache.getAnimFrame(type, animName, frameIndex);
        }
      }
      return null;
    }
    return spriteCache.getImage(type);
  }

  void _drawSprite(Canvas canvas, ui.Image image, double cx, double cy, double ts) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromCenter(center: Offset(cx, cy), width: ts, height: ts);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  void _drawCircle(Canvas canvas, Offset center, double r, Color color, String symbol) {
    canvas.drawCircle(center + const Offset(1, 2), r,
        Paint()..color = const Color(0x4D000000));
    canvas.drawCircle(center, r, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: r * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
}

// ─── Render-only Component — renders PlaySession in world space ───────────────

class PlayRenderer extends Component {
  PlaySession? session;

  @override
  void render(Canvas canvas) {
    session?.render(canvas);
  }
}
