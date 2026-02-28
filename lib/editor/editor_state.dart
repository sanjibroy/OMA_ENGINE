import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/game_object.dart';
import '../models/game_project.dart';
import '../models/game_rule.dart';
import '../models/map_data.dart';
import '../services/audio_manager.dart';
import '../services/project_service.dart';
import '../services/sprite_cache.dart';
import 'editor_game.dart';

enum EditorTool { tile, object, collision }

class _UndoSnapshot {
  final List<List<int>> tiles;
  final List<List<int>> variants;
  final List<List<int>> collision;
  final String objectsJson;
  final String rulesJson;
  _UndoSnapshot({
    required this.tiles,
    required this.variants,
    required this.collision,
    required this.objectsJson,
    required this.rulesJson,
  });
}

class EditorState {
  // ─── Persistent game canvas (never recreated) ──────────────────────────────
  final MapData mapData;
  final SpriteCache spriteCache = SpriteCache();
  final AudioManager audioManager = AudioManager();
  late final EditorGame game;

  // ─── Project ───────────────────────────────────────────────────────────────
  GameProject project;
  String _currentMapId;
  String? projectDir; // null = unsaved

  /// In-memory cache of every map's raw JSON, keyed by ProjectMap.id.
  /// The CURRENTLY OPEN map is NOT in the cache (it lives in [mapData]).
  final Map<String, Map<String, dynamic>> _mapCache = {};

  /// Read-only access for ProjectService when saving.
  Map<String, Map<String, dynamic>> get mapCache => _mapCache;

  // ─── Undo / Redo ───────────────────────────────────────────────────────────
  final _undoStack = <_UndoSnapshot>[];
  final _redoStack = <_UndoSnapshot>[];
  static const _kMaxUndoSteps = 50;

  // ─── Editor notifiers ──────────────────────────────────────────────────────
  final ValueNotifier<TileType> selectedTile;
  final ValueNotifier<int> selectedTileVariant;
  final ValueNotifier<GameObjectType> selectedObjectType;
  final ValueNotifier<GameObject?> selectedObject;
  final ValueNotifier<EditorTool> activeTool;
  final ValueNotifier<(int, int)?> hoverTile;
  final ValueNotifier<int> mapChanged;
  final ValueNotifier<int> projectChanged; // rebuilds map list UI
  final ValueNotifier<bool> isPlayMode;
  final ValueNotifier<bool> showGrid;
  final ValueNotifier<int> undoCount;
  final ValueNotifier<int> redoCount;

  String get currentMapId => _currentMapId;

  ProjectMap? get currentMapMeta {
    try {
      return project.maps.firstWhere((m) => m.id == _currentMapId);
    } catch (_) {
      return null;
    }
  }

  EditorState({required this.mapData})
      : project = _defaultProject(),
        _currentMapId = _kInitialMapId,
        selectedTile = ValueNotifier(TileType.grass),
        selectedTileVariant = ValueNotifier(0),
        selectedObjectType = ValueNotifier(GameObjectType.playerSpawn),
        selectedObject = ValueNotifier(null),
        activeTool = ValueNotifier(EditorTool.tile),
        hoverTile = ValueNotifier(null),
        mapChanged = ValueNotifier(0),
        projectChanged = ValueNotifier(0),
        isPlayMode = ValueNotifier(false),
        showGrid = ValueNotifier(true),
        undoCount = ValueNotifier(0),
        redoCount = ValueNotifier(0) {
    game = EditorGame(mapData: mapData, spriteCache: spriteCache);
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  void notifyMapChanged() => mapChanged.value++;
  void notifyProjectChanged() => projectChanged.value++;

  // ─── Undo / Redo ───────────────────────────────────────────────────────────

  _UndoSnapshot _snapshot() => _UndoSnapshot(
        tiles: mapData.tiles
            .map((row) => List<int>.from(row.map((t) => t.index)))
            .toList(),
        variants: mapData.tileVariants.map((row) => List<int>.from(row)).toList(),
        collision: mapData.tileCollision.map((row) => List<int>.from(row)).toList(),
        objectsJson: jsonEncode(mapData.objects.map((o) => o.toJson()).toList()),
        rulesJson: jsonEncode(mapData.rules.map((r) => r.toJson()).toList()),
      );

  void pushUndo() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _kMaxUndoSteps) _undoStack.removeAt(0);
    _redoStack.clear();
    undoCount.value = _undoStack.length;
    redoCount.value = 0;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
    undoCount.value = _undoStack.length;
    redoCount.value = _redoStack.length;
    selectedObject.value = null;
    notifyMapChanged();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
    undoCount.value = _undoStack.length;
    redoCount.value = _redoStack.length;
    selectedObject.value = null;
    notifyMapChanged();
  }

  void _restore(_UndoSnapshot s) {
    mapData.tiles = s.tiles.map((row) {
      return row.map((i) => TileType.values[i]).toList();
    }).toList();
    mapData.tileVariants = s.variants.map((row) => List<int>.from(row)).toList();
    mapData.tileCollision = s.collision.map((row) => List<int>.from(row)).toList();
    final objList = jsonDecode(s.objectsJson) as List;
    mapData.objects = objList
        .map((o) => GameObject.fromJson(o as Map<String, dynamic>))
        .toList();
    final ruleList = jsonDecode(s.rulesJson) as List;
    mapData.rules = ruleList
        .map((r) => GameRule.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ─── Sprite helpers ────────────────────────────────────────────────────────

  Future<void> reloadSprites() async {
    spriteCache.clear();
    await spriteCache.loadFromPaths(mapData.spritePaths);
    await spriteCache.loadTileFromPaths(mapData.tileSpritesPaths);
    await spriteCache.loadAnimFromPaths(mapData.animPaths, mapData.animFps, mapData.animDefaults);
    await spriteCache.loadAnimFromSheets(mapData.animSheets, mapData.animFps, mapData.animDefaults);
  }

  // ─── Map switching ─────────────────────────────────────────────────────────

  /// Switches the editor to [mapId]. Saves the current map to the in-memory
  /// cache first, then loads the target map (from cache or disk).
  Future<void> switchToMap(String mapId) async {
    if (mapId == _currentMapId) return;

    // Snapshot current map into cache
    _mapCache[_currentMapId] = mapData.toJson();

    // Get target map data
    Map<String, dynamic>? target = _mapCache[mapId];
    if (target == null && projectDir != null) {
      final loaded =
          await ProjectService.loadMapById(project, mapId, projectDir!);
      if (loaded != null) target = loaded.toJson();
    }

    if (target != null) {
      mapData.loadFromJson(target);
    } else {
      // New unsaved map — start empty using its name
      final meta = project.maps.firstWhere((m) => m.id == mapId,
          orElse: () => ProjectMap(id: mapId, name: 'Map', fileName: ''));
      mapData.reset(name: meta.name);
    }

    _currentMapId = mapId;
    selectedObject.value = null;
    selectedTile.value = TileType.grass;
    selectedTileVariant.value = 0;
    await reloadSprites();
    notifyMapChanged();
    notifyProjectChanged();
  }

  // ─── Map management ────────────────────────────────────────────────────────

  /// Adds a new empty map to the project and switches to it.
  Future<void> addMap({
    required String name,
    int width = 20,
    int height = 15,
    int tileSize = 32,
  }) async {
    final id = 'map_${DateTime.now().microsecondsSinceEpoch}';
    final fileName = 'maps/${_safeName(name)}_${id.hashCode.abs()}.json';
    project.maps.add(ProjectMap(id: id, name: name, fileName: fileName));

    // Pre-populate cache with a fresh empty map
    final fresh = MapData(
        name: name, width: width, height: height, tileSize: tileSize);
    _mapCache[id] = fresh.toJson();

    notifyProjectChanged();
    await switchToMap(id);
  }

  /// Removes [mapId] from the project (minimum 1 map always kept).
  Future<void> removeMap(String mapId) async {
    if (project.maps.length <= 1) return;
    _mapCache.remove(mapId);
    project.maps.removeWhere((m) => m.id == mapId);
    if (project.startMapId == mapId) {
      project.startMapId = project.maps.first.id;
    }
    if (_currentMapId == mapId) {
      await switchToMap(project.maps.first.id);
    }
    notifyProjectChanged();
  }

  void renameMap(String mapId, String newName) {
    try {
      project.maps.firstWhere((m) => m.id == mapId).name = newName;
      if (mapId == _currentMapId) mapData.name = newName;
      notifyProjectChanged();
    } catch (_) {}
  }

  void setStartMap(String mapId) {
    project.startMapId = mapId;
    notifyProjectChanged();
  }

  // ─── Project-level load (called after opening a project) ───────────────────

  /// Replaces the current project in-place. Called by Toolbar after open.
  Future<void> loadProject({
    required GameProject newProject,
    required String newMapId,
    required MapData newMapData,
    required String newProjectDir,
  }) async {
    project = newProject;
    projectDir = newProjectDir;
    _currentMapId = newMapId;
    _mapCache.clear();

    mapData.loadFromJson(newMapData.toJson());
    selectedObject.value = null;
    await reloadSprites();
    notifyMapChanged();
    notifyProjectChanged();
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  static const _kInitialMapId = 'map_0';

  static GameProject _defaultProject() {
    return GameProject(
      name: 'Untitled Game',
      startMapId: _kInitialMapId,
      maps: [
        ProjectMap(
          id: _kInitialMapId,
          name: 'Level 1',
          fileName: 'maps/level_1.json',
        ),
      ],
    );
  }

  static String _safeName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .padRight(1, 'map');

  void dispose() {
    audioManager.dispose();
    spriteCache.dispose();
    selectedTile.dispose();
    selectedTileVariant.dispose();
    selectedObjectType.dispose();
    selectedObject.dispose();
    activeTool.dispose();
    hoverTile.dispose();
    mapChanged.dispose();
    projectChanged.dispose();
    isPlayMode.dispose();
    showGrid.dispose();
    undoCount.dispose();
    redoCount.dispose();
  }
}
