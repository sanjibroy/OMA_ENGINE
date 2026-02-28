import 'package:flutter/material.dart';
import 'game_object.dart';
import 'game_rule.dart';

enum TileType {
  empty,
  grass,
  wall,
  water,
  sand,
  stone,
  woodFloor,
}

extension TileTypeExtension on TileType {
  String get label => switch (this) {
        TileType.empty => 'Empty',
        TileType.grass => 'Grass',
        TileType.wall => 'Wall',
        TileType.water => 'Water',
        TileType.sand => 'Sand',
        TileType.stone => 'Stone',
        TileType.woodFloor => 'Wood Floor',
      };

  bool get isSolid => this == TileType.wall || this == TileType.water;

  Color get color => switch (this) {
        TileType.empty => const Color(0xFF1A1A26),
        TileType.grass => const Color(0xFF3A7D44),
        TileType.wall => const Color(0xFF52525B),
        TileType.water => const Color(0xFF1D6FA4),
        TileType.sand => const Color(0xFFB5934A),
        TileType.stone => const Color(0xFF6B7280),
        TileType.woodFloor => const Color(0xFF7C4D1E),
      };
}

class MapData {
  String name;
  int width;
  int height;
  int tileSize;
  late List<List<TileType>> tiles;
  late List<List<int>> tileVariants; // per-tile variant index
  late List<List<int>> tileCollision; // 0=default, 1=force passable, 2=force solid
  List<GameObject> objects = [];
  List<GameRule> rules = [];
  Map<String, String> spritePaths = {};       // GameObjectType.name → path
  Map<String, List<String>> tileSpritesPaths = {}; // TileType.name → [path, ...]
  Map<String, Map<String, List<String>>> animPaths = {}; // type → animName → [frames]
  Map<String, Map<String, int>> animFps = {};            // type → animName → fps
  Map<String, String> animDefaults = {};                 // type → default anim name
  Map<String, Map<String, Map<String, dynamic>>> animSheets = {}; // type → animName → AnimSheetDef.toJson()

  MapData({
    this.name = 'Untitled Map',
    this.width = 20,
    this.height = 15,
    this.tileSize = 32,
  }) {
    _initTiles();
  }

  void _initTiles() {
    tiles = List.generate(height, (_) => List.filled(width, TileType.empty));
    tileVariants = List.generate(height, (_) => List.filled(width, 0));
    tileCollision = List.generate(height, (_) => List.filled(width, 0));
  }

  void reset({String? name, int? width, int? height, int? tileSize}) {
    this.name = name ?? this.name;
    this.width = width ?? this.width;
    this.height = height ?? this.height;
    this.tileSize = tileSize ?? this.tileSize;
    _initTiles();
    objects = [];
    rules = [];
    spritePaths = {};
    tileSpritesPaths = {};
    animPaths = {};
    animFps = {};
    animDefaults = {};
    animSheets = {};
  }

  int getTileCollision(int x, int y) {
    if (!inBounds(x, y)) return 0;
    return tileCollision[y][x];
  }

  void setTileCollision(int x, int y, int value) {
    if (inBounds(x, y)) tileCollision[y][x] = value;
  }

  bool inBounds(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  TileType getTile(int x, int y) {
    if (!inBounds(x, y)) return TileType.empty;
    return tiles[y][x];
  }

  int getTileVariant(int x, int y) {
    if (!inBounds(x, y)) return 0;
    return tileVariants[y][x];
  }

  void setTile(int x, int y, TileType type, {int variant = 0}) {
    if (inBounds(x, y)) {
      tiles[y][x] = type;
      tileVariants[y][x] = variant;
    }
  }

  // ─── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'width': width,
      'height': height,
      'tileSize': tileSize,
      'tiles': tiles.map((row) => row.map((t) => t.index).toList()).toList(),
      'objects': objects.map((o) => o.toJson()).toList(),
      'rules': rules.map((r) => r.toJson()).toList(),
      'spritePaths': spritePaths,
      'tileSpritesPaths': tileSpritesPaths,
    };
    // Only save tileVariants if any are non-zero
    if (tileVariants.any((row) => row.any((v) => v != 0))) {
      map['tileVariants'] =
          tileVariants.map((row) => List<int>.from(row)).toList();
    }
    // Only save tileCollision if any are non-zero
    if (tileCollision.any((row) => row.any((v) => v != 0))) {
      map['tileCollision'] =
          tileCollision.map((row) => List<int>.from(row)).toList();
    }
    // Only save animation data if non-empty
    if (animPaths.isNotEmpty) map['animPaths'] = animPaths;
    if (animFps.isNotEmpty) map['animFps'] = animFps;
    if (animDefaults.isNotEmpty) map['animDefaults'] = animDefaults;
    if (animSheets.isNotEmpty) map['animSheets'] = animSheets;
    return map;
  }

  void loadFromJson(Map<String, dynamic> json) {
    name = json['name'] as String? ?? 'Untitled Map';
    width = json['width'] as int;
    height = json['height'] as int;
    tileSize = json['tileSize'] as int? ?? 32;

    final rawTiles = json['tiles'] as List;
    tiles = List.generate(height, (y) {
      final row = rawTiles[y] as List;
      return List.generate(width, (x) => TileType.values[row[x] as int]);
    });

    if (json.containsKey('tileVariants')) {
      final raw = json['tileVariants'] as List;
      tileVariants = List.generate(height, (y) {
        final row = raw[y] as List;
        return List.generate(width, (x) => row[x] as int);
      });
    } else {
      tileVariants = List.generate(height, (_) => List.filled(width, 0));
    }

    if (json.containsKey('tileCollision')) {
      final raw = json['tileCollision'] as List;
      tileCollision = List.generate(height, (y) {
        final row = raw[y] as List;
        return List.generate(width, (x) => row[x] as int);
      });
    } else {
      tileCollision = List.generate(height, (_) => List.filled(width, 0));
    }

    objects = (json['objects'] as List? ?? [])
        .map((o) => GameObject.fromJson(o as Map<String, dynamic>))
        .toList();
    rules = (json['rules'] as List? ?? [])
        .map((r) => GameRule.fromJson(r as Map<String, dynamic>))
        .toList();
    spritePaths = Map<String, String>.from(json['spritePaths'] as Map? ?? {});
    final rawTSP = json['tileSpritesPaths'] as Map? ?? {};
    tileSpritesPaths = rawTSP.map((k, v) =>
        MapEntry(k as String, (v as List).map((e) => e as String).toList()));

    final rawAP = json['animPaths'] as Map? ?? {};
    if (rawAP.isNotEmpty && rawAP.values.first is Map) {
      animPaths = rawAP.map((k, v) {
        final inner = v as Map;
        return MapEntry(
          k as String,
          inner.map((ak, av) => MapEntry(
              ak as String, (av as List).map((e) => e as String).toList())),
        );
      });
    } else {
      animPaths = {}; // old format — discard, incompatible
    }
    final rawAF = json['animFps'] as Map? ?? {};
    if (rawAF.isNotEmpty && rawAF.values.first is Map) {
      animFps = rawAF.map((k, v) {
        final inner = v as Map;
        return MapEntry(
            k as String, inner.map((ak, av) => MapEntry(ak as String, av as int)));
      });
    } else {
      animFps = {};
    }
    final rawAD = json['animDefaults'] as Map? ?? {};
    animDefaults = rawAD.map((k, v) => MapEntry(k as String, v as String));

    final rawAS = json['animSheets'] as Map? ?? {};
    animSheets = rawAS.map((k, v) {
      final inner = v as Map;
      return MapEntry(
        k as String,
        inner.map((ak, av) =>
            MapEntry(ak as String, Map<String, dynamic>.from(av as Map))),
      );
    });
  }
}
