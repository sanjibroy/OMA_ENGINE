class GameEffect {
  String name;

  /// 'blast' | 'fire' | 'snow' | 'electric' | 'smoke'
  String type;

  /// Duration in seconds. -1 = loop until stopped (fire / snow / smoke).
  double duration;

  // ── Blast settings ────────────────────────────────────────────────────────
  /// Color theme for blast: 'fire' | 'ice' | 'electric' | 'smoke'
  String blastColor;
  int count;
  int radius; // tiles

  // ── Shared settings for fire / snow / electric / smoke ───────────────────
  /// Intensity 1–10: fire = flame density, snow/smoke = particle density,
  /// electric = arc count.
  int intensity;

  /// Spread in tiles: fire = flame width, snow = fall area, smoke = drift
  /// width, electric = arc range.
  int spread;

  /// Speed in tiles/s: fire = rise speed, snow = fall speed,
  /// smoke = rise speed. (Unused for electric.)
  double speed;

  /// Particle size multiplier (0.5 = tiny, 1.0 = normal, 3.0 = large).
  /// Blast = particle size, Fire = flame size, Snow = flake size,
  /// Electric = arc thickness, Smoke = puff size.
  double particleSize;

  /// Max particles alive at once for continuous effects (fire/snow/smoke).
  /// 0 = unlimited.
  int maxParticles;

  GameEffect({
    required this.name,
    this.type = 'blast',
    this.duration = 0.8,
    this.blastColor = 'fire',
    this.count = 30,
    this.radius = 3,
    this.intensity = 5,
    this.spread = 3,
    this.speed = 2.0,
    this.particleSize = 1.0,
    this.maxParticles = 200,
  });

  GameEffect copyWith({
    String? name,
    String? type,
    double? duration,
    String? blastColor,
    int? count,
    int? radius,
    int? intensity,
    int? spread,
    double? speed,
    double? particleSize,
    int? maxParticles,
  }) =>
      GameEffect(
        name: name ?? this.name,
        type: type ?? this.type,
        duration: duration ?? this.duration,
        blastColor: blastColor ?? this.blastColor,
        count: count ?? this.count,
        radius: radius ?? this.radius,
        intensity: intensity ?? this.intensity,
        spread: spread ?? this.spread,
        speed: speed ?? this.speed,
        particleSize: particleSize ?? this.particleSize,
        maxParticles: maxParticles ?? this.maxParticles,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'duration': duration,
        'blastColor': blastColor,
        'count': count,
        'radius': radius,
        'intensity': intensity,
        'spread': spread,
        'speed': speed,
        'particleSize': particleSize,
        'maxParticles': maxParticles,
      };

  factory GameEffect.fromJson(Map<String, dynamic> json) {
    // Back-compat: old format used 'preset' field
    final oldPreset = json['preset'] as String?;
    return GameEffect(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'blast',
      duration: (json['duration'] as num?)?.toDouble() ?? 0.8,
      blastColor: json['blastColor'] as String? ?? oldPreset ?? 'fire',
      count: json['count'] as int? ?? 30,
      radius: json['radius'] as int? ?? 3,
      intensity: json['intensity'] as int? ?? 5,
      spread: json['spread'] as int? ?? 3,
      speed: (json['speed'] as num?)?.toDouble() ?? 2.0,
      particleSize: (json['particleSize'] as num?)?.toDouble() ?? 1.0,
      maxParticles: json['maxParticles'] as int? ?? 200,
    );
  }
}
