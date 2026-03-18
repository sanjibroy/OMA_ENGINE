class TilesetDef {
  final String id;
  String name;
  String imagePath;
  int tileWidth;
  int tileHeight;
  int columns; // derived: imageWidth / tileWidth
  int rows;    // derived: imageHeight / tileHeight

  TilesetDef({
    String? id,
    required this.name,
    required this.imagePath,
    required this.tileWidth,
    required this.tileHeight,
    required this.columns,
    required this.rows,
  }) : id = id ?? 'ts_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'tileWidth': tileWidth,
        'tileHeight': tileHeight,
        'columns': columns,
        'rows': rows,
      };

  factory TilesetDef.fromJson(Map<String, dynamic> json) => TilesetDef(
        id: json['id'] as String,
        name: json['name'] as String,
        imagePath: json['imagePath'] as String,
        tileWidth: json['tileWidth'] as int,
        tileHeight: json['tileHeight'] as int,
        columns: json['columns'] as int,
        rows: json['rows'] as int,
      );
}

class TileCell {
  final String tilesetId; // '' = solid-color cell (no tileset)
  final int tileX; // column index in tileset (unused for color cells)
  final int tileY; // row index in tileset (unused for color cells)
  final int colorArgb; // ARGB value, only used when tilesetId == ''

  const TileCell({
    required this.tilesetId,
    this.tileX = 0,
    this.tileY = 0,
    this.colorArgb = 0,
  });

  /// True when this cell represents a solid color rather than a tileset tile.
  bool get isColor => tilesetId.isEmpty;

  /// Convenience constructor for a solid-color cell.
  factory TileCell.color(int argb) =>
      TileCell(tilesetId: '', colorArgb: argb);

  Map<String, dynamic> toJson() => isColor
      ? {'color': colorArgb}
      : {'ts': tilesetId, 'x': tileX, 'y': tileY};

  factory TileCell.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('color')) {
      return TileCell.color(json['color'] as int);
    }
    return TileCell(
      tilesetId: json['ts'] as String,
      tileX: json['x'] as int,
      tileY: json['y'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TileCell &&
      other.tilesetId == tilesetId &&
      other.tileX == tileX &&
      other.tileY == tileY &&
      other.colorArgb == colorArgb;

  @override
  int get hashCode => Object.hash(tilesetId, tileX, tileY, colorArgb);
}

/// A named tile layer holding a full grid of TileCell? values.
class TileLayer {
  final String id;
  String name;
  bool visible;
  List<List<TileCell?>> cells;

  TileLayer({
    String? id,
    required this.name,
    this.visible = true,
    required this.cells,
  }) : id = id ?? 'layer_${DateTime.now().microsecondsSinceEpoch}';

  factory TileLayer.empty(String name, int width, int height, {String? id}) =>
      TileLayer(
        id: id,
        name: name,
        cells: List.generate(height, (_) => List.filled(width, null)),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (!visible) 'visible': false,
        if (cells.any((row) => row.any((c) => c != null)))
          'cells': cells.map((row) => row.map((c) => c?.toJson()).toList()).toList(),
      };

  static TileLayer fromJson(Map<String, dynamic> json, int width, int height) {
    final List<List<TileCell?>> cells;
    if (json.containsKey('cells')) {
      final raw = json['cells'] as List;
      cells = List.generate(height, (y) {
        final row = raw[y] as List;
        return List.generate(width, (x) {
          final c = row[x];
          return c == null ? null : TileCell.fromJson(c as Map<String, dynamic>);
        });
      });
    } else {
      cells = List.generate(height, (_) => List.filled(width, null));
    }
    return TileLayer(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Layer',
      visible: json['visible'] as bool? ?? true,
      cells: cells,
    );
  }

  /// Deep copy for undo snapshots.
  TileLayer snapshot() => TileLayer(
        id: id,
        name: name,
        visible: visible,
        cells: cells.map((row) => List<TileCell?>.from(row)).toList(),
      );
}

/// A rectangular selection of tiles from a tileset, used as the paint brush.
class TilesetBrush {
  final String tilesetId;
  final int col1, row1; // top-left (inclusive)
  final int col2, row2; // bottom-right (inclusive)

  const TilesetBrush({
    required this.tilesetId,
    required this.col1,
    required this.row1,
    required this.col2,
    required this.row2,
  });

  int get width => col2 - col1 + 1;
  int get height => row2 - row1 + 1;

  /// Returns the TileCell at brush offset (dx, dy).
  TileCell cellAt(int dx, int dy) => TileCell(
        tilesetId: tilesetId,
        tileX: col1 + dx,
        tileY: row1 + dy,
      );

  TilesetBrush get normalized => TilesetBrush(
        tilesetId: tilesetId,
        col1: col1 < col2 ? col1 : col2,
        row1: row1 < row2 ? row1 : row2,
        col2: col1 < col2 ? col2 : col1,
        row2: row1 < row2 ? row2 : row1,
      );
}
