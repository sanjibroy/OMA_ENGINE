import 'package:flutter/material.dart';
import '../../editor/editor_state.dart';
import '../../models/map_data.dart';
import '../../theme/app_theme.dart';

class StatusBar extends StatelessWidget {
  final EditorState editorState;

  const StatusBar({super.key, required this.editorState});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.panelBg,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          _statusItem(Icons.layers, 'Top-down'),
          _sep(),
          _statusItem(
            Icons.grid_4x4,
            '${editorState.mapData.width} × ${editorState.mapData.height} tiles',
          ),
          _sep(),
          ValueListenableBuilder<(int, int)?>(
            valueListenable: editorState.hoverTile,
            builder: (_, tile, __) => _statusItem(
              Icons.mouse,
              tile != null ? 'Tile: (${tile.$1}, ${tile.$2})' : 'Tile: —',
            ),
          ),
          _sep(),
          ValueListenableBuilder(
            valueListenable: editorState.selectedTile,
            builder: (_, tile, __) => _statusItem(
              Icons.brush,
              'Brush: ${tile.label}',
              color: tile.color,
            ),
          ),
          const Spacer(),
          _statusItem(Icons.circle, 'Ready', color: AppColors.success),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String text, {Color? color}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color ?? AppColors.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: color ?? AppColors.textMuted),
          ),
        ],
      );

  Widget _sep() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: TextStyle(color: AppColors.borderColor)),
      );
}
