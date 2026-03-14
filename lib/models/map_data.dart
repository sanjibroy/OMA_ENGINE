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
        TileType.empty => const Color(0xFF1E1E1E),
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
  Map<String, String> spritePaths = {};              // GameObjectType.name → path (variant 0, backward compat)
  Map<String, List<String>> objectVariantPaths = {}; // GameObjectType.name → [variant0, variant1, ...]
  Map<String, List<String>> tileSpritesPaths = {};   // TileType.name → [path, ...]
  Map<String, Map<String, List<String>>> animPaths = {}; // type → animName → [frames]
  Map<String, Map<String, int>> animFps = {};            // type → animName → fps
  Map<String, String> animDefaults = {};                 // type → default anim name
  Map<String, Map<String, Map<String, dynamic>>> animSheets = {}; // type → animName → AnimSheetDef.toJson()
  Map<String, List<String>> variantNames = {}; // typeName → [name per variant index]
  Map<String, bool> variantUseAnimation = {}; // 'type:vi' → true/false
  bool ySortEnabled = false; // sort objects by Y within same zOrder

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
    objectVariantPaths = {};
    tileSpritesPaths = {};
    animPaths = {};
    animFps = {};
    animDefaults = {};
    animSheets = {};
    variantNames = {};
    variantUseAnimation = {};
    ySortEnabled = false;
  }

  /// Resize the map, preserving existing tile data that fits within the new bounds.
  void resize(int newWidth, int newHeight) {
    final oldTiles     = tiles;
    final oldVariants  = tileVariants;
    final oldCollision = tileCollision;
    final oldH = height;
    final oldW = width;

    width  = newWidth;
    height = newHeight;

    tiles = List.generate(newHeight, (y) =>
        List.generate(newWidth, (x) =>
            (y < oldH && x < oldW) ? oldTiles[y][x] : TileType.empty));
    tileVariants = List.generate(newHeight, (y) =>
        List.generate(newWidth, (x) =>
            (y < oldH && x < oldW) ? oldVariants[y][x] : 0));
    tileCollision = List.generate(newHeight, (y) =>
        List.generate(newWidth, (x) =>
            (y < oldH && x < oldW) ? oldCollision[y][x] : 0));

    // Remove objects that fall outside the new bounds
    objects.removeWhere((o) => o.tileX >= newWidth || o.tileY >= newHeight);
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

  void fillAll(TileType type, {int variant = 0}) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        tiles[y][x] = type;
        tileVariants[y][x] = variant;
      }
    }
  }

  void fillRect(int x1, int y1, int x2, int y2, TileType type, {int variant = 0}) {
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (inBounds(x, y)) {
          tiles[y][x] = type;
          tileVariants[y][x] = variant;
        }
      }
    }
  }

  void floodFill(int startX, int startY, TileType newType, {int variant = 0}) {
    if (!inBounds(startX, startY)) return;
    final oldType = tiles[startY][startX];
    final oldVariant = tileVariants[startY][startX];
    if (oldType == newType && oldVariant == variant) return;
    final stack = <(int, int)>[(startX, startY)];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      if (!inBounds(x, y)) continue;
      if (tiles[y][x] != oldType || tileVariants[y][x] != oldVariant) continue;
      tiles[y][x] = newType;
      tileVariants[y][x] = variant;
      stack.add((x + 1, y));
      stack.add((x - 1, y));
      stack.add((x, y + 1));
      stack.add((x, y - 1));
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
      if (objectVariantPaths.isNotEmpty) 'objectVariantPaths': objectVariantPaths,
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
    if (variantNames.isNotEmpty) map['variantNames'] = variantNames;
    if (variantUseAnimation.isNotEmpty) map['variantUseAnimation'] = variantUseAnimation;
    if (ySortEnabled) map['ySortEnabled'] = true; // only save when enabled (default is off)
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
    final rawOVP = json['objectVariantPaths'] as Map? ?? {};
    objectVariantPaths = rawOVP.map((k, v) =>
        MapEntry(k as String, (v as List).map((e) => e as String).toList()));
    final rawTSP = json['tileSpritesPaths'] as Map? ?? {};
    tileSpritesPaths = rawTSP.map((k, v) =>
        MapEntry(k as String, (v as List).map((e) => e as String).toList()));

    final rawAP = json['animPaths'] as Map? ?? {};
    if (rawAP.isNotEmpty && rawAP.values.first is Map) {
      final parsed = rawAP.map((k, v) {
        final inner = v as Map;
        return MapEntry(
          k as String,
          inner.map((ak, av) => MapEntry(
              ak as String, (av as List).map((e) => e as String).toList())),
        );
      });
      // Normalize: keys without ':' are old format — append ':0'
      animPaths = {
        for (final e in parsed.entries)
          (e.key.contains(':') ? e.key : '${e.key}:0'): e.value
      };
    } else {
      animPaths = {}; // old format — discard, incompatible
    }
    final rawAF = json['animFps'] as Map? ?? {};
    if (rawAF.isNotEmpty && rawAF.values.first is Map) {
      final parsed = rawAF.map((k, v) {
        final inner = v as Map;
        return MapEntry(
            k as String, inner.map((ak, av) => MapEntry(ak as String, av as int)));
      });
      animFps = {
        for (final e in parsed.entries)
          (e.key.contains(':') ? e.key : '${e.key}:0'): e.value
      };
    } else {
      animFps = {};
    }
    final rawAD = json['animDefaults'] as Map? ?? {};
    final parsedAD = rawAD.map((k, v) => MapEntry(k as String, v as String));
    animDefaults = {
      for (final e in parsedAD.entries)
        (e.key.contains(':') ? e.key : '${e.key}:0'): e.value
    };

    ySortEnabled = json['ySortEnabled'] as bool? ?? false;
    final rawAS = json['animSheets'] as Map? ?? {};
    final parsedAS = rawAS.map((k, v) {
      final inner = v as Map;
      return MapEntry(
        k as String,
        inner.map((ak, av) =>
            MapEntry(ak as String, Map<String, dynamic>.from(av as Map))),
      );
    });
    animSheets = {
      for (final e in parsedAS.entries)
        (e.key.contains(':') ? e.key : '${e.key}:0'): e.value
    };

    final rawVN = json['variantNames'] as Map? ?? {};
    variantNames = rawVN.map((k, v) =>
        MapEntry(k as String, (v as List).map((e) => e as String).toList()));

    final rawVUA = json['variantUseAnimation'] as Map? ?? {};
    variantUseAnimation = rawVUA.map((k, v) => MapEntry(k as String, v as bool));
  }

  // ─── Variant name helpers ────────────────────────────────────────────────

  /// Returns the user-set name for a variant, or a generated default.
  String getVariantName(GameObjectType type, int vi) {
    final names = variantNames[type.name];
    if (names != null && vi < names.length && names[vi].isNotEmpty) {
      return names[vi];
    }
    return '${type.label} ${vi + 1}';
  }

  void setVariantName(GameObjectType type, int vi, String name) {
    final names = variantNames.putIfAbsent(type.name, () => []);
    while (names.length <= vi) names.add('');
    names[vi] = name.trim();
  }

  // ─── Variant useAnimation helpers ────────────────────────────────────────
  String _vaKey(GameObjectType type, int vi) => '${type.name}:$vi';

  bool getVariantUseAnimation(GameObjectType type, int vi) =>
      variantUseAnimation[_vaKey(type, vi)] ?? false;

  void setVariantUseAnimation(GameObjectType type, int vi, bool value) {
    if (value) {
      variantUseAnimation[_vaKey(type, vi)] = true;
    } else {
      variantUseAnimation.remove(_vaKey(type, vi));
    }
  }
}
