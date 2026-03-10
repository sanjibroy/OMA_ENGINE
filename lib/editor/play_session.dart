import 'dart:math' show pi, sin, cos;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import '../effects/particle_system.dart';
import '../models/game_effect.dart';
import '../models/game_object.dart';
import '../models/game_rule.dart';
import '../models/map_data.dart';
import '../services/sprite_cache.dart';

// ─── Fade animation helper ────────────────────────────────────────────────────

class _FadeAnim {
  final double from;
  final double to;
  final double duration;
  double elapsed = 0;
  _FadeAnim(this.from, this.to, this.duration);
  double get alpha => duration <= 0 ? to : (from + (to - from) * (elapsed / duration).clamp(0.0, 1.0));
  bool get isDone => elapsed >= duration;
}

// ─── Dash FX state machine ────────────────────────────────────────────────────

class _DashFx {
  final double _cosA;
  final double _sinA;
  final double _distancePx;
  final double _speedPx;
  final double _interval;

  double _idleTimer = 0;
  double _progress = 0; // 0 = at rest, 1 = full dash
  bool _dashing = false;
  bool _returning = false;

  _DashFx({
    required double angleRad,
    required double distancePx,
    required double speedPx,
    required double interval,
  })  : _cosA = cos(angleRad),
        _sinA = sin(angleRad),
        _distancePx = distancePx,
        _speedPx = speedPx,
        _interval = interval;

  void update(double dt) {
    final step = _distancePx > 0 ? (_speedPx * dt) / _distancePx : 1.0;
    if (_dashing) {
      _progress = (_progress + step).clamp(0.0, 1.0);
      if (_progress >= 1.0) { _dashing = false; _returning = true; }
    } else if (_returning) {
      _progress = (_progress - step).clamp(0.0, 1.0);
      if (_progress <= 0.0) { _returning = false; _idleTimer = 0; }
    } else {
      _idleTimer += dt;
      if (_idleTimer >= _interval) _dashing = true;
    }
  }

  double get offsetX => _progress * _distancePx * _cosA;
  double get offsetY => _progress * _distancePx * _sinA;
}

// ─── Enemy runtime state ──────────────────────────────────────────────────────

enum _EnemyBehavior { idle, patrol, chase }

class _Enemy {
  final GameObject source;
  Vector2 pos;

  _EnemyBehavior behavior = _EnemyBehavior.idle;
  bool hidden = false;
  double alpha = 1.0;
  _FadeAnim? fade;
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
  final List<GameEffect> effects;
  final Map<String, String> keyBindings;

  final void Function(int health, int score) onHudUpdate;
  final void Function(String msg) onMessage;
  final void Function(String event) onGameEvent;

  late Vector2 _playerPos;
  bool _playerFlipH = false;
  bool _playerFlipV = false;
  double _playerScale = 1.0;
  double _playerRotation = 0.0;
  int _health = 100;
  int _score = 0;
  double _playerSpeedTiles = 4.0;
  double _elapsedSec = 0;

  bool _playerHidden = false;
  double _playerAlpha = 1.0;
  _FadeAnim? _playerFade;
  final Set<String> _hiddenObjectIds = {};
  final Map<String, double> _objectAlpha = {};
  final Map<String, _FadeAnim> _objectFades = {};
  final List<_Enemy> _enemies = [];
  final Map<String, double> _cooldowns = {};
  final Map<String, double> _timerElapsed = {};
  final Map<String, double> _projectileDist = {};
  final Set<String> _activeProjectiles = {};
  final Map<String, double> _projectileHideTimer = {};
  // Stores the GameEffect config to fire when a projectile lands
  final Map<String, GameEffect> _landEffects = {};
  final Map<String, _DashFx> _dashFx = {};
  final ParticleSystem _particles = ParticleSystem();
  static const double _hitCooldown = 1.5;

  bool _playerInWater = false;
  double _waterDamageTimer = 0;
  double _waterSpeedMult = 1.0;

  Vector2 get playerPos => _playerPos;
  int get health => _health;
  int get score => _score;

  PlaySession({
    required this.mapData,
    required this.spriteCache,
    required this.rules,
    required this.effects,
    this.keyBindings = const {},
    required this.onHudUpdate,
    required this.onMessage,
    required this.onGameEvent,
  });

  /// Resolves the physical key bound to a key trigger type.
  /// Returns null if no custom binding (caller uses the default key).
  LogicalKeyboardKey? _boundKey(TriggerType t) {
    final id = keyBindings[t.name];
    if (id == null || id.isEmpty) return null;
    return _kKeyMap[id];
  }

  static const Map<String, LogicalKeyboardKey> _kKeyMap = {
    'a': LogicalKeyboardKey.keyA, 'b': LogicalKeyboardKey.keyB,
    'c': LogicalKeyboardKey.keyC, 'd': LogicalKeyboardKey.keyD,
    'e': LogicalKeyboardKey.keyE, 'f': LogicalKeyboardKey.keyF,
    'g': LogicalKeyboardKey.keyG, 'h': LogicalKeyboardKey.keyH,
    'i': LogicalKeyboardKey.keyI, 'j': LogicalKeyboardKey.keyJ,
    'k': LogicalKeyboardKey.keyK, 'l': LogicalKeyboardKey.keyL,
    'm': LogicalKeyboardKey.keyM, 'n': LogicalKeyboardKey.keyN,
    'o': LogicalKeyboardKey.keyO, 'p': LogicalKeyboardKey.keyP,
    'q': LogicalKeyboardKey.keyQ, 'r': LogicalKeyboardKey.keyR,
    's': LogicalKeyboardKey.keyS, 't': LogicalKeyboardKey.keyT,
    'u': LogicalKeyboardKey.keyU, 'v': LogicalKeyboardKey.keyV,
    'w': LogicalKeyboardKey.keyW, 'x': LogicalKeyboardKey.keyX,
    'y': LogicalKeyboardKey.keyY, 'z': LogicalKeyboardKey.keyZ,
    '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
    '2': LogicalKeyboardKey.digit2, '3': LogicalKeyboardKey.digit3,
    '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
    '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7,
    '8': LogicalKeyboardKey.digit8, '9': LogicalKeyboardKey.digit9,
    'space': LogicalKeyboardKey.space,
    'enter': LogicalKeyboardKey.enter,
    'tab': LogicalKeyboardKey.tab,
    'shift': LogicalKeyboardKey.shiftLeft,
    'ctrl': LogicalKeyboardKey.controlLeft,
    'escape': LogicalKeyboardKey.escape,
    'f1': LogicalKeyboardKey.f1, 'f2': LogicalKeyboardKey.f2,
    'f3': LogicalKeyboardKey.f3, 'f4': LogicalKeyboardKey.f4,
  };

  GameEffect? _findEffect(String name) {
    for (final e in effects) {
      if (e.name == name) return e;
    }
    return null;
  }

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
    _playerFlipH = spawn?.flipH ?? false;
    _playerFlipV = spawn?.flipV ?? false;
    _playerScale = spawn?.scale ?? 1.0;
    _playerRotation = spawn?.rotation ?? 0.0;

    // Init enemies from map objects
    for (final obj in mapData.objects.where((o) => o.type == GameObjectType.enemy)) {
      final e = _Enemy(
        source: obj,
        pos: Vector2((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts),
      );
      e.hidden = obj.hidden;
      e.alpha = obj.alpha;
      _enemies.add(e);
    }

    // Init hidden/alpha state from object properties
    for (final obj in mapData.objects) {
      if (obj.hidden) _hiddenObjectIds.add(obj.id);
      if (obj.alpha != 1.0) _objectAlpha[obj.id] = obj.alpha;
    }

    _applyStartRules();
    onHudUpdate(_health, _score);
  }

  void _applyStartRules() {
    final ts = mapData.tileSize.toDouble();
    final maxX = mapData.width * ts;
    for (final rule in rules.where((r) => r.enabled && r.trigger == TriggerType.gameStart)) {
      if (!_evalConditions(rule)) continue;
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
    _updateFades(dt);
    _updateFx(dt);
    _tickProjectileHideTimers(dt);
    _particles.update(dt);
    _checkWater(dt);        // update water state BEFORE movement
    _checkKeyTriggers(dt); // uses correct _waterSpeedMult this frame
    _checkTimerRules(dt);
    _moveEnemies(dt);
    _checkCollisions();
    _checkProximityRules();
  }

  void _updateFx(double dt) {
    final ts = mapData.tileSize.toDouble();
    for (final obj in mapData.objects) {
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (obj.projectileEnabled && _activeProjectiles.contains(obj.id)) {
        final speedPx = obj.projectileSpeed * ts;
        final rangePx = (obj.projectileRange * ts).clamp(0.01, double.infinity);
        final prev = _projectileDist[obj.id] ?? 0.0;
        final next = prev + speedPx * dt;
        if (obj.projectileLoop) {
          _projectileDist[obj.id] = next % (rangePx * 2);
        } else {
          _projectileDist[obj.id] = next.clamp(0.0, rangePx);
          if (next >= rangePx) {
            _activeProjectiles.remove(obj.id);
            // Fire land effect at landing position if no hide-timer is set
            if (!_projectileHideTimer.containsKey(obj.id)) {
              final fx = _landEffects.remove(obj.id);
              if (fx != null) {
                final wx = (obj.tileX + 0.5) * ts;
                final wy = (obj.tileY + 0.5) * ts;
                _spawnEffect(fx, wx, wy);
              }
            }
          }
        }
      }
      if (obj.dashEnabled) {
        _dashFx.putIfAbsent(obj.id, () => _DashFx(
              angleRad: obj.dashAngle * pi / 180.0,
              distancePx: obj.dashDistance * ts,
              speedPx: obj.dashSpeed * ts,
              interval: obj.dashInterval,
            )).update(dt);
      }
    }
    for (final e in _enemies) {
      if (e.hidden) continue;
      final obj = e.source;
      if (obj.projectileEnabled && _activeProjectiles.contains(obj.id)) {
        final speedPx = obj.projectileSpeed * ts;
        final rangePx = (obj.projectileRange * ts).clamp(0.01, double.infinity);
        final prev = _projectileDist[obj.id] ?? 0.0;
        final next = prev + speedPx * dt;
        if (obj.projectileLoop) {
          _projectileDist[obj.id] = next % (rangePx * 2);
        } else {
          _projectileDist[obj.id] = next.clamp(0.0, rangePx);
          if (next >= rangePx) {
            _activeProjectiles.remove(obj.id);
            // Fire land effect at landing position if no hide-timer is set
            if (!_projectileHideTimer.containsKey(obj.id)) {
              final fx = _landEffects.remove(obj.id);
              if (fx != null) {
                _spawnEffect(fx, e.pos.x, e.pos.y);
              }
            }
          }
        }
      }
      if (obj.dashEnabled) {
        _dashFx.putIfAbsent(obj.id, () => _DashFx(
              angleRad: obj.dashAngle * pi / 180.0,
              distancePx: obj.dashDistance * ts,
              speedPx: obj.dashSpeed * ts,
              interval: obj.dashInterval,
            )).update(dt);
      }
    }
  }

  (double, double) _fxOffset(GameObject obj, double ts) {
    double dx = 0, dy = 0;
    if (obj.projectileEnabled) {
      final rangePx = (obj.projectileRange * ts).clamp(0.01, double.infinity);
      final raw = _projectileDist[obj.id] ?? 0.0;
      // Ping-pong for loop: forward 0→rangePx (land), then back rangePx→0 (return)
      final dist = obj.projectileLoop
          ? (raw <= rangePx ? raw : rangePx * 2 - raw)
          : raw;
      final rad = obj.projectileAngle * pi / 180.0;
      dx += dist * cos(rad);
      dy += dist * sin(rad);
      if (obj.projectileArc > 0) {
        final progress = (dist / rangePx).clamp(0.0, 1.0);
        // Arc goes UP (negative Y in screen space) at midpoint, back to 0 at endpoints
        dy -= obj.projectileArc * ts * sin(pi * progress);
      }
    }
    if (obj.dashEnabled) {
      final fx = _dashFx[obj.id];
      if (fx != null) { dx += fx.offsetX; dy += fx.offsetY; }
    }
    return (dx, dy);
  }

  void _checkTimerRules(double dt) {
    final ts = mapData.tileSize.toDouble();
    for (final rule in rules.where((r) => r.enabled && r.trigger == TriggerType.onTimer)) {
      if (!_evalConditions(rule)) continue;
      final interval = (rule.triggerParams['interval'] as num?)?.toDouble() ?? 1.0;
      _timerElapsed[rule.id] = (_timerElapsed[rule.id] ?? 0.0) + dt;
      if (_timerElapsed[rule.id]! >= interval) {
        _timerElapsed[rule.id] = _timerElapsed[rule.id]! - interval;
        _executeActions(rule.actions, ts: ts);
      }
    }
  }

  void _updateFades(double dt) {
    if (_playerFade != null) {
      _playerFade!.elapsed += dt;
      _playerAlpha = _playerFade!.alpha;
      if (_playerFade!.isDone) {
        if (_playerAlpha <= 0) _playerHidden = true;
        _playerFade = null;
      }
    }
    for (final e in _enemies) {
      if (e.fade != null) {
        e.fade!.elapsed += dt;
        e.alpha = e.fade!.alpha;
        if (e.fade!.isDone) {
          if (e.alpha <= 0) e.hidden = true;
          e.fade = null;
        }
      }
    }
    for (final id in _objectFades.keys.toList()) {
      final f = _objectFades[id]!;
      f.elapsed += dt;
      _objectAlpha[id] = f.alpha;
      if (f.isDone) {
        if (f.alpha <= 0) {
          _hiddenObjectIds.add(id);
          // Remove faded-out collectibles from the map so they don't respawn on stop/play
          mapData.objects.removeWhere((o) =>
              o.id == id && (o.type == GameObjectType.coin || o.type == GameObjectType.chest));
        }
        _objectFades.remove(id);
      }
    }
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
    final spd = _playerSpeedTiles * ts * dt * _waterSpeedMult;

    // Fire key trigger rules (move player, score, messages, etc.)
    // Arrows always work for movement; the secondary key respects bindings.
    bool up    = keys.contains(LogicalKeyboardKey.arrowUp)    || keys.contains(_boundKey(TriggerType.keyUpPressed)    ?? LogicalKeyboardKey.keyW);
    bool down  = keys.contains(LogicalKeyboardKey.arrowDown)  || keys.contains(_boundKey(TriggerType.keyDownPressed)  ?? LogicalKeyboardKey.keyS);
    bool left  = keys.contains(LogicalKeyboardKey.arrowLeft)  || keys.contains(_boundKey(TriggerType.keyLeftPressed)  ?? LogicalKeyboardKey.keyA);
    bool right = keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(_boundKey(TriggerType.keyRightPressed) ?? LogicalKeyboardKey.keyD);
    bool space = keys.contains(_boundKey(TriggerType.keySpacePressed) ?? LogicalKeyboardKey.space);

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
    if (mapData.getTile(tx, ty).isSolid) return true;
    // Block-mode water zones act as solid walls
    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.waterBody) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (obj.tileX == tx && obj.tileY == ty &&
          (obj.properties['waterMode'] as String? ?? 'wade') == 'block') {
        return true;
      }
    }
    return false;
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
      if (!_evalConditions(rule)) continue;
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
      if (_hiddenObjectIds.contains(obj.id)) continue;
      switch (obj.type) {
        case GameObjectType.coin:
        case GameObjectType.chest:
          _fire(TriggerType.playerTouchesCollectible, triggerObj: obj, cooldownKey: obj.id);
          // Only auto-remove if no fade animation was started by the rule.
          // If a fade was started, _updateFades will hide/remove it when done.
          if (!_objectFades.containsKey(obj.id)) toRemove.add(obj);
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
      if (e.hidden) continue;
      if ((e.pos - _playerPos).length < ts * 0.55) {
        _fire(TriggerType.playerTouchesEnemy, triggerObj: e.source, cooldownKey: 'enemy_${e.source.id}');
      }
    }
  }

  void _checkProximityRules() {
    final ts = mapData.tileSize.toDouble();
    for (final rule in rules.where((r) => r.enabled && r.trigger == TriggerType.enemyNearPlayer)) {
      if (!_evalConditions(rule)) continue;
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

  void _checkWater(double dt) {
    final ts = mapData.tileSize.toDouble();
    final px = (_playerPos.x / ts).floor().clamp(0, mapData.width - 1);
    final py = (_playerPos.y / ts).floor().clamp(0, mapData.height - 1);

    GameObject? waterObj;
    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.waterBody) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (obj.tileX == px && obj.tileY == py) { waterObj = obj; break; }
    }

    final nowInWater = waterObj != null;

    if (nowInWater && !_playerInWater) {
      _playerInWater = true;
      _fire(TriggerType.playerEntersWater, triggerObj: waterObj, cooldownKey: 'waterEnter_${waterObj.id}');
    } else if (!nowInWater && _playerInWater) {
      _playerInWater = false;
      _waterDamageTimer = 0;
      _fire(TriggerType.playerExitsWater, cooldownKey: 'waterExit');
    }

    if (waterObj != null) {
      final mode = waterObj.properties['waterMode'] as String? ?? 'wade';
      _waterSpeedMult = switch (mode) {
        'block' => 0.0,
        'wade'  => 0.5,
        'swim'  => 0.7,
        'boat'  => 1.2,
        _ => 1.0,
      };

      // Flow push
      final flowDir = waterObj.properties['flowDirection'] as String? ?? 'none';
      final flowStr = (waterObj.properties['flowStrength'] as num?)?.toDouble() ?? 1.0;
      if (flowDir != 'none') {
        final flowPx = flowStr * ts * dt;
        switch (flowDir) {
          case 'N': _movePlayer(0, -flowPx);
          case 'S': _movePlayer(0, flowPx);
          case 'E': _movePlayer(flowPx, 0);
          case 'W': _movePlayer(-flowPx, 0);
        }
      }

      // Damage over time
      final damaging = waterObj.properties['damaging'] as bool? ?? false;
      if (damaging) {
        final dps = (waterObj.properties['damagePerSecond'] as num?)?.toDouble() ?? 1.0;
        _waterDamageTimer += dt;
        if (_waterDamageTimer >= 1.0) {
          _waterDamageTimer -= 1.0;
          _health = (_health - dps.round()).clamp(0, 100);
          onHudUpdate(_health, _score);
          if (_health <= 0) _fire(TriggerType.playerHealthZero);
        }
      }

      // Fishing (space while in fishable water)
      final canFish = waterObj.properties['canFish'] as bool? ?? false;
      if (canFish && HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.space)) {
        _fire(TriggerType.playerFishes, triggerObj: waterObj, cooldownKey: 'fish_${waterObj.id}');
      }
    } else {
      _waterSpeedMult = 1.0;
    }
  }

  void _fire(TriggerType trigger, {GameObject? triggerObj, String? cooldownKey}) {
    final key = cooldownKey ?? trigger.name;
    if (_cooldowns.containsKey(key)) return;

    bool anyFired = false;
    for (final rule in rules.where((r) => r.enabled && r.trigger == trigger)) {
      if (!_evalConditions(rule)) continue;
      _executeActions(rule.actions, triggerObj: triggerObj);
      anyFired = true;
    }
    if (anyFired) _cooldowns[key] = _hitCooldown;
  }

  /// Evaluates secondary conditions (index 1+) with AND/OR/NOT logic.
  bool _evalConditions(GameRule rule) {
    if (rule.conditions.length <= 1) return true;
    bool result = true; // primary condition already matched
    for (int i = 1; i < rule.conditions.length; i++) {
      final cond = rule.conditions[i];
      final op = rule.operators[i - 1];
      bool val = _checkConditionState(cond.trigger);
      if (cond.negate) val = !val;
      result = op == ConditionOp.and ? result && val : result || val;
    }
    return result;
  }

  /// Checks current game state for a given trigger type (used for secondary conditions).
  bool _checkConditionState(TriggerType t) {
    final ts = mapData.tileSize.toDouble();
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return switch (t) {
      TriggerType.keyUpPressed =>
        keys.contains(LogicalKeyboardKey.arrowUp) || keys.contains(_boundKey(TriggerType.keyUpPressed) ?? LogicalKeyboardKey.keyW),
      TriggerType.keyDownPressed =>
        keys.contains(LogicalKeyboardKey.arrowDown) || keys.contains(_boundKey(TriggerType.keyDownPressed) ?? LogicalKeyboardKey.keyS),
      TriggerType.keyLeftPressed =>
        keys.contains(LogicalKeyboardKey.arrowLeft) || keys.contains(_boundKey(TriggerType.keyLeftPressed) ?? LogicalKeyboardKey.keyA),
      TriggerType.keyRightPressed =>
        keys.contains(LogicalKeyboardKey.arrowRight) || keys.contains(_boundKey(TriggerType.keyRightPressed) ?? LogicalKeyboardKey.keyD),
      TriggerType.keySpacePressed =>
        keys.contains(_boundKey(TriggerType.keySpacePressed) ?? LogicalKeyboardKey.space),
      TriggerType.playerHealthZero => _health <= 0,
      TriggerType.enemyNearPlayer =>
        _enemies.any((e) => !e.hidden && (e.pos - _playerPos).length < ts * 5),
      TriggerType.playerTouchesEnemy =>
        _enemies.any((e) => !e.hidden && (e.pos - _playerPos).length < ts * 0.55),
      TriggerType.playerTouchesCollectible => mapData.objects.any((o) =>
        !_hiddenObjectIds.contains(o.id) &&
        (o.type == GameObjectType.coin || o.type == GameObjectType.chest) &&
        o.tileX == (_playerPos.x / ts).floor() && o.tileY == (_playerPos.y / ts).floor()),
      TriggerType.playerTouchesDoor => mapData.objects.any((o) =>
        !_hiddenObjectIds.contains(o.id) &&
        o.type == GameObjectType.door &&
        o.tileX == (_playerPos.x / ts).floor() && o.tileY == (_playerPos.y / ts).floor()),
      TriggerType.playerTouchesNpc => mapData.objects.any((o) =>
        !_hiddenObjectIds.contains(o.id) &&
        o.type == GameObjectType.npc &&
        o.tileX == (_playerPos.x / ts).floor() && o.tileY == (_playerPos.y / ts).floor()),
      TriggerType.gameStart => true,
      TriggerType.onTimer => false,
      TriggerType.playerEntersWater => _playerInWater,
      TriggerType.playerExitsWater => !_playerInWater,
      TriggerType.playerFishes => _playerInWater &&
        mapData.objects.any((o) =>
          o.type == GameObjectType.waterBody &&
          !_hiddenObjectIds.contains(o.id) &&
          (o.properties['canFish'] as bool? ?? false) &&
          o.tileX == (_playerPos.x / ts).floor() &&
          o.tileY == (_playerPos.y / ts).floor()),
    };
  }

  GameObject? _findObjectById(String id) {
    for (final obj in mapData.objects) {
      if (obj.id == id) return obj;
    }
    return null;
  }

  GameObject? _findNamedObject(String name) {
    for (final obj in mapData.objects) {
      if (obj.name == name) return obj;
    }
    return null;
  }

  void _tickProjectileHideTimers(double dt) {
    final ts = mapData.tileSize.toDouble();
    for (final id in _projectileHideTimer.keys.toList()) {
      _projectileHideTimer[id] = _projectileHideTimer[id]! - dt;
      if (_projectileHideTimer[id]! <= 0) {
        _projectileHideTimer.remove(id);
        _activeProjectiles.remove(id);
        _projectileDist[id] = 0.0;
        final obj = _findObjectById(id);
        if (obj != null) {
          // Resolve current world position for the effect
          final enemy = _enemyFor(obj);
          double wx, wy;
          if (enemy != null) {
            wx = enemy.pos.x; wy = enemy.pos.y;
            enemy.hidden = true;
          } else {
            wx = (obj.tileX + 0.5) * ts; wy = (obj.tileY + 0.5) * ts;
            _hiddenObjectIds.add(id);
          }
          // Fire land effect if configured
          final fx = _landEffects.remove(id);
          if (fx != null) _spawnEffect(fx, wx, wy);
        }
      }
    }
  }

  List<GameObject> _findTaggedObjects(String tag) {
    if (tag.isEmpty) return [];
    return mapData.objects.where((o) => o.tag == tag).toList();
  }

  _Enemy? _enemyFor(GameObject obj) {
    for (final e in _enemies) {
      if (e.source.id == obj.id) return e;
    }
    return null;
  }

  void _executeActions(List<RuleAction> actions,
      {GameObject? triggerObj, double dt = 0, double dirX = 0, double dirY = 0, double ts = 32}) {
    for (final a in actions) {
      switch (a.type) {
        case ActionType.movePlayer:
          final speed = ((a.params['speed'] as int?) ?? 4).toDouble();
          final spd = speed * ts * dt * _waterSpeedMult;
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
        case ActionType.setScale:
          final target = a.params['target'] as String? ?? 'player';
          final val = double.tryParse(a.params['value']?.toString() ?? '') ?? 1.0;
          if (target == 'player') {
            _playerScale = val;
          } else if (target == 'trigger' && triggerObj != null) {
            triggerObj.scale = val;
          } else if (target == 'named') {
            _findNamedObject(a.params['objectName'] as String? ?? '')?.scale = val;
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) obj.scale = val;
          } else if (target == 'enemies') {
            for (final e in _enemies) e.source.scale = val;
          }
        case ActionType.setRotation:
          final target = a.params['target'] as String? ?? 'player';
          final angle = ((a.params['angle'] as int?) ?? 0).toDouble();
          if (target == 'player') {
            _playerRotation = angle;
          } else if (target == 'trigger' && triggerObj != null) {
            triggerObj.rotation = angle;
          } else if (target == 'named') {
            _findNamedObject(a.params['objectName'] as String? ?? '')?.rotation = angle;
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) obj.rotation = angle;
          } else if (target == 'enemies') {
            for (final e in _enemies) e.source.rotation = angle;
          }
        case ActionType.adjustRotation:
          final target = a.params['target'] as String? ?? 'player';
          final delta = ((a.params['angle'] as int?) ?? 0).toDouble();
          if (target == 'player') {
            _playerRotation = (_playerRotation + delta) % 360;
          } else if (target == 'trigger' && triggerObj != null) {
            triggerObj.rotation = (triggerObj.rotation + delta) % 360;
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) obj.rotation = (obj.rotation + delta) % 360;
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              obj.rotation = (obj.rotation + delta) % 360;
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) e.source.rotation = (e.source.rotation + delta) % 360;
          }
        case ActionType.flipH:
          final target = a.params['target'] as String? ?? 'player';
          if (target == 'player') {
            _playerFlipH = !_playerFlipH;
          } else if (target == 'trigger' && triggerObj != null) {
            triggerObj.flipH = !triggerObj.flipH;
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) obj.flipH = !obj.flipH;
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) obj.flipH = !obj.flipH;
          } else if (target == 'enemies') {
            for (final e in _enemies) e.source.flipH = !e.source.flipH;
          }
        case ActionType.flipV:
          final target = a.params['target'] as String? ?? 'player';
          if (target == 'player') {
            _playerFlipV = !_playerFlipV;
          } else if (target == 'trigger' && triggerObj != null) {
            triggerObj.flipV = !triggerObj.flipV;
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) obj.flipV = !obj.flipV;
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) obj.flipV = !obj.flipV;
          } else if (target == 'enemies') {
            for (final e in _enemies) e.source.flipV = !e.source.flipV;
          }
        case ActionType.hideObject:
          final target = a.params['target'] as String? ?? 'trigger';
          if (target == 'player') {
            _playerHidden = true;
          } else if (target == 'trigger' && triggerObj != null) {
            final enemy = _enemyFor(triggerObj);
            if (enemy != null) { enemy.hidden = true; } else { _hiddenObjectIds.add(triggerObj.id); }
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) _hiddenObjectIds.add(obj.id);
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final enemy = _enemyFor(obj);
              if (enemy != null) { enemy.hidden = true; } else { _hiddenObjectIds.add(obj.id); }
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) e.hidden = true;
          }
        case ActionType.showObject:
          final target = a.params['target'] as String? ?? 'trigger';
          if (target == 'player') {
            _playerHidden = false;
          } else if (target == 'trigger' && triggerObj != null) {
            final enemy = _enemyFor(triggerObj);
            if (enemy != null) { enemy.hidden = false; } else { _hiddenObjectIds.remove(triggerObj.id); }
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) _hiddenObjectIds.remove(obj.id);
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final enemy = _enemyFor(obj);
              if (enemy != null) { enemy.hidden = false; } else { _hiddenObjectIds.remove(obj.id); }
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) e.hidden = false;
          }
        case ActionType.fadeIn:
          final target = a.params['target'] as String? ?? 'trigger';
          final dur = double.tryParse(a.params['duration']?.toString() ?? '') ?? 1.0;
          if (target == 'player') {
            _playerHidden = false;
            _playerFade = _FadeAnim(_playerAlpha, 1.0, dur);
          } else if (target == 'trigger' && triggerObj != null) {
            final enemy = _enemyFor(triggerObj);
            if (enemy != null) {
              enemy.hidden = false;
              enemy.fade = _FadeAnim(enemy.alpha, 1.0, dur);
            } else {
              _hiddenObjectIds.remove(triggerObj.id);
              _objectFades[triggerObj.id] = _FadeAnim(_objectAlpha[triggerObj.id] ?? 0.0, 1.0, dur);
            }
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) {
              _hiddenObjectIds.remove(obj.id);
              _objectFades[obj.id] = _FadeAnim(_objectAlpha[obj.id] ?? 0.0, 1.0, dur);
            }
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final enemy = _enemyFor(obj);
              if (enemy != null) {
                enemy.hidden = false;
                enemy.fade = _FadeAnim(enemy.alpha, 1.0, dur);
              } else {
                _hiddenObjectIds.remove(obj.id);
                _objectFades[obj.id] = _FadeAnim(_objectAlpha[obj.id] ?? 0.0, 1.0, dur);
              }
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) {
              e.hidden = false;
              e.fade = _FadeAnim(e.alpha, 1.0, dur);
            }
          }
        case ActionType.fadeOut:
          final target = a.params['target'] as String? ?? 'trigger';
          final dur = double.tryParse(a.params['duration']?.toString() ?? '') ?? 1.0;
          if (target == 'player') {
            _playerFade = _FadeAnim(_playerAlpha, 0.0, dur);
          } else if (target == 'trigger' && triggerObj != null) {
            final enemy = _enemyFor(triggerObj);
            if (enemy != null) {
              enemy.fade = _FadeAnim(enemy.alpha, 0.0, dur);
            } else {
              _objectFades[triggerObj.id] = _FadeAnim(_objectAlpha[triggerObj.id] ?? 1.0, 0.0, dur);
            }
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) {
              _objectFades[obj.id] = _FadeAnim(_objectAlpha[obj.id] ?? 1.0, 0.0, dur);
            }
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final enemy = _enemyFor(obj);
              if (enemy != null) {
                enemy.fade = _FadeAnim(enemy.alpha, 0.0, dur);
              } else {
                _objectFades[obj.id] = _FadeAnim(_objectAlpha[obj.id] ?? 1.0, 0.0, dur);
              }
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) e.fade = _FadeAnim(e.alpha, 0.0, dur);
          }
        case ActionType.setAlpha:
          final target = a.params['target'] as String? ?? 'player';
          final val = double.tryParse(a.params['value']?.toString() ?? '') ?? 1.0;
          final clamped = val.clamp(0.0, 1.0);
          if (target == 'player') {
            _playerAlpha = clamped;
            _playerFade = null;
          } else if (target == 'trigger' && triggerObj != null) {
            final enemy = _enemyFor(triggerObj);
            if (enemy != null) {
              enemy.alpha = clamped;
              enemy.fade = null;
            } else {
              _objectAlpha[triggerObj.id] = clamped;
              _objectFades.remove(triggerObj.id);
            }
          } else if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) {
              _objectAlpha[obj.id] = clamped;
              _objectFades.remove(obj.id);
            }
          } else if (target == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final enemy = _enemyFor(obj);
              if (enemy != null) {
                enemy.alpha = clamped;
                enemy.fade = null;
              } else {
                _objectAlpha[obj.id] = clamped;
                _objectFades.remove(obj.id);
              }
            }
          } else if (target == 'enemies') {
            for (final e in _enemies) {
              e.alpha = clamped;
              e.fade = null;
            }
          }
        case ActionType.launchProjectile:
          final target = a.params['target'] as String? ?? 'named';
          final fromObjName = (a.params['fromObject'] as String? ?? '').trim();
          final fromObj = fromObjName.isNotEmpty ? _findNamedObject(fromObjName) : null;
          // Resolve launch origin in pixels (accounts for enemy moving position)
          double originPx, originPy;
          if (fromObj != null) {
            final fromEnemy = _enemyFor(fromObj);
            if (fromEnemy != null) {
              originPx = fromEnemy.pos.x;
              originPy = fromEnemy.pos.y;
            } else {
              originPx = (fromObj.tileX + 0.5) * ts;
              originPy = (fromObj.tileY + 0.5) * ts;
            }
          } else {
            originPx = _playerPos.x;
            originPy = _playerPos.y;
          }
          List<GameObject> projectiles = [];
          if (target == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) projectiles.add(obj);
          } else if (target == 'tag') {
            projectiles.addAll(_findTaggedObjects(a.params['tag'] as String? ?? ''));
          }
          final hideAfterSec = double.tryParse(a.params['hideAfter']?.toString() ?? '') ?? 0.0;
          final landFxName = (a.params['landEffectName'] as String? ?? '').trim();
          final landFxDef = landFxName.isNotEmpty ? _findEffect(landFxName) : null;
          for (final obj in projectiles) {
            _projectileDist[obj.id] = 0.0;
            _activeProjectiles.add(obj.id);
            if (hideAfterSec > 0) {
              _projectileHideTimer[obj.id] = hideAfterSec;
            } else {
              _projectileHideTimer.remove(obj.id);
            }
            if (landFxDef != null) {
              _landEffects[obj.id] = landFxDef;
            } else {
              _landEffects.remove(obj.id);
            }
            final bombEnemy = _enemyFor(obj);
            if (bombEnemy != null) {
              // Enemy-type: update pos and e.hidden
              bombEnemy.pos.x = originPx;
              bombEnemy.pos.y = originPy;
              bombEnemy.hidden = false;
              bombEnemy.alpha = 1.0;
              bombEnemy.fade = null;
            } else {
              // Non-enemy: update tileX/tileY and _hiddenObjectIds
              obj.tileX = (originPx / ts - 0.5).round();
              obj.tileY = (originPy / ts - 0.5).round();
              _hiddenObjectIds.remove(obj.id);
              _objectAlpha[obj.id] = 1.0;
              _objectFades.remove(obj.id);
            }
          }
        case ActionType.stopProjectile:
          final stopTarget = a.params['target'] as String? ?? 'named';
          List<GameObject> stopList = [];
          if (stopTarget == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) stopList.add(obj);
          } else if (stopTarget == 'tag') {
            stopList.addAll(_findTaggedObjects(a.params['tag'] as String? ?? ''));
          }
          for (final obj in stopList) {
            _activeProjectiles.remove(obj.id);
            _projectileDist[obj.id] = 0.0;
            _projectileHideTimer.remove(obj.id);
            _landEffects.remove(obj.id);
          }
        case ActionType.playEffect:
          final fxName = (a.params['effectName'] as String? ?? '').trim();
          final fxDef = _findEffect(fxName);
          if (fxDef == null) break;
          final effectTarget = a.params['target'] as String? ?? 'trigger';
          final positions = <(double, double)>[];
          if (effectTarget == 'trigger' && triggerObj != null) {
            final en = _enemyFor(triggerObj);
            positions.add(en != null
                ? (en.pos.x, en.pos.y)
                : ((triggerObj.tileX + 0.5) * ts, (triggerObj.tileY + 0.5) * ts));
          } else if (effectTarget == 'player') {
            positions.add((_playerPos.x, _playerPos.y));
          } else if (effectTarget == 'named') {
            final obj = _findNamedObject(a.params['objectName'] as String? ?? '');
            if (obj != null) {
              final en = _enemyFor(obj);
              positions.add(en != null
                  ? (en.pos.x, en.pos.y)
                  : ((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts));
            }
          } else if (effectTarget == 'tag') {
            for (final obj in _findTaggedObjects(a.params['tag'] as String? ?? '')) {
              final en = _enemyFor(obj);
              positions.add(en != null
                  ? (en.pos.x, en.pos.y)
                  : ((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts));
            }
          }
          for (final pos in positions) {
            _spawnEffect(fxDef, pos.$1, pos.$2);
          }
        default:
          break;
      }
    }
  }

  void _spawnEffect(GameEffect fx, double wx, double wy) {
    final ts = mapData.tileSize.toDouble();
    final spreadPx = fx.spread * ts;
    final speedPx = fx.speed * ts;
    final sm = fx.particleSize;
    switch (fx.type) {
      case 'blast':
        _particles.spawnBlast(wx, wy,
            count: fx.count,
            radiusPx: fx.radius * ts,
            durationSec: fx.duration < 0 ? 0.8 : fx.duration,
            theme: BlastThemeExt.fromId(fx.blastColor),
            sizeMultiplier: sm);
      case 'fire':
        _particles.startFire(wx, wy,
            intensity: fx.intensity, spreadPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
      case 'snow':
        _particles.startSnow(wx, wy,
            density: fx.intensity, areaPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
      case 'electric':
        _particles.spawnElectric(wx, wy,
            arcCount: fx.intensity, rangePx: spreadPx,
            durationSec: fx.duration < 0 ? 0.35 : fx.duration,
            sizeMultiplier: sm);
      case 'smoke':
        _particles.startSmoke(wx, wy,
            density: fx.intensity, spreadPx: spreadPx, speedPx: speedPx,
            duration: fx.duration, sizeMultiplier: sm, maxParticles: fx.maxParticles);
    }
  }

  void render(Canvas canvas) {
    final ts = mapData.tileSize.toDouble();
    final r = ts * 0.32;

    // Water body overlays — drawn first, below everything
    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.waterBody) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      _drawWaterTile(canvas, obj, ts);
    }

    for (final obj in mapData.objects) {
      if (obj.type == GameObjectType.playerSpawn || obj.type == GameObjectType.enemy ||
          obj.type == GameObjectType.waterBody) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      final alpha = _objectAlpha[obj.id] ?? 1.0;
      final floatY = obj.floatEnabled
          ? obj.floatAmplitude * sin(2 * pi * obj.floatSpeed * _elapsedSec)
          : 0.0;
      final (fxDx, fxDy) = _fxOffset(obj, ts);
      _drawObject(
          canvas,
          Offset((obj.tileX + 0.5) * ts + fxDx, (obj.tileY + 0.5) * ts + floatY + fxDy),
          ts, r, obj.type,
          flipH: obj.flipH, flipV: obj.flipV,
          scale: obj.scale, rotation: obj.rotation, alpha: alpha);
    }

    for (final e in _enemies) {
      if (e.hidden) continue;
      final floatY = e.source.floatEnabled
          ? e.source.floatAmplitude * sin(2 * pi * e.source.floatSpeed * _elapsedSec)
          : 0.0;
      final (fxDx, fxDy) = _fxOffset(e.source, ts);
      _drawObject(canvas, Offset(e.pos.x + fxDx, e.pos.y + floatY + fxDy), ts, r, e.source.type,
          flipH: e.source.flipH, flipV: e.source.flipV,
          scale: e.source.scale, rotation: e.source.rotation, alpha: e.alpha);
    }

    // Player
    if (!_playerHidden) {
      final spawn = mapData.objects.where((o) => o.type == GameObjectType.playerSpawn).firstOrNull;
      final playerFloatY = (spawn != null && spawn.floatEnabled)
          ? spawn.floatAmplitude * sin(2 * pi * spawn.floatSpeed * _elapsedSec)
          : 0.0;
      final playerDrawY = _playerPos.y + playerFloatY;
      final playerSprite = _resolveSprite(GameObjectType.playerSpawn);
      if (playerSprite != null) {
        _drawSprite(canvas, playerSprite, _playerPos.x, playerDrawY, ts,
            flipH: _playerFlipH, flipV: _playerFlipV,
            scale: _playerScale, rotation: _playerRotation, alpha: _playerAlpha);
      } else {
        _drawCircle(canvas, Offset(_playerPos.x, playerDrawY), r,
            const Color(0xFF4ADE80), 'P', alpha: _playerAlpha);
      }
    }

    // Particles — always on top
    _particles.render(canvas);
  }

  void _drawObject(Canvas canvas, Offset center, double ts, double r, GameObjectType type,
      {bool flipH = false, bool flipV = false,
      double scale = 1.0, double rotation = 0.0, double alpha = 1.0}) {
    final sprite = _resolveSprite(type);
    if (sprite != null) {
      _drawSprite(canvas, sprite, center.dx, center.dy, ts,
          flipH: flipH, flipV: flipV, scale: scale, rotation: rotation, alpha: alpha);
    } else {
      _drawCircle(canvas, center, r, type.color, type.symbol, alpha: alpha);
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

  void _drawSprite(Canvas canvas, ui.Image image, double cx, double cy, double ts,
      {bool flipH = false, bool flipV = false,
      double scale = 1.0, double rotation = 0.0, double alpha = 1.0}) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.save();
    canvas.translate(cx, cy);
    if (rotation != 0.0) canvas.rotate(rotation * pi / 180.0);
    canvas.scale(flipH ? -scale : scale, flipV ? -scale : scale);
    canvas.drawImageRect(
      image, src,
      Rect.fromCenter(center: Offset.zero, width: ts, height: ts),
      Paint()..color = Color.fromARGB((alpha * 255).round().clamp(0, 255), 255, 255, 255),
    );
    canvas.restore();
  }

  void _drawCircle(Canvas canvas, Offset center, double r, Color color, String symbol,
      {double alpha = 1.0}) {
    canvas.drawCircle(center + const Offset(1, 2), r,
        Paint()..color = Color(0x4D000000).withOpacity(0.3 * alpha));
    canvas.drawCircle(center, r, Paint()..color = color.withOpacity(alpha));
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: Color.fromARGB((alpha * 255).round().clamp(0, 255), 255, 255, 255),
          fontSize: r * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
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
