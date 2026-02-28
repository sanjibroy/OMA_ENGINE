import 'package:flutter/material.dart';
import '../../editor/editor_state.dart';
import '../../models/game_project.dart';
import '../../services/export_service.dart';
import '../../services/project_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/new_map_dialog.dart';
import '../dialogs/project_settings_dialog.dart';
// EditorTool is defined in editor_state.dart (already imported)

class Toolbar extends StatefulWidget {
  final EditorState editorState;

  const Toolbar({super.key, required this.editorState});

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isExporting = false;
  bool _isExportingApk = false;

  EditorState get _es => widget.editorState;

  // ─── New Project ────────────────────────────────────────────────────────────

  Future<void> _onNew() async {
    final config = await NewMapDialog.show(context);
    if (config == null) return;

    // Reset to a fresh single-map project
    _es.mapData.reset(
      name: config.name,
      width: config.width,
      height: config.height,
      tileSize: config.tileSize,
    );
    _es.spriteCache.clear();

    const id = 'map_0';
    _es.project.name = config.projectName;
    _es.project.startMapId = id;
    _es.project.maps
      ..clear()
      ..add(ProjectMap(
          id: id,
          name: config.name,
          fileName:
              'maps/${config.name.toLowerCase().replaceAll(' ', '_')}.json'));
    _es.projectDir = null;
    _es.notifyMapChanged();
    _es.notifyProjectChanged();
  }

  Future<void> _renameProject() async {
    final ctrl = TextEditingController(text: _es.project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Text('Rename Project',
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
      _es.project.name = newName;
      _es.notifyProjectChanged();
    }
  }

  // ─── Save Project ───────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    String? dir = _es.projectDir;

    // First save — pick a location
    if (dir == null) {
      dir = await ProjectService.createProject(
        _es.project,
        _es.currentMapId,
        _es.mapData,
      );
      if (dir == null) {
        setState(() => _isSaving = false);
        return;
      }
      _es.projectDir = dir;
    } else {
      await ProjectService.saveProject(
        project: _es.project,
        projectDir: dir,
        currentMapId: _es.currentMapId,
        currentMap: _es.mapData,
        mapCache: _es.mapCache,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    _showSnack('Project saved.');
  }

  // ─── Open Project ───────────────────────────────────────────────────────────

  Future<void> _onOpen() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final OpenProjectResult? result = await ProjectService.openProject();
    setState(() => _isLoading = false);
    if (result == null || !mounted) return;

    await _es.loadProject(
      newProject: result.project,
      newMapId: result.startMapId,
      newMapData: result.startMapData,
      newProjectDir: result.projectDir,
    );
    _showSnack('Opened: ${result.project.name}');
  }

  Future<void> _onExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final result = await ExportService.export(context, widget.editorState);
    if (!mounted) return;
    setState(() => _isExporting = false);
    if (result.message == 'Cancelled') return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: Text(
          result.success ? 'Export Complete' : 'Export Failed',
          style: TextStyle(
            color: result.success ? AppColors.success : AppColors.error,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          result.success
              ? 'Game exported to:\n${result.projectPath}'
              : result.message,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          if (result.success)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ExportService.launchGame(
                    result.projectPath!, result.safeName!);
              },
              child: const Text('Play Game',
                  style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              result.success ? 'Close' : 'OK',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onExportApk() async {
    if (_isExportingApk) return;
    setState(() => _isExportingApk = true);
    final result =
        await ExportService.exportApk(context, widget.editorState);
    if (!mounted) return;
    setState(() => _isExportingApk = false);
    if (result.message == 'Cancelled') return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: Text(
          result.success ? 'APK Export Complete' : 'APK Export Failed',
          style: TextStyle(
            color: result.success ? AppColors.success : AppColors.error,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          result.success
              ? 'APK saved to:\n${result.projectPath}.apk\n\nInstall it on any Android device.'
              : result.message,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        backgroundColor: AppColors.surfaceBg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.borderColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.panelBg,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.gamepad, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'OMA ENGINE',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),
          _divider(),
          const SizedBox(width: 16),

          // File actions
          _ToolbarButton(icon: Icons.add, label: 'New', onTap: _onNew),
          _ToolbarButton(
            icon: _isLoading ? Icons.hourglass_top : Icons.folder_open,
            label: 'Open',
            onTap: _onOpen,
          ),
          _ToolbarButton(
            icon: _isSaving ? Icons.hourglass_top : Icons.save,
            label: 'Save',
            onTap: _onSave,
          ),
          _ToolbarButton(
            icon: Icons.settings_outlined,
            tooltip: 'Project Settings',
            onTap: () => ProjectSettingsDialog.show(
              context,
              project: _es.project,
              onChanged: _es.notifyProjectChanged,
            ),
          ),

          const SizedBox(width: 16),
          _divider(),
          const SizedBox(width: 16),

          // Project > Map name
          ValueListenableBuilder<int>(
            valueListenable: widget.editorState.projectChanged,
            builder: (_, __, ___) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Click to rename project',
                  child: GestureDetector(
                    onTap: _renameProject,
                    child: Text(
                      widget.editorState.project.name,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.chevron_right,
                      size: 12, color: AppColors.textMuted),
                ),
                Text(
                  widget.editorState.currentMapMeta?.name ??
                      widget.editorState.mapData.name,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Undo/Redo
          const SizedBox(width: 16),
          _divider(),
          const SizedBox(width: 16),
          ValueListenableBuilder<int>(
            valueListenable: widget.editorState.undoCount,
            builder: (_, count, __) => Opacity(
              opacity: count > 0 ? 1.0 : 0.35,
              child: _ToolbarButton(
                icon: Icons.undo,
                tooltip: 'Undo (${count})',
                onTap: count > 0 ? () => _es.undo() : () {},
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: widget.editorState.redoCount,
            builder: (_, count, __) => Opacity(
              opacity: count > 0 ? 1.0 : 0.35,
              child: _ToolbarButton(
                icon: Icons.redo,
                tooltip: 'Redo (${count})',
                onTap: count > 0 ? () => _es.redo() : () {},
              ),
            ),
          ),

          const SizedBox(width: 16),
          _divider(),
          const SizedBox(width: 16),

          // Grid toggle
          ValueListenableBuilder<bool>(
            valueListenable: widget.editorState.showGrid,
            builder: (_, showGrid, __) => _ToolbarButton(
              icon: showGrid ? Icons.grid_on : Icons.grid_off,
              tooltip: showGrid ? 'Hide Grid' : 'Show Grid',
              onTap: () =>
                  widget.editorState.showGrid.value = !showGrid,
            ),
          ),

          const SizedBox(width: 4),

          // Collision tool toggle
          ValueListenableBuilder<EditorTool>(
            valueListenable: widget.editorState.activeTool,
            builder: (_, tool, __) {
              final isCollision = tool == EditorTool.collision;
              return Tooltip(
                message: isCollision
                    ? 'Exit Collision mode'
                    : 'Collision tool: left-click=block tile (red), right-click=unblock tile (cyan)',
                child: GestureDetector(
                  onTap: () {
                    if (isCollision) {
                      widget.editorState.activeTool.value = EditorTool.tile;
                    } else {
                      widget.editorState.activeTool.value = EditorTool.collision;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: isCollision
                          ? AppColors.accent.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isCollision
                            ? AppColors.accent.withOpacity(0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: isCollision
                          ? AppColors.accent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),

          const Spacer(),

          // Play / Stop toggle
          ValueListenableBuilder<bool>(
            valueListenable: widget.editorState.isPlayMode,
            builder: (_, isPlay, __) => GestureDetector(
              onTap: () {
                widget.editorState.isPlayMode.value = !isPlay;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isPlay
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPlay
                        ? AppColors.success.withOpacity(0.5)
                        : AppColors.accent.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlay ? Icons.stop : Icons.play_arrow,
                      size: 16,
                      color: isPlay ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPlay ? 'Stop' : 'Play',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isPlay ? AppColors.success : AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Export Windows button
          GestureDetector(
            onTap: _onExport,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _isExporting
                    ? AppColors.accent.withOpacity(0.5)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExporting ? Icons.hourglass_top : Icons.desktop_windows,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isExporting ? 'Exporting…' : 'Export .exe',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Export Android APK button
          GestureDetector(
            onTap: _onExportApk,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _isExportingApk
                    ? const Color(0xFF3DDC84).withOpacity(0.4)
                    : const Color(0xFF3DDC84).withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExportingApk
                        ? Icons.hourglass_top
                        : Icons.android,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isExportingApk ? 'Building…' : 'Export .apk',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 20,
        color: AppColors.borderColor,
      );
}

// ─── Toolbar Button ───────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    this.label,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label != null ? 10 : 8, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(label!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
