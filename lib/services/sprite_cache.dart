import 'dart:io';
import 'dart:ui' as ui;
import '../models/game_object.dart';
import '../models/map_data.dart';

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
  // ─── Object sprites (one per GameObjectType) ──────────────────────────────
  final Map<GameObjectType, ui.Image> _objImages = {};
  final Map<GameObjectType, String> _objPaths = {};

  ui.Image? getImage(GameObjectType type) => _objImages[type];
  String? getPath(GameObjectType type) => _objPaths[type];
  bool hasSprite(GameObjectType type) => _objImages.containsKey(type);

  Map<String, String> get paths =>
      {for (final e in _objPaths.entries) e.key.name: e.value};

  Future<bool> loadSprite(GameObjectType type, String path) async {
    try {
      final img = await _loadImage(path);
      _objImages[type]?.dispose();
      _objImages[type] = img;
      _objPaths[type] = path;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadFromPaths(Map<String, String> savedPaths) async {
    for (final e in savedPaths.entries) {
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == e.key);
        await loadSprite(type, e.value);
      } catch (_) {}
    }
  }

  void removeSprite(GameObjectType type) {
    _objImages[type]?.dispose();
    _objImages.remove(type);
    _objPaths.remove(type);
  }

  // ─── Tile sprites (multiple variants per TileType) ────────────────────────
  final Map<TileType, List<ui.Image>> _tileImages = {};
  final Map<TileType, List<String>> _tilePaths = {};

  List<ui.Image> getTileImages(TileType type) => _tileImages[type] ?? [];
  List<String> getTilePaths(TileType type) => _tilePaths[type] ?? [];

  ui.Image? getTileImage(TileType type, int variant) {
    final list = _tileImages[type];
    if (list == null || list.isEmpty) return null;
    return list[variant.clamp(0, list.length - 1)];
  }

  int tileVariantCount(TileType type) => _tileImages[type]?.length ?? 0;

  Future<int?> addTileSprite(TileType type, String path) async {
    try {
      final img = await _loadImage(path);
      _tileImages.putIfAbsent(type, () => []).add(img);
      _tilePaths.putIfAbsent(type, () => []).add(path);
      return _tileImages[type]!.length - 1;
    } catch (_) {
      return null;
    }
  }

  void removeTileSprite(TileType type, int index) {
    final imgs = _tileImages[type];
    final paths = _tilePaths[type];
    if (imgs == null || index >= imgs.length) return;
    imgs[index].dispose();
    imgs.removeAt(index);
    paths?.removeAt(index);
    if (imgs.isEmpty) {
      _tileImages.remove(type);
      _tilePaths.remove(type);
    }
  }

  Map<String, List<String>> get tilePaths =>
      {for (final e in _tilePaths.entries) e.key.name: List.from(e.value)};

  Future<void> loadTileFromPaths(Map<String, List<String>> saved) async {
    for (final e in saved.entries) {
      try {
        final type = TileType.values.firstWhere((t) => t.name == e.key);
        for (final path in e.value) {
          await addTileSprite(type, path);
        }
      } catch (_) {}
    }
  }

  // ─── Named animations per GameObjectType ─────────────────────────────────
  // Structure: type → animationName → frames
  final Map<GameObjectType, Map<String, List<ui.Image>>> _animImages = {};
  final Map<GameObjectType, Map<String, List<String>>> _animPaths = {};
  final Map<GameObjectType, Map<String, int>> _animFps = {};
  final Map<GameObjectType, String> _defaultAnim = {};

  // Spritesheet source definitions (alternative to _animPaths)
  final Map<GameObjectType, Map<String, AnimSheetDef>> _animSheetDefs = {};

  bool isAnimated(GameObjectType type) =>
      (_animPaths.containsKey(type) && _animPaths[type]!.isNotEmpty) ||
      (_animSheetDefs.containsKey(type) && _animSheetDefs[type]!.isNotEmpty);

  List<String> animNames(GameObjectType type) {
    final fromPaths = _animPaths[type]?.keys.toSet() ?? {};
    final fromSheets = _animSheetDefs[type]?.keys.toSet() ?? {};
    return {...fromPaths, ...fromSheets}.toList();
  }

  bool isSheetAnim(GameObjectType type, String animName) =>
      _animSheetDefs[type]?.containsKey(animName) == true;

  AnimSheetDef? getSheetDef(GameObjectType type, String animName) =>
      _animSheetDefs[type]?[animName];

  String defaultAnim(GameObjectType type) {
    final d = _defaultAnim[type];
    if (d != null && animNames(type).contains(d)) return d;
    return animNames(type).firstOrNull ?? '';
  }

  void setDefaultAnim(GameObjectType type, String name) {
    _defaultAnim[type] = name;
  }

  int animFrameCount(GameObjectType type, String animName) =>
      _animImages[type]?[animName]?.length ?? 0;

  ui.Image? getAnimFrame(GameObjectType type, String animName, int frameIndex) {
    final list = _animImages[type]?[animName];
    if (list == null || list.isEmpty) return null;
    return list[frameIndex % list.length];
  }

  int getAnimFps(GameObjectType type, String animName) =>
      _animFps[type]?[animName] ?? 8;

  List<String> getAnimPaths(GameObjectType type, String animName) =>
      _animPaths[type]?[animName] ?? [];

  void addAnimation(GameObjectType type, String name) {
    _animImages.putIfAbsent(type, () => {})[name] ??= [];
    _animPaths.putIfAbsent(type, () => {})[name] ??= [];
    _animFps.putIfAbsent(type, () => {})[name] ??= 8;
    if (!_defaultAnim.containsKey(type)) _defaultAnim[type] = name;
  }

  void removeAnimation(GameObjectType type, String name) {
    final imgs = _animImages[type]?.remove(name);
    if (imgs != null) {
      for (final img in imgs) img.dispose();
    }
    _animPaths[type]?.remove(name);
    _animSheetDefs[type]?.remove(name);
    _animFps[type]?.remove(name);
    if (_defaultAnim[type] == name) {
      _defaultAnim[type] = animNames(type).firstOrNull ?? '';
    }
    final remaining = animNames(type);
    if (remaining.isEmpty) {
      _animImages.remove(type);
      _animPaths.remove(type);
      _animSheetDefs.remove(type);
      _animFps.remove(type);
      _defaultAnim.remove(type);
    }
  }

  Future<void> addAnimFrame(
      GameObjectType type, String animName, String path) async {
    try {
      final img = await _loadImage(path);
      _animImages.putIfAbsent(type, () => {}).putIfAbsent(animName, () => []).add(img);
      _animPaths.putIfAbsent(type, () => {}).putIfAbsent(animName, () => []).add(path);
      _animFps.putIfAbsent(type, () => {}).putIfAbsent(animName, () => 8);
      if (!_defaultAnim.containsKey(type)) _defaultAnim[type] = animName;
    } catch (_) {}
  }

  void removeAnimFrame(GameObjectType type, String animName, int index) {
    final imgs = _animImages[type]?[animName];
    final paths = _animPaths[type]?[animName];
    if (imgs == null || index >= imgs.length) return;
    imgs[index].dispose();
    imgs.removeAt(index);
    paths?.removeAt(index);
  }

  void setAnimFps(GameObjectType type, String animName, int fps) {
    _animFps.putIfAbsent(type, () => {})[animName] = fps.clamp(1, 60);
  }

  void clearAnimForType(GameObjectType type) {
    final animMap = _animImages.remove(type);
    if (animMap != null) {
      for (final imgs in animMap.values) {
        for (final img in imgs) img.dispose();
      }
    }
    _animPaths.remove(type);
    _animSheetDefs.remove(type);
    _animFps.remove(type);
    _defaultAnim.remove(type);
  }

  /// Switch an animation to spritesheet source.
  /// Disposes any existing frames, slices the sheet, stores frames + def.
  Future<void> setSheetAnim(
      GameObjectType type, String animName, AnimSheetDef def) async {
    // Clear existing frame data for this anim
    final oldImgs = _animImages[type]?.remove(animName);
    if (oldImgs != null) {
      for (final img in oldImgs) img.dispose();
    }
    _animPaths[type]?.remove(animName);

    // Slice the sheet into frames
    final frames = await _sliceSheet(def);
    _animImages.putIfAbsent(type, () => {})[animName] = frames;
    _animFps.putIfAbsent(type, () => {})[animName] =
        _animFps[type]?[animName] ?? 8;
    _animSheetDefs.putIfAbsent(type, () => {})[animName] = def;
    if (!_defaultAnim.containsKey(type)) _defaultAnim[type] = animName;
  }

  /// Switch an animation back to frames mode (removes sheet def + clears frames).
  void clearSheetAnim(GameObjectType type, String animName) {
    final oldImgs = _animImages[type]?.remove(animName);
    if (oldImgs != null) {
      for (final img in oldImgs) img.dispose();
    }
    _animSheetDefs[type]?.remove(animName);
    // Re-create empty frames-mode entry
    _animImages.putIfAbsent(type, () => {})[animName] = [];
    _animPaths.putIfAbsent(type, () => {})[animName] = [];
    _animFps.putIfAbsent(type, () => {})[animName] = 8;
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

  // Getters for export/serialization
  Map<String, Map<String, List<String>>> get animPaths => {
        for (final te in _animPaths.entries)
          te.key.name: {
            for (final ae in te.value.entries) ae.key: List.from(ae.value)
          }
      };

  Map<String, Map<String, int>> get animFpsMap => {
        for (final te in _animFps.entries)
          te.key.name: Map.from(te.value)
      };

  Map<String, String> get defaultAnimMap => {
        for (final e in _defaultAnim.entries)
          if (e.value.isNotEmpty) e.key.name: e.value
      };

  /// Returns animSheets as serializable map: typeName → animName → {path, frameWidth, frameHeight, frameCount}
  Map<String, Map<String, Map<String, dynamic>>> get animSheets => {
        for (final te in _animSheetDefs.entries)
          te.key.name: {
            for (final ae in te.value.entries) ae.key: ae.value.toJson()
          }
      };

  Future<void> loadAnimFromPaths(
    Map<String, Map<String, List<String>>> paths,
    Map<String, Map<String, int>> fps,
    Map<String, String> defaults,
  ) async {
    for (final te in paths.entries) {
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == te.key);
        for (final ae in te.value.entries) {
          for (final path in ae.value) {
            await addAnimFrame(type, ae.key, path);
          }
          final f = fps[te.key]?[ae.key];
          if (f != null) _animFps.putIfAbsent(type, () => {})[ae.key] = f;
        }
        final d = defaults[te.key];
        if (d != null && d.isNotEmpty) _defaultAnim[type] = d;
      } catch (_) {}
    }
  }

  Future<void> loadAnimFromSheets(
    Map<String, Map<String, Map<String, dynamic>>> sheets,
    Map<String, Map<String, int>> fps,
    Map<String, String> defaults,
  ) async {
    for (final te in sheets.entries) {
      try {
        final type = GameObjectType.values.firstWhere((t) => t.name == te.key);
        for (final ae in te.value.entries) {
          final def = AnimSheetDef.fromJson(ae.value);
          // Only load if file exists
          if (!File(def.path).existsSync()) continue;
          await setSheetAnim(type, ae.key, def);
          final f = fps[te.key]?[ae.key];
          if (f != null) _animFps.putIfAbsent(type, () => {})[ae.key] = f;
        }
        final d = defaults[te.key];
        if (d != null && d.isNotEmpty) _defaultAnim[type] = d;
      } catch (_) {}
    }
  }

  // ─── Shared ───────────────────────────────────────────────────────────────
  static Future<ui.Image> _loadImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void clear() {
    for (final img in _objImages.values) img.dispose();
    _objImages.clear();
    _objPaths.clear();
    for (final list in _tileImages.values) {
      for (final img in list) img.dispose();
    }
    _tileImages.clear();
    _tilePaths.clear();
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
  }

  void dispose() => clear();
}
