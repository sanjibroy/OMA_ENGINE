import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/map_data.dart';

class MapService {
  static const _ext = 'oma';

  /// Saves [mapData] to a user-chosen .oma file.
  /// Returns true on success.
  static Future<bool> saveMap(MapData mapData) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Map',
      fileName: '${mapData.name}.$_ext',
      type: FileType.custom,
      allowedExtensions: [_ext],
    );
    if (path == null) return false;

    final savePath = path.endsWith('.$_ext') ? path : '$path.$_ext';
    await File(savePath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(mapData.toJson()),
    );
    return true;
  }

  /// Opens a .oma file and loads it into [mapData] in-place.
  /// Returns true on success.
  static Future<bool> loadMap(MapData mapData) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Map',
      type: FileType.custom,
      allowedExtensions: [_ext],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return false;

    final path = result.files.single.path;
    if (path == null) return false;

    final content = await File(path).readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    mapData.loadFromJson(json);
    return true;
  }
}
