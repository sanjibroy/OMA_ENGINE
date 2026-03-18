import 'game_object.dart';
import 'game_rule.dart';
import 'tileset_def.dart';

// Legacy migration table: old TileType index → ARGB color
const _legacyTileColors = [
  0,            // 0 = empty → transparent
  0xFF3A7D44,   // 1 = grass
  0xFF52525B,   // 2 = wall
  0xFF1D6FA4,   // 3 = water
  0xFFB5934A,   // 4 = sand
  0xFF6B7280,   // 5 = stone
  0xFF7C4D1E,   // 6 = woodFloor
];

class MapData {
  String name;
  int width;
  int height;
  int tileSize;
  late List<List<int>> tileColors; // ARGB per tile, 0 = transparent/empty
  late List<List<int>> tileCollision; // 0=default, 1=force passable, 2=force solid
  List<GameObject> objects = [];
  List<GameRule> rules = [];
  Map<String, String> spritePaths = {};              // GameObjectType.name → path (variant 0, backward compat)
  Map<String, List<String>> objectVariantPaths = {}; // GameObjectType.name → [variant0, variant1, ...]
  Map<String, Map<String, List<String>>> animPaths = {}; // type → animName → [frames]
  Map<String, Map<String, int>> animFps = {};            // type → animName → fps
  Map<String, String> animDefaults = {};                 // type → default anim name
  Map<String, Map<String, Map<String, dynamic>>> animSheets = {}; // type → animName → AnimSheetDef.toJson()
  Map<String, List<String>> variantNames = {}; // typeName → [name per variant index]
  Map<String, bool> variantUseAnimation = {}; // 'type:vi' → true/false
  bool ySortEnabled = false; // sort objects by Y within same zOrder
  List<TilesetDef> tilesets = [];
  List<TileLayer> layers = []; // tile layers, bottom-to-top, all below objects

  MapData({
    this.name = 'Untitled Map',
    this.width = 20,
    this.height = 15,
    this.tileSize = 32,
  }) {
    _initTiles();
  }

  void _initTiles() {
    tileColors = List.generate(height, (_) => List.filled(width, 0));
    tileCollision = List.generate(height, (_) => List.filled(width, 0));
    if (layers.isEmpty) {
      layers = [TileLayer.empty('Ground', width, height, id: 'layer_ground')];
    }
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
    animPaths = {};
    animFps = {};
    animDefaults = {};
    animSheets = {};
    variantNames = {};
    variantUseAnimation = {};
    ySortEnabled = false;
    tilesets = [];
    layers = [TileLayer.empty('Ground', this.width, this.height, id: 'layer_ground')];
  }

  /// Resize the map, preserving existing tile data that fits within the new bounds.
  void resize(int newWidth, int newHeight) {
    final oldColors   = tileColors;
    final oldCollision = tileCollision;
    final oldH = height;
    final oldW = width;

    width  = newWidth;
    height = newHeight;

    tileColors = List.generate(newHeight, (y) =>
        List.generate(newWidth, (x) =>
            (y < oldH && x < oldW) ? oldColors[y][x] : 0));
    tileCollision = List.generate(newHeight, (y) =>
        List.generate(newWidth, (x) =>
            (y < oldH && x < oldW) ? oldCollision[y][x] : 0));
    for (final layer in layers) {
      final old = layer.cells;
      layer.cells = List.generate(newHeight, (y) =>
          List.generate(newWidth, (x) =>
              (y < oldH && x < oldW) ? old[y][x] : null));
    }

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

  // ─── Layer helpers ────────────────────────────────────────────────────────

  TileCell? getLayerCell(int layerIdx, int x, int y) {
    if (layerIdx < 0 || layerIdx >= layers.length || !inBounds(x, y)) return null;
    return layers[layerIdx].cells[y][x];
  }

  void setLayerCell(int layerIdx, int x, int y, TileCell? cell) {
    if (layerIdx < 0 || layerIdx >= layers.length || !inBounds(x, y)) return;
    layers[layerIdx].cells[y][x] = cell;
  }

  // Backward-compat: reads/writes layer 0
  TileCell? getTilesetCell(int x, int y) => getLayerCell(0, x, y);
  void setTilesetCell(int x, int y, TileCell? cell) => setLayerCell(0, x, y, cell);

  int getTileColor(int x, int y) {
    if (!inBounds(x, y)) return 0;
    return tileColors[y][x];
  }

  void setTileColor(int x, int y, int color) {
    if (inBounds(x, y)) tileColors[y][x] = color;
  }

  void fillAll(int color) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        tileColors[y][x] = color;
      }
    }
  }

  void fillRect(int x1, int y1, int x2, int y2, int color) {
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (inBounds(x, y)) tileColors[y][x] = color;
      }
    }
  }

  void floodFill(int startX, int startY, int newColor) {
    if (!inBounds(startX, startY)) return;
    final oldColor = tileColors[startY][startX];
    if (oldColor == newColor) return;
    final stack = <(int, int)>[(startX, startY)];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      if (!inBounds(x, y)) continue;
      if (tileColors[y][x] != oldColor) continue;
      tileColors[y][x] = newColor;
      stack.add((x + 1, y));
      stack.add((x - 1, y));
      stack.add((x, y + 1));
      stack.add((x, y - 1));
    }
  }

  // ─── Tileset fill helpers ────────────────────────────────────────────────────

  void fillAllTileset(TileCell cell, {int layerIndex = 0}) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final cells = layers[layerIndex].cells;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        cells[y][x] = cell;
      }
    }
  }

  void fillRectTileset(int x1, int y1, int x2, int y2, TileCell cell, {int layerIndex = 0}) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final cells = layers[layerIndex].cells;
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (inBounds(x, y)) cells[y][x] = cell;
      }
    }
  }

  void floodFillTileset(int startX, int startY, TileCell newCell, {int layerIndex = 0}) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    if (!inBounds(startX, startY)) return;
    final cells = layers[layerIndex].cells;
    final oldCell = cells[startY][startX];
    if (oldCell == newCell) return;
    final stack = <(int, int)>[(startX, startY)];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      if (!inBounds(x, y)) continue;
      if (cells[y][x] != oldCell) continue;
      cells[y][x] = newCell;
      stack.add((x + 1, y));
      stack.add((x - 1, y));
      stack.add((x, y + 1));
      stack.add((x, y - 1));
    }
  }

  // ─── Layer color-cell helpers ────────────────────────────────────────────────

  /// Writes a color cell (or erases when argb==0) into a layer at (x, y).
  void setLayerColor(int layerIndex, int x, int y, int argb) {
    if (layerIndex < 0 || layerIndex >= layers.length || !inBounds(x, y)) return;
    layers[layerIndex].cells[y][x] = argb == 0 ? null : TileCell.color(argb);
  }

  void fillRectLayerColor(int x1, int y1, int x2, int y2, int argb, {int layerIndex = 0}) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    final cells = layers[layerIndex].cells;
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    final cell = argb == 0 ? null : TileCell.color(argb);
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (inBounds(x, y)) cells[y][x] = cell;
      }
    }
  }

  void floodFillLayerColor(int startX, int startY, int newArgb, {int layerIndex = 0}) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    if (!inBounds(startX, startY)) return;
    final cells = layers[layerIndex].cells;
    // Determine what "color" the start cell has (null=0, color cell=argb, tileset=-1)
    int _argbOf(TileCell? c) => c == null ? 0 : (c.isColor ? c.colorArgb : -1);
    final oldArgb = _argbOf(cells[startY][startX]);
    if (oldArgb == newArgb) return;
    final newCell = newArgb == 0 ? null : TileCell.color(newArgb);
    final stack = <(int, int)>[(startX, startY)];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      if (!inBounds(x, y)) continue;
      if (_argbOf(cells[y][x]) != oldArgb) continue;
      cells[y][x] = newCell;
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
      'objects': objects.map((o) => o.toJson()).toList(),
      'rules': rules.map((r) => r.toJson()).toList(),
      'spritePaths': spritePaths,
      if (objectVariantPaths.isNotEmpty) 'objectVariantPaths': objectVariantPaths,
    };
    // Only save tileColors if any are non-zero
    if (tileColors.any((row) => row.any((v) => v != 0))) {
      map['tileColors'] = tileColors.map((row) => List<int>.from(row)).toList();
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
    if (tilesets.isNotEmpty) map['tilesets'] = tilesets.map((t) => t.toJson()).toList();
    if (layers.isNotEmpty) map['layers'] = layers.map((l) => l.toJson()).toList();
    return map;
  }

  void loadFromJson(Map<String, dynamic> json) {
    name = json['name'] as String? ?? 'Untitled Map';
    width = json['width'] as int;
    height = json['height'] as int;
    tileSize = json['tileSize'] as int? ?? 32;

    if (json.containsKey('tileColors')) {
      // New format: ARGB ints
      final raw = json['tileColors'] as List;
      tileColors = List.generate(height, (y) {
        final row = raw[y] as List;
        return List.generate(width, (x) => row[x] as int);
      });
    } else if (json.containsKey('tiles')) {
      // Legacy format: TileType indices → migrate to ARGB
      final rawTiles = json['tiles'] as List;
      tileColors = List.generate(height, (y) {
        final row = rawTiles[y] as List;
        return List.generate(width, (x) {
          final idx = (row[x] as int).clamp(0, _legacyTileColors.length - 1);
          return _legacyTileColors[idx];
        });
      });
    } else {
      tileColors = List.generate(height, (_) => List.filled(width, 0));
    }

    // Ignore tileVariants and tileSpritesPaths (legacy fields)

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

    tilesets = (json['tilesets'] as List? ?? [])
        .map((e) => TilesetDef.fromJson(e as Map<String, dynamic>))
        .toList();

    if (json.containsKey('layers')) {
      layers = (json['layers'] as List)
          .map((e) => TileLayer.fromJson(e as Map<String, dynamic>, width, height))
          .toList();
    } else if (json.containsKey('tilesetCells')) {
      // Migrate old single-grid format → first layer named "Ground"
      final raw = json['tilesetCells'] as List;
      final cells = List.generate(height, (y) {
        final row = raw[y] as List;
        return List.generate(width, (x) {
          final c = row[x];
          return c == null ? null : TileCell.fromJson(c as Map<String, dynamic>);
        });
      });
      layers = [TileLayer(id: 'layer_ground', name: 'Ground', cells: cells)];
    } else {
      layers = [TileLayer.empty('Ground', width, height, id: 'layer_ground')];
    }
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
