import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'toolbar.dart';
import 'status_bar.dart';
import '../panels/left_panel.dart';
import '../panels/center_canvas.dart';
import '../panels/right_panel.dart';
import '../../theme/app_theme.dart';
import '../../editor/editor_state.dart';
import '../../models/map_data.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(mapData: MapData());
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _editorState.dispose();
    super.dispose();
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
