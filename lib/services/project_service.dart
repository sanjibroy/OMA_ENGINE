import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/game_project.dart';
import '../models/map_data.dart';

class ProjectService {
  static const _projectFile = 'project.json';

  // ─── New Project ────────────────────────────────────────────────────────────

  /// Lets user pick a directory and saves the initial project there.
  /// Returns the project directory path, or null if cancelled.
  static Future<String?> createProject(
    GameProject project,
    String currentMapId,
    MapData currentMap,
  ) async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save your project',
    );
    if (dir == null) return null;

    final projectDir = '$dir/${_safeName(project.name)}';
    await _ensureDirs(projectDir);

    // Save the first map
    final meta = project.maps.firstWhere((m) => m.id == currentMapId);
    await File('$projectDir/${meta.fileName}')
        .writeAsString(_encode(currentMap.toJson()));

    // Save project.json
    await File('$projectDir/$_projectFile')
        .writeAsString(_encode(project.toJson()));

    return projectDir;
  }

  // ─── Open Project ───────────────────────────────────────────────────────────

  /// Opens a project.json (or legacy .oma map) and returns everything needed.
  static Future<OpenProjectResult?> openProject() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open project.json or .oma map',
      type: FileType.custom,
      allowedExtensions: ['json', 'oma'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final filePath = result.files.single.path!;
    final raw =
        jsonDecode(await File(filePath).readAsString()) as Map<String, dynamic>;

    // Legacy single-map .oma — wrap in a project
    if (!raw.containsKey('maps')) {
      final mapData = MapData()..loadFromJson(raw);
      final id = 'map_0';
      final proj = GameProject(
        name: mapData.name,
        startMapId: id,
        maps: [ProjectMap(id: id, name: mapData.name, fileName: filePath)],
      );
      return OpenProjectResult(
        project: proj,
        startMapId: id,
        startMapData: mapData,
        projectDir: File(filePath).parent.path,
      );
    }

    // Full project
    final project = GameProject.fromJson(raw);
    if (project.maps.isEmpty) return null;

    final projectDir = File(filePath).parent.path;
    final startId =
        project.startMap?.id ?? project.maps.first.id;
    final mapData = await _loadMapFile(project, startId, projectDir);
    if (mapData == null) return null;

    return OpenProjectResult(
      project: project,
      startMapId: startId,
      startMapData: mapData,
      projectDir: projectDir,
    );
  }

  // ─── Save Project ───────────────────────────────────────────────────────────

  /// Saves the project.json + all cached maps + current map to disk.
  static Future<bool> saveProject({
    required GameProject project,
    required String projectDir,
    required String currentMapId,
    required MapData currentMap,
    required Map<String, Map<String, dynamic>> mapCache,
  }) async {
    try {
      await _ensureDirs(projectDir);

      // Save current map
      final curMeta =
          project.maps.firstWhere((m) => m.id == currentMapId);
      await File('$projectDir/${curMeta.fileName}')
          .writeAsString(_encode(currentMap.toJson()));

      // Save all other cached maps
      for (final entry in mapCache.entries) {
        if (entry.key == currentMapId) continue;
        try {
          final meta =
              project.maps.firstWhere((m) => m.id == entry.key);
          await File('$projectDir/${meta.fileName}')
              .writeAsString(_encode(entry.value));
        } catch (_) {}
      }

      // Save project.json
      await File('$projectDir/$_projectFile')
          .writeAsString(_encode(project.toJson()));

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Load a single map ──────────────────────────────────────────────────────

  static Future<MapData?> loadMapById(
    GameProject project,
    String mapId,
    String projectDir,
  ) async =>
      _loadMapFile(project, mapId, projectDir);

  // ─── Internal helpers ───────────────────────────────────────────────────────

  static Future<MapData?> _loadMapFile(
    GameProject project,
    String mapId,
    String projectDir,
  ) async {
    try {
      final meta = project.maps.firstWhere((m) => m.id == mapId);
      // fileName may be an absolute path (legacy .oma) or relative
      final filePath = meta.fileName.startsWith(RegExp(r'[A-Za-z]:'))
          ? meta.fileName
          : '$projectDir/${meta.fileName}';
      final raw =
          jsonDecode(await File(filePath).readAsString()) as Map<String, dynamic>;
      return MapData()..loadFromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static String _safeName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .padRight(1, 'game');

  static String _encode(dynamic obj) =>
      const JsonEncoder.withIndent('  ').convert(obj);

  static Future<void> _ensureDirs(String projectDir) async {
    for (final sub in ['maps', 'sprites', 'music', 'sfx', 'fonts']) {
      await Directory('$projectDir/$sub').create(recursive: true);
    }
  }
}

class OpenProjectResult {
  final GameProject project;
  final String startMapId;
  final MapData startMapData;
  final String projectDir;
  OpenProjectResult({
    required this.project,
    required this.startMapId,
    required this.startMapData,
    required this.projectDir,
  });
}
