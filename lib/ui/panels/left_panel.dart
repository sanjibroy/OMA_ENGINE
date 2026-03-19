import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../editor/editor_state.dart';
import '../../models/game_object.dart';
import '../../models/game_project.dart';
import '../../models/tileset_def.dart';
import '../../theme/app_theme.dart';
import '../dialogs/new_map_dialog.dart';
// import '../dialogs/animations_dialog.dart' // moved to right_panel;
import '../../services/audio_manager.dart';
import '../../editor/editor_game.dart';

class LeftPanel extends StatefulWidget {
  final EditorState editorState;
  final double width;

  const LeftPanel({super.key, required this.editorState, this.width = 200});

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  int _selectedTab = 0;

  @override
  void initState(){
    super.initState();
    widget.editorState.activeTool.addListener(_onToolChanged);
  }

  @override
  void dispose(){
    widget.editorState.activeTool.removeListener(_onToolChanged);
    super.dispose();
  }

  void _onToolChanged(){
    final tool = widget.editorState.activeTool.value;
    // When exiting collision, resync activeTool to match current visible tab
    if(tool != EditorTool.collision){
      final correctTool = _selectedTab == 1 ? EditorTool.object : EditorTool.tile;
      if(tool!=correctTool){
        // Tab and tool are out of sync — fix the tool to match the tab
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.editorState.activeTool.value = correctTool;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
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
              //final inCollision = widget.editorState.activeTool.value == EditorTool.collision;
              //if (!inCollision) {
                if (i == 0) widget.editorState.activeTool.value = EditorTool.tile;
                if (i == 1) widget.editorState.activeTool.value = EditorTool.object;
              //}
              // Audio tab: leave activeTool unchanged
            },
          ),
          Expanded(
            child: _selectedTab == 0
                ? _TilesList(editorState: widget.editorState)
                : _selectedTab == 1
                    ? _ObjectsTab(editorState: widget.editorState)
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
        backgroundColor: AppColors.dialogBg,
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
      color: AppColors.dialogBg,
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
  @override
  void initState() {
    super.initState();
    widget.editorState.activeTool.addListener(_rebuild);
    widget.editorState.selectedBrush.addListener(_rebuild);
    widget.editorState.mapChanged.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.editorState.activeTool.removeListener(_rebuild);
    widget.editorState.selectedBrush.removeListener(_rebuild);
    widget.editorState.mapChanged.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _fillAll() {
    final es = widget.editorState;
    es.pushUndo();
    final brush = es.selectedBrush.value;
    if (brush != null) {
      es.game.fillAllTileset(brush, layerIndex: es.activeLayerIndex.value);
    }
    es.notifyMapChanged();
  }

  Future<void> _eraseAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        title: const Text('Erase entire map?', style: TextStyle(color: Colors.white)),
        content: const Text('This will clear all tiles and all layer sprites. This cannot be undone after saving.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final es = widget.editorState;
    es.pushUndo();
    es.game.eraseAllLayers();
    es.notifyMapChanged();
  }

  @override
  Widget build(BuildContext context) {
    final es = widget.editorState;
    final activeTool = es.activeTool.value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tool strip ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _TileToolBtn(
                  icon: Icons.edit_outlined,
                  tooltip: 'Paint',
                  active: activeTool == EditorTool.tile,
                  onTap: () => es.activeTool.value = EditorTool.tile,
                ),
                _TileToolBtn(
                  icon: Icons.format_color_fill,
                  tooltip: 'Flood Fill',
                  active: activeTool == EditorTool.fill,
                  onTap: () => es.activeTool.value = EditorTool.fill,
                ),
                _TileToolBtn(
                  icon: Icons.crop_square,
                  tooltip: 'Rectangle Fill',
                  active: activeTool == EditorTool.rect,
                  onTap: () => es.activeTool.value = EditorTool.rect,
                ),
                _TileToolBtn(
                  icon: Icons.auto_fix_off_outlined,
                  tooltip: 'Eraser — click or drag to erase tiles',
                  active: activeTool == EditorTool.erase,
                  onTap: () => es.activeTool.value = EditorTool.erase,
                ),
                _TileToolBtn(
                  icon: Icons.highlight_alt,
                  tooltip: 'Select (marquee) — move or delete painted tiles',
                  active: activeTool == EditorTool.select,
                  onTap: () => es.activeTool.value = EditorTool.select,
                ),
                _TileToolBtn(
                  icon: Icons.select_all,
                  tooltip: 'Fill entire map with selected tile',
                  active: false,
                  onTap: _fillAll,
                ),
                _TileToolBtn(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Erase entire map',
                  active: false,
                  danger: true,
                  onTap: _eraseAll,
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderColor),
          // ── Layers ────────────────────────────────────────────────────────
          _LayersSection(editorState: es),
          Container(height: 1, color: AppColors.borderColor),
          // ── Tilesets ──────────────────────────────────────────────────────
          _TilesetsSection(editorState: es),
        ],
      ),
    );
  }
}

// ─── Layers Section ───────────────────────────────────────────────────────────

class _LayersSection extends StatefulWidget {
  final EditorState editorState;
  const _LayersSection({required this.editorState});

  @override
  State<_LayersSection> createState() => _LayersSectionState();
}

class _LayersSectionState extends State<_LayersSection> {
  EditorState get _es => widget.editorState;

  @override
  void initState() {
    super.initState();
    _es.mapChanged.addListener(_rebuild);
    _es.activeLayerIndex.addListener(_rebuild);
  }

  @override
  void dispose() {
    _es.mapChanged.removeListener(_rebuild);
    _es.activeLayerIndex.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _addLayer() async {
    final ctrl = TextEditingController(text: 'Layer ${_es.mapData.layers.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Text('New Layer',
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
              child: const Text('Add',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      _es.addLayer(name);
    }
  }

  Future<void> _renameLayer(int index) async {
    final ctrl = TextEditingController(text: _es.mapData.layers[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Text('Rename Layer',
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
    if (!mounted) return;
    if (name != null && name.isNotEmpty) {
      _es.renameLayer(index, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = _es.mapData.layers;
    final activeIdx = _es.activeLayerIndex.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Text('LAYERS',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              const Spacer(),
              GestureDetector(
                onTap: _addLayer,
                child: const Tooltip(
                  message: 'Add layer',
                  child: Icon(Icons.add, size: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),

        // Layer list (top = rendered last = visually on top)
        ...List.generate(layers.length, (i) {
          // Display reversed so top of list = topmost layer
          final idx = layers.length - 1 - i;
          final layer = layers[idx];
          final isActive = idx == activeIdx;
          return GestureDetector(
            onTap: () => setState(() => _es.activeLayerIndex.value = idx),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accent.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: isActive ? AppColors.accent : Colors.transparent),
              ),
              child: Row(
                children: [
                  // Visibility eye
                  GestureDetector(
                    onTap: () => _es.toggleLayerVisible(idx),
                    child: Icon(
                      layer.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 13,
                      color: layer.visible
                          ? (isActive ? AppColors.accent : AppColors.textSecondary)
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Layer name
                  Expanded(
                    child: Text(
                      layer.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Move up/down
                  if (idx < layers.length - 1)
                    GestureDetector(
                      onTap: () => _es.moveLayerDown(idx),
                      child: const Tooltip(
                        message: 'Move layer up',
                        child: Icon(Icons.keyboard_arrow_up,
                            size: 13, color: AppColors.textMuted),
                      ),
                    ),
                  if (idx > 0)
                    GestureDetector(
                      onTap: () => _es.moveLayerUp(idx),
                      child: const Tooltip(
                        message: 'Move layer down',
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 13, color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(width: 2),
                  // Context menu
                  GestureDetector(
                    onTap: () => _showLayerMenu(context, idx),
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

  void _showLayerMenu(BuildContext context, int index) {
    showMenu<String>(
      context: context,
      color: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      position: RelativeRect.fill,
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: _MenuItem(Icons.edit_outlined, 'Rename'),
        ),
        if (_es.mapData.layers.length > 1)
          const PopupMenuItem(
            value: 'delete',
            child: _MenuItem(Icons.delete_outline, 'Delete', danger: true),
          ),
      ],
    ).then((val) async {
      if (!mounted) return;
      if (val == 'rename') await _renameLayer(index);
      if (val == 'delete') _es.removeLayer(index);
    });
  }
}

// ─── Tilesets Section ─────────────────────────────────────────────────────────

class _TilesetsSection extends StatefulWidget {
  final EditorState editorState;
  const _TilesetsSection({required this.editorState});

  @override
  State<_TilesetsSection> createState() => _TilesetsSectionState();
}

class _TilesetsSectionState extends State<_TilesetsSection> {
  bool _expanded = true;
  String? _expandedTilesetId; // which tileset viewer is open

  EditorState get _es => widget.editorState;

  Future<void> _importTileset() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;

    // Get image dimensions to compute columns/rows
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imgW = frame.image.width;
    final imgH = frame.image.height;
    frame.image.dispose();

    if (!mounted) return;

    // Show config dialog
    final config = await _showTilesetImportDialog(path, imgW, imgH);
    if (config == null) return;

    final def = TilesetDef(
      name: config.name,
      imagePath: path,
      tileWidth: config.tileWidth,
      tileHeight: config.tileHeight,
      columns: imgW ~/ config.tileWidth,
      rows: imgH ~/ config.tileHeight,
    );

    _es.mapData.tilesets.add(def);
    await _es.spriteCache.loadTileset(def);
    _es.notifyMapChanged();

    setState(() {
      _expandedTilesetId = def.id;
    });
  }

  Future<_TilesetImportConfig?> _showTilesetImportDialog(String path, int imgW, int imgH) {
    final nameCtrl = TextEditingController(text: _nameFromPath(path));
    final wCtrl = TextEditingController(text: '16');
    final hCtrl = TextEditingController(text: '16');
    return showDialog<_TilesetImportConfig>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final tw = int.tryParse(wCtrl.text) ?? 16;
          final th = int.tryParse(hCtrl.text) ?? 16;
          final cols = tw > 0 ? imgW ~/ tw : 0;
          final rows = th > 0 ? imgH ~/ th : 0;
          return AlertDialog(
            backgroundColor: AppColors.dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.borderColor),
            ),
            title: const Text('Import Tileset',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  const Text('Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  _dialogField(nameCtrl),
                  const SizedBox(height: 12),
                  // Tile size
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tile Width', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      _dialogField(wCtrl, onChanged: (_) => setD(() {}), isNumber: true),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tile Height', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(height: 4),
                      _dialogField(hCtrl, onChanged: (_) => setD(() {}), isNumber: true),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  // Info
                  Text('Image: ${imgW}×${imgH}px → $cols×$rows tiles',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final tw2 = int.tryParse(wCtrl.text) ?? 0;
                  final th2 = int.tryParse(hCtrl.text) ?? 0;
                  if (tw2 <= 0 || th2 <= 0) return;
                  Navigator.pop(ctx, _TilesetImportConfig(
                    name: nameCtrl.text.trim().isEmpty ? 'Tileset' : nameCtrl.text.trim(),
                    tileWidth: tw2,
                    tileHeight: th2,
                  ));
                },
                child: const Text('Import', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, {void Function(String)? onChanged, bool isNumber = false}) =>
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: AppColors.surfaceBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
        ),
      );

  String _nameFromPath(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  void _removeTileset(TilesetDef def) {
    _es.mapData.tilesets.remove(def);
    // Clear cells that used this tileset across all layers
    for (final layer in _es.mapData.layers) {
      for (int y = 0; y < _es.mapData.height; y++) {
        for (int x = 0; x < _es.mapData.width; x++) {
          if (layer.cells[y][x]?.tilesetId == def.id) {
            layer.cells[y][x] = null;
          }
        }
      }
    }
    if (_es.selectedBrush.value?.tilesetId == def.id) {
      _es.selectedBrush.value = null;
    }
    _es.spriteCache.clearTilesets();
    // Reload remaining tilesets
    _es.spriteCache.loadTilesets(_es.mapData.tilesets);
    _es.notifyMapChanged();
    setState(() {
      if (_expandedTilesetId == def.id) _expandedTilesetId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tilesets = _es.mapData.tilesets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                const Text('TILESETS',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
                const Spacer(),
                GestureDetector(
                  onTap: _importTileset,
                  child: const Tooltip(
                    message: 'Import tileset image',
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 14, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          if (tilesets.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text('No tilesets imported',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            )
          else
            ...tilesets.map((def) {
              final isOpen = _expandedTilesetId == def.id;
              final isActive = _es.selectedBrush.value?.tilesetId == def.id;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tileset row
                  GestureDetector(
                    onTap: () => setState(() {
                      _expandedTilesetId = isOpen ? null : def.id;
                    }),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(6, 1, 6, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.accent.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: isActive ? AppColors.accent.withOpacity(0.4) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Image.file(File(def.imagePath),
                                width: 16, height: 16, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(def.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isActive
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary)),
                                Text('${def.columns}×${def.rows} tiles, ${def.tileWidth}×${def.tileHeight}px',
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Icon(isOpen ? Icons.expand_more : Icons.chevron_right,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeTileset(def),
                            child: const Tooltip(
                              message: 'Remove tileset',
                              child: Icon(Icons.close, size: 12, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tileset viewer
                  if (isOpen)
                    _TilesetViewer(
                      def: def,
                      image: _es.spriteCache.getTilesetImage(def.id),
                      activeBrush: _es.selectedBrush.value?.tilesetId == def.id
                          ? _es.selectedBrush.value
                          : null,
                      onBrushSelected: (brush) {
                        _es.selectedBrush.value = brush;
                        
                        final current = _es.activeTool.value;
                        if (current != EditorTool.object && current != EditorTool.collision) {
                          _es.activeTool.value = EditorTool.tile;
                        }

                      },
                    ),
                ],
              );
            }),
        ],
      ],
    );
  }
}

class _TilesetImportConfig {
  final String name;
  final int tileWidth;
  final int tileHeight;
  const _TilesetImportConfig({required this.name, required this.tileWidth, required this.tileHeight});
}

// ─── Tileset Viewer ───────────────────────────────────────────────────────────

class _TilesetViewer extends StatefulWidget {
  final TilesetDef def;
  final ui.Image? image;
  final TilesetBrush? activeBrush;
  final void Function(TilesetBrush brush) onBrushSelected;

  const _TilesetViewer({
    required this.def,
    required this.image,
    required this.activeBrush,
    required this.onBrushSelected,
  });

  @override
  State<_TilesetViewer> createState() => _TilesetViewerState();
}

class _TilesetViewerState extends State<_TilesetViewer> {
  // Zoom & pan
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  bool _initDone = false;

  // Drag selection (left button)
  bool _isSelecting = false;
  int _selStartCol = 0, _selStartRow = 0;
  int _selEndCol = 0, _selEndRow = 0;

  // Pan (middle / right button)
  bool _isPanning = false;
  Offset _lastPanPos = Offset.zero;

  @override
  void didUpdateWidget(_TilesetViewer old) {
    super.didUpdateWidget(old);
    if (old.def.id != widget.def.id) _initDone = false;
  }

  void _fitToWidth(double availW) {
    final naturalW = widget.def.columns * widget.def.tileWidth.toDouble();
    _zoom = (availW / naturalW).clamp(0.1, 12.0);
    _pan = Offset.zero;
    _initDone = true;
  }

  /// Screen → content coordinate.
  Offset _toContent(Offset screen) {
    final d = screen - _pan;
    return Offset(d.dx / _zoom, d.dy / _zoom);
  }

  /// Clamp a content position to valid tile indices.
  (int col, int row) _toTile(Offset content) => (
        (content.dx / widget.def.tileWidth).floor().clamp(0, widget.def.columns - 1),
        (content.dy / widget.def.tileHeight).floor().clamp(0, widget.def.rows - 1),
      );

  void _confirmSelection() {
    if (!_isSelecting) return;
    final c1 = _selStartCol < _selEndCol ? _selStartCol : _selEndCol;
    final c2 = _selStartCol < _selEndCol ? _selEndCol : _selStartCol;
    final r1 = _selStartRow < _selEndRow ? _selStartRow : _selEndRow;
    final r2 = _selStartRow < _selEndRow ? _selEndRow : _selStartRow;
    widget.onBrushSelected(TilesetBrush(
      tilesetId: widget.def.id,
      col1: c1, row1: r1,
      col2: c2, row2: r2,
    ));
    setState(() => _isSelecting = false);
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final tileW = def.tileWidth.toDouble();
    final tileH = def.tileHeight.toDouble();
    final naturalW = def.columns * tileW;
    final naturalH = def.rows * tileH;

    // Determine which selection rect to draw
    final brush = widget.activeBrush;
    int? dc1, dr1, dc2, dr2;
    if (_isSelecting) {
      dc1 = _selStartCol < _selEndCol ? _selStartCol : _selEndCol;
      dc2 = _selStartCol < _selEndCol ? _selEndCol : _selStartCol;
      dr1 = _selStartRow < _selEndRow ? _selStartRow : _selEndRow;
      dr2 = _selStartRow < _selEndRow ? _selEndRow : _selStartRow;
    } else if (brush != null && brush.tilesetId == def.id) {
      dc1 = brush.col1; dr1 = brush.row1;
      dc2 = brush.col2; dr2 = brush.row2;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(builder: (_, constraints) {
          if (!_initDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _fitToWidth(constraints.maxWidth));
            });
          }
          return Listener(
            // Scroll = zoom centered on cursor
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                setState(() {
                  final oldZoom = _zoom;
                  final factor = e.scrollDelta.dy < 0 ? 1.15 : 0.87;
                  _zoom = (_zoom * factor).clamp(0.1, 12.0);
                  // Keep cursor point fixed during zoom
                  final ratio = _zoom / oldZoom;
                  final delta = e.localPosition - _pan;
                  _pan = e.localPosition - Offset(delta.dx * ratio, delta.dy * ratio);
                });
              }
            },
            // Middle / right button = pan
            onPointerDown: (e) {
              if (e.buttons == kMiddleMouseButton || e.buttons == kSecondaryMouseButton) {
                setState(() { _isPanning = true; _lastPanPos = e.localPosition; });
              }
            },
            onPointerMove: (e) {
              if (_isPanning) {
                setState(() {
                  _pan += e.localPosition - _lastPanPos;
                  _lastPanPos = e.localPosition;
                });
              }
            },
            onPointerUp: (_) {
              if (_isPanning) setState(() => _isPanning = false);
            },
            // Left button drag = tile selection
            child: GestureDetector(
              onPanStart: (d) {
                if (_isPanning) return;
                final tile = _toTile(_toContent(d.localPosition));
                setState(() {
                  _isSelecting = true;
                  _selStartCol = tile.$1; _selStartRow = tile.$2;
                  _selEndCol = tile.$1;   _selEndRow = tile.$2;
                });
              },
              onPanUpdate: (d) {
                if (!_isSelecting) return;
                final tile = _toTile(_toContent(d.localPosition));
                setState(() { _selEndCol = tile.$1; _selEndRow = tile.$2; });
              },
              onPanEnd: (_) => _confirmSelection(),
              onTapDown: (d) {
                // Single-tile click
                final tile = _toTile(_toContent(d.localPosition));
                widget.onBrushSelected(TilesetBrush(
                  tilesetId: def.id,
                  col1: tile.$1, row1: tile.$2,
                  col2: tile.$1, row2: tile.$2,
                ));
              },
              child: CustomPaint(
                painter: _TilesetGridPainter(
                  def: def,
                  image: widget.image,
                  zoom: _zoom,
                  pan: _pan,
                  selC1: dc1, selR1: dr1,
                  selC2: dc2, selR2: dr2,
                  naturalW: naturalW,
                  naturalH: naturalH,
                ),
                size: Size(constraints.maxWidth, 200),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TilesetGridPainter extends CustomPainter {
  final TilesetDef def;
  final ui.Image? image;
  final double zoom;
  final Offset pan;
  final int? selC1, selR1, selC2, selR2;
  final double naturalW, naturalH;

  const _TilesetGridPainter({
    required this.def,
    required this.image,
    required this.zoom,
    required this.pan,
    required this.naturalW,
    required this.naturalH,
    this.selC1,
    this.selR1,
    this.selC2,
    this.selR2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    final tileW = def.tileWidth.toDouble();
    final tileH = def.tileHeight.toDouble();

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, naturalW, naturalH),
        Paint()..color = const Color(0xFF2A2A2A));

    // Tileset image
    if (image != null) {
      canvas.drawImageRect(
        image!,
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
        Rect.fromLTWH(0, 0, naturalW, naturalH),
        Paint()..filterQuality = FilterQuality.none,
      );
    }

    // Grid lines — keep 1px wide regardless of zoom
    final gridPaint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.0 / zoom
      ..style = PaintingStyle.stroke;
    for (int c = 0; c <= def.columns; c++) {
      canvas.drawLine(Offset(c * tileW, 0), Offset(c * tileW, naturalH), gridPaint);
    }
    for (int r = 0; r <= def.rows; r++) {
      canvas.drawLine(Offset(0, r * tileH), Offset(naturalW, r * tileH), gridPaint);
    }

    // Selection highlight
    if (selC1 != null && selR1 != null && selC2 != null && selR2 != null) {
      final rect = Rect.fromLTWH(
        selC1! * tileW, selR1! * tileH,
        (selC2! - selC1! + 1) * tileW,
        (selR2! - selR1! + 1) * tileH,
      );
      canvas.drawRect(rect, Paint()
        ..color = const Color(0x446C63FF)
        ..style = PaintingStyle.fill);
      canvas.drawRect(rect, Paint()
        ..color = const Color(0xFF6C63FF)
        ..strokeWidth = 2.0 / zoom
        ..style = PaintingStyle.stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TilesetGridPainter old) => true;
}

// ─── Tile Tool Button ─────────────────────────────────────────────────────────

class _TileToolBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final bool danger;
  final VoidCallback onTap;

  const _TileToolBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.error
        : active
            ? AppColors.accent
            : AppColors.textMuted;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 26,
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: danger
                  ? AppColors.error.withOpacity(0.5)
                  : active
                      ? AppColors.accent
                      : AppColors.borderColor,
            ),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
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

  /// Adds a new variant (or replaces variant 0 if none exist yet).
  Widget _variantRow(GameObjectType type, int vi, int activeVariant, dynamic cache) {
    final es = widget.editorState;
    final isActive = vi == activeVariant;
    final name = es.mapData.getVariantName(type, vi);
    final paths = cache.objVariantPathsList(type) as List<String>;

    return GestureDetector(
      onTap: () => setState(() => es.selectedVariantIndex[type] = vi),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isActive ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Sprite thumbnail
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: paths.length > vi
                    ? Image.file(File(paths[vi]), fit: BoxFit.cover)
                    : Container(color: type.color,
                        child: Icon(type.icon, size: 14, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            // Name
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            // Rename button
            GestureDetector(
              onTap: () => _renameVariant(type, vi, name),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
              ),
            ),
            // Remove button
            GestureDetector(
              onTap: () => _removeVariant(type, vi),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameVariant(GameObjectType type, int vi, String current) async {
    final ctrl = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Text('Rename Variant',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Goblin',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.borderColor)),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Rename', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    widget.editorState.mapData.setVariantName(type, vi, newName);
    widget.editorState.notifyMapChanged();
    setState(() {});
  }

  Future<void> _addVariant(GameObjectType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final es = widget.editorState;
    final idx = await es.spriteCache.addObjectVariant(type, path);
    if (idx != null) {
      _syncVariantPaths(type);
      setState(() {});
    }
  }

  void _removeVariant(GameObjectType type, int index) {
    final es = widget.editorState;
    es.spriteCache.removeObjectVariant(type, index);
    // Clamp selected variant if it was pointing past the end
    final count = es.spriteCache.objVariantCount(type);
    if ((es.selectedVariantIndex[type] ?? 0) >= count) {
      es.selectedVariantIndex[type] = (count - 1).clamp(0, 99);
    }
    _syncVariantPaths(type);
    setState(() {});
  }

  void _syncVariantPaths(GameObjectType type) {
    final es = widget.editorState;
    final paths = es.spriteCache.objVariantPathsList(type);
    es.mapData.objectVariantPaths[type.name] = List.from(paths);
    // Keep spritePaths (variant 0) in sync for backward compat
    if (paths.isNotEmpty) {
      es.mapData.spritePaths[type.name] = paths[0];
    } else {
      es.mapData.spritePaths.remove(type.name);
      es.mapData.objectVariantPaths.remove(type.name);
    }
    es.notifyMapChanged();
  }

  String? _previewPath(GameObjectType type) {
    final cache = widget.editorState.spriteCache;
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
        final preview = _previewPath(type);
        final variantCount = cache.objVariantCount(type);
        final activeVariant = widget.editorState.selectedVariantIndex[type] ?? 0;

        return GestureDetector(
          onTap: () {
            widget.editorState.selectedObjectType.value = type;
            // Clear selected instance so right panel shows this type's sprite/anim editor
            widget.editorState.selectedObject.value = null;
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
                // Main row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Default icon (always, regardless of imported sprite)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: type.color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(type.icon, color: Colors.white, size: 11),
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
                    ],
                  ),
                ),

                // Expanded actions (when selected)
                if (isSelected) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Variant list with names ───────────────────────
                        if (variantCount > 0) ...[
                          Column(
                            children: [
                              for (int vi = 0; vi < variantCount; vi++)
                                _variantRow(type, vi, activeVariant, cache),
                              // Add variant button
                              GestureDetector(
                                onTap: () => _addVariant(type),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppColors.borderColor),
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: AppColors.textMuted),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Add New ${type.label}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ] else ...[
                          // No variants yet — show add button
                          GestureDetector(
                            onTap: () => _addVariant(type),
                            child: Row(
                              children: [
                                const Icon(Icons.add,
                                    size: 13, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Add New ${type.label}',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
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

// ─── Objects Tab (type palette + instances) ────────────────────────────────────

class _ObjectsTab extends StatelessWidget {
  final EditorState editorState;
  const _ObjectsTab({required this.editorState});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _ObjectsList(editorState: editorState)),
        _InstancesSection(editorState: editorState),
      ],
    );
  }
}

// ─── Instances Section ─────────────────────────────────────────────────────────

class _InstancesSection extends StatefulWidget {
  final EditorState editorState;
  const _InstancesSection({required this.editorState});

  @override
  State<_InstancesSection> createState() => _InstancesSectionState();
}

class _InstancesSectionState extends State<_InstancesSection> {
  bool _expanded = true;

  EditorState get _es => widget.editorState;
  EditorGame get _game => _es.game;

  @override
  void initState() {
    super.initState();
    _es.mapChanged.addListener(_rebuild);
    _es.selectedObject.addListener(_rebuild);
  }

  @override
  void dispose() {
    _es.mapChanged.removeListener(_rebuild);
    _es.selectedObject.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _select(GameObject obj) {
    _es.selectedObject.value = obj;
    _game.setSelectedObject(obj.id);
    _es.activeTool.value = EditorTool.object;
  }

  void _duplicate(GameObject obj) {
    final copy = _game.duplicateObject(obj, _es);
    _es.selectedObject.value = copy;
    _game.setSelectedObject(copy.id);
    _es.notifyMapChanged();
  }

  void _delete(GameObject obj) {
    _es.pushUndo();
    _es.mapData.objects.remove(obj);
    if (_es.selectedObject.value?.id == obj.id) {
      _es.selectedObject.value = null;
      _game.setSelectedObject(null);
    }
    _es.notifyMapChanged();
  }

  @override
  Widget build(BuildContext context) {
    final objects = _es.mapData.objects;
    final selectedId = _es.selectedObject.value?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: AppColors.borderColor),
        // Header
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: AppColors.panelBg,
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'INSTANCES (${objects.length})',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: objects.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Text(
                        'No objects placed',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: objects.length,
                    itemBuilder: (_, i) {
                      // Show in reverse so newest is at top
                      final obj = objects[objects.length - 1 - i];
                      final isSelected = obj.id == selectedId;
                      final preview = _es.spriteCache.getPath(obj.type);

                      return GestureDetector(
                        onTap: () => _select(obj),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Type icon / sprite preview
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: preview != null
                                    ? Image.file(File(preview),
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: obj.type.color,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Icon(obj.type.icon,
                                              color: Colors.white, size: 9),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      obj.name.isNotEmpty
                                          ? obj.name
                                          : obj.type.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      '(${obj.tileX}, ${obj.tileY})',
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                              // Duplicate button
                              GestureDetector(
                                onTap: () => _duplicate(obj),
                                child: const Tooltip(
                                  message: 'Duplicate (Ctrl+D)',
                                  child: Icon(Icons.copy_outlined,
                                      size: 12,
                                      color: AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Delete button
                              GestureDetector(
                                onTap: () => _delete(obj),
                                child: const Tooltip(
                                  message: 'Remove',
                                  child: Icon(Icons.close,
                                      size: 12,
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
