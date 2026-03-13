import 'package:flutter/material.dart';

enum GameObjectType {
  playerSpawn,  // 0
  enemy,        // 1
  npc,          // 2
  coin,         // 3
  chest,        // 4
  door,         // 5
  waterBody,    // 6
  gem,          // 7 — second collectible
  collectible,  // 8 — generic item
  prop,         // 9 — environmental object (solid by default)
  hazard,       // 10 — damage zone
  checkpoint,   // 11 — respawn point
  weaponPickup, // 12 — item/weapon/tool on the ground to pick up
}

extension GameObjectTypeExtension on GameObjectType {
  String get label => switch (this) {
        GameObjectType.playerSpawn => 'Player Spawn',
        GameObjectType.enemy      => 'Enemy',
        GameObjectType.npc        => 'NPC',
        GameObjectType.coin       => 'Coin',
        GameObjectType.chest      => 'Chest',
        GameObjectType.door       => 'Door',
        GameObjectType.waterBody  => 'Water Zone',
        GameObjectType.gem        => 'Gem',
        GameObjectType.collectible => 'Collectible',
        GameObjectType.prop       => 'Prop',
        GameObjectType.hazard     => 'Hazard',
        GameObjectType.checkpoint   => 'Checkpoint',
        GameObjectType.weaponPickup => 'Item Pickup',
      };

  String get symbol => switch (this) {
        GameObjectType.playerSpawn => 'P',
        GameObjectType.enemy      => 'E',
        GameObjectType.npc        => 'N',
        GameObjectType.coin       => 'C',
        GameObjectType.chest      => 'X',
        GameObjectType.door       => 'D',
        GameObjectType.waterBody  => 'W',
        GameObjectType.gem        => 'G',
        GameObjectType.collectible => 'I',
        GameObjectType.prop       => 'O',
        GameObjectType.hazard     => '!',
        GameObjectType.checkpoint   => 'K',
        GameObjectType.weaponPickup => 'W',
      };

  Color get color => switch (this) {
        GameObjectType.playerSpawn => const Color(0xFF6C63FF),
        GameObjectType.enemy      => const Color(0xFFEF4444),
        GameObjectType.npc        => const Color(0xFF22C55E),
        GameObjectType.coin       => const Color(0xFFFBBF24),
        GameObjectType.chest      => const Color(0xFFB45309),
        GameObjectType.door       => const Color(0xFF94A3B8),
        GameObjectType.waterBody  => const Color(0xFF29B6F6),
        GameObjectType.gem        => const Color(0xFF818CF8),
        GameObjectType.collectible => const Color(0xFF34D399),
        GameObjectType.prop       => const Color(0xFF78716C),
        GameObjectType.hazard     => const Color(0xFFFF4444),
        GameObjectType.checkpoint   => const Color(0xFF38BDF8),
        GameObjectType.weaponPickup => const Color(0xFFFF9800),
      };

  IconData get icon => switch (this) {
        GameObjectType.playerSpawn => Icons.person,
        GameObjectType.enemy      => Icons.smart_toy,
        GameObjectType.npc        => Icons.face,
        GameObjectType.coin       => Icons.monetization_on,
        GameObjectType.chest      => Icons.inventory_2,
        GameObjectType.door       => Icons.door_front_door,
        GameObjectType.waterBody  => Icons.water,
        GameObjectType.gem        => Icons.diamond,
        GameObjectType.collectible => Icons.category,
        GameObjectType.prop       => Icons.park,
        GameObjectType.hazard     => Icons.warning_amber,
        GameObjectType.checkpoint   => Icons.flag,
        GameObjectType.weaponPickup => Icons.sports_martial_arts,
      };

  bool get isUnique => this == GameObjectType.playerSpawn;
}

class GameObject {
  final String id;
  final GameObjectType type;
  int tileX;
  int tileY;
  String name;
  bool flipH;
  bool flipV;
  double scale;
  double rotation; // degrees 0–360
  bool hidden;
  double alpha; // initial opacity 0.0–1.0
  String tag;
  bool floatEnabled;
  double floatAmplitude; // pixels up/down
  double floatSpeed;     // cycles per second
  bool projectileEnabled;
  bool projectileLoop;     // true = loop continuously, false = one-shot
  double projectileAngle;  // degrees (0=right, 90=down)
  double projectileSpeed;  // tiles/sec
  double projectileRange;  // tiles (distance to destination)
  double projectileArc;    // tiles (peak height above path, 0=linear)
  bool dashEnabled;
  double dashAngle;        // degrees
  double dashDistance;     // tiles
  double dashSpeed;        // tiles/sec
  double dashInterval;     // seconds between dashes
  Map<String, dynamic> properties;

  GameObject({
    required this.type,
    required this.tileX,
    required this.tileY,
    String? name,
    String? id,
    this.flipH = false,
    this.flipV = false,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.hidden = false,
    this.alpha = 1.0,
    this.tag = '',
    this.floatEnabled = false,
    this.floatAmplitude = 4.0,
    this.floatSpeed = 1.0,
    this.projectileEnabled = false,
    this.projectileLoop = false,
    this.projectileAngle = 0.0,
    this.projectileSpeed = 3.0,
    this.projectileRange = 5.0,
    this.projectileArc = 0.0,
    this.dashEnabled = false,
    this.dashAngle = 0.0,
    this.dashDistance = 2.0,
    this.dashSpeed = 8.0,
    this.dashInterval = 2.0,
    Map<String, dynamic>? properties,
  })  : id = id ?? '${type.name}_${tileX}_${tileY}_${DateTime.now().microsecondsSinceEpoch}',
        name = name ?? type.label,
        properties = properties ?? _defaultProperties(type);

  static Map<String, dynamic> _defaultProperties(GameObjectType type) =>
      switch (type) {
        GameObjectType.enemy => {
            'health': 3,
            'speed': 2.0,
            'damage': 1,
            'patrolRange': 3,
          },
        GameObjectType.npc => {'dialog': 'Hello!'},
        GameObjectType.coin => {'value': 1},
        GameObjectType.chest => {'value': 10},
        GameObjectType.door => {
            'targetMapId': '',
            'targetX': 0,
            'targetY': 0,
          },
        GameObjectType.waterBody => {
            'waterMode': 'wade',
            'flowDirection': 'none',
            'flowStrength': 1.0,
            'canFish': false,
            'fishDensity': 3,
            'damaging': false,
            'damagePerSecond': 1.0,
            'animStyle': 'ripple',
            'waterColor': 'blue',
            'opacity': 0.6,
          },
        GameObjectType.gem        => {'value': 1},
        GameObjectType.collectible => {'value': 1},
        GameObjectType.prop       => {'solid': true},
        GameObjectType.hazard     => {'damage': 1.0, 'knockback': false},
        GameObjectType.checkpoint   => {},
        GameObjectType.playerSpawn  => {},
        GameObjectType.weaponPickup => {'itemId': ''},
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'tileX': tileX,
        'tileY': tileY,
        'name': name,
        'flipH': flipH,
        'flipV': flipV,
        'scale': scale,
        'rotation': rotation,
        'hidden': hidden,
        'alpha': alpha,
        'tag': tag,
        'floatEnabled': floatEnabled,
        'floatAmplitude': floatAmplitude,
        'floatSpeed': floatSpeed,
        'projectileEnabled': projectileEnabled,
        'projectileLoop': projectileLoop,
        'projectileAngle': projectileAngle,
        'projectileSpeed': projectileSpeed,
        'projectileRange': projectileRange,
        'projectileArc': projectileArc,
        'dashEnabled': dashEnabled,
        'dashAngle': dashAngle,
        'dashDistance': dashDistance,
        'dashSpeed': dashSpeed,
        'dashInterval': dashInterval,
        'properties': properties,
      };

  factory GameObject.fromJson(Map<String, dynamic> json) {
    final type = GameObjectType.values[json['type'] as int];
    final defaults = _defaultProperties(type);
    final saved = Map<String, dynamic>.from(json['properties'] as Map? ?? {});
    // Merge: saved values take priority, missing keys filled from defaults
    final merged = {...defaults, ...saved};
    return GameObject(
      id: json['id'] as String,
      type: type,
      tileX: json['tileX'] as int,
      tileY: json['tileY'] as int,
      name: json['name'] as String,
      flipH: json['flipH'] as bool? ?? false,
      flipV: json['flipV'] as bool? ?? false,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      hidden: json['hidden'] as bool? ?? false,
      alpha: (json['alpha'] as num?)?.toDouble() ?? 1.0,
      tag: json['tag'] as String? ?? '',
      floatEnabled: json['floatEnabled'] as bool? ?? false,
      floatAmplitude: (json['floatAmplitude'] as num?)?.toDouble() ?? 4.0,
      floatSpeed: (json['floatSpeed'] as num?)?.toDouble() ?? 1.0,
      projectileEnabled: json['projectileEnabled'] as bool? ?? false,
      projectileLoop: json['projectileLoop'] as bool? ?? false,
      projectileAngle: (json['projectileAngle'] as num?)?.toDouble() ?? 0.0,
      projectileSpeed: (json['projectileSpeed'] as num?)?.toDouble() ?? 3.0,
      projectileRange: (json['projectileRange'] as num?)?.toDouble() ?? 5.0,
      projectileArc: (json['projectileArc'] as num?)?.toDouble() ?? 0.0,
      dashEnabled: json['dashEnabled'] as bool? ?? false,
      dashAngle: (json['dashAngle'] as num?)?.toDouble() ?? 0.0,
      dashDistance: (json['dashDistance'] as num?)?.toDouble() ?? 2.0,
      dashSpeed: (json['dashSpeed'] as num?)?.toDouble() ?? 8.0,
      dashInterval: (json['dashInterval'] as num?)?.toDouble() ?? 2.0,
      properties: merged,
    );
  }
}
