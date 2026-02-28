import 'package:flutter/material.dart';

enum GameObjectType {
  playerSpawn,
  enemy,
  npc,
  coin,
  chest,
  door,
}

extension GameObjectTypeExtension on GameObjectType {
  String get label => switch (this) {
        GameObjectType.playerSpawn => 'Player Spawn',
        GameObjectType.enemy => 'Enemy',
        GameObjectType.npc => 'NPC',
        GameObjectType.coin => 'Coin',
        GameObjectType.chest => 'Chest',
        GameObjectType.door => 'Door',
      };

  String get symbol => switch (this) {
        GameObjectType.playerSpawn => 'P',
        GameObjectType.enemy => 'E',
        GameObjectType.npc => 'N',
        GameObjectType.coin => 'C',
        GameObjectType.chest => 'X',
        GameObjectType.door => 'D',
      };

  Color get color => switch (this) {
        GameObjectType.playerSpawn => const Color(0xFF6C63FF),
        GameObjectType.enemy => const Color(0xFFEF4444),
        GameObjectType.npc => const Color(0xFF22C55E),
        GameObjectType.coin => const Color(0xFFFBBF24),
        GameObjectType.chest => const Color(0xFFB45309),
        GameObjectType.door => const Color(0xFF94A3B8),
      };

  IconData get icon => switch (this) {
        GameObjectType.playerSpawn => Icons.person,
        GameObjectType.enemy => Icons.smart_toy,
        GameObjectType.npc => Icons.face,
        GameObjectType.coin => Icons.monetization_on,
        GameObjectType.chest => Icons.inventory_2,
        GameObjectType.door => Icons.door_front_door,
      };

  bool get isUnique => this == GameObjectType.playerSpawn;
}

class GameObject {
  final String id;
  final GameObjectType type;
  int tileX;
  int tileY;
  String name;
  Map<String, dynamic> properties;

  GameObject({
    required this.type,
    required this.tileX,
    required this.tileY,
    String? name,
    String? id,
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
        GameObjectType.playerSpawn => {},
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'tileX': tileX,
        'tileY': tileY,
        'name': name,
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
      properties: merged,
    );
  }
}
