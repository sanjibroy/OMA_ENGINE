import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../editor/editor_state.dart';
import '../../models/game_object.dart';
import '../../models/game_project.dart';
import '../../models/map_data.dart';
import '../../theme/app_theme.dart';
import '../dialogs/new_map_dialog.dart';
import '../dialogs/animations_dialog.dart';
import '../../services/audio_manager.dart';

class LeftPanel extends StatefulWidget {
  final EditorState editorState;

  const LeftPanel({super.key, required this.editorState});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppColors.panelBg,
      child: Column(
        children: [
          // Maps section (always visible)
          _MapsSection(editorState: widget.editorState),
          Container(height: 1, color: AppColors.borderColor),
          // Tiles / Objects / Audio tabs
          _PanelHeader(
            tabs: const ['Tiles', 'Objects', 'Audio'],
            selected: _selectedTab,
            onTap: (i) {
              setState(() => _selectedTab = i);
              // Don't override collision tool when switching palette tabs
              final inCollision = widget.editorState.activeTool.value == EditorTool.collision;
              if (!inCollision) {
                if (i == 0) widget.editorState.activeTool.value = EditorTool.tile;
                if (i == 1) widget.editorState.activeTool.value = EditorTool.object;
              }
              // Audio tab: leave activeTool unchanged
            },
          ),
          Expanded(
            child: _selectedTab == 0
                ? _TilesList(editorState: widget.editorState)
                : _selectedTab == 1
                    ? _ObjectsList(editorState: widget.editorState)
                    : _AudioList(editorState: widget.editorState),
          ),
        ],
      ),
    );
  }
}

// ─── Maps Section ─────────────────────────────────────────────────────────────

class _MapsSection extends StatefulWidget {
  final EditorState editorState;
  const _MapsSection({required this.editorState});

  @override
  State<_MapsSection> createState() => _MapsSectionState();
}

class _MapsSectionState extends State<_MapsSection> {
  bool _expanded = true;

  EditorState get _es => widget.editorState;

  @override
  void initState() {
    super.initState();
    _es.projectChanged.addListener(_rebuild);
  }

  @override
  void dispose() {
    _es.projectChanged.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _addMap() async {
    final config = await NewMapDialog.show(context);
    if (config == null) return;
    await _es.addMap(
      name: config.name,
      width: config.width,
      height: config.height,
      tileSize: config.tileSize,
    );
  }

  Future<void> _renameMap(ProjectMap map) async {
    final ctrl = TextEditingController(text: map.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Text('Rename Map',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Rename',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      _es.renameMap(map.id, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maps = _es.project.maps;
    final currentId = _es.currentMapId;
    final startId = _es.project.startMapId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                const Text('MAPS',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
                const Spacer(),
                GestureDetector(
                  onTap: _addMap,
                  child: const Tooltip(
                    message: 'Add map',
                    child: Icon(Icons.add, size: 14, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_expanded)
          ...maps.map((map) {
            final isCurrent = map.id == currentId;
            final isStart = map.id == startId;
            return GestureDetector(
              onTap: () => _es.switchToMap(map.id),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.accent.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color:
                        isCurrent ? AppColors.accent : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCurrent
                          ? Icons.layers
                          : Icons.layers_outlined,
                      size: 12,
                      color: isCurrent
                          ? AppColors.accent
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        map.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // Start map indicator
                    if (isStart)
                      const Tooltip(
                        message: 'Start map',
                        child: Icon(Icons.play_circle_outline,
                            size: 11, color: AppColors.success),
                      ),
                    const SizedBox(width: 2),
                    // Context menu
                    GestureDetector(
                      onTap: () => _showMenu(context, map),
                      child: const Icon(Icons.more_vert,
                          size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 4),
      ],
    );
  }

  void _showMenu(BuildContext context, ProjectMap map) {
    final isStart = map.id == _es.project.startMapId;
    showMenu<String>(
      context: context,
      color: const Color(0xFF201E1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      position: RelativeRect.fill,
      items: [
        if (!isStart)
          const PopupMenuItem(
            value: 'start',
            child: _MenuItem(Icons.play_circle_outline, 'Set as start map'),
          ),
        const PopupMenuItem(
          value: 'rename',
          child: _MenuItem(Icons.edit_outlined, 'Rename'),
        ),
        if (_es.project.maps.length > 1)
          const PopupMenuItem(
            value: 'delete',
            child: _MenuItem(Icons.delete_outline, 'Delete', danger: true),
          ),
      ],
    ).then((val) async {
      if (val == 'start') _es.setStartMap(map.id);
      if (val == 'rename') await _renameMap(map);
      if (val == 'delete') await _es.removeMap(map.id);
    });
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _MenuItem(this.icon, this.label, {this.danger = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon,
              size: 14,
              color: danger ? AppColors.error : AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: danger
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 12)),
        ],
      );
}

// ─── Tab Header ───────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final void Function(int) onTap;

  const _PanelHeader(
      {required this.tabs, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = selected == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Tiles List ───────────────────────────────────────────────────────────────

class _TilesList extends StatefulWidget {
  final EditorState editorState;

  const _TilesList({required this.editorState});

  @override
  State<_TilesList> createState() => _TilesListState();
}

class _TilesListState extends State<_TilesList> {
  static const _paintableTiles = [
    TileType.grass,
    TileType.wall,
    TileType.water,
    TileType.sand,
    TileType.stone,
    TileType.woodFloor,
  ];

  @override
  void initState() {
    super.initState();
    widget.editorState.selectedTile.addListener(_onSelectionChanged);
    widget.editorState.selectedTileVariant.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.editorState.selectedTile.removeListener(_onSelectionChanged);
    widget.editorState.selectedTileVariant.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() => setState(() {});

  Future<void> _addVariant(TileType tile) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final index =
        await widget.editorState.spriteCache.addTileSprite(tile, path);
    if (index != null) {
      widget.editorState.mapData.tileSpritesPaths
          .putIfAbsent(tile.name, () => [])
          .add(path);
      // Auto-select the new variant
      widget.editorState.selectedTile.value = tile;
      widget.editorState.selectedTileVariant.value = index;
      setState(() {});
    }
  }

  void _removeVariant(TileType tile, int index) {
    widget.editorState.spriteCache.removeTileSprite(tile, index);
    final paths = widget.editorState.mapData.tileSpritesPaths[tile.name];
    if (paths != null && index < paths.length) {
      paths.removeAt(index);
      if (paths.isEmpty) {
        widget.editorState.mapData.tileSpritesPaths.remove(tile.name);
      }
    }
    // Reset selected variant if it's now out of range
    final count =
        widget.editorState.spriteCache.tileVariantCount(tile);
    if (widget.editorState.selectedTileVariant.value >= count) {
      widget.editorState.selectedTileVariant.value =
          (count - 1).clamp(0, count);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.editorState.selectedTile.value;
    final selectedVariant = widget.editorState.selectedTileVariant.value;
    final cache = widget.editorState.spriteCache;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _paintableTiles.length,
      itemBuilder: (_, i) {
        final tile = _paintableTiles[i];
        final isSelected = selected == tile;
        final variantPaths = cache.getTilePaths(tile);
        final hasSprites = variantPaths.isNotEmpty;

        return GestureDetector(
          onTap: () {
            widget.editorState.selectedTile.value = tile;
            widget.editorState.selectedTileVariant.value = 0;
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tile row: color/sprite preview + label + add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Preview: first sprite or color swatch
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: hasSprites
                            ? Image.file(File(variantPaths[0]),
                                width: 18, height: 18, fit: BoxFit.cover)
                            : Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: tile.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tile.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      // Add variant button
                      GestureDetector(
                        onTap: () => _addVariant(tile),
                        child: const Tooltip(
                          message: 'Add sprite variant',
                          child: Icon(Icons.add_photo_alternate_outlined,
                              size: 14, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),

                // Variant thumbnails (shown only when sprites exist)
                if (hasSprites && isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (int v = 0; v < variantPaths.length; v++)
                          GestureDetector(
                            onTap: () {
                              widget.editorState.selectedTileVariant.value = v;
                            },
                            onLongPress: () => _removeVariant(tile, v),
                            child: Stack(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: (isSelected && selectedVariant == v)
                                          ? AppColors.accent
                                          : AppColors.borderColor,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: Image.file(File(variantPaths[v]),
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Audio List ───────────────────────────────────────────────────────────────

class _AudioList extends StatefulWidget {
  final EditorState editorState;
  const _AudioList({required this.editorState});

  @override
  State<_AudioList> createState() => _AudioListState();
}

class _AudioListState extends State<_AudioList> {
  String? _previewingTrack; // track name currently previewing (music or sfx)

  EditorState get _es => widget.editorState;
  AudioManager get _audio => _es.audioManager;

  @override
  void initState() {
    super.initState();
    _es.projectChanged.addListener(_rebuild);
  }

  @override
  void dispose() {
    _es.projectChanged.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _import(Map<String, String> target) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final fileName = path.replaceAll('\\', '/').split('/').last;
    String name = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    // Ensure unique key
    int n = 2;
    final base = name;
    while (target.containsKey(name)) {
      name = '$base$n';
      n++;
    }
    target[name] = path;
    _es.notifyProjectChanged();
  }

  Future<void> _togglePreview(String name, String path, {bool loop = false}) async {
    if (_previewingTrack == name) {
      await _audio.stopPreview();
      setState(() => _previewingTrack = null);
    } else {
      if (loop) {
        await _audio.playMusic(path);
      } else {
        await _audio.preview(path);
      }
      setState(() => _previewingTrack = name);
    }
  }

  void _delete(Map<String, String> target, String name) {
    if (_previewingTrack == name) {
      _audio.stopPreview();
      _previewingTrack = null;
    }
    target.remove(name);
    _es.notifyProjectChanged();
  }

  @override
  Widget build(BuildContext context) {
    final music = _es.project.musicPaths;
    final sfx = _es.project.sfxPaths;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: [
        _sectionHeader('MUSIC', () => _import(music)),
        if (music.isEmpty)
          _emptyHint('No music imported')
        else
          ...music.entries.map((e) => _audioRow(
                name: e.key,
                isPlaying: _previewingTrack == e.key,
                onPreview: () =>
                    _togglePreview(e.key, e.value, loop: true),
                onDelete: () => _delete(music, e.key),
              )),
        const SizedBox(height: 12),
        _sectionHeader('SFX', () => _import(sfx)),
        if (sfx.isEmpty)
          _emptyHint('No sounds imported')
        else
          ...sfx.entries.map((e) => _audioRow(
                name: e.key,
                isPlaying: _previewingTrack == e.key,
                onPreview: () =>
                    _togglePreview(e.key, e.value, loop: false),
                onDelete: () => _delete(sfx, e.key),
              )),
      ],
    );
  }

  Widget _sectionHeader(String label, VoidCallback onImport) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0)),
            const Spacer(),
            GestureDetector(
              onTap: onImport,
              child: const Tooltip(
                message: 'Import audio file',
                child: Icon(Icons.add, size: 14, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );

  Widget _audioRow({
    required String name,
    required bool isPlaying,
    required VoidCallback onPreview,
    required VoidCallback onDelete,
  }) =>
      Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isPlaying
              ? AppColors.accent.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
              color: isPlaying
                  ? AppColors.accent.withOpacity(0.4)
                  : Colors.transparent),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onPreview,
              child: Icon(
                isPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                size: 16,
                color: isPlaying ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close,
                  size: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      );
}

// ─── Objects List ─────────────────────────────────────────────────────────────

class _ObjectsList extends StatefulWidget {
  final EditorState editorState;
  const _ObjectsList({required this.editorState});

  @override
  State<_ObjectsList> createState() => _ObjectsListState();
}

class _ObjectsListState extends State<_ObjectsList> {
  static const _types = GameObjectType.values;

  @override
  void initState() {
    super.initState();
    widget.editorState.selectedObjectType.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.editorState.selectedObjectType.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _importSprite(GameObjectType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final ok = await widget.editorState.spriteCache.loadSprite(type, path);
    if (ok) {
      widget.editorState.mapData.spritePaths[type.name] = path;
      setState(() {});
    }
  }

  void _removeSprite(GameObjectType type) {
    widget.editorState.spriteCache.removeSprite(type);
    widget.editorState.mapData.spritePaths.remove(type.name);
    setState(() {});
  }

  Future<void> _openAnimations(GameObjectType type) async {
    await AnimationsDialog.show(
      context,
      type: type,
      spriteCache: widget.editorState.spriteCache,
      mapData: widget.editorState.mapData,
      onChanged: () => setState(() {}),
    );
    setState(() {});
  }

  String? _previewPath(GameObjectType type) {
    final cache = widget.editorState.spriteCache;
    if (cache.isAnimated(type)) {
      final def = cache.defaultAnim(type);
      if (def.isNotEmpty) {
        final paths = cache.getAnimPaths(type, def);
        if (paths.isNotEmpty) return paths.first;
      }
    }
    return cache.getPath(type);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.editorState.selectedObjectType.value;
    final cache = widget.editorState.spriteCache;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _types.length,
      itemBuilder: (_, i) {
        final type = _types[i];
        final isSelected = selected == type;
        final isAnim = cache.isAnimated(type);
        final spritePath = cache.getPath(type);
        final preview = _previewPath(type);
        final animCount = cache.animNames(type).length;

        return GestureDetector(
          onTap: () => widget.editorState.selectedObjectType.value = type,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: preview != null
                            ? Image.file(File(preview),
                                width: 18, height: 18, fit: BoxFit.cover)
                            : Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: type.color,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(type.symbol,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(type.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )),
                      ),
                      if (type.isUnique)
                        const Text('×1',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10)),
                      // Anim badge (when not selected)
                      if (!isSelected && isAnim) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: '$animCount animation${animCount == 1 ? '' : 's'}',
                          child: const Icon(Icons.movie_outlined,
                              size: 12, color: AppColors.accent),
                        ),
                      ],
                    ],
                  ),
                ),

                // Expanded actions (when selected)
                if (isSelected) ...[
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Static sprite row
                        GestureDetector(
                          onTap: () => spritePath != null
                              ? _removeSprite(type)
                              : _importSprite(type),
                          child: Row(
                            children: [
                              Icon(
                                spritePath != null
                                    ? Icons.close
                                    : Icons.image_outlined,
                                size: 13,
                                color: spritePath != null
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                spritePath != null
                                    ? 'Remove static sprite'
                                    : 'Import static sprite',
                                style: TextStyle(
                                    color: spritePath != null
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Animations button
                        GestureDetector(
                          onTap: () => _openAnimations(type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isAnim
                                  ? AppColors.accent.withOpacity(0.12)
                                  : AppColors.surfaceBg,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isAnim
                                    ? AppColors.accent.withOpacity(0.5)
                                    : AppColors.borderColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie_outlined,
                                    size: 13,
                                    color: isAnim
                                        ? AppColors.accent
                                        : AppColors.textSecondary),
                                const SizedBox(width: 5),
                                Text(
                                  isAnim
                                      ? '$animCount animation${animCount == 1 ? '' : 's'}'
                                      : 'Animations\u2026',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAnim
                                        ? AppColors.accent
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
