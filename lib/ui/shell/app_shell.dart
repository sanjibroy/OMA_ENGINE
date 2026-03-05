import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'toolbar.dart';
import 'status_bar.dart';
import '../panels/left_panel.dart';
import '../panels/center_canvas.dart';
import '../panels/right_panel.dart';
import '../../theme/app_theme.dart';
import '../../editor/editor_state.dart';
import '../../models/map_data.dart';
import '../../services/project_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  late final EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(mapData: MapData());
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    _editorState.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!_editorState.isDirty.value) {
      await windowManager.destroy();
      return;
    }

    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Text('Unsaved Changes',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'You have unsaved changes. Save before closing?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'quit'),
            child: const Text('Quit Without Saving',
                style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save & Quit',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (choice == 'quit') {
      await windowManager.destroy();
    } else if (choice == 'save') {
      final dir = _editorState.projectDir;
      if (dir == null) {
        // No existing path — pick a location
        final saved = await ProjectService.createProject(
          _editorState.project,
          _editorState.currentMapId,
          _editorState.mapData,
        );
        if (saved != null) {
          _editorState.projectDir = saved;
          _editorState.markClean();
          await windowManager.destroy();
        }
        // If picker was cancelled, stay open
      } else {
        await ProjectService.saveProject(
          project: _editorState.project,
          projectDir: dir,
          currentMapId: _editorState.currentMapId,
          currentMap: _editorState.mapData,
          mapCache: _editorState.mapCache,
        );
        _editorState.markClean();
        await windowManager.destroy();
      }
    }
    // choice == 'cancel' or null → do nothing, window stays open
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_editorState.isPlayMode.value) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final isCtrl = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    if (!isCtrl) return false;
    final isShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (isShift) {
        _editorState.redo();
      } else {
        _editorState.undo();
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      _editorState.redo();
      return true;
    }
    return false;
  }

  Widget _hiddenInPlay(Widget child) => ValueListenableBuilder<bool>(
        valueListenable: _editorState.isPlayMode,
        builder: (_, isPlay, __) => isPlay ? const SizedBox.shrink() : child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Toolbar(editorState: _editorState),
          Expanded(
            // Row is STATIC — never rebuilt on play toggle.
            // Each panel hides itself individually so GameWidget is never remounted.
            child: Row(
              children: [
                _hiddenInPlay(LeftPanel(editorState: _editorState)),
                _hiddenInPlay(Container(width: 1, color: AppColors.borderColor)),
                Expanded(child: CenterCanvas(editorState: _editorState)),
                _hiddenInPlay(Container(width: 1, color: AppColors.borderColor)),
                _hiddenInPlay(RightPanel(editorState: _editorState)),
              ],
            ),
          ),
          _hiddenInPlay(StatusBar(editorState: _editorState)),
        ],
      ),
    );
  }
}
