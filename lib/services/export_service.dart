import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../editor/editor_state.dart';

class ExportResult {
  final bool success;
  final String message;
  final String? projectPath;
  final String? safeName;
  ExportResult.ok(this.projectPath, this.safeName)
      : success = true,
        message = 'Export complete';
  ExportResult.err(this.message)
      : success = false,
        projectPath = null,
        safeName = null;
}

class ExportService {
  static Future<ExportResult> export(
      BuildContext context, EditorState state) async {
    // 1. Find runtime directory
    final runtimeDir = _runtimeDir();
    if (runtimeDir == null) {
      return ExportResult.err(
          'Runtime not found.\n\nPlace the "runtime" folder next to oma_engine.exe\nor rebuild OMA Engine from source.');
    }

    // 2. Pick output directory
    final outDir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Choose export folder');
    if (outDir == null) return ExportResult.err('Cancelled');

    final safeName = _safeName(state.project.name);
    final gameDir = '${outDir.replaceAll('\\', '/')}/$safeName';

    try {
      await Directory(gameDir).create(recursive: true);

      // 3. Copy runtime files (oma_runtime.exe renamed to safeName.exe)
      await _copyRuntime(runtimeDir, gameDir, safeName);

      // 4. Build game_data/ folder
      final gameDataDir = '$gameDir/game_data';

      // 4a. Sprites
      final spritesDir = Directory('$gameDataDir/sprites');
      await spritesDir.create(recursive: true);

      final objMap = <String, String>{};
      for (final e in state.spriteCache.paths.entries) {
        final ext = e.value.split('.').last;
        final rel = 'sprites/obj_${e.key}.$ext';
        await File(e.value).copy('$gameDataDir/$rel');
        objMap[e.key] = rel;
      }
      final tileMap = <String, List<String>>{};
      for (final e in state.spriteCache.tilePaths.entries) {
        final list = <String>[];
        for (int i = 0; i < e.value.length; i++) {
          final p = e.value[i];
          final ext = p.split('.').last;
          final rel = 'sprites/tile_${e.key}_$i.$ext';
          await File(p).copy('$gameDataDir/$rel');
          list.add(rel);
        }
        tileMap[e.key] = list;
      }
      final animMap = <String, Map<String, List<String>>>{};
      final animFpsMap = <String, Map<String, int>>{};
      final animDefaultsMap = <String, String>{};
      for (final te in state.spriteCache.animPaths.entries) {
        final typePaths = <String, List<String>>{};
        final typeFps = <String, int>{};
        for (final ae in te.value.entries) {
          final list = <String>[];
          for (int i = 0; i < ae.value.length; i++) {
            final p = ae.value[i];
            final ext = p.split('.').last;
            final rel = 'sprites/anim_${te.key}_${ae.key}_$i.$ext';
            await File(p).copy('$gameDataDir/$rel');
            list.add(rel);
          }
          if (list.isNotEmpty) {
            typePaths[ae.key] = list;
            typeFps[ae.key] = state.spriteCache.animFpsMap[te.key]?[ae.key] ?? 8;
          }
        }
        if (typePaths.isNotEmpty) {
          animMap[te.key] = typePaths;
          animFpsMap[te.key] = typeFps;
        }
      }
      for (final e in state.spriteCache.defaultAnimMap.entries) {
        animDefaultsMap[e.key] = e.value;
      }
      final animSheetsMap = <String, Map<String, Map<String, dynamic>>>{};
      for (final te in state.spriteCache.animSheets.entries) {
        final typeSheets = <String, Map<String, dynamic>>{};
        for (final ae in te.value.entries) {
          final def = ae.value;
          final src = def['path'] as String;
          final ext = src.replaceAll('\\', '/').split('.').last;
          final rel = 'sprites/anim_${te.key}_${ae.key}_sheet.$ext';
          await File(src).copy('$gameDataDir/$rel');
          typeSheets[ae.key] = {
            'path': rel,
            'frameWidth': def['frameWidth'],
            'frameHeight': def['frameHeight'],
            'frameCount': def['frameCount'],
          };
        }
        if (typeSheets.isNotEmpty) animSheetsMap[te.key] = typeSheets;
      }

      // 4b. Audio
      final audioDir = Directory('$gameDataDir/audio');
      await audioDir.create(recursive: true);

      final exportMusicPaths = <String, String>{};
      for (final e in state.project.musicPaths.entries) {
        final src = File(e.value);
        if (!src.existsSync()) continue;
        final ext = e.value.replaceAll('\\', '/').split('.').last;
        final fileName = 'm_${e.key}.$ext';
        await src.copy('$gameDataDir/audio/$fileName');
        exportMusicPaths[e.key] = fileName;
      }
      final exportSfxPaths = <String, String>{};
      for (final e in state.project.sfxPaths.entries) {
        final src = File(e.value);
        if (!src.existsSync()) continue;
        final ext = e.value.replaceAll('\\', '/').split('.').last;
        final fileName = 's_${e.key}.$ext';
        await src.copy('$gameDataDir/audio/$fileName');
        exportSfxPaths[e.key] = fileName;
      }

      // 4c. Maps
      final mapsDir = Directory('$gameDataDir/maps');
      await mapsDir.create(recursive: true);

      final allMaps =
          Map<String, Map<String, dynamic>>.from(state.mapCache);
      allMaps[state.currentMapId] = state.mapData.toJson()
        ..['spritePaths'] = objMap
        ..['tileSpritesPaths'] = tileMap
        ..['animPaths'] = animMap
        ..['animFps'] = animFpsMap
        ..['animDefaults'] = animDefaultsMap
        ..['animSheets'] = animSheetsMap;

      // Load maps not yet in cache from disk
      if (state.projectDir != null) {
        for (final pm in state.project.maps) {
          if (!allMaps.containsKey(pm.id)) {
            final f = File('${state.projectDir}/${pm.fileName}');
            if (await f.exists()) {
              try {
                allMaps[pm.id] = Map<String, dynamic>.from(
                    jsonDecode(await f.readAsString()) as Map);
              } catch (_) {}
            }
          }
        }
      }

      final exportedMaps = <Map<String, String>>[];
      for (final pm in state.project.maps) {
        final mapJson =
            Map<String, dynamic>.from(allMaps[pm.id] ?? {});
        if (mapJson['spritePaths'] == null) mapJson['spritePaths'] = objMap;
        if (mapJson['tileSpritesPaths'] == null) {
          mapJson['tileSpritesPaths'] = tileMap;
        }
        if (mapJson['animPaths'] == null) mapJson['animPaths'] = animMap;
        if (mapJson['animFps'] == null) mapJson['animFps'] = animFpsMap;
        if (mapJson['animDefaults'] == null) mapJson['animDefaults'] = animDefaultsMap;
        if (mapJson['animSheets'] == null) mapJson['animSheets'] = animSheetsMap;
        final fileName = 'maps/${pm.id}.json';
        await File('$gameDataDir/$fileName')
            .writeAsString(jsonEncode(mapJson));
        exportedMaps
            .add({'id': pm.id, 'name': pm.name, 'file': fileName});
      }

      // 4d. project.json
      await File('$gameDataDir/project.json').writeAsString(jsonEncode({
        'name': state.project.name,
        'startMapId': state.project.startMapId,
        'viewportWidth': state.project.viewportWidth,
        'viewportHeight': state.project.viewportHeight,
        'hudAtBottom': state.project.hudAtBottom,
        'androidOrientation': state.project.androidOrientation,
        'playerSpeed': state.project.playerSpeed,
        'playerHealth': state.project.playerHealth,
        'playerLives': state.project.playerLives,
        'maps': exportedMaps,
        'musicPaths': exportMusicPaths,
        'sfxPaths': exportSfxPaths,
      }));

      return ExportResult.ok(gameDir, safeName);
    } catch (e) {
      return ExportResult.err('$e');
    }
  }

  // ─── Android APK export ──────────────────────────────────────────────────

  static Future<ExportResult> exportApk(
      BuildContext context, EditorState state) async {
    final androidDir = _apkToolsDir();
    if (androidDir == null) {
      return ExportResult.err(
          'Android tools not found.\n\nPlace the "apk_tools" folder next to oma_engine.exe.');
    }

    final outDir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Choose APK export folder');
    if (outDir == null) return ExportResult.err('Cancelled');

    final safeName = _safeName(state.project.name);
    final outBase = '${outDir.replaceAll('\\', '/')}/$safeName';

    try {
      // 1. Build game_data in memory
      final gameData = await _buildGameData(state);

      // 2. Write game_data to a temp directory
      final tempDir = await Directory.systemTemp.createTemp('oma_apk_');
      final tempGameData =
          '${tempDir.path.replaceAll('\\', '/')}/game_data';
      for (final entry in gameData.entries) {
        final f = File('$tempGameData/${entry.key}');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.value);
      }

      // 3. Write Python repack script to temp
      final pyScript =
          '${tempDir.path.replaceAll('\\', '/')}/repack.py';
      await File(pyScript).writeAsString(r'''
import zipfile, sys, os

base_apk   = sys.argv[1]
out_apk    = sys.argv[2]
gdata_dir  = sys.argv[3]

with zipfile.ZipFile(base_apk, 'r') as src:
    with zipfile.ZipFile(out_apk, 'w') as dst:
        for item in src.infolist():
            if not item.filename.startswith('META-INF/'):
                dst.writestr(item, src.read(item.filename))
        for root, dirs, files in os.walk(gdata_dir):
            for fname in files:
                full = os.path.join(root, fname)
                rel  = os.path.relpath(full, gdata_dir).replace('\\', '/')
                info = zipfile.ZipInfo('assets/flutter_assets/assets/' + rel)
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(full, 'rb') as f:
                    dst.writestr(info, f.read())
''');

      // 4. Run Python to repack APK
      final unsignedPath = '${outBase}_unsigned.apk';
      final baseApkPath = '$androidDir/oma_runtime.apk';
      final python = await Process.run(
        'python',
        [pyScript, baseApkPath, unsignedPath, tempGameData],
        runInShell: true,
      );
      await tempDir.delete(recursive: true);
      if (python.exitCode != 0) {
        return ExportResult.err(
            'APK repack failed:\n${python.stderr}\n${python.stdout}');
      }

      // 5. zipalign
      final alignedPath = '${outBase}_aligned.apk';
      final zipalign = await Process.run(
        '$androidDir/zipalign.exe',
        ['-f', '-v', '4', unsignedPath, alignedPath],
        runInShell: false,
      );
      await File(unsignedPath).delete();
      if (zipalign.exitCode != 0) {
        return ExportResult.err('zipalign failed:\n${zipalign.stderr}');
      }

      // 6. Sign with apksigner
      final signedPath = '$outBase.apk';
      final java = _findJava();
      if (java == null) {
        return ExportResult.err(
            'Java not found. Install Java or Android Studio.');
      }
      final sign = await Process.run(
        java,
        [
          '-jar', '$androidDir/apksigner.jar',
          'sign',
          '--ks', '$androidDir/debug.keystore',
          '--ks-key-alias', 'androiddebugkey',
          '--ks-pass', 'pass:android',
          '--key-pass', 'pass:android',
          '--out', signedPath,
          alignedPath,
        ],
        runInShell: false,
      );
      await File(alignedPath).delete();
      if (sign.exitCode != 0) {
        return ExportResult.err('apksigner failed:\n${sign.stderr}');
      }

      return ExportResult.ok(outBase, safeName);
    } catch (e) {
      return ExportResult.err('$e');
    }
  }

  /// Collects all game_data files into a map of relPath → bytes.
  /// relPath is relative to game_data/ (e.g. "project.json", "maps/map_0.json").
  static Future<Map<String, List<int>>> _buildGameData(
      EditorState state) async {
    final data = <String, List<int>>{};

    // Sprites
    final objMap = <String, String>{};
    for (final e in state.spriteCache.paths.entries) {
      final ext = e.value.split('.').last;
      final rel = 'sprites/obj_${e.key}.$ext';
      data[rel] = await File(e.value).readAsBytes();
      objMap[e.key] = rel;
    }
    final tileMap = <String, List<String>>{};
    for (final e in state.spriteCache.tilePaths.entries) {
      final list = <String>[];
      for (int i = 0; i < e.value.length; i++) {
        final p = e.value[i];
        final ext = p.split('.').last;
        final rel = 'sprites/tile_${e.key}_$i.$ext';
        data[rel] = await File(p).readAsBytes();
        list.add(rel);
      }
      tileMap[e.key] = list;
    }
    final animMap = <String, Map<String, List<String>>>{};
    final animFpsMap = <String, Map<String, int>>{};
    final animDefaultsMap = <String, String>{};
    for (final te in state.spriteCache.animPaths.entries) {
      final typePaths = <String, List<String>>{};
      final typeFps = <String, int>{};
      for (final ae in te.value.entries) {
        final list = <String>[];
        for (int i = 0; i < ae.value.length; i++) {
          final p = ae.value[i];
          final ext = p.split('.').last;
          final rel = 'sprites/anim_${te.key}_${ae.key}_$i.$ext';
          data[rel] = await File(p).readAsBytes();
          list.add(rel);
        }
        if (list.isNotEmpty) {
          typePaths[ae.key] = list;
          typeFps[ae.key] = state.spriteCache.animFpsMap[te.key]?[ae.key] ?? 8;
        }
      }
      if (typePaths.isNotEmpty) {
        animMap[te.key] = typePaths;
        animFpsMap[te.key] = typeFps;
      }
    }
    for (final e in state.spriteCache.defaultAnimMap.entries) {
      animDefaultsMap[e.key] = e.value;
    }
    final animSheetsMap = <String, Map<String, Map<String, dynamic>>>{};
    for (final te in state.spriteCache.animSheets.entries) {
      final typeSheets = <String, Map<String, dynamic>>{};
      for (final ae in te.value.entries) {
        final def = ae.value;
        final src = def['path'] as String;
        final ext = src.replaceAll('\\', '/').split('.').last;
        final rel = 'sprites/anim_${te.key}_${ae.key}_sheet.$ext';
        data[rel] = await File(src).readAsBytes();
        typeSheets[ae.key] = {
          'path': rel,
          'frameWidth': def['frameWidth'],
          'frameHeight': def['frameHeight'],
          'frameCount': def['frameCount'],
        };
      }
      if (typeSheets.isNotEmpty) animSheetsMap[te.key] = typeSheets;
    }

    // Audio
    final exportMusicPaths = <String, String>{};
    for (final e in state.project.musicPaths.entries) {
      final src = File(e.value);
      if (!src.existsSync()) continue;
      final ext = e.value.replaceAll('\\', '/').split('.').last;
      final fileName = 'm_${e.key}.$ext';
      data['audio/$fileName'] = await src.readAsBytes();
      exportMusicPaths[e.key] = fileName;
    }
    final exportSfxPaths = <String, String>{};
    for (final e in state.project.sfxPaths.entries) {
      final src = File(e.value);
      if (!src.existsSync()) continue;
      final ext = e.value.replaceAll('\\', '/').split('.').last;
      final fileName = 's_${e.key}.$ext';
      data['audio/$fileName'] = await src.readAsBytes();
      exportSfxPaths[e.key] = fileName;
    }

    // Maps
    final allMaps =
        Map<String, Map<String, dynamic>>.from(state.mapCache);
    allMaps[state.currentMapId] = state.mapData.toJson()
      ..['spritePaths'] = objMap
      ..['tileSpritesPaths'] = tileMap
      ..['animPaths'] = animMap
      ..['animFps'] = animFpsMap
      ..['animDefaults'] = animDefaultsMap
      ..['animSheets'] = animSheetsMap;
    if (state.projectDir != null) {
      for (final pm in state.project.maps) {
        if (!allMaps.containsKey(pm.id)) {
          final f = File('${state.projectDir}/${pm.fileName}');
          if (await f.exists()) {
            try {
              allMaps[pm.id] = Map<String, dynamic>.from(
                  jsonDecode(await f.readAsString()) as Map);
            } catch (_) {}
          }
        }
      }
    }

    final exportedMaps = <Map<String, String>>[];
    for (final pm in state.project.maps) {
      final mapJson =
          Map<String, dynamic>.from(allMaps[pm.id] ?? {});
      if (mapJson['spritePaths'] == null) mapJson['spritePaths'] = objMap;
      if (mapJson['tileSpritesPaths'] == null) {
        mapJson['tileSpritesPaths'] = tileMap;
      }
      if (mapJson['animPaths'] == null) mapJson['animPaths'] = animMap;
      if (mapJson['animFps'] == null) mapJson['animFps'] = animFpsMap;
      if (mapJson['animDefaults'] == null) mapJson['animDefaults'] = animDefaultsMap;
      if (mapJson['animSheets'] == null) mapJson['animSheets'] = animSheetsMap;
      final fileName = 'maps/${pm.id}.json';
      data[fileName] = jsonEncode(mapJson).codeUnits;
      exportedMaps.add({'id': pm.id, 'name': pm.name, 'file': fileName});
    }

    // project.json
    data['project.json'] = jsonEncode({
      'name': state.project.name,
      'startMapId': state.project.startMapId,
      'viewportWidth': state.project.viewportWidth,
      'viewportHeight': state.project.viewportHeight,
      'hudAtBottom': state.project.hudAtBottom,
      'androidOrientation': state.project.androidOrientation,
      'playerSpeed': state.project.playerSpeed,
      'playerHealth': state.project.playerHealth,
      'playerLives': state.project.playerLives,
      'maps': exportedMaps,
      'musicPaths': exportMusicPaths,
      'sfxPaths': exportSfxPaths,
    }).codeUnits;

    return data;
  }

  // ─── Launch exported game ────────────────────────────────────────────────

  static Future<void> launchGame(String gameDir, String safeName) async {
    final exePath = '${gameDir.replaceAll('/', '\\')}\\$safeName.exe';
    await Process.start(exePath, [], mode: ProcessStartMode.detached);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Finds the android/ tools folder (same search strategy as runtime/).
  static String? _apkToolsDir() {
    try {
      final exeDir =
          File(Platform.resolvedExecutable).parent.path.replaceAll('\\', '/');
      final d = Directory('$exeDir/apk_tools');
      if (d.existsSync()) return d.path;
    } catch (_) {}
    try {
      final d = Directory(
          '${Directory.current.path.replaceAll('\\', '/')}/apk_tools');
      if (d.existsSync()) return d.path;
    } catch (_) {}
    return null;
  }

  /// Finds java.exe: checks JAVA_HOME, then Android Studio's bundled JRE.
  static String? _findJava() {
    // JAVA_HOME env var
    final jh = Platform.environment['JAVA_HOME'];
    if (jh != null) {
      final j = File('$jh/bin/java.exe');
      if (j.existsSync()) return j.path;
    }
    // Android Studio bundled JRE (common locations)
    final candidates = [
      r'D:\Program Files\Android\Android Studio\jbr\bin\java.exe',
      r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
      r'C:\Program Files\Android\Android Studio\jre\bin\java.exe',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    // Fall back to java on PATH
    return 'java';
  }

  /// Finds the runtime/ folder.
  /// Production: next to oma_engine.exe.
  /// Development (flutter run): relative to the current working directory.
  static String? _runtimeDir() {
    // 1. Next to the running exe
    try {
      final exeDir =
          File(Platform.resolvedExecutable).parent.path.replaceAll('\\', '/');
      final d = Directory('$exeDir/runtime');
      if (d.existsSync()) return d.path;
    } catch (_) {}

    // 2. Working-directory fallback (flutter run from project root)
    try {
      final d = Directory(
          '${Directory.current.path.replaceAll('\\', '/')}/runtime');
      if (d.existsSync()) return d.path;
    } catch (_) {}

    return null;
  }

  /// Copies all files from [runtimeDir] into [gameDir],
  /// renaming oma_runtime.exe → [safeName].exe.
  static Future<void> _copyRuntime(
      String runtimeDir, String gameDir, String safeName) async {
    final src = Directory(runtimeDir);
    await for (final entity
        in src.list(recursive: true, followLinks: false)) {
      final relative = entity.path
          .replaceAll('\\', '/')
          .substring(runtimeDir.replaceAll('\\', '/').length)
          .replaceAll(RegExp(r'^/'), '');

      if (entity is Directory) {
        await Directory('$gameDir/$relative').create(recursive: true);
      } else if (entity is File) {
        if (relative.toLowerCase() == 'oma_runtime.exe') {
          await entity.copy('$gameDir/$safeName.exe');
        } else {
          final dest = File('$gameDir/$relative');
          await dest.parent.create(recursive: true);
          await entity.copy(dest.path);
        }
      }
    }
  }

  static String _safeName(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .padRight(1, 'game');
}
