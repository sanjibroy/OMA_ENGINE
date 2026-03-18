import 'dart:io';
import 'dart:ui' as ui;
import '../models/game_object.dart';
import '../models/tileset_def.dart';

// ─── Spritesheet definition ────────────────────────────────────────────────

class AnimSheetDef {
  final String path;       // absolute path to the spritesheet image
  final int frameWidth;
  final int frameHeight;
  final int frameCount;    // 0 = auto (all cells in grid)

  const AnimSheetDef({
    required this.path,
    required this.frameWidth,
    required this.frameHeight,
    this.frameCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'frameWidth': frameWidth,
        'frameHeight': frameHeight,
        'frameCount': frameCount,
      };

  factory AnimSheetDef.fromJson(Map<String, dynamic> j) => AnimSheetDef(
        path: j['path'] as String,
        frameWidth: j['frameWidth'] as int,
        frameHeight: j['frameHeight'] as int,
        frameCount: j['frameCount'] as int? ?? 0,
      );
}

// ─── SpriteCache ──────────────────────────────────────────────────────────

class SpriteCache {
  // ─── Object sprites — variant list per type ───────────────────────────────
  final Map<GameObjectType, List<ui.Image>> _objVariantImages = {};
  final Map<GameObjectType, List<String>> _objVariantPaths = {};

  // Variant 0 getters (backward compat)
  ui.Image? getImage(GameObjectType type) => getVariantImage(type, 0);
  String? getPath(GameObjectType type) => _objVariantPaths[type]?.firstOrNull;
  bool hasSprite(GameObjectType type) =>
      (_objVariantImages[type]?.isNotEmpty) ?? false;

  ui.Image? getVariantImage(GameObjectType type, int variantIndex) {
    final list = _objVariantImages[type];
    if (list == null || list.isEmpty) return null;
    return list[variantIndex.clamp(0, list.length - 1)];
  }

  int objVariantCount(GameObjectType type) =>
      _objVariantImages[type]?.length ?? 0;

  List<String> objVariantPathsList(GameObjectType type) =>
      List.unmodifiable(_objVariantPaths[type] ?? []);

  /// Backward-compat: replaces variant 0 (or adds it if list is empty).
  Future<bool> loadSprite(GameObjectType type, String path) async {
    try {
      final img = await _loadImage(path);
      final imgs = _objVariantImages.putIfAbsent(type, () => []);
      final paths = _objVariantPaths.putIfAbsent(type, () => []);
      if (imgs.isEmpty) {
        imgs.add(img);
        paths.add(path);
      } else {
        imgs[0].dispose();
        imgs[0] = img;
        paths[0] = path;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adds a new variant sprite for the type. Returns the new variant index.
  Future<int?> addObjectVariant(GameObjectType type, String path) async {
    try {
      final img = await _loadImage(path);
      _objVariantImages.putIfAbsent(type, () => []).add(img);
      _objVariantPaths.putIfAbsent(type, () => []).add(path);
      return _objVariantImages[type]!.length - 1;
    } catch (_) {
      return null;
    }
  }

  /// Removes a variant by index. Shifts higher-index variants down.
  void removeObjectVariant(GameObjectType type, int index) {
    final imgs = _objVariantImages[type];
    final paths = _objVariantPaths[type];
    if (imgs == null || index >= imgs.length) return;
    imgs[index].dispose();
    imgs.removeAt(index);
    paths?.removeAt(index);
    if (imgs.isEmpty) {
      _objVariantImages.remove(type);
      _objVariantPaths.remove(type);
    }
  }

  /// Backward-compat paths getter (variant 0 only, for old export code).
  Map<String, String> get paths => {
        for (final e in _objVariantPaths.entries)
          if (e.value.isNotEmpty) e.key.name: e.value[0]
      };

  /// Full variant paths map for export/saving.
  Map<String, List<String>> get objVariantPathsMap => {
        for (final e in _objVariantPaths.entries)
          if (e.value.isNotEmpty) e.key.name: List.from(e.value)
      };

  Future<void> loadFromPaths(Map<String, String> savedPaths) async {
    for (final e in savedPaths.entries) {
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == e.key);
        await loadSprite(type, e.value); // loads as variant 0
      } catch (_) {}
    }
  }

  /// Loads full variant lists. Replaces any previously loaded variants.
  Future<void> loadObjVariantsFromPaths(
      Map<String, List<String>> saved) async {
    for (final e in saved.entries) {
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == e.key);
        // Clear existing variants first
        _objVariantImages[type]?.forEach((img) => img.dispose());
        _objVariantImages[type] = [];
        _objVariantPaths[type] = [];
        for (final path in e.value) {
          await addObjectVariant(type, path);
        }
      } catch (_) {}
    }
  }

  void removeSprite(GameObjectType type) {
    _objVariantImages[type]?.forEach((img) => img.dispose());
    _objVariantImages.remove(type);
    _objVariantPaths.remove(type);
  }

  // ─── Named animations per GameObjectType+variant ─────────────────────────
  // Composite key: '${type.name}:${variantIndex}' → animationName → frames
  final Map<String, Map<String, List<ui.Image>>> _animImages = {};
  final Map<String, Map<String, List<String>>> _animPaths = {};
  final Map<String, Map<String, int>> _animFps = {};
  final Map<String, String> _defaultAnim = {};

  // Spritesheet source definitions (alternative to _animPaths)
  final Map<String, Map<String, AnimSheetDef>> _animSheetDefs = {};

  static String _animKey(GameObjectType type, int vi) => '${type.name}:$vi';

  bool isAnimated(GameObjectType type, int variantIndex) {
    final k = _animKey(type, variantIndex);
    return (_animPaths.containsKey(k) && _animPaths[k]!.isNotEmpty) ||
        (_animSheetDefs.containsKey(k) && _animSheetDefs[k]!.isNotEmpty);
  }

  List<String> animNames(GameObjectType type, int variantIndex) {
    final k = _animKey(type, variantIndex);
    final fromPaths = _animPaths[k]?.keys.toSet() ?? {};
    final fromSheets = _animSheetDefs[k]?.keys.toSet() ?? {};
    return {...fromPaths, ...fromSheets}.toList();
  }

  bool isSheetAnim(GameObjectType type, int variantIndex, String animName) {
    final k = _animKey(type, variantIndex);
    return _animSheetDefs[k]?.containsKey(animName) == true;
  }

  AnimSheetDef? getSheetDef(GameObjectType type, int variantIndex, String animName) {
    return _animSheetDefs[_animKey(type, variantIndex)]?[animName];
  }

  String defaultAnim(GameObjectType type, int variantIndex) {
    final k = _animKey(type, variantIndex);
    final d = _defaultAnim[k];
    if (d != null && animNames(type, variantIndex).contains(d)) return d;
    return animNames(type, variantIndex).firstOrNull ?? '';
  }

  void setDefaultAnim(GameObjectType type, int variantIndex, String name) {
    _defaultAnim[_animKey(type, variantIndex)] = name;
  }

  int animFrameCount(GameObjectType type, int variantIndex, String animName) =>
      _animImages[_animKey(type, variantIndex)]?[animName]?.length ?? 0;

  ui.Image? getAnimFrame(GameObjectType type, int variantIndex, String animName, int frameIndex) {
    final list = _animImages[_animKey(type, variantIndex)]?[animName];
    if (list == null || list.isEmpty) return null;
    return list[frameIndex % list.length];
  }

  int getAnimFps(GameObjectType type, int variantIndex, String animName) =>
      _animFps[_animKey(type, variantIndex)]?[animName] ?? 8;

  List<String> getAnimPaths(GameObjectType type, int variantIndex, String animName) =>
      _animPaths[_animKey(type, variantIndex)]?[animName] ?? [];

  void addAnimation(GameObjectType type, int variantIndex, String name) {
    final k = _animKey(type, variantIndex);
    _animImages.putIfAbsent(k, () => {})[name] ??= [];
    _animPaths.putIfAbsent(k, () => {})[name] ??= [];
    _animFps.putIfAbsent(k, () => {})[name] ??= 8;
    if (!_defaultAnim.containsKey(k)) _defaultAnim[k] = name;
  }

  void removeAnimation(GameObjectType type, int variantIndex, String name) {
    final k = _animKey(type, variantIndex);
    final imgs = _animImages[k]?.remove(name);
    if (imgs != null) {
      for (final img in imgs) img.dispose();
    }
    _animPaths[k]?.remove(name);
    _animSheetDefs[k]?.remove(name);
    _animFps[k]?.remove(name);
    if (_defaultAnim[k] == name) {
      _defaultAnim[k] = animNames(type, variantIndex).firstOrNull ?? '';
    }
    final remaining = animNames(type, variantIndex);
    if (remaining.isEmpty) {
      _animImages.remove(k);
      _animPaths.remove(k);
      _animSheetDefs.remove(k);
      _animFps.remove(k);
      _defaultAnim.remove(k);
    }
  }

  Future<void> addAnimFrame(
      GameObjectType type, int variantIndex, String animName, String path) async {
    try {
      final k = _animKey(type, variantIndex);
      final img = await _loadImage(path);
      _animImages.putIfAbsent(k, () => {}).putIfAbsent(animName, () => []).add(img);
      _animPaths.putIfAbsent(k, () => {}).putIfAbsent(animName, () => []).add(path);
      _animFps.putIfAbsent(k, () => {}).putIfAbsent(animName, () => 8);
      if (!_defaultAnim.containsKey(k)) _defaultAnim[k] = animName;
    } catch (_) {}
  }

  void removeAnimFrame(GameObjectType type, int variantIndex, String animName, int index) {
    final k = _animKey(type, variantIndex);
    final imgs = _animImages[k]?[animName];
    final paths = _animPaths[k]?[animName];
    if (imgs == null || index >= imgs.length) return;
    imgs[index].dispose();
    imgs.removeAt(index);
    paths?.removeAt(index);
  }

  void setAnimFps(GameObjectType type, int variantIndex, String animName, int fps) {
    _animFps.putIfAbsent(_animKey(type, variantIndex), () => {})[animName] = fps.clamp(1, 60);
  }

  /// Clears all animation data for all variants of a type.
  void clearAnimForType(GameObjectType type) {
    final prefix = '${type.name}:';
    final keysToRemove = _animImages.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keysToRemove) {
      final animMap = _animImages.remove(k);
      if (animMap != null) {
        for (final imgs in animMap.values) {
          for (final img in imgs) img.dispose();
        }
      }
      _animPaths.remove(k);
      _animSheetDefs.remove(k);
      _animFps.remove(k);
      _defaultAnim.remove(k);
    }
  }

  /// Switch an animation to spritesheet source.
  /// Disposes any existing frames, slices the sheet, stores frames + def.
  Future<void> setSheetAnim(
      GameObjectType type, int variantIndex, String animName, AnimSheetDef def) async {
    final k = _animKey(type, variantIndex);
    // Clear existing frame data for this anim
    final oldImgs = _animImages[k]?.remove(animName);
    if (oldImgs != null) {
      for (final img in oldImgs) img.dispose();
    }
    _animPaths[k]?.remove(animName);

    // Slice the sheet into frames
    final frames = await _sliceSheet(def);
    _animImages.putIfAbsent(k, () => {})[animName] = frames;
    _animFps.putIfAbsent(k, () => {})[animName] =
        _animFps[k]?[animName] ?? 8;
    _animSheetDefs.putIfAbsent(k, () => {})[animName] = def;
    if (!_defaultAnim.containsKey(k)) _defaultAnim[k] = animName;
  }

  /// Switch an animation back to frames mode (removes sheet def + clears frames).
  void clearSheetAnim(GameObjectType type, int variantIndex, String animName) {
    final k = _animKey(type, variantIndex);
    final oldImgs = _animImages[k]?.remove(animName);
    if (oldImgs != null) {
      for (final img in oldImgs) img.dispose();
    }
    _animSheetDefs[k]?.remove(animName);
    // Re-create empty frames-mode entry
    _animImages.putIfAbsent(k, () => {})[animName] = [];
    _animPaths.putIfAbsent(k, () => {})[animName] = [];
    _animFps.putIfAbsent(k, () => {})[animName] = 8;
  }

  static Future<List<ui.Image>> _sliceSheet(AnimSheetDef def) async {
    final sheet = await _loadImage(def.path);
    final sheetW = sheet.width;
    final sheetH = sheet.height;
    final fw = def.frameWidth;
    final fh = def.frameHeight;
    if (fw <= 0 || fh <= 0) return [];

    final cols = sheetW ~/ fw;
    final rows = sheetH ~/ fh;
    final totalCells = cols * rows;
    final count = (def.frameCount > 0 && def.frameCount <= totalCells)
        ? def.frameCount
        : totalCells;

    final frames = <ui.Image>[];
    for (int i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final srcRect = ui.Rect.fromLTWH(
          col * fw.toDouble(), row * fh.toDouble(), fw.toDouble(), fh.toDouble());
      final dstRect = ui.Rect.fromLTWH(0, 0, fw.toDouble(), fh.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, dstRect);
      canvas.drawImageRect(sheet, srcRect, dstRect, ui.Paint());
      final picture = recorder.endRecording();
      final frame = await picture.toImage(fw, fh);
      picture.dispose();
      frames.add(frame);
    }
    sheet.dispose();
    return frames;
  }

  // Getters for export/serialization — keyed by composite 'type:vi' string
  Map<String, Map<String, List<String>>> get animPaths => {
        for (final te in _animPaths.entries)
          te.key: {
            for (final ae in te.value.entries) ae.key: List.from(ae.value)
          }
      };

  Map<String, Map<String, int>> get animFpsMap => {
        for (final te in _animFps.entries)
          te.key: Map.from(te.value)
      };

  Map<String, String> get defaultAnimMap => {
        for (final e in _defaultAnim.entries)
          if (e.value.isNotEmpty) e.key: e.value
      };

  /// Returns animSheets as serializable map: 'type:vi' → animName → {path, frameWidth, frameHeight, frameCount}
  Map<String, Map<String, Map<String, dynamic>>> get animSheets => {
        for (final te in _animSheetDefs.entries)
          te.key: {
            for (final ae in te.value.entries) ae.key: ae.value.toJson()
          }
      };

  Future<void> loadAnimFromPaths(
    Map<String, Map<String, List<String>>> paths,
    Map<String, Map<String, int>> fps,
    Map<String, String> defaults,
  ) async {
    for (final te in paths.entries) {
      // Normalize key: if no ':' present, assume variant 0
      final compositeKey = te.key.contains(':') ? te.key : '${te.key}:0';
      // Parse type name from composite key
      final typeName = compositeKey.split(':')[0];
      final viStr = compositeKey.split(':')[1];
      final vi = int.tryParse(viStr) ?? 0;
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == typeName);
        for (final ae in te.value.entries) {
          for (final path in ae.value) {
            await addAnimFrame(type, vi, ae.key, path);
          }
          final f = fps[te.key]?[ae.key];
          if (f != null) _animFps.putIfAbsent(compositeKey, () => {})[ae.key] = f;
        }
        final d = defaults[te.key];
        if (d != null && d.isNotEmpty) _defaultAnim[compositeKey] = d;
      } catch (_) {}
    }
  }

  Future<void> loadAnimFromSheets(
    Map<String, Map<String, Map<String, dynamic>>> sheets,
    Map<String, Map<String, int>> fps,
    Map<String, String> defaults,
  ) async {
    for (final te in sheets.entries) {
      // Normalize key: if no ':' present, assume variant 0
      final compositeKey = te.key.contains(':') ? te.key : '${te.key}:0';
      final typeName = compositeKey.split(':')[0];
      final viStr = compositeKey.split(':')[1];
      final vi = int.tryParse(viStr) ?? 0;
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == typeName);
        for (final ae in te.value.entries) {
          final def = AnimSheetDef.fromJson(ae.value);
          // Only load if file exists
          if (!File(def.path).existsSync()) continue;
          await setSheetAnim(type, vi, ae.key, def);
          final f = fps[te.key]?[ae.key];
          if (f != null) _animFps.putIfAbsent(compositeKey, () => {})[ae.key] = f;
        }
        final d = defaults[te.key];
        if (d != null && d.isNotEmpty) _defaultAnim[compositeKey] = d;
      } catch (_) {}
    }
  }

  /// Adds a new variant and replaces an existing one at [index].
  Future<bool> replaceObjectVariant(GameObjectType type, int index, String path) async {
    try {
      final img = await _loadImage(path);
      final imgs = _objVariantImages[type];
      final paths = _objVariantPaths[type];
      if (imgs == null || index >= imgs.length) {
        // Just add
        _objVariantImages.putIfAbsent(type, () => []).add(img);
        _objVariantPaths.putIfAbsent(type, () => []).add(path);
      } else {
        imgs[index].dispose();
        imgs[index] = img;
        paths![index] = path;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Shared ───────────────────────────────────────────────────────────────
  static Future<ui.Image> _loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // ─── Tileset images ─────────────────────────────────────────────────────────

  final Map<String, ui.Image> _tilesetImages = {}; // tilesetId → full image

  ui.Image? getTilesetImage(String tilesetId) => _tilesetImages[tilesetId];

  Future<void> loadTileset(TilesetDef def) async {
    if (_tilesetImages.containsKey(def.id)) return; // already loaded
    if (!File(def.imagePath).existsSync()) return;
    final img = await _loadImage(def.imagePath);
    _tilesetImages[def.id]?.dispose();
    _tilesetImages[def.id] = img;
  }

  Future<void> loadTilesets(List<TilesetDef> defs) async {
    for (final def in defs) {
      await loadTileset(def);
    }
  }

  void clearTilesets() {
    for (final img in _tilesetImages.values) img.dispose();
    _tilesetImages.clear();
  }

  // ─── Clear / Dispose ─────────────────────────────────────────────────────────

  void clear() {
    for (final list in _objVariantImages.values) {
      for (final img in list) img.dispose();
    }
    _objVariantImages.clear();
    _objVariantPaths.clear();
    for (final animMap in _animImages.values) {
      for (final imgs in animMap.values) {
        for (final img in imgs) img.dispose();
      }
    }
    _animImages.clear();
    _animPaths.clear();
    _animSheetDefs.clear();
    _animFps.clear();
    _defaultAnim.clear();
    clearTilesets();
    // (maps are now String-keyed, no extra cleanup needed)
  }

  void dispose() => clear();
}
