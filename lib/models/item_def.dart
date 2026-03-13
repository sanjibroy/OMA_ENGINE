import 'package:flutter/material.dart';

enum WeaponCategory { melee, ranged, tool }

enum ToolType { none, pickaxe, axe, shovel, hammer }

extension WeaponCategoryExt on WeaponCategory {
  String get label => switch (this) {
        WeaponCategory.melee  => 'Melee',
        WeaponCategory.ranged => 'Ranged',
        WeaponCategory.tool   => 'Tool',
      };

  IconData get icon => switch (this) {
        WeaponCategory.melee  => Icons.sports_martial_arts,
        WeaponCategory.ranged => Icons.adjust,
        WeaponCategory.tool   => Icons.construction,
      };
}

extension ToolTypeExt on ToolType {
  String get label => switch (this) {
        ToolType.none    => 'None',
        ToolType.pickaxe => 'Pickaxe',
        ToolType.axe     => 'Axe',
        ToolType.shovel  => 'Shovel',
        ToolType.hammer  => 'Hammer',
      };

  IconData get icon => switch (this) {
        ToolType.none    => Icons.block,
        ToolType.pickaxe => Icons.hardware,
        ToolType.axe     => Icons.forest,
        ToolType.shovel  => Icons.landscape,
        ToolType.hammer  => Icons.handyman,
      };
}

class ItemDef {
  String id;
  String name;
  WeaponCategory category;

  // ── Combat ──────────────────────────────────────────────────────────────────
  double combatDamage;    // damage per hit to enemy
  double combatRange;     // melee reach or max projectile range (tiles)
  double cooldown;        // seconds between uses
  bool isProjectile;      // ranged: spawns a projectile
  double projectileSpeed; // px/s
  bool piercing;          // projectile passes through multiple enemies

  // ── Tool ────────────────────────────────────────────────────────────────────
  ToolType toolType;
  double toolPower;       // damage per swing to breakable tiles/props

  // ── Shared ──────────────────────────────────────────────────────────────────
  double reach;           // interaction distance in tiles
  int ammo;               // -1 = infinite

  ItemDef({
    required this.id,
    required this.name,
    this.category = WeaponCategory.melee,
    this.combatDamage = 1.0,
    this.combatRange = 1.5,
    this.cooldown = 0.5,
    this.isProjectile = false,
    this.projectileSpeed = 300.0,
    this.piercing = false,
    this.toolType = ToolType.none,
    this.toolPower = 1.0,
    this.reach = 1.5,
    this.ammo = -1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.index,
        'combatDamage': combatDamage,
        'combatRange': combatRange,
        'cooldown': cooldown,
        'isProjectile': isProjectile,
        'projectileSpeed': projectileSpeed,
        'piercing': piercing,
        'toolType': toolType.index,
        'toolPower': toolPower,
        'reach': reach,
        'ammo': ammo,
      };

  factory ItemDef.fromJson(Map<String, dynamic> j) => ItemDef(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Item',
        category: WeaponCategory
            .values[(j['category'] as int?)?.clamp(0, WeaponCategory.values.length - 1) ?? 0],
        combatDamage: (j['combatDamage'] as num?)?.toDouble() ?? 1.0,
        combatRange: (j['combatRange'] as num?)?.toDouble() ?? 1.5,
        cooldown: (j['cooldown'] as num?)?.toDouble() ?? 0.5,
        isProjectile: j['isProjectile'] as bool? ?? false,
        projectileSpeed: (j['projectileSpeed'] as num?)?.toDouble() ?? 300.0,
        piercing: j['piercing'] as bool? ?? false,
        toolType: ToolType
            .values[(j['toolType'] as int?)?.clamp(0, ToolType.values.length - 1) ?? 0],
        toolPower: (j['toolPower'] as num?)?.toDouble() ?? 1.0,
        reach: (j['reach'] as num?)?.toDouble() ?? 1.5,
        ammo: j['ammo'] as int? ?? -1,
      );
}
