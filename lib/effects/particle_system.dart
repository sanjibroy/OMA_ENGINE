import 'dart:math';
import 'dart:ui';

enum EffectType { blast, fire, snow, electric, smoke, rain }

enum BlastTheme { fire, ice, electric, smoke }

extension BlastThemeExt on BlastTheme {
  String get label => switch (this) {
        BlastTheme.fire => 'Fire',
        BlastTheme.ice => 'Ice',
        BlastTheme.electric => 'Electric',
        BlastTheme.smoke => 'Smoke',
      };
  String get id => switch (this) {
        BlastTheme.fire => 'fire',
        BlastTheme.ice => 'ice',
        BlastTheme.electric => 'electric',
        BlastTheme.smoke => 'smoke',
      };
  static BlastTheme fromId(String id) => switch (id) {
        'ice' => BlastTheme.ice,
        'electric' => BlastTheme.electric,
        'smoke' => BlastTheme.smoke,
        _ => BlastTheme.fire,
      };
}

class _Particle {
  double x, y;
  double vx, vy;
  double life;
  final double maxLife;
  final double sizeStart;
  final double sizeEnd;
  final Color colorA;
  final Color colorB;
  final double gravity;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.sizeStart,
    this.sizeEnd = 0,
    required this.colorA,
    required this.colorB,
    this.gravity = 0,
  }) : maxLife = life;
}

class _Emitter {
  final double x, y;
  final EffectType type;
  double remaining; // seconds; -1 = loop
  final int intensity;
  final double spreadPx;
  final double speedPx;
  final double sizeMultiplier;
  final int maxParticles; // 0 = unlimited
  final double extra; // type-specific: rain = angle degrees
  double accumDt = 0;

  _Emitter({
    required this.x,
    required this.y,
    required this.type,
    required this.remaining,
    required this.intensity,
    required this.spreadPx,
    required this.speedPx,
    this.sizeMultiplier = 1.0,
    this.maxParticles = 0,
    this.extra = 0,
  });

  bool get isDone => remaining != -1 && remaining <= 0;
}

class ParticleSystem {
  final _rand = Random();
  final List<_Particle> _particles = [];
  final List<_Emitter> _emitters = [];

  bool get isEmpty => _particles.isEmpty && _emitters.isEmpty;

  // ── Blast — one-shot radial burst with color theme ────────────────────────

  void spawnBlast(
    double x,
    double y, {
    int count = 30,
    double radiusPx = 96,
    double durationSec = 0.8,
    BlastTheme theme = BlastTheme.fire,
    double sizeMultiplier = 1.0,
  }) {
    final (inner, outer, grav) = _blastProps(theme);
    final sm = sizeMultiplier.clamp(0.3, 4.0);

    // Core flash
    final coreCount = (count * 0.25).round().clamp(2, 10);
    for (int i = 0; i < coreCount; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = radiusPx * 0.6 / durationSec;
      _particles.add(_Particle(
        x: x, y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: durationSec * 0.25,
        sizeStart: (9.0 + _rand.nextDouble() * 5.0) * sm,
        colorA: const Color(0xFFFFFFFF),
        colorB: inner,
        gravity: 0,
      ));
    }

    // Main burst
    for (int i = 0; i < count; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = (radiusPx / durationSec) * (0.35 + _rand.nextDouble() * 0.65);
      final life = durationSec * (0.4 + _rand.nextDouble() * 0.6);
      _particles.add(_Particle(
        x: x + (_rand.nextDouble() * 6 - 3),
        y: y + (_rand.nextDouble() * 6 - 3),
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: life,
        sizeStart: (3.0 + _rand.nextDouble() * 6.0) * sm,
        colorA: inner,
        colorB: outer,
        gravity: grav + (_rand.nextDouble() * 60 - 30),
      ));
    }

    // Trailing embers
    final emberCount = (count * 0.3).round().clamp(3, 15);
    for (int i = 0; i < emberCount; i++) {
      final angle = _rand.nextDouble() * 2 * pi;
      final speed = (radiusPx / durationSec) * (0.1 + _rand.nextDouble() * 0.3);
      final life = durationSec * (0.8 + _rand.nextDouble() * 0.5);
      _particles.add(_Particle(
        x: x, y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: life,
        sizeStart: (1.5 + _rand.nextDouble() * 2.5) * sm,
        colorA: inner,
        colorB: _withAlpha(outer, 0),
        gravity: grav * 0.5,
      ));
    }
  }

  // ── Electric — one-shot zigzag arcs ──────────────────────────────────────

  void spawnElectric(
    double x,
    double y, {
    int arcCount = 5,
    double rangePx = 80,
    double durationSec = 0.35,
    double sizeMultiplier = 1.0,
  }) {
    final sm = sizeMultiplier.clamp(0.3, 4.0);

    // Central core flash
    _particles.add(_Particle(
      x: x, y: y,
      vx: 0, vy: 0,
      life: durationSec * 0.5,
      sizeStart: 14.0 * sm,
      sizeEnd: 0,
      colorA: const Color(0xFFFFFFFF),
      colorB: const Color(0xFF9944FF),
      gravity: 0,
    ));

    for (int arc = 0; arc < arcCount; arc++) {
      final angle = (arc / arcCount) * 2 * pi + _rand.nextDouble() * 0.4;
      final steps = 3 + _rand.nextInt(4);
      double cx = x, cy = y;
      final stepLen = rangePx / steps;

      for (int s = 0; s < steps; s++) {
        final perpAngle = angle + pi / 2;
        final zigzag = (s % 2 == 0 ? 1 : -1) * (_rand.nextDouble() * 14 + 4);
        final nx = cx + cos(angle) * stepLen + cos(perpAngle) * zigzag;
        final ny = cy + sin(angle) * stepLen + sin(perpAngle) * zigzag;
        final life = durationSec * (0.4 + _rand.nextDouble() * 0.5);

        _particles.add(_Particle(
          x: (cx + nx) / 2,
          y: (cy + ny) / 2,
          vx: 0, vy: 0,
          life: life,
          sizeStart: (2.5 + _rand.nextDouble() * 2.5) * sm,
          colorA: const Color(0xFFFFFFCC),
          colorB: const Color(0x00BB44FF),
          gravity: 0,
        ));
        cx = nx;
        cy = ny;
      }

      // Tip spark
      _particles.add(_Particle(
        x: cx, y: cy,
        vx: (_rand.nextDouble() - 0.5) * 40,
        vy: (_rand.nextDouble() - 0.5) * 40,
        life: durationSec * 0.8,
        sizeStart: 4.0 * sm,
        colorA: const Color(0xFFFFFFFF),
        colorB: const Color(0x009933FF),
        gravity: 0,
      ));
    }
  }

  // ── Fire — continuous upward flame emitter ────────────────────────────────

  void startFire(
    double x,
    double y, {
    int intensity = 5,
    double spreadPx = 64,
    double speedPx = 100,
    double duration = -1,
    double sizeMultiplier = 1.0,
    int maxParticles = 0,
  }) {
    _emitters.add(_Emitter(
      x: x, y: y,
      type: EffectType.fire,
      remaining: duration,
      intensity: intensity,
      spreadPx: spreadPx,
      speedPx: speedPx,
      sizeMultiplier: sizeMultiplier,
      maxParticles: maxParticles,
    ));
  }

  // ── Rain — continuous diagonal rainfall emitter ──────────────────────────

  void startRain(
    double x,
    double y, {
    int density = 5,
    double areaPx = 256,
    double speedPx = 220,
    double duration = -1,
    double sizeMultiplier = 1.0,
    int maxParticles = 0,
    double angleDeg = 15,
  }) {
    _emitters.add(_Emitter(
      x: x, y: y,
      type: EffectType.rain,
      remaining: duration,
      intensity: density,
      spreadPx: areaPx,
      speedPx: speedPx,
      sizeMultiplier: sizeMultiplier,
      maxParticles: maxParticles,
      extra: angleDeg,
    ));
  }

  // ── Snow — continuous downward snowflake emitter ──────────────────────────

  void startSnow(
    double x,
    double y, {
    int density = 5,
    double areaPx = 128,
    double speedPx = 60,
    double duration = -1,
    double sizeMultiplier = 1.0,
    int maxParticles = 0,
  }) {
    _emitters.add(_Emitter(
      x: x, y: y,
      type: EffectType.snow,
      remaining: duration,
      intensity: density,
      spreadPx: areaPx,
      speedPx: speedPx,
      sizeMultiplier: sizeMultiplier,
      maxParticles: maxParticles,
    ));
  }

  // ── Smoke — continuous slow upward drift emitter ──────────────────────────

  void startSmoke(
    double x,
    double y, {
    int density = 5,
    double spreadPx = 64,
    double speedPx = 40,
    double duration = -1,
    double sizeMultiplier = 1.0,
    int maxParticles = 0,
  }) {
    _emitters.add(_Emitter(
      x: x, y: y,
      type: EffectType.smoke,
      remaining: duration,
      intensity: density,
      spreadPx: spreadPx,
      speedPx: speedPx,
      sizeMultiplier: sizeMultiplier,
      maxParticles: maxParticles,
    ));
  }

  // ── Update & Render ───────────────────────────────────────────────────────

  void update(double dt) {
    _particles.removeWhere((p) => p.life <= 0);
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
      p.vx *= (1.0 - dt * 1.5);
      p.life -= dt;
    }

    _emitters.removeWhere((e) => e.isDone);
    for (final e in _emitters) {
      if (e.remaining != -1) e.remaining -= dt;
      e.accumDt += dt;
      final rate = e.intensity * 5.0;
      final emitInterval = 1.0 / rate;
      while (e.accumDt >= emitInterval) {
        e.accumDt -= emitInterval;
        if (e.maxParticles == 0 || _particles.length < e.maxParticles) {
          _emitOne(e);
        }
      }
    }
  }

  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    for (final p in _particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final alpha = (t * t).clamp(0.0, 1.0);
      paint.color = _lerpColor(p.colorB, p.colorA, t, alpha);
      final sz = (p.sizeStart + (p.sizeEnd - p.sizeStart) * (1.0 - t)).clamp(0.5, 40.0);
      canvas.drawCircle(Offset(p.x, p.y), sz, paint);
    }
  }

  void stopAll() {
    _particles.clear();
    _emitters.clear();
  }

  void clear() => stopAll();

  // ── Internal emitters ─────────────────────────────────────────────────────

  void _emitOne(_Emitter e) {
    switch (e.type) {
      case EffectType.fire:
        _emitFire(e);
      case EffectType.snow:
        _emitSnow(e);
      case EffectType.smoke:
        _emitSmoke(e);
      case EffectType.rain:
        _emitRain(e);
      default:
        break;
    }
  }

  void _emitFire(_Emitter e) {
    final sm = e.sizeMultiplier.clamp(0.3, 4.0);
    final ox = (_rand.nextDouble() - 0.5) * e.spreadPx;
    final speed = e.speedPx * (0.7 + _rand.nextDouble() * 0.6);
    final life = 0.4 + _rand.nextDouble() * 0.7;
    _particles.add(_Particle(
      x: e.x + ox,
      y: e.y,
      vx: (_rand.nextDouble() - 0.5) * e.speedPx * 0.25,
      vy: -speed,
      life: life,
      sizeStart: (5.0 + _rand.nextDouble() * 6.0) * sm,
      sizeEnd: 0,
      colorA: const Color(0xFFFFEE44),
      colorB: const Color(0xFFCC3300),
      gravity: -20.0,
    ));
    // Occasional floating ember
    if (_rand.nextDouble() < 0.3) {
      _particles.add(_Particle(
        x: e.x + ox * 0.5,
        y: e.y,
        vx: (_rand.nextDouble() - 0.5) * e.speedPx * 0.5,
        vy: -speed * (0.3 + _rand.nextDouble() * 0.3),
        life: life * 1.6,
        sizeStart: (1.5 + _rand.nextDouble() * 1.5) * sm,
        colorA: const Color(0xFFFF8800),
        colorB: const Color(0x00FF4400),
        gravity: 25.0,
      ));
    }
  }

  void _emitSnow(_Emitter e) {
    final sm = e.sizeMultiplier.clamp(0.3, 4.0);
    final ox = (_rand.nextDouble() - 0.5) * e.spreadPx;
    final spawnY = e.y - e.spreadPx * 0.5;
    final speed = e.speedPx * (0.6 + _rand.nextDouble() * 0.8);
    final swayVx = (_rand.nextDouble() - 0.5) * 14;
    final life = (e.spreadPx * 1.4) / speed;
    _particles.add(_Particle(
      x: e.x + ox,
      y: spawnY,
      vx: swayVx,
      vy: speed,
      life: life,
      sizeStart: (2.0 + _rand.nextDouble() * 2.5) * sm,
      sizeEnd: 1.0 * sm,
      colorA: const Color(0xFFECF6FF),
      colorB: const Color(0x00B0D8FF),
      gravity: 0,
    ));
  }

  void _emitRain(_Emitter e) {
    final sm = e.sizeMultiplier.clamp(0.3, 4.0);
    final ox = (_rand.nextDouble() - 0.5) * e.spreadPx;
    final speed = e.speedPx * (0.85 + _rand.nextDouble() * 0.3);
    // Convert wind angle (degrees from vertical) to velocity components
    final angleRad = e.extra * 3.14159265 / 180.0;
    final vx = speed * sin(angleRad) * (0.85 + _rand.nextDouble() * 0.3);
    final vy = speed * cos(angleRad);
    final life = (e.spreadPx * 1.3) / speed;
    _particles.add(_Particle(
      x: e.x + ox,
      y: e.y,
      vx: vx,
      vy: vy,
      life: life,
      sizeStart: (1.2 + _rand.nextDouble() * 1.0) * sm,
      sizeEnd: 0.4 * sm,
      colorA: const Color(0xFFAAD4FF),
      colorB: const Color(0x005599CC),
      gravity: 0,
    ));
  }

  void _emitSmoke(_Emitter e) {
    final sm = e.sizeMultiplier.clamp(0.3, 4.0);
    final ox = (_rand.nextDouble() - 0.5) * e.spreadPx * 0.4;
    final speed = e.speedPx * (0.5 + _rand.nextDouble() * 0.5);
    final life = 1.5 + _rand.nextDouble() * 1.5;
    _particles.add(_Particle(
      x: e.x + ox,
      y: e.y,
      vx: (_rand.nextDouble() - 0.5) * 16,
      vy: -speed,
      life: life,
      sizeStart: (8.0 + _rand.nextDouble() * 8.0) * sm,
      sizeEnd: (22.0 + _rand.nextDouble() * 12.0) * sm,
      colorA: const Color(0x66999999),
      colorB: const Color(0x00555555),
      gravity: -5.0,
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _lerpColor(Color a, Color b, double t, double alpha) => Color.fromARGB(
        (alpha * 255).round().clamp(0, 255),
        (a.red + (b.red - a.red) * t).round().clamp(0, 255),
        (a.green + (b.green - a.green) * t).round().clamp(0, 255),
        (a.blue + (b.blue - a.blue) * t).round().clamp(0, 255),
      );

  Color _withAlpha(Color c, double alpha) =>
      Color.fromARGB((alpha * 255).round(), c.red, c.green, c.blue);

  (Color, Color, double) _blastProps(BlastTheme theme) => switch (theme) {
        BlastTheme.fire =>
          (const Color(0xFFFFCC00), const Color(0xFFCC2200), -80.0),
        BlastTheme.ice =>
          (const Color(0xFFCCEEFF), const Color(0xFF2255CC), 150.0),
        BlastTheme.electric =>
          (const Color(0xFFFFFF88), const Color(0xFF8833FF), 0.0),
        BlastTheme.smoke =>
          (const Color(0xFFAAAAAA), const Color(0xFF222222), -40.0),
      };
}
