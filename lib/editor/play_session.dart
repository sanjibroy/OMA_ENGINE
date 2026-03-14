import 'dart:math' show pi, sin, cos, atan2, sqrt, max, Random;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard, LogicalKeyboardKey;
import '../effects/particle_system.dart';
import '../models/game_effect.dart';
import '../models/game_object.dart';
import '../models/game_rule.dart';
import '../models/item_def.dart';
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

// ─── Live weapon projectile ───────────────────────────────────────────────────

class _LiveProjectile {
  Vector2 pos;
  final Vector2 dir;       // normalized direction
  final double speedPx;
  final double damage;
  final double rangePx;
  final bool piercing;
  double distTraveled = 0;

  _LiveProjectile({
    required this.pos,
    required this.dir,
    required this.speedPx,
    required this.damage,
    required this.rangePx,
    required this.piercing,
  });
}

// ─── Enemy ────────────────────────────────────────────────────────────────────

class _Enemy {
  final GameObject source;
  Vector2 pos;

  _EnemyBehavior behavior = _EnemyBehavior.idle;
  bool hidden = false;
  double alpha = 1.0;
  _FadeAnim? fade;
  double pixelSpeed = 0;
  double chaseRangePx = 0;
  int health = 3;
  int maxHealth = 3;

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

  /// Returns true if this hit killed the enemy.
  bool takeDamage(double dmg) {
    health = (health - dmg.round()).clamp(0, maxHealth);
    return health <= 0;
  }

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
  final List<ItemDef> items;
  final Map<String, String> keyBindings;

  final void Function(int health, int score, int coins, int gems, int items) onHudUpdate;
  final void Function(String msg) onMessage;
  final void Function(String event) onGameEvent;
  final void Function(String? name)? onEquippedItemChanged;

  bool debugCollision = false;

  late Vector2 _playerPos;
  bool _playerFlipH = false;
  bool _playerFlipV = false;
  double _playerScale = 1.0;
  double _playerRotation = 0.0;
  String _playerColliderShape = 'circle';
  double _playerColliderR = 0.35;
  double _playerColliderW = 0.35;
  double _playerColliderH = 0.35;
  double _playerColliderRX = 0.35;
  double _playerColliderRY = 0.35;
  List<List<double>> _playerColliderPoly = [];
  int _health = 100;
  int _score = 0;
  int _coinCount = 0;
  int _gemCount = 0;
  int _itemCount = 0;
  Vector2? _checkpointPos; // last activated checkpoint position
  ItemDef? _equippedItem;  // currently held weapon/tool
  Vector2 _facingDir = Vector2(1, 0); // last movement direction for attack aim
  double _attackCooldown = 0;
  double _swingTimer = 0;
  bool _spaceWasPressed = false;
  final List<_LiveProjectile> _liveProjectiles = [];
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
  final _shakeRand = Random();
  double _shakeRemaining = 0;
  double _shakeTotalDuration = 0;
  double _shakeMagnitude = 0;
  double _shakeX = 0;
  double _shakeY = 0;

  double get cameraShakeX => _shakeX;
  double get cameraShakeY => _shakeY;

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
    this.items = const [],
    this.keyBindings = const {},
    required this.onHudUpdate,
    required this.onMessage,
    required this.onGameEvent,
    this.onEquippedItemChanged,
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
    _playerColliderShape = spawn?.properties['blockShape'] as String? ?? 'circle';
    _playerColliderR  = (spawn?.properties['blockR']  as num?)?.toDouble() ?? 0.35;
    _playerColliderW  = (spawn?.properties['blockW']  as num?)?.toDouble() ?? 0.35;
    _playerColliderH  = (spawn?.properties['blockH']  as num?)?.toDouble() ?? 0.35;
    _playerColliderRX = (spawn?.properties['blockRX'] as num?)?.toDouble() ?? 0.35;
    _playerColliderRY = (spawn?.properties['blockRY'] as num?)?.toDouble() ?? 0.35;
    final rawPoly = spawn?.properties['sortPoints'];
    _playerColliderPoly = rawPoly is List
        ? rawPoly.whereType<List>().map((p) => p.cast<double>()).toList()
        : [];

    // Init enemies from map objects
    for (final obj in mapData.objects.where((o) => o.type == GameObjectType.enemy)) {
      final hp = ((obj.properties['health'] as num?)?.toInt() ?? 3).clamp(1, 9999);
      final e = _Enemy(
        source: obj,
        pos: Vector2((obj.tileX + 0.5) * ts, (obj.tileY + 0.5) * ts),
      );
      e.health = hp;
      e.maxHealth = hp;
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
    onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
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
    if (_attackCooldown > 0) _attackCooldown = (_attackCooldown - dt).clamp(0.0, double.infinity);
    if (_swingTimer > 0) _swingTimer = (_swingTimer - dt).clamp(0.0, double.infinity);
    _tickCooldowns(dt);
    _updateFades(dt);
    _tickShake(dt);
    _updateFx(dt);
    _tickProjectileHideTimers(dt);
    _particles.update(dt);
    _checkWater(dt);        // update water state BEFORE movement
    _checkKeyTriggers(dt); // uses correct _waterSpeedMult this frame
    _checkTimerRules(dt);
    _updateLiveProjectiles(dt);
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

  void _tickShake(double dt) {
    if (_shakeRemaining <= 0) {
      _shakeX = 0;
      _shakeY = 0;
      return;
    }
    _shakeRemaining -= dt;
    // Decay magnitude toward zero as shake timer runs out
    final progress = (_shakeRemaining / _shakeTotalDuration).clamp(0.0, 1.0);
    final mag = _shakeMagnitude * progress;
    _shakeX = (_shakeRand.nextDouble() - 0.5) * mag * 2;
    _shakeY = (_shakeRand.nextDouble() - 0.5) * mag * 2;
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

    // Update facing direction from movement input
    double fdx = 0, fdy = 0;
    if (left)  fdx -= 1;
    if (right) fdx += 1;
    if (up)    fdy -= 1;
    if (down)  fdy += 1;
    if (fdx != 0 || fdy != 0) _facingDir = Vector2(fdx, fdy).normalized();

    // Attack on space edge (fires once per press, not held)
    if (space && !_spaceWasPressed && _equippedItem != null && _attackCooldown <= 0) {
      _tryAttack();
    }
    _spaceWasPressed = space;

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

  /// Returns true if a point (px, py) hits a solid tile or block-mode water.
  /// Does NOT check solid props — use [_propSolidAt] for that.
  bool _solidAt(double px, double py) {
    final ts = mapData.tileSize.toDouble();
    final tx = (px / ts).floor().clamp(0, mapData.width - 1);
    final ty = (py / ts).floor().clamp(0, mapData.height - 1);
    final col = mapData.getTileCollision(tx, ty);
    if (col == 1) return false;
    if (col == 2) return true;
    if (mapData.getTile(tx, ty).isSolid) return true;
    for (final obj in mapData.objects) {
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (obj.tileX != tx || obj.tileY != ty) continue;
      if (obj.type == GameObjectType.waterBody &&
          (obj.properties['waterMode'] as String? ?? 'wade') == 'block') {
        return true;
      }
    }
    return false;
  }

  /// Returns true if a point (px, py) is inside a solid prop's collision shape.
  bool _propSolidAt(double px, double py) {
    final ts = mapData.tileSize.toDouble();
    for (final obj in mapData.objects) {
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (obj.type != GameObjectType.prop) continue;
      if (!(obj.properties['solid'] as bool? ?? true)) continue;
      final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
      final shape = obj.properties['blockShape'] as String? ?? 'rect';
      switch (shape) {
        case 'circle':
          final r = ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.5) * ts;
          final dx = px - cx, dy = py - cy;
          if (dx * dx + dy * dy <= r * r) return true;
        case 'ellipse':
          final rx = ((obj.properties['blockRX'] as num?)?.toDouble() ?? 0.5) * ts;
          final ry = ((obj.properties['blockRY'] as num?)?.toDouble() ?? 0.5) * ts;
          final dx = px - cx, dy = py - cy;
          if (rx > 0 && ry > 0 &&
              (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0) return true;
        case 'custom':
          if (_pointInSortPolygon(px, py, obj, cx, cy, ts)) return true;
        default: // 'rect'
          final hw = ((obj.properties['blockW'] as num?)?.toDouble() ?? 1.0) * ts / 2;
          final hh = ((obj.properties['blockH'] as num?)?.toDouble() ?? 1.0) * ts / 2;
          if (px >= cx - hw && px < cx + hw && py >= cy - hh && py < cy + hh) return true;
      }
    }
    return false;
  }

  /// Returns a list of sample points on/inside the player collider at (cx,cy).
  List<(double, double)> _playerColliderPoints(double cx, double cy) {
    final ts = mapData.tileSize.toDouble();
    switch (_playerColliderShape) {
      case 'circle':
        final r = _playerColliderR * ts;
        return [
          (cx, cy), (cx, cy - r), (cx, cy + r), (cx - r, cy), (cx + r, cy),
          (cx - r * 0.707, cy - r * 0.707), (cx + r * 0.707, cy - r * 0.707),
          (cx - r * 0.707, cy + r * 0.707), (cx + r * 0.707, cy + r * 0.707),
        ];
      case 'ellipse':
        final rx = _playerColliderRX * ts;
        final ry = _playerColliderRY * ts;
        return [
          (cx, cy), (cx, cy - ry), (cx, cy + ry), (cx - rx, cy), (cx + rx, cy),
          (cx - rx * 0.707, cy - ry * 0.707), (cx + rx * 0.707, cy - ry * 0.707),
          (cx - rx * 0.707, cy + ry * 0.707), (cx + rx * 0.707, cy + ry * 0.707),
        ];
      case 'rect':
        final hw = _playerColliderW * ts;
        final hh = _playerColliderH * ts;
        return [
          (cx, cy),
          (cx - hw, cy - hh), (cx + hw, cy - hh),
          (cx - hw, cy + hh), (cx + hw, cy + hh),
          (cx, cy - hh), (cx, cy + hh), (cx - hw, cy), (cx + hw, cy),
        ];
      case 'custom':
        if (_playerColliderPoly.length >= 3) {
          final pts = <(double, double)>[(cx, cy)];
          for (final p in _playerColliderPoly) {
            if (p.length >= 2) pts.add((cx + p[0] * ts, cy + p[1] * ts));
          }
          return pts;
        }
        // fallback to circle
        final r = _playerColliderR * ts;
        return [(cx, cy), (cx - r, cy - r), (cx + r, cy - r),
                (cx - r, cy + r), (cx + r, cy + r)];
      default:
        final r = _playerColliderR * ts;
        return [(cx, cy), (cx - r, cy - r), (cx + r, cy - r),
                (cx - r, cy + r), (cx + r, cy + r)];
    }
  }

  /// Effective touch radius for an entity based on its collider shape.
  double _entityTouchR(GameObject obj) {
    final ts = mapData.tileSize.toDouble();
    final shape = obj.properties['blockShape'] as String? ?? 'circle';
    switch (shape) {
      case 'rect':
        final w = (obj.properties['blockW'] as num?)?.toDouble() ?? 0.38;
        final h = (obj.properties['blockH'] as num?)?.toDouble() ?? 0.38;
        return max(w, h) * ts;
      case 'ellipse':
        final rx = (obj.properties['blockRX'] as num?)?.toDouble() ?? 0.38;
        final ry = (obj.properties['blockRY'] as num?)?.toDouble() ?? 0.38;
        return max(rx, ry) * ts;
      default:
        return ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.38) * ts;
    }
  }

  double _playerTouchR() {
    final ts = mapData.tileSize.toDouble();
    switch (_playerColliderShape) {
      case 'rect':    return max(_playerColliderW, _playerColliderH) * ts;
      case 'ellipse': return max(_playerColliderRX, _playerColliderRY) * ts;
      default:        return _playerColliderR * ts;
    }
  }

  /// Returns true if the player collider at (cx, cy) overlaps a solid.
  bool _collidesAt(double cx, double cy) {
    final pts = _playerColliderPoints(cx, cy);
    // Check tile solids with the corner points only (4 corners + center)
    for (final (px, py) in pts.take(5)) {
      if (_solidAt(px, py)) return true;
    }
    // Check props with all sample points
    for (final (px, py) in pts) {
      if (_propSolidAt(px, py)) return true;
    }
    return false;
  }

  /// Effective Y used for depth sorting. Uses sort polygon max-Y if defined,
  /// else falls back to sortAnchorY offset from sprite centre.
  /// Ray-casting point-in-polygon test using the object's sortPoints.
  bool _pointInSortPolygon(double px, double py, GameObject obj,
      double cx, double cy, double ts) {
    final raw = obj.properties['sortPoints'];
    if (raw is! List || raw.length < 3) return false;
    // Build world-space vertices
    final verts = <(double, double)>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        verts.add((cx + (p[0] as num).toDouble() * ts,
                   cy + (p[1] as num).toDouble() * ts));
      }
    }
    if (verts.length < 3) return false;
    bool inside = false;
    int j = verts.length - 1;
    for (int i = 0; i < verts.length; i++) {
      final xi = verts[i].$1, yi = verts[i].$2;
      final xj = verts[j].$1, yj = verts[j].$2;
      if (((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  double _sortY(GameObject obj, double ts) {
    final centerY = (obj.tileY + 0.5) * ts + obj.offsetY;
    final rawPoints = obj.properties['sortPoints'];
    if (rawPoints is List && rawPoints.isNotEmpty) {
      double maxDy = double.negativeInfinity;
      for (final p in rawPoints) {
        if (p is List && p.length >= 2) {
          final dy = (p[1] as num).toDouble();
          if (dy > maxDy) maxDy = dy;
        }
      }
      if (maxDy != double.negativeInfinity) return centerY + maxDy * ts;
    }
    return centerY + obj.sortAnchorY * ts;
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
      return;
    }
    // Escape sticking at irregular polygon corners — try angled slides
    _trySlideEscape(dx, dy);
  }

  /// When fully blocked, try moving at ±20° and ±40° from intended direction
  /// so the player slides along irregular polygon edges instead of sticking.
  void _trySlideEscape(double dx, double dy) {
    final len = sqrt(dx * dx + dy * dy);
    if (len < 0.001) return;
    final ux = dx / len, uy = dy / len;
    final ts = mapData.tileSize.toDouble();
    final maxX = mapData.width * ts;
    final maxY = mapData.height * ts;
    for (final deg in [-20.0, 20.0, -40.0, 40.0]) {
      final rad = deg * pi / 180.0;
      final ca = cos(rad), sa = sin(rad);
      final tx = (_playerPos.x + len * (ux * ca - uy * sa)).clamp(0.0, maxX);
      final ty = (_playerPos.y + len * (ux * sa + uy * ca)).clamp(0.0, maxY);
      if (!_collidesAt(tx, ty)) {
        _playerPos.x = tx;
        _playerPos.y = ty;
        return;
      }
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
          _coinCount += (obj.properties['value'] as num?)?.toInt() ?? 1;
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
          _fire(TriggerType.playerTouchesCollectible, triggerObj: obj, cooldownKey: obj.id);
          if (!_objectFades.containsKey(obj.id)) toRemove.add(obj);
        case GameObjectType.gem:
          _gemCount += (obj.properties['value'] as num?)?.toInt() ?? 1;
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
          _fire(TriggerType.playerTouchesCollectible, triggerObj: obj, cooldownKey: obj.id);
          if (!_objectFades.containsKey(obj.id)) toRemove.add(obj);
        case GameObjectType.collectible:
          _itemCount += (obj.properties['value'] as num?)?.toInt() ?? 1;
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
          _fire(TriggerType.playerTouchesCollectible, triggerObj: obj, cooldownKey: obj.id);
          if (!_objectFades.containsKey(obj.id)) toRemove.add(obj);
        case GameObjectType.hazard:
          final dmg = (obj.properties['damage'] as num?)?.toDouble() ?? 1.0;
          _fire(TriggerType.playerTouchesHazard, triggerObj: obj, cooldownKey: 'hazard_${obj.id}');
          if (!_cooldowns.containsKey('hazardDmg_${obj.id}')) {
            _health = (_health - dmg.round()).clamp(0, 100);
            onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
            _cooldowns['hazardDmg_${obj.id}'] = _hitCooldown;
            if (_health <= 0) _fire(TriggerType.playerHealthZero);
          }
        case GameObjectType.checkpoint:
          final ts2 = mapData.tileSize.toDouble();
          final newPos = Vector2((obj.tileX + 0.5) * ts2, (obj.tileY + 0.5) * ts2);
          if (_checkpointPos == null || _checkpointPos != newPos) {
            _checkpointPos = newPos;
            _fire(TriggerType.playerActivatesCheckpoint, triggerObj: obj, cooldownKey: 'cp_${obj.id}');
          }
        case GameObjectType.weaponPickup:
          final itemId = obj.properties['itemId'] as String? ?? '';
          if (itemId.isNotEmpty) {
            try {
              final def = items.firstWhere((i) => i.id == itemId);
              _equippedItem = def;
              onEquippedItemChanged?.call(def.name);
              onMessage('Picked up ${def.name}');
            } catch (_) {}
            mapData.objects.remove(obj);
          }
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
      final touchDist = _playerTouchR() + _entityTouchR(e.source);
      if ((e.pos - _playerPos).length < touchDist) {
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

  // ─── Combat ───────────────────────────────────────────────────────────────

  void _tryAttack() {
    final item = _equippedItem!;
    if (item.category == WeaponCategory.ranged) {
      _doRangedAttack(item);
    } else {
      _doMeleeAttack(item);
    }
  }

  void _doMeleeAttack(ItemDef item) {
    final ts = mapData.tileSize.toDouble();
    _attackCooldown = item.cooldown;
    _swingTimer = 0.25;

    final rangePx = item.combatRange * ts;
    final toKill = <_Enemy>[];

    for (final e in _enemies) {
      if (e.hidden) continue;
      final diff = e.pos - _playerPos;
      if (diff.length > rangePx) continue;
      // 180° frontal arc — enemy must be roughly in front of player
      if (diff.length > 0.01 && diff.normalized().dot(_facingDir) < 0) continue;
      if (e.takeDamage(item.combatDamage)) toKill.add(e);
    }
    for (final e in toKill) _killEnemy(e);
  }

  void _doRangedAttack(ItemDef item) {
    final ts = mapData.tileSize.toDouble();
    _attackCooldown = item.cooldown;
    final dir = _facingDir.clone();
    if (dir.length < 0.01) dir.x = 1;
    _liveProjectiles.add(_LiveProjectile(
      pos: _playerPos.clone(),
      dir: dir.normalized(),
      speedPx: item.projectileSpeed,
      damage: item.combatDamage,
      rangePx: item.combatRange * ts,
      piercing: item.piercing,
    ));
  }

  void _killEnemy(_Enemy e) {
    e.hidden = true;
    _fire(TriggerType.enemyDefeated, triggerObj: e.source, cooldownKey: 'death_${e.source.id}');
  }

  void _updateLiveProjectiles(double dt) {
    final ts = mapData.tileSize.toDouble();
    final toRemove = <_LiveProjectile>[];

    for (final proj in _liveProjectiles) {
      final step = proj.speedPx * dt;
      proj.pos += proj.dir * step;
      proj.distTraveled += step;

      if (_solidAt(proj.pos.x, proj.pos.y) || _propSolidAt(proj.pos.x, proj.pos.y) || proj.distTraveled >= proj.rangePx) {
        toRemove.add(proj);
        continue;
      }

      bool hit = false;
      for (final e in _enemies) {
        if (e.hidden) continue;
        if ((e.pos - proj.pos).length < ts * 0.5) {
          if (e.takeDamage(proj.damage)) _killEnemy(e);
          if (!proj.piercing) { toRemove.add(proj); hit = true; break; }
        }
      }
      if (hit) continue;
    }

    for (final p in toRemove) _liveProjectiles.remove(p);
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
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
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
        _enemies.any((e) => !e.hidden &&
            (e.pos - _playerPos).length < _playerTouchR() + _entityTouchR(e.source)),
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
      TriggerType.playerTouchesHazard => mapData.objects.any((o) =>
          o.type == GameObjectType.hazard &&
          !_hiddenObjectIds.contains(o.id) &&
          o.tileX == (_playerPos.x / ts).floor() &&
          o.tileY == (_playerPos.y / ts).floor()),
      TriggerType.playerActivatesCheckpoint => mapData.objects.any((o) =>
          o.type == GameObjectType.checkpoint &&
          !_hiddenObjectIds.contains(o.id) &&
          o.tileX == (_playerPos.x / ts).floor() &&
          o.tileY == (_playerPos.y / ts).floor()),
      TriggerType.enemyDefeated => false, // event-based, not polled
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
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
          if (_health <= 0) _fire(TriggerType.playerHealthZero);
        case ActionType.adjustScore:
          _score += (a.params['value'] as int?) ?? 0;
          onHudUpdate(_health, _score, _coinCount, _gemCount, _itemCount);
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
        case ActionType.shakeCamera:
          final dur = ((a.params['duration'] as int?) ?? 1).toDouble();
          final mag = ((a.params['magnitude'] as int?) ?? 8).toDouble();
          _shakeRemaining = dur;
          _shakeTotalDuration = dur;
          _shakeMagnitude = mag;
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
      case 'rain':
        // Rain covers the whole map — spawn from top-center
        final mapW = mapData.width * ts;
        _particles.startRain(
          mapW / 2,
          -ts, // slightly above the map
          density: fx.intensity,
          areaPx: mapW * 1.5,
          speedPx: speedPx,
          duration: fx.duration,
          sizeMultiplier: sm,
          maxParticles: fx.maxParticles > 0 ? fx.maxParticles : 600,
          angleDeg: fx.radius.toDouble(), // radius field repurposed as angle
        );
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

    // ── Build sorted render queue (z-order + y-sort) ──────────────────────
    final queue = <({int zOrder, double worldY, void Function() draw})>[];

    // Static objects (not player/enemy/water)
    for (final obj in mapData.objects) {
      if (obj.type == GameObjectType.playerSpawn ||
          obj.type == GameObjectType.enemy ||
          obj.type == GameObjectType.waterBody) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      final alpha = _objectAlpha[obj.id] ?? 1.0;
      final floatY = obj.floatEnabled
          ? obj.floatAmplitude * sin(2 * pi * obj.floatSpeed * _elapsedSec)
          : 0.0;
      final (fxDx, fxDy) = _fxOffset(obj, ts);
      final cx = (obj.tileX + 0.5) * ts + obj.offsetX + fxDx;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY + floatY + fxDy;
      final sortY = _sortY(obj, ts);
      queue.add((
        zOrder: obj.zOrder,
        worldY: sortY,
        draw: () => _drawObject(canvas, Offset(cx, cy), ts, r, obj.type,
            flipH: obj.flipH, flipV: obj.flipV,
            scale: obj.scale, rotation: obj.rotation, alpha: alpha,
            variantIndex: obj.variantIndex,
            useAnimation: mapData.getVariantUseAnimation(obj.type, obj.variantIndex)),
      ));
    }

    // Enemies
    for (final e in _enemies) {
      if (e.hidden) continue;
      final floatY = e.source.floatEnabled
          ? e.source.floatAmplitude * sin(2 * pi * e.source.floatSpeed * _elapsedSec)
          : 0.0;
      final (fxDx, fxDy) = _fxOffset(e.source, ts);
      final cx = e.pos.x + fxDx;
      final cy = e.pos.y + floatY + fxDy;
      queue.add((
        zOrder: e.source.zOrder,
        worldY: e.pos.y,
        draw: () => _drawObject(canvas, Offset(cx, cy), ts, r, e.source.type,
            flipH: e.source.flipH, flipV: e.source.flipV,
            scale: e.source.scale, rotation: e.source.rotation, alpha: e.alpha,
            variantIndex: e.source.variantIndex,
            useAnimation: mapData.getVariantUseAnimation(e.source.type, e.source.variantIndex)),
      ));
    }

    // Player
    if (!_playerHidden) {
      final spawn = mapData.objects
          .where((o) => o.type == GameObjectType.playerSpawn)
          .firstOrNull;
      final playerZOrder = spawn?.zOrder ?? 0;
      final playerFloatY = (spawn != null && spawn.floatEnabled)
          ? spawn.floatAmplitude * sin(2 * pi * spawn.floatSpeed * _elapsedSec)
          : 0.0;
      final playerDrawY = _playerPos.y + playerFloatY;
      queue.add((
        zOrder: playerZOrder,
        worldY: _playerPos.y,
        draw: () {
          final playerSprite = _resolveSprite(GameObjectType.playerSpawn,
              variantIndex: spawn?.variantIndex ?? 0,
              useAnimation: mapData.getVariantUseAnimation(
                  GameObjectType.playerSpawn, spawn?.variantIndex ?? 0));
          if (playerSprite != null) {
            _drawSprite(canvas, playerSprite, _playerPos.x, playerDrawY, ts,
                flipH: _playerFlipH, flipV: _playerFlipV,
                scale: _playerScale, rotation: _playerRotation, alpha: _playerAlpha);
          } else {
            _drawCircle(canvas, Offset(_playerPos.x, playerDrawY), r,
                const Color(0xFF4ADE80), Icons.person, alpha: _playerAlpha);
          }
        },
      ));
    }

    // Sort and execute
    queue.sort((a, b) {
      final zCmp = a.zOrder.compareTo(b.zOrder);
      if (zCmp != 0) return zCmp;
      return mapData.ySortEnabled ? a.worldY.compareTo(b.worldY) : 0;
    });
    for (final item in queue) {
      item.draw();
    }

    // ── Overlays: HP bars (always above sprites) ───────────────────────────
    for (final e in _enemies) {
      if (e.hidden) continue;
      if (e.health < e.maxHealth && e.maxHealth > 0) {
        final barW = ts * 0.7;
        final barLeft = e.pos.x - barW / 2;
        final barTop = e.pos.y - ts * 0.65;
        final pct = (e.health / e.maxHealth).clamp(0.0, 1.0);
        canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barW, 3),
            Paint()..color = Colors.black54);
        canvas.drawRect(Rect.fromLTWH(barLeft, barTop, barW * pct, 3),
            Paint()..color = const Color(0xFFF87171));
      }
    }

    // Melee swing arc
    final equipped = _equippedItem;
    if (_swingTimer > 0 && equipped != null && equipped.category != WeaponCategory.ranged) {
      final rangePx = equipped.combatRange * ts;
      final angle = atan2(_facingDir.y, _facingDir.x);
      const halfSweep = pi * 0.75;
      final arcAlpha = (_swingTimer / 0.25).clamp(0.0, 1.0) * 0.35;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(_playerPos.x, _playerPos.y),
          width: rangePx * 2, height: rangePx * 2,
        ),
        angle - halfSweep / 2,
        halfSweep,
        true,
        Paint()
          ..color = Colors.white.withOpacity(arcAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // Live weapon projectiles
    for (final proj in _liveProjectiles) {
      final trailEnd = Offset(proj.pos.x - proj.dir.x * 8, proj.pos.y - proj.dir.y * 8);
      canvas.drawLine(
        trailEnd, Offset(proj.pos.x, proj.pos.y),
        Paint()
          ..color = const Color(0xFFFFD700).withOpacity(0.5)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(proj.pos.x, proj.pos.y), 4,
        Paint()..color = const Color(0xFFFFD700),
      );
    }

    // Particles — always on top
    _particles.render(canvas);

    // Debug collision overlay
    if (debugCollision) _renderDebugCollision(canvas);
  }

  void _renderDebugCollision(Canvas canvas) {
    final ts = mapData.tileSize.toDouble();

    final tilePaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Solid tiles
    for (int ty = 0; ty < mapData.height; ty++) {
      for (int tx = 0; tx < mapData.width; tx++) {
        if (_solidAt(tx * ts + ts * 0.5, ty * ts + ts * 0.5)) {
          canvas.drawRect(
            Rect.fromLTWH(tx * ts, ty * ts, ts, ts),
            tilePaint,
          );
        }
      }
    }

    // Prop collision shapes
    final propStroke = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final propFill = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.08)
      ..style = PaintingStyle.fill;

    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.prop) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      if (!(obj.properties['solid'] as bool? ?? true)) continue;

      final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
      final shape = obj.properties['blockShape'] as String? ?? 'rect';

      switch (shape) {
        case 'circle':
          final r = ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.5) * ts;
          canvas.drawCircle(Offset(cx, cy), r, propFill);
          canvas.drawCircle(Offset(cx, cy), r, propStroke);
        case 'ellipse':
          final rx = ((obj.properties['blockRX'] as num?)?.toDouble() ?? 0.5) * ts;
          final ry = ((obj.properties['blockRY'] as num?)?.toDouble() ?? 0.5) * ts;
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
          canvas.drawOval(rect, propFill);
          canvas.drawOval(rect, propStroke);
        case 'custom':
          final raw = obj.properties['sortPoints'];
          if (raw is List && raw.length >= 3) {
            final path = Path();
            bool first = true;
            for (final p in raw) {
              if (p is! List || p.length < 2) continue;
              final wx = cx + (p[0] as num).toDouble() * ts;
              final wy = cy + (p[1] as num).toDouble() * ts;
              if (first) { path.moveTo(wx, wy); first = false; }
              else path.lineTo(wx, wy);
            }
            path.close();
            canvas.drawPath(path, propFill);
            canvas.drawPath(path, propStroke);
          }
        default: // rect
          final hw = ((obj.properties['blockW'] as num?)?.toDouble() ?? 1.0) * ts * 0.5;
          final hh = ((obj.properties['blockH'] as num?)?.toDouble() ?? 1.0) * ts * 0.5;
          final rect = Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2);
          canvas.drawRect(rect, propFill);
          canvas.drawRect(rect, propStroke);
      }
    }

    // Player collider
    final playerStroke = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final playerFill = Paint()
      ..color = const Color(0xFF4ADE80).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final px = _playerPos.x, py = _playerPos.y;
    switch (_playerColliderShape) {
      case 'rect':
        final hw = _playerColliderW * ts;
        final hh = _playerColliderH * ts;
        final rect = Rect.fromCenter(center: Offset(px, py), width: hw * 2, height: hh * 2);
        canvas.drawRect(rect, playerFill);
        canvas.drawRect(rect, playerStroke);
      case 'ellipse':
        final rx = _playerColliderRX * ts;
        final ry = _playerColliderRY * ts;
        final rect = Rect.fromCenter(center: Offset(px, py), width: rx * 2, height: ry * 2);
        canvas.drawOval(rect, playerFill);
        canvas.drawOval(rect, playerStroke);
      case 'custom':
        if (_playerColliderPoly.length >= 3) {
          final path = Path();
          bool first = true;
          for (final p in _playerColliderPoly) {
            if (p.length < 2) continue;
            final wx = px + p[0] * ts;
            final wy = py + p[1] * ts;
            if (first) { path.moveTo(wx, wy); first = false; }
            else path.lineTo(wx, wy);
          }
          path.close();
          canvas.drawPath(path, playerFill);
          canvas.drawPath(path, playerStroke);
        } else {
          // No polygon defined yet — fallback circle
          final r = _playerColliderR * ts;
          canvas.drawCircle(Offset(px, py), r, playerFill);
          canvas.drawCircle(Offset(px, py), r, playerStroke);
        }
      default: // circle
        final r = _playerColliderR * ts;
        canvas.drawCircle(Offset(px, py), r, playerFill);
        canvas.drawCircle(Offset(px, py), r, playerStroke);
    }

    // Enemy + NPC colliders
    final enemyStroke = Paint()
      ..color = const Color(0xFFF87171).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final enemyFill = Paint()
      ..color = const Color(0xFFF87171).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    for (final e in _enemies) {
      if (e.hidden) continue;
      _drawEntityColliderDebug(canvas, e.source, e.pos.x, e.pos.y, ts, enemyStroke, enemyFill);
    }

    final npcStroke = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final npcFill = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    for (final obj in mapData.objects) {
      if (obj.type != GameObjectType.npc) continue;
      if (_hiddenObjectIds.contains(obj.id)) continue;
      final cx = (obj.tileX + 0.5) * ts + obj.offsetX;
      final cy = (obj.tileY + 0.5) * ts + obj.offsetY;
      _drawEntityColliderDebug(canvas, obj, cx, cy, ts, npcStroke, npcFill);
    }
  }

  void _drawEntityColliderDebug(Canvas canvas, GameObject obj,
      double cx, double cy, double ts, Paint stroke, Paint fill) {
    final shape = obj.properties['blockShape'] as String? ?? 'circle';
    switch (shape) {
      case 'rect':
        final hw = ((obj.properties['blockW'] as num?)?.toDouble() ?? 0.38) * ts;
        final hh = ((obj.properties['blockH'] as num?)?.toDouble() ?? 0.38) * ts;
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      case 'ellipse':
        final rx = ((obj.properties['blockRX'] as num?)?.toDouble() ?? 0.38) * ts;
        final ry = ((obj.properties['blockRY'] as num?)?.toDouble() ?? 0.38) * ts;
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
      case 'custom':
        final raw = obj.properties['sortPoints'];
        if (raw is List && raw.length >= 3) {
          final path = Path();
          bool first = true;
          for (final p in raw) {
            if (p is! List || p.length < 2) continue;
            final wx = cx + (p[0] as num).toDouble() * ts;
            final wy = cy + (p[1] as num).toDouble() * ts;
            if (first) { path.moveTo(wx, wy); first = false; }
            else path.lineTo(wx, wy);
          }
          path.close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
          break;
        }
        // fallback to circle
        final r = ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.38) * ts;
        canvas.drawCircle(Offset(cx, cy), r, fill);
        canvas.drawCircle(Offset(cx, cy), r, stroke);
      default: // circle
        final r = ((obj.properties['blockR'] as num?)?.toDouble() ?? 0.38) * ts;
        canvas.drawCircle(Offset(cx, cy), r, fill);
        canvas.drawCircle(Offset(cx, cy), r, stroke);
    }
  }

  void _drawObject(Canvas canvas, Offset center, double ts, double r, GameObjectType type,
      {bool flipH = false, bool flipV = false,
      double scale = 1.0, double rotation = 0.0, double alpha = 1.0,
      int variantIndex = 0, bool useAnimation = false}) {
    final sprite = _resolveSprite(type, variantIndex: variantIndex, useAnimation: useAnimation);
    if (sprite != null) {
      _drawSprite(canvas, sprite, center.dx, center.dy, ts,
          flipH: flipH, flipV: flipV, scale: scale, rotation: rotation, alpha: alpha);
    } else {
      _drawCircle(canvas, center, r, type.color, type.icon, alpha: alpha);
    }
  }

  ui.Image? _resolveSprite(GameObjectType type, {int variantIndex = 0, bool useAnimation = false}) {
    // Animated frame
    if (useAnimation && spriteCache.isAnimated(type, variantIndex)) {
      final animName = spriteCache.defaultAnim(type, variantIndex);
      if (animName.isNotEmpty) {
        final fps = spriteCache.getAnimFps(type, variantIndex, animName);
        final frameCount = spriteCache.animFrameCount(type, variantIndex, animName);
        if (frameCount > 0) {
          final frameIndex = (_elapsedSec * fps).floor() % frameCount;
          return spriteCache.getAnimFrame(type, variantIndex, animName, frameIndex);
        }
      }
    }
    // Static sprite
    final staticImg = spriteCache.getVariantImage(type, variantIndex);
    if (staticImg != null) return staticImg;
    // Fall back to frame 0 if animation exists but no static sprite imported
    if (spriteCache.isAnimated(type, variantIndex)) {
      final animName = spriteCache.defaultAnim(type, variantIndex);
      if (animName.isNotEmpty) {
        return spriteCache.getAnimFrame(type, variantIndex, animName, 0);
      }
    }
    return null;
  }

  void _drawSprite(Canvas canvas, ui.Image image, double cx, double cy, double ts,
      {bool flipH = false, bool flipV = false,
      double scale = 1.0, double rotation = 0.0, double alpha = 1.0}) {
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
      Paint()..color = Color.fromARGB((alpha * 255).round().clamp(0, 255), 255, 255, 255),
    );
    canvas.restore();
  }

  void _drawCircle(Canvas canvas, Offset center, double r, Color color, IconData icon,
      {double alpha = 1.0}) {
    canvas.drawCircle(center + const Offset(1, 2), r,
        Paint()..color = Color(0x4D000000).withOpacity(0.3 * alpha));
    canvas.drawCircle(center, r, Paint()..color = color.withOpacity(alpha));
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Color.fromARGB((alpha * 255).round().clamp(0, 255), 255, 255, 255),
          fontSize: r * 1.1,
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
