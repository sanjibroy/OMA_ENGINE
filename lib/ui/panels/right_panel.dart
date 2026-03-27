import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../editor/editor_state.dart';
import '../../models/game_object.dart';
import '../../models/game_effect.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../models/item_def.dart';
import '../../theme/app_theme.dart';
import '../dialogs/rule_editor_dialog.dart';
import '../dialogs/animations_dialog.dart';
import 'package:file_picker/file_picker.dart';
import '../dialogs/rule_editor_v2.dart';

class RightPanel extends StatefulWidget {
  final EditorState editorState;

  const RightPanel({super.key, required this.editorState});

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.panelBg,
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['Properties',  'Effects', 'Code'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppColors.accent : Colors.transparent,
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
                    color: selected
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

  Widget _buildContent() {
    return switch (_selectedTab) {
      0 => _PropertiesTab(editorState: widget.editorState),
      //1 => _RulesTab(editorState: widget.editorState),
      1 => _EffectsTab(editorState: widget.editorState),
      2 => const _CodeTab(),
      _ => const SizedBox(),
    };
  }
}

// ─── Properties Tab ───────────────────────────────────────────────────────────

class _PropertiesTab extends StatefulWidget {
  final EditorState editorState;
  const _PropertiesTab({required this.editorState});

  @override
  State<_PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends State<_PropertiesTab> {
  late TextEditingController _wCtrl;
  late TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    final map = widget.editorState.mapData;
    _wCtrl = TextEditingController(text: '${map.width}');
    _hCtrl = TextEditingController(text: '${map.height}');
    widget.editorState.mapChanged.addListener(_onMapChanged);
    widget.editorState.projectChanged.addListener(_rebuild);
    widget.editorState.selectedObjectType.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.editorState.mapChanged.removeListener(_onMapChanged);
    widget.editorState.projectChanged.removeListener(_rebuild);
    widget.editorState.selectedObjectType.removeListener(_rebuild);
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  void _onMapChanged() {
    final map = widget.editorState.mapData;
    _wCtrl.text = '${map.width}';
    _hCtrl.text = '${map.height}';
    setState(() {});
  }

  void _rebuild() => setState(() {});

  void _applyResize() {
    final w = int.tryParse(_wCtrl.text) ?? 0;
    final h = int.tryParse(_hCtrl.text) ?? 0;
    if (w < 1 || w > 200 || h < 1 || h > 200) return;
    final map = widget.editorState.mapData;
    if (w == map.width && h == map.height) return;
    widget.editorState.pushUndo();
    map.resize(w, h);
    widget.editorState.notifyMapChanged();
  }

  void _setHudAtBottom(bool val) {
    widget.editorState.project.hudAtBottom = val;
    widget.editorState.notifyProjectChanged();
  }

  void _setPlayerSpeed(String val) {
    final v = double.tryParse(val);
    if (v != null && v > 0) {
      widget.editorState.project.playerSpeed = v;
      widget.editorState.notifyProjectChanged();
    }
  }

  void _setPlayerHealth(String val) {
    final v = int.tryParse(val);
    if (v != null && v > 0) {
      widget.editorState.project.playerHealth = v;
      widget.editorState.notifyProjectChanged();
    }
  }

  void _setPlayerLives(String val) {
    final v = int.tryParse(val);
    if (v != null && v > 0) {
      widget.editorState.project.playerLives = v;
      widget.editorState.notifyProjectChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.editorState.mapData;
    final project = widget.editorState.project;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Map properties ───────────────────────────────
        _sectionLabel('MAP'),
        const SizedBox(height: 8),
        _propertyRow('Name', map.name),
        _propertyRow('Tile Size', '${map.tileSize} px'),
        _propertyRow('Total Tiles', '${map.width * map.height}'),
        const SizedBox(height: 8),
        _resizeRow(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Y-Sort',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            GestureDetector(
              onTap: () {
                setState(() => map.ySortEnabled = !map.ySortEnabled);
                widget.editorState.notifyMapChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: map.ySortEnabled
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: map.ySortEnabled
                        ? AppColors.accent
                        : AppColors.borderColor,
                  ),
                ),
                child: Text(
                  map.ySortEnabled ? 'On' : 'Off',
                  style: TextStyle(
                    color: map.ySortEnabled
                        ? AppColors.accent
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),

        _divider(),

        // ── Project settings ─────────────────────────────
        _sectionLabel('PROJECT SETTINGS'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('HUD Position',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Row(
              children: [
                _posBtn(
                  icon: Icons.keyboard_arrow_up,
                  label: 'Top',
                  active: !project.hudAtBottom,
                  onTap: () => _setHudAtBottom(false),
                ),
                const SizedBox(width: 4),
                _posBtn(
                  icon: Icons.keyboard_arrow_down,
                  label: 'Bottom',
                  active: project.hudAtBottom,
                  onTap: () => _setHudAtBottom(true),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        _playerSection(project),

        // ── Context-sensitive bottom ──────────────────────
        ValueListenableBuilder<EditorTool>(
          valueListenable: widget.editorState.activeTool,
          builder: (_, tool, __) {
            if (tool == EditorTool.object) {
              return ValueListenableBuilder<GameObject?>(
                valueListenable: widget.editorState.selectedObject,
                builder: (_, obj, __) {
                  final type = obj?.type ?? widget.editorState.selectedObjectType.value;
                  final vi = obj?.variantIndex ??
                      (widget.editorState.selectedVariantIndex[widget.editorState.selectedObjectType.value] ?? 0);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _divider(),
                      _SpriteAnimEditor(
                        key: ValueKey('${type.name}:$vi'),
                        editorState: widget.editorState,
                        type: type,
                        variantIndex: vi,
                        onChanged: () => setState(() {}),
                      ),
                      if (obj != null) ...[
                        _divider(),
                        _ObjectPropsForm(
                          key: ValueKey(obj.id),
                          obj: obj,
                          editorState: widget.editorState,
                        ),
                      ],
                    ],
                  );
                },
              );
            }

            // Tile / Collision tool — show hovered tile info
            return ValueListenableBuilder<(int, int)?>(
              valueListenable: widget.editorState.hoverTile,
              builder: (_, hover, __) {
                return Column(
                  children: [
                    _divider(),
                    _TileInfoSection(
                      editorState: widget.editorState,
                      hover: hover,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _playerSection(GameProject project) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('PLAYER'),
          const SizedBox(height: 10),
          _inputRow('Speed', project.playerSpeed.toString(),
              isDecimal: true, onChanged: _setPlayerSpeed),
          const SizedBox(height: 6),
          _inputRow('Health', project.playerHealth.toString(),
              onChanged: _setPlayerHealth),
          const SizedBox(height: 6),
          _inputRow('Lives', project.playerLives.toString(),
              onChanged: _setPlayerLives),
        ],
      );

  Widget _inputRow(String label, String value,
      {bool isDecimal = false, required void Function(String) onChanged}) {
    final ctrl = TextEditingController(text: value);
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: ctrl,
              keyboardType: isDecimal
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.number,
              inputFormatters: isDecimal
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              onSubmitted: onChanged,
              onEditingComplete: () => onChanged(ctrl.text),
            ),
          ),
        ),
      ],
    );
  }

  Widget _posBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active
                  ? AppColors.accent.withOpacity(0.6)
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: active
                      ? AppColors.accent
                      : AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      color: active
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ],
          ),
        ),
      );

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.borderColor.withOpacity(0.5),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _propertyRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      );

  Widget _resizeRow() => Row(
        children: [
          const Text('Size',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          SizedBox(
            width: 46,
            height: 26,
            child: TextField(
              controller: _wCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                hintText: 'W',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                filled: true,
                fillColor: AppColors.surfaceBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              onSubmitted: (_) => _applyResize(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('×', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          SizedBox(
            width: 46,
            height: 26,
            child: TextField(
              controller: _hCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                hintText: 'H',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                filled: true,
                fillColor: AppColors.surfaceBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              onSubmitted: (_) => _applyResize(),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _applyResize,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: const Text('Apply',
                  style: TextStyle(color: AppColors.accent, fontSize: 11)),
            ),
          ),
        ],
      );
}

// ─── Sprite & Animation Editor (shown in Properties tab when object tool active, no instance selected) ───

class _SpriteAnimEditor extends StatefulWidget {
  final EditorState editorState;
  final GameObjectType type;
  final int variantIndex;
  final VoidCallback onChanged;

  const _SpriteAnimEditor({
    super.key,
    required this.editorState,
    required this.type,
    required this.variantIndex,
    required this.onChanged,
  });

  @override
  State<_SpriteAnimEditor> createState() => _SpriteAnimEditorState();
}

class _SpriteAnimEditorState extends State<_SpriteAnimEditor> {
  EditorState get _es => widget.editorState;
  GameObjectType get _type => widget.type;
  int get _vi => widget.variantIndex;

  Future<void> _importOrReplaceSprite() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final count = _es.spriteCache.objVariantCount(_type);
    bool ok;
    if (count <= _vi) {
      final idx = await _es.spriteCache.addObjectVariant(_type, path);
      ok = idx != null;
    } else {
      ok = await _es.spriteCache.replaceObjectVariant(_type, _vi, path);
    }
    if (ok) {
      // Sync variant paths in mapData
      final paths = _es.spriteCache.objVariantPathsList(_type);
      _es.mapData.objectVariantPaths[_type.name] = List.from(paths);
      if (paths.isNotEmpty) {
        _es.mapData.spritePaths[_type.name] = paths[0];
      }
      _es.notifyMapChanged();
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> _openAnimations() async {
    await AnimationsDialog.show(
      context,
      type: _type,
      variantIndex: _vi,
      spriteCache: _es.spriteCache,
      mapData: _es.mapData,
      onChanged: () => setState(() {}),
    );
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cache = _es.spriteCache;
    final variantCount = cache.objVariantCount(_type);
    final hasSprite = variantCount > _vi;
    final spritePath = hasSprite ? cache.objVariantPathsList(_type)[_vi] : null;
    final isAnim = cache.isAnimated(_type, _vi);
    final animCount = cache.animNames(_type, _vi).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: _type.color, shape: BoxShape.circle),
              child: Center(
                child: Icon(_type.icon, color: Colors.white, size: 11),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_type.label} — Variant ${_vi + 1}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Sprite section
        const Text('SPRITE',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Row(
          children: [
            // Thumbnail
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: spritePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.file(File(spritePath), fit: BoxFit.cover),
                    )
                  : Center(
                      child: Icon(_type.icon, color: _type.color, size: 28),
                    ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _importOrReplaceSprite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_outlined, size: 13, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Text(
                      hasSprite ? 'Replace' : 'Import Sprite',
                      style: const TextStyle(color: AppColors.accent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Animations section
        const Text('ANIMATIONS',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openAnimations,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              children: [
                Icon(Icons.movie_outlined,
                    size: 13,
                    color: isAnim ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  isAnim
                      ? '$animCount animation${animCount == 1 ? '' : 's'}'
                      : 'Edit Animations\u2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: isAnim ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
              ],
            ),
          ),
        ),

        // Use Animation toggle — only when animation frames exist
        if (isAnim) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Use Animation',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              GestureDetector(
                onTap: () {
                  final cur = _es.mapData.getVariantUseAnimation(_type, _vi);
                  _es.mapData.setVariantUseAnimation(_type, _vi, !cur);
                  _es.notifyMapChanged();
                  setState(() {});
                  widget.onChanged();
                },
                child: Builder(builder: (ctx) {
                  final on = _es.mapData.getVariantUseAnimation(_type, _vi);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: on ? AppColors.accent : AppColors.borderColor,
                      ),
                    ),
                    child: Text(
                      on ? 'On' : 'Off',
                      style: TextStyle(
                        color: on ? AppColors.accent : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Object Properties Form ────────────────────────────────────────────────────

class _ObjectPropsForm extends StatefulWidget {
  final GameObject obj;
  final EditorState editorState;
  const _ObjectPropsForm({super.key, required this.obj, required this.editorState});
  @override
  State<_ObjectPropsForm> createState() => _ObjectPropsFormState();
}

class _ObjectPropsFormState extends State<_ObjectPropsForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tagCtrl;

  bool _transformExpanded = true;
  bool _fxExpanded = true;
  bool _propsExpanded = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.obj.name);
    _tagCtrl  = TextEditingController(text: widget.obj.tag);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _setName(String v) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return;
    setState(() => widget.obj.name = trimmed);
    widget.editorState.notifyMapChanged();
  }

  void _setTag(String v) {
    setState(() => widget.obj.tag = v.trim());
    widget.editorState.notifyMapChanged();
  }

  void _set(String key, dynamic value) {
    setState(() => widget.obj.properties[key] = value);
    widget.editorState.notifyMapChanged();
  }

  void _setFlipH(bool v) {
    setState(() => widget.obj.flipH = v);
    widget.editorState.notifyMapChanged();
  }

  void _setFlipV(bool v) {
    setState(() => widget.obj.flipV = v);
    widget.editorState.notifyMapChanged();
  }

  void _setScale(double v) {
    setState(() => widget.obj.scale = v.clamp(0.25, 4.0));
    widget.editorState.notifyMapChanged();
  }

  void _setRotation(double v) {
    setState(() => widget.obj.rotation = v % 360);
    widget.editorState.notifyMapChanged();
  }

  void _setAlpha(double v) {
    setState(() => widget.obj.alpha = v.clamp(0.0, 1.0));
    widget.editorState.notifyMapChanged();
  }

  void _setZOrder(int v) {
    setState(() => widget.obj.zOrder = v.clamp(-9, 9));
    widget.editorState.notifyMapChanged();
  }

  void _setFloatAmplitude(double v) {
    setState(() => widget.obj.floatAmplitude = v.clamp(1.0, 32.0));
    widget.editorState.notifyMapChanged();
  }

  void _setFloatSpeed(double v) {
    setState(() => widget.obj.floatSpeed = v.clamp(0.1, 5.0));
    widget.editorState.notifyMapChanged();
  }

  void _setProjectileAngle(double v) {
    setState(() => widget.obj.projectileAngle = v % 360);
    widget.editorState.notifyMapChanged();
  }

  void _setProjectileSpeed(double v) {
    setState(() => widget.obj.projectileSpeed = v.clamp(0.5, 20.0));
    widget.editorState.notifyMapChanged();
  }

  void _setProjectileRange(double v) {
    setState(() => widget.obj.projectileRange = v.clamp(1.0, 20.0));
    widget.editorState.notifyMapChanged();
  }

  void _setProjectileArc(double v) {
    setState(() => widget.obj.projectileArc = v.clamp(0.0, 10.0));
    widget.editorState.notifyMapChanged();
  }

  Widget _buildProjectilePreviewButton(GameObject obj) {
    final game = widget.editorState.game;
    final isPreviewing = game.isProjectilePreviewing(obj.id);
    return GestureDetector(
      onTap: () {
        if (isPreviewing) {
          game.stopProjectilePreview(obj.id);
        } else {
          game.startProjectilePreview(obj.id);
        }
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPreviewing
              ? const Color(0xFFEF4444).withOpacity(0.18)
              : const Color(0xFF6C63FF).withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPreviewing
                ? const Color(0xFFEF4444).withOpacity(0.5)
                : const Color(0xFF6C63FF).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPreviewing ? Icons.stop : Icons.play_arrow,
              size: 14,
              color: isPreviewing ? const Color(0xFFEF4444) : const Color(0xFF6C63FF),
            ),
            const SizedBox(width: 6),
            Text(
              isPreviewing ? 'Stop Preview' : 'Preview Path',
              style: TextStyle(
                fontSize: 11,
                color: isPreviewing ? const Color(0xFFEF4444) : const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDashAngle(double v) {
    setState(() => widget.obj.dashAngle = v % 360);
    widget.editorState.notifyMapChanged();
  }

  void _setDashDistance(double v) {
    setState(() => widget.obj.dashDistance = v.clamp(0.5, 10.0));
    widget.editorState.notifyMapChanged();
  }

  void _setDashSpeed(double v) {
    setState(() => widget.obj.dashSpeed = v.clamp(1.0, 20.0));
    widget.editorState.notifyMapChanged();
  }

  void _setDashInterval(double v) {
    setState(() => widget.obj.dashInterval = v.clamp(0.5, 10.0));
    widget.editorState.notifyMapChanged();
  }

  void _setHidden(bool v) {
    setState(() => widget.obj.hidden = v);
    widget.editorState.notifyMapChanged();
  }

  void _resetTransform() {
    setState(() {
      widget.obj.flipH = false;
      widget.obj.flipV = false;
      widget.obj.scale = 1.0;
      widget.obj.rotation = 0.0;
    });
    widget.editorState.notifyMapChanged();
  }

  @override
  Widget build(BuildContext context) {
    final obj = widget.obj;
    final es = widget.editorState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Object header
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: obj.type.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(obj.type.symbol,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Text(obj.type.label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Tooltip(
              message: obj.hidden ? 'Show object' : 'Hide object',
              child: GestureDetector(
                onTap: () => _setHidden(!obj.hidden),
                child: Icon(
                  obj.hidden ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: obj.hidden ? AppColors.textMuted : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Editable name
        _label('NAME'),
        const SizedBox(height: 4),
        _stringField(_nameCtrl, hint: obj.type.label, onChanged: _setName, onSubmitted: _setName),
        const SizedBox(height: 6),
        // Tag
        _label('TAG'),
        const SizedBox(height: 4),
        _stringField(_tagCtrl, hint: 'e.g. breakable', onChanged: _setTag),
        const SizedBox(height: 8),
        _propRow('Tile X', '${obj.tileX}'),
        _propRow('Tile Y', '${obj.tileY}'),
        const SizedBox(height: 10),

        // ── Transform ──────────────────────────────────
        _sectionHeader(
          'TRANSFORM',
          _transformExpanded,
          () => setState(() => _transformExpanded = !_transformExpanded),
          trailing: (obj.flipH || obj.flipV || obj.scale != 1.0 || obj.rotation != 0.0)
              ? GestureDetector(
                  onTap: _resetTransform,
                  child: const Text('Reset',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                )
              : null,
        ),
        if (_transformExpanded) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              _flipBtn(
                icon: Icons.flip,
                label: 'H',
                tooltip: 'Flip Horizontal',
                active: obj.flipH,
                onTap: () => _setFlipH(!obj.flipH),
              ),
              const SizedBox(width: 6),
              _flipBtn(
                icon: Icons.flip,
                label: 'V',
                tooltip: 'Flip Vertical',
                active: obj.flipV,
                rotate: true,
                onTap: () => _setFlipV(!obj.flipV),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _transformRow(
            label: 'Scale',
            display: '${obj.scale.toStringAsFixed(2)}×',
            onDecrement: () => _setScale(obj.scale - 0.25),
            onIncrement: () => _setScale(obj.scale + 0.25),
          ),
          const SizedBox(height: 4),
          _transformRow(
            label: 'Rotate',
            display: '${obj.rotation.toStringAsFixed(0)}°',
            onDecrement: () => _setRotation(obj.rotation - 45),
            onIncrement: () => _setRotation(obj.rotation + 45),
          ),
          const SizedBox(height: 4),
          _transformRow(
            label: 'Alpha',
            display: '${(obj.alpha * 100).round()}%',
            onDecrement: () => _setAlpha(obj.alpha - 0.1),
            onIncrement: () => _setAlpha(obj.alpha + 0.1),
          ),
          const SizedBox(height: 4),
          _transformRow(
            label: 'Z-Order',
            display: '${obj.zOrder}',
            onDecrement: () => _setZOrder(obj.zOrder - 1),
            onIncrement: () => _setZOrder(obj.zOrder + 1),
          ),
          const SizedBox(height: 4),
        ],

        // ── FX ─────────────────────────────────────────
        _sectionHeader('FX', _fxExpanded,
            () => setState(() => _fxExpanded = !_fxExpanded)),
        if (_fxExpanded) ...[
          const SizedBox(height: 4),
          // Float
          _fxToggle('Float', obj.floatEnabled, () {
            setState(() => obj.floatEnabled = !obj.floatEnabled);
            widget.editorState.notifyMapChanged();
          }),
          if (obj.floatEnabled) ...[
            const SizedBox(height: 4),
            _transformRow(
              label: 'Height',
              display: '${obj.floatAmplitude.toStringAsFixed(0)}px',
              onDecrement: () => _setFloatAmplitude(obj.floatAmplitude - 1),
              onIncrement: () => _setFloatAmplitude(obj.floatAmplitude + 1),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Speed',
              display: '${obj.floatSpeed.toStringAsFixed(1)}×',
              onDecrement: () => _setFloatSpeed(obj.floatSpeed - 0.1),
              onIncrement: () => _setFloatSpeed(obj.floatSpeed + 0.1),
            ),
          ],
          const SizedBox(height: 6),
          // Projectile
          _fxToggle('Projectile', obj.projectileEnabled, () {
            setState(() => obj.projectileEnabled = !obj.projectileEnabled);
            widget.editorState.notifyMapChanged();
          }),
          if (obj.projectileEnabled) ...[
            const SizedBox(height: 4),
            _checkboxRow('Loop', obj.projectileLoop, () {
              setState(() => obj.projectileLoop = !obj.projectileLoop);
              widget.editorState.notifyMapChanged();
            }),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Angle',
              display: '${obj.projectileAngle.toStringAsFixed(0)}°',
              onDecrement: () => _setProjectileAngle(obj.projectileAngle - 45),
              onIncrement: () => _setProjectileAngle(obj.projectileAngle + 45),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Speed',
              display: '${obj.projectileSpeed.toStringAsFixed(1)} t/s',
              onDecrement: () => _setProjectileSpeed(obj.projectileSpeed - 0.5),
              onIncrement: () => _setProjectileSpeed(obj.projectileSpeed + 0.5),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Range',
              display: '${obj.projectileRange.toStringAsFixed(0)} t',
              onDecrement: () => _setProjectileRange(obj.projectileRange - 1),
              onIncrement: () => _setProjectileRange(obj.projectileRange + 1),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Height',
              display: '${obj.projectileArc.toStringAsFixed(1)} t',
              onDecrement: () => _setProjectileArc(obj.projectileArc - 0.5),
              onIncrement: () => _setProjectileArc(obj.projectileArc + 0.5),
            ),
            const SizedBox(height: 6),
            _buildProjectilePreviewButton(obj),
          ],
          const SizedBox(height: 6),
          // Dash
          _fxToggle('Dash', obj.dashEnabled, () {
            setState(() => obj.dashEnabled = !obj.dashEnabled);
            widget.editorState.notifyMapChanged();
          }),
          if (obj.dashEnabled) ...[
            const SizedBox(height: 4),
            _transformRow(
              label: 'Angle',
              display: '${obj.dashAngle.toStringAsFixed(0)}°',
              onDecrement: () => _setDashAngle(obj.dashAngle - 45),
              onIncrement: () => _setDashAngle(obj.dashAngle + 45),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Dist',
              display: '${obj.dashDistance.toStringAsFixed(1)} t',
              onDecrement: () => _setDashDistance(obj.dashDistance - 0.5),
              onIncrement: () => _setDashDistance(obj.dashDistance + 0.5),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Speed',
              display: '${obj.dashSpeed.toStringAsFixed(1)} t/s',
              onDecrement: () => _setDashSpeed(obj.dashSpeed - 1),
              onIncrement: () => _setDashSpeed(obj.dashSpeed + 1),
            ),
            const SizedBox(height: 4),
            _transformRow(
              label: 'Pause',
              display: '${obj.dashInterval.toStringAsFixed(1)}s',
              onDecrement: () => _setDashInterval(obj.dashInterval - 0.5),
              onIncrement: () => _setDashInterval(obj.dashInterval + 0.5),
            ),
          ],
          const SizedBox(height: 4),
        ],

        // ── Properties ─────────────────────────────────
        _sectionHeader(
          'PROPERTIES',
          _propsExpanded,
          () => setState(() => _propsExpanded = !_propsExpanded),
        ),
        if (_propsExpanded) ..._buildTypeFields(obj, es),
      ],
    );
  }

  List<Widget> _buildTypeFields(GameObject obj, EditorState es) {
    switch (obj.type) {
      case GameObjectType.enemy:
        return [
          _numField('Health', obj.properties['health'] ?? 3,
              onChanged: (v) => _set('health', v)),
          _numField('Speed', obj.properties['speed'] ?? 2.0,
              isDecimal: true,
              onChanged: (v) => _set('speed', v)),
          _numField('Damage', obj.properties['damage'] ?? 1,
              onChanged: (v) => _set('damage', v)),
          _numField('Patrol Range', obj.properties['patrolRange'] ?? 3,
              onChanged: (v) => _set('patrolRange', v)),
          const SizedBox(height: 10),
          ..._colliderSection(obj, es, defaultR: 0.38),
        ];
      case GameObjectType.npc:
        return [
          _textareaField('Dialog',
              obj.properties['dialog'] as String? ?? 'Hello!',
              onChanged: (v) => _set('dialog', v)),
          const SizedBox(height: 10),
          ..._colliderSection(obj, es, defaultR: 0.38),
        ];
      case GameObjectType.coin:
        return [
          _numField('Value', obj.properties['value'] ?? 1,
              onChanged: (v) => _set('value', v))
        ];
      case GameObjectType.chest:
        return [
          _numField('Value', obj.properties['value'] ?? 10,
              onChanged: (v) => _set('value', v))
        ];
      case GameObjectType.door:
        final maps = es.project.maps;
        final currentTarget =
            obj.properties['targetMapId'] as String? ?? '';
        return [
          _label('Target Map'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: maps.any((m) => m.id == currentTarget)
                ? currentTarget
                : null,
            dropdownColor: AppColors.surfaceBg,
            hint: const Text('None (same map)',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(),
            items: maps
                .map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => _set('targetMapId', v ?? ''),
          ),
          const SizedBox(height: 6),
          _numField('Spawn X', obj.properties['targetX'] ?? 0,
              onChanged: (v) => _set('targetX', v)),
          _numField('Spawn Y', obj.properties['targetY'] ?? 0,
              onChanged: (v) => _set('targetY', v)),
        ];
      case GameObjectType.waterBody:
        final mode = obj.properties['waterMode'] as String? ?? 'wade';
        final flow = obj.properties['flowDirection'] as String? ?? 'none';
        final animStyle = obj.properties['animStyle'] as String? ?? 'ripple';
        final color = obj.properties['waterColor'] as String? ?? 'blue';
        final canFish = obj.properties['canFish'] as bool? ?? false;
        final damaging = obj.properties['damaging'] as bool? ?? false;
        final opacity = (obj.properties['opacity'] as num?)?.toDouble() ?? 0.6;
        final flowStr = (obj.properties['flowStrength'] as num?)?.toDouble() ?? 1.0;
        final dps = (obj.properties['damagePerSecond'] as num?)?.toDouble() ?? 1.0;
        final fishDensity = obj.properties['fishDensity'] as int? ?? 3;
        return [
          _label('INTERACTION'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: mode,
            dropdownColor: AppColors.surfaceBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(),
            items: const [
              DropdownMenuItem(value: 'block', child: Text('Block (solid wall)')),
              DropdownMenuItem(value: 'wade',  child: Text('Wade (50% speed)')),
              DropdownMenuItem(value: 'swim',  child: Text('Swim (70% speed)')),
              DropdownMenuItem(value: 'boat',  child: Text('Boat (120% speed)')),
            ],
            onChanged: (v) => _set('waterMode', v ?? 'wade'),
          ),
          const SizedBox(height: 10),
          _label('FLOW'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: flow,
            dropdownColor: AppColors.surfaceBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('No flow')),
              DropdownMenuItem(value: 'N',    child: Text('North ↑')),
              DropdownMenuItem(value: 'S',    child: Text('South ↓')),
              DropdownMenuItem(value: 'E',    child: Text('East →')),
              DropdownMenuItem(value: 'W',    child: Text('West ←')),
            ],
            onChanged: (v) => _set('flowDirection', v ?? 'none'),
          ),
          if (flow != 'none') ...[
            const SizedBox(height: 6),
            _numField('Strength', flowStr, isDecimal: true,
                onChanged: (v) => _set('flowStrength', v)),
          ],
          const SizedBox(height: 10),
          _label('VISUAL'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: animStyle,
            dropdownColor: AppColors.surfaceBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(),
            items: const [
              DropdownMenuItem(value: 'still',  child: Text('Still')),
              DropdownMenuItem(value: 'ripple', child: Text('Ripple')),
              DropdownMenuItem(value: 'flow',   child: Text('Flow')),
              DropdownMenuItem(value: 'waves',  child: Text('Waves')),
            ],
            onChanged: (v) => _set('animStyle', v ?? 'ripple'),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: color,
            dropdownColor: AppColors.surfaceBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(),
            items: const [
              DropdownMenuItem(value: 'blue',  child: Text('Blue (ocean/lake)')),
              DropdownMenuItem(value: 'green', child: Text('Green (swamp)')),
              DropdownMenuItem(value: 'brown', child: Text('Brown (muddy)')),
              DropdownMenuItem(value: 'red',   child: Text('Red (lava/blood)')),
            ],
            onChanged: (v) => _set('waterColor', v ?? 'blue'),
          ),
          const SizedBox(height: 6),
          _transformRow(
            label: 'Opacity',
            display: '${(opacity * 100).round()}%',
            onDecrement: () => _set('opacity', (opacity - 0.05).clamp(0.1, 1.0)),
            onIncrement: () => _set('opacity', (opacity + 0.05).clamp(0.1, 1.0)),
          ),
          const SizedBox(height: 10),
          _label('FISHING'),
          const SizedBox(height: 4),
          _checkboxRow('Can fish here', canFish, () => _set('canFish', !canFish)),
          if (canFish) ...[
            const SizedBox(height: 6),
            _numField('Fish density', fishDensity, onChanged: (v) => _set('fishDensity', v)),
          ],
          const SizedBox(height: 10),
          _label('HAZARD'),
          const SizedBox(height: 4),
          _checkboxRow('Damages player', damaging, () => _set('damaging', !damaging)),
          if (damaging) ...[
            const SizedBox(height: 6),
            _numField('Damage/sec', dps, isDecimal: true,
                onChanged: (v) => _set('damagePerSecond', v)),
          ],
        ];
      case GameObjectType.gem:
        return [
          _numField('Value', obj.properties['value'] ?? 1,
              onChanged: (v) => _set('value', v)),
        ];
      case GameObjectType.collectible:
        return [
          _numField('Value', obj.properties['value'] ?? 1,
              onChanged: (v) => _set('value', v)),
        ];
      case GameObjectType.prop:
        final solid = obj.properties['solid'] as bool? ?? true;
        final shape = obj.properties['blockShape'] as String? ?? 'rect';
        final bw  = (obj.properties['blockW']  as num?)?.toDouble() ?? 1.0;
        final bh  = (obj.properties['blockH']  as num?)?.toDouble() ?? 1.0;
        final br  = (obj.properties['blockR']  as num?)?.toDouble() ?? 0.5;
        final brx = (obj.properties['blockRX'] as num?)?.toDouble() ?? 0.5;
        final bry = (obj.properties['blockRY'] as num?)?.toDouble() ?? 0.5;
        return [
          _checkboxRow('Solid (blocks player)', solid,
              () => _set('solid', !solid)),
          if (solid) ...[
            const SizedBox(height: 8),
            _label('COLLISION SHAPE'),
            const SizedBox(height: 6),
            // Shape selector (2-row Wrap so Custom fits without overflow)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _shapeBtn('Rect',    Icons.crop_square,       shape == 'rect',
                    () => _set('blockShape', 'rect')),
                _shapeBtn('Circle',  Icons.circle_outlined,   shape == 'circle',
                    () => _set('blockShape', 'circle')),
                _shapeBtn('Ellipse', Icons.circle_outlined,   shape == 'ellipse',
                    () => _set('blockShape', 'ellipse')),
                _shapeBtn('Custom',  Icons.polyline_outlined,  shape == 'custom',
                    () => _set('blockShape', 'custom')),
              ],
            ),
            const SizedBox(height: 8),
            // Dimension sliders / hint
            if (shape == 'rect') ...[
              _blockSlider('Width',  bw,  0.1, 6.0, (v) => _set('blockW', v)),
              _blockSlider('Height', bh,  0.1, 6.0, (v) => _set('blockH', v)),
            ] else if (shape == 'circle') ...[
              _blockSlider('Radius', br,  0.1, 4.0, (v) => _set('blockR', v)),
            ] else if (shape == 'ellipse') ...[
              _blockSlider('X Radius', brx, 0.1, 6.0, (v) => _set('blockRX', v)),
              _blockSlider('Y Radius', bry, 0.1, 6.0, (v) => _set('blockRY', v)),
            ] else ...[
              // Custom — hint to use the sort region editor below
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Draw polygon via "Edit Sort Region" — same shape used for collision.',
                  style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.8), fontSize: 10),
                ),
              ),
            ],
          ],
          // Sort region controls
          const SizedBox(height: 10),
          _label('DEPTH SORT'),
          const SizedBox(height: 6),
          _blockSlider('Sort Anchor', obj.sortAnchorY, -2.0, 2.0,
              (v) { setState(() => obj.sortAnchorY = v); es.notifyMapChanged(); }),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    es.sortEditMode.value = !es.sortEditMode.value;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: es.sortEditMode.value
                          ? const Color(0xFFFFB300).withOpacity(0.15)
                          : AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: es.sortEditMode.value
                            ? const Color(0xFFFFB300).withOpacity(0.8)
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.polyline_outlined, size: 12,
                            color: es.sortEditMode.value
                                ? const Color(0xFFFFB300)
                                : AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text(
                          es.sortEditMode.value ? 'Done Editing' : 'Edit Sort Region',
                          style: TextStyle(
                            fontSize: 11,
                            color: es.sortEditMode.value
                                ? const Color(0xFFFFB300)
                                : AppColors.textMuted,
                            fontWeight: es.sortEditMode.value
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() => obj.properties['sortPoints'] = <List<double>>[]);
                  es.notifyMapChanged();
                },
                child: Tooltip(
                  message: 'Clear sort polygon',
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: const Icon(Icons.clear, size: 12, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ];
      case GameObjectType.hazard:
        final knockback = obj.properties['knockback'] as bool? ?? false;
        return [
          _numField('Damage', obj.properties['damage'] ?? 1.0,
              isDecimal: true, onChanged: (v) => _set('damage', v)),
          _checkboxRow('Knockback', knockback,
              () => _set('knockback', !knockback)),
        ];
      case GameObjectType.checkpoint:
        return [];
      case GameObjectType.playerSpawn:
        return _colliderSection(obj, es, defaultR: 0.35);
      case GameObjectType.weaponPickup:
        final items = es.project.items;
        final currentId = obj.properties['itemId'] as String? ?? '';
        return [
          _labelRow('Item'),
          const SizedBox(height: 4),
          items.isEmpty
              ? const Text(
                  'No items defined. Open Items & Weapons from the toolbar.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: items.any((i) => i.id == currentId)
                          ? currentId
                          : null,
                      isExpanded: true,
                      dropdownColor: AppColors.dialogBg,
                      hint: const Text('Select item…',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12),
                      items: items
                          .map((i) => DropdownMenuItem(
                                value: i.id,
                                child: Row(
                                  children: [
                                    Icon(i.category.icon,
                                        size: 13,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 6),
                                    Text(i.name,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _set('itemId', v);
                      },
                    ),
                  ),
                ),
          if (currentId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final item = items.firstWhere((i) => i.id == currentId,
                  orElse: () => ItemDef(id: '', name: ''));
              if (item.id.isEmpty) return const SizedBox();
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Category', item.category.label),
                    _infoRow('Damage', item.combatDamage.toString()),
                    _infoRow('Range', '${item.combatRange} tiles'),
                    _infoRow('Cooldown', '${item.cooldown}s'),
                    if (item.toolType != ToolType.none)
                      _infoRow('Tool', item.toolType.label),
                  ],
                ),
              );
            }),
          ],
        ];
    }
  }

  Widget _labelRow(String text) => Text(
        text,
        style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 11)),
          ],
        ),
      );

  Widget _stringField(
    TextEditingController ctrl, {
    required String hint,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: SizedBox(
          height: 30,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(hint: hint),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      );

  Widget _propRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      );

  Widget _numField(String label, dynamic value,
      {bool isDecimal = false, required void Function(dynamic) onChanged}) {
    final ctrl = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: ctrl,
                keyboardType: isDecimal
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                inputFormatters: isDecimal
                    ? [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ]
                    : [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: _inputDeco(),
                onSubmitted: (v) => isDecimal
                    ? onChanged(double.tryParse(v) ?? value)
                    : onChanged(int.tryParse(v) ?? value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textareaField(String label, String value,
      {required void Function(String) onChanged}) {
    final ctrl = TextEditingController(text: value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          decoration: _inputDeco(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700));

  Widget _sectionHeader(String title, bool expanded, VoidCallback onToggle, {Widget? trailing}) =>
      GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
              const SizedBox(width: 6),
              Expanded(
                child: Container(height: 1, color: AppColors.borderColor),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      );

  Widget _fxToggle(String name, bool enabled, VoidCallback onToggle) =>
      GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Text(name,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.borderColor)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: enabled ? AppColors.accent.withOpacity(0.18) : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: enabled ? AppColors.accent : AppColors.borderColor),
              ),
              child: Text(
                enabled ? 'ON' : 'OFF',
                style: TextStyle(
                    color: enabled ? AppColors.accent : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _checkboxRow(String label, bool checked, VoidCallback onToggle) =>
      GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: checked ? AppColors.accent : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: checked ? AppColors.accent : AppColors.borderColor,
                  width: 1.5,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _shapeBtn(String label, IconData icon, bool active, VoidCallback onTap) =>
      SizedBox(
        width: 58,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF00E5FF).withOpacity(0.15)
                  : AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? const Color(0xFF00E5FF).withOpacity(0.7)
                    : AppColors.borderColor,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13,
                    color: active ? const Color(0xFF00E5FF) : AppColors.textMuted),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: active ? const Color(0xFF00E5FF) : AppColors.textMuted,
                        fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      );

  /// Shared collider shape section for player, enemy, and NPC.
  List<Widget> _colliderSection(GameObject obj, EditorState es,
      {double defaultR = 0.38}) {
    final shape = obj.properties['blockShape'] as String? ?? 'circle';
    final br  = (obj.properties['blockR']  as num?)?.toDouble() ?? defaultR;
    final bw  = (obj.properties['blockW']  as num?)?.toDouble() ?? defaultR;
    final bh  = (obj.properties['blockH']  as num?)?.toDouble() ?? defaultR;
    final brx = (obj.properties['blockRX'] as num?)?.toDouble() ?? defaultR;
    final bry = (obj.properties['blockRY'] as num?)?.toDouble() ?? defaultR;
    return [
      _label('COLLIDER SHAPE'),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _shapeBtn('Rect',    Icons.crop_square,      shape == 'rect',
              () => _set('blockShape', 'rect')),
          _shapeBtn('Circle',  Icons.circle_outlined,   shape == 'circle',
              () => _set('blockShape', 'circle')),
          _shapeBtn('Ellipse', Icons.circle_outlined,   shape == 'ellipse',
              () => _set('blockShape', 'ellipse')),
          _shapeBtn('Custom',  Icons.polyline_outlined,  shape == 'custom',
              () => _set('blockShape', 'custom')),
        ],
      ),
      const SizedBox(height: 8),
      if (shape == 'rect') ...[
        _blockSlider('Half Width',  bw,  0.1, 2.0, (v) => _set('blockW', v)),
        _blockSlider('Half Height', bh,  0.1, 2.0, (v) => _set('blockH', v)),
      ] else if (shape == 'circle') ...[
        _blockSlider('Radius', br, 0.1, 2.0, (v) => _set('blockR', v)),
      ] else if (shape == 'ellipse') ...[
        _blockSlider('X Radius', brx, 0.1, 2.0, (v) => _set('blockRX', v)),
        _blockSlider('Y Radius', bry, 0.1, 2.0, (v) => _set('blockRY', v)),
      ] else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Draw polygon via "Edit Collider" button below.',
            style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.8), fontSize: 10),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  es.sortEditMode.value = !es.sortEditMode.value;
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: es.sortEditMode.value
                        ? const Color(0xFF00E5FF).withOpacity(0.12)
                        : AppColors.surfaceBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: es.sortEditMode.value
                          ? const Color(0xFF00E5FF).withOpacity(0.8)
                          : AppColors.borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.polyline_outlined, size: 12,
                          color: es.sortEditMode.value
                              ? const Color(0xFF00E5FF)
                              : AppColors.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        es.sortEditMode.value ? 'Done Editing' : 'Edit Collider',
                        style: TextStyle(
                          fontSize: 11,
                          color: es.sortEditMode.value
                              ? const Color(0xFF00E5FF)
                              : AppColors.textMuted,
                          fontWeight: es.sortEditMode.value
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => obj.properties['sortPoints'] = <List<double>>[]);
                es.notifyMapChanged();
              },
              child: Tooltip(
                message: 'Clear collider polygon',
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: const Icon(Icons.clear, size: 12, color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _blockSlider(String label, double value, double min, double max,
      void Function(double) onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: const Color(0xFF00E5FF),
                  inactiveTrackColor: AppColors.borderColor,
                  thumbColor: const Color(0xFF00E5FF),
                  overlayColor: const Color(0xFF00E5FF).withOpacity(0.15),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: ((max - min) / 0.1).round(),
                  onChanged: onChanged,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(value.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ),
          ],
        ),
      );

  Widget _flipBtn({
    required IconData icon,
    required String label,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
    bool rotate = false,
  }) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? AppColors.accent.withOpacity(0.6)
                    : AppColors.borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: rotate ? 1.5708 : 0, // 90° for vertical flip icon
                  child: Icon(icon,
                      size: 13,
                      color: active
                          ? AppColors.accent
                          : AppColors.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: active
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ],
            ),
          ),
        ),
      );

  Widget _transformRow({
    required String label,
    required String display,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) =>
      Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          _stepBtn(Icons.remove, onDecrement),
          const SizedBox(width: 4),
          SizedBox(
            width: 46,
            child: Text(display,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          _stepBtn(Icons.add, onIncrement),
        ],
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Icon(icon, size: 11, color: AppColors.textSecondary),
        ),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceBg,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}

// ─── Paint color palette ──────────────────────────────────────────────────────

const _kPaletteColors = [
  // Neutral
  0xFF0D0D0D, 0xFF1A1A1A, 0xFF2C2C2C, 0xFF4A4A4A, 0xFF808080, 0xFFBFBFBF,
  // Nature
  0xFF1A4A1A, 0xFF3A7D44, 0xFF6BBF6B, 0xFFB5934A, 0xFF7C4D1E, 0xFF5C3A1E,
  // Water/Sky
  0xFF0D2040, 0xFF1D6FA4, 0xFF4A9FD4, 0xFF6A3A7D, 0xFF9B5FC0, 0xFFFFE0B2,
  // Stone/Misc
  0xFF52525B, 0xFF6B7280, 0xFF9CA3AF, 0xFFCC6622, 0xFFAA3333, 0xFFFFFFFF,
];

// ─── Tile Info Section ────────────────────────────────────────────────────────

class _TileInfoSection extends StatelessWidget {
  final EditorState editorState;
  final (int, int)? hover;
  const _TileInfoSection({required this.editorState, required this.hover});

  @override
  Widget build(BuildContext context) {
    final es = editorState;
    final map = es.mapData;

    return ValueListenableBuilder<Color>(
      valueListenable: es.selectedPaintColor,
      builder: (_, selColor, __) {
        final rows = <Widget>[
          _label('PAINT COLOR'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _kPaletteColors.map((argb) {
              final c = Color(argb);
              final isSelected = selColor.value == argb;
              return GestureDetector(
                onTap: () {
                  es.selectedPaintColor.value = c;
                  es.selectedBrush.value = null; // deselect tileset brush
                },
                child: Container(
                  width: 34,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? Colors.white : const Color(0xFF2A2A2A),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ];

        if (hover != null) {
          final (tx, ty) = hover!;
          final hColor = map.getTileColor(tx, ty);
          final hColl = map.getTileCollision(tx, ty);
          final collLabel = switch (hColl) {
            1 => 'Force passable',
            2 => 'Force solid',
            _ => 'Default',
          };
          rows.addAll([
            const SizedBox(height: 14),
            _label('HOVERED TILE'),
            const SizedBox(height: 8),
            _row('Position', '($tx, $ty)'),
            _row('Color', hColor == 0 ? 'Empty' : '#${hColor.toRadixString(16).padLeft(8, '0').toUpperCase()}'),
            _row('Collision', collLabel),
          ]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ],
        ),
      );
}

// ─── Rules Tab ────────────────────────────────────────────────────────────────

class _RulesTab extends StatefulWidget {
  final EditorState editorState;
  const _RulesTab({required this.editorState});

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  List<GameRule> get _rules => widget.editorState.mapData.rules;

  @override
  void initState() {
    super.initState();
    widget.editorState.mapChanged.addListener(_onMapChanged);
  }

  @override
  void dispose() {
    widget.editorState.mapChanged.removeListener(_onMapChanged);
    super.dispose();
  }

  void _onMapChanged() => setState(() {});

  Future<void> _addRule() async {
    widget.editorState.pushUndo();
    final rule = await RuleEditorDialog.show(
      context,
      availableMaps: widget.editorState.project.maps,
      availableEffects: widget.editorState.project.effects,
      keyBindings: widget.editorState.project.keyBindings,
    );
    if (rule != null) {
      setState(() => _rules.add(rule));
    }
  }

  Future<void> _editRule(int index) async {
    widget.editorState.pushUndo();
    final rule = await RuleEditorDialog.show(
      context,
      existing: _rules[index],
      availableMaps: widget.editorState.project.maps,
      availableEffects: widget.editorState.project.effects,
      keyBindings: widget.editorState.project.keyBindings,
    );
    if (rule != null) setState(() => _rules[index] = rule);
  }

  void _deleteRule(int index) {
    widget.editorState.pushUndo();
    setState(() => _rules.removeAt(index));
  }

  void _toggleRule(int index, bool val) =>
      setState(() => _rules[index].enabled = val);

  Future<void> _copyFromMap() async {
    await _CopyRulesDialog.show(context, widget.editorState);
    setState(() {});
  }

  Future<void> _openManager() async {
    await _RulesManagerDialog.show(context, widget.editorState);
    setState(() {});
  }

  Future<void> _openManagerV2() async {
  await RulesManagerV2.show(
    context,
    rules: widget.editorState.mapData.rules,
    availableMaps: widget.editorState.project.maps,
    availableEffects: widget.editorState.project.effects,
    keyBindings: widget.editorState.project.keyBindings,
    onChanged: () => setState(() {}),
    availableAnimations: [],
  );
  setState(() {});
}

  @override
  Widget build(BuildContext context) {
    final hasOtherMaps = widget.editorState.project.maps.length > 1;
    return Column(
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              Text(
                '${_rules.length} rule${_rules.length == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const Spacer(),
              Tooltip(
                message: 'Open rules manager',
                child: GestureDetector(
                  onTap: _openManager,
                  child: const Icon(Icons.open_in_full,
                      size: 14, color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Manager V2',
                child: GestureDetector(
                  onTap: _openManagerV2,
                  child: const Icon(Icons.open_in_full,
                      size: 14, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt,
                          color: AppColors.textMuted, size: 32),
                      const SizedBox(height: 8),
                      const Text('No rules yet',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Add rules to define game logic',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _rules.length,
                  itemBuilder: (_, i) => _RuleCard(
                    rule: _rules[i],
                    onEdit: () => _editRule(i),
                    onDelete: () => _deleteRule(i),
                    onToggle: (v) => _toggleRule(i, v),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              // Add Rule
              Expanded(
                child: GestureDetector(
                  onTap: _addRule,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 15, color: AppColors.accent),
                        SizedBox(width: 5),
                        Text('Add Rule',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),

              // Copy from map (only if multiple maps exist)
              if (hasOtherMaps) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Copy rules from another map',
                  child: GestureDetector(
                    onTap: _copyFromMap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: const Icon(Icons.copy_all,
                          size: 15, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final GameRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggle;

  const _RuleCard({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: rule.enabled
              ? AppColors.surfaceBg
              : AppColors.surfaceBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.name,
                    style: TextStyle(
                      color: rule.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                _miniSwitch(rule.enabled, onToggle),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _chip('WHEN', rule.trigger.label, AppColors.accent),
            const SizedBox(height: 3),
            _chip('THEN', rule.summary, AppColors.success),
          ],
        ),
      ),
    );
  }

  Widget _chip(String tag, String text, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.only(top: 1, right: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 2),
          ),
        ],
      );

  Widget _miniSwitch(bool value, void Function(bool) onChanged) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 16,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.borderColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

// ─── Rules Manager Dialog ─────────────────────────────────────────────────────

class _RulesManagerDialog extends StatefulWidget {
  final EditorState editorState;
  const _RulesManagerDialog({required this.editorState});

  static Future<void> show(BuildContext context, EditorState es) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _RulesManagerDialog(editorState: es),
    );
  }

  @override
  State<_RulesManagerDialog> createState() => _RulesManagerDialogState();
}

class _RulesManagerDialogState extends State<_RulesManagerDialog> {
  List<GameRule> get _rules => widget.editorState.mapData.rules;

  Future<void> _addRule() async {
    widget.editorState.pushUndo();
    final rule = await RuleEditorDialog.show(
      context,
      availableMaps: widget.editorState.project.maps,
      availableEffects: widget.editorState.project.effects,
      keyBindings: widget.editorState.project.keyBindings,
    );
    if (rule != null && mounted) setState(() => _rules.add(rule));
  }

  Future<void> _editRule(int index) async {
    widget.editorState.pushUndo();
    final rule = await RuleEditorDialog.show(
      context,
      existing: _rules[index],
      availableMaps: widget.editorState.project.maps,
      availableEffects: widget.editorState.project.effects,
      keyBindings: widget.editorState.project.keyBindings,
    );
    if (rule != null && mounted) setState(() => _rules[index] = rule);
  }

  void _deleteRule(int index) {
    widget.editorState.pushUndo();
    setState(() => _rules.removeAt(index));
  }

  void _toggleRule(int index, bool val) =>
      setState(() => _rules[index].enabled = val);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 780,
        height: 560,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderColor)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            const Text('Rules Manager',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('${_rules.length} rule${_rules.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: _addRule,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 13, color: AppColors.accent),
                    SizedBox(width: 5),
                    Text('Add Rule',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close,
                  color: AppColors.textSecondary, size: 16),
            ),
          ],
        ),
      );

  Widget _buildBody() {
    if (_rules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: AppColors.textMuted, size: 40),
            SizedBox(height: 10),
            Text('No rules yet',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            SizedBox(height: 4),
            Text('Click Add Rule to get started',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildRuleRow(i),
    );
  }

  Widget _buildRuleRow(int i) {
    final rule = _rules[i];
    return Container(
      decoration: BoxDecoration(
        color: rule.enabled ? AppColors.surfaceBg : AppColors.surfaceBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _miniSwitch(rule.enabled, (v) => _toggleRule(i, v)),
            ),
            const SizedBox(width: 12),
            // Rule info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rule.name,
                      style: TextStyle(
                          color: rule.enabled
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _buildConditionsSummary(rule),
                  const SizedBox(height: 4),
                  _infoChip('THEN', rule.summary, AppColors.success),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Actions
            Column(
              children: [
                GestureDetector(
                  onTap: () => _editRule(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.dialogSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: const Text('Edit',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _deleteRule(i),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsSummary(GameRule rule) {
    if (rule.conditions.length == 1) {
      final c = rule.conditions.first;
      return _infoChip('WHEN', c.trigger.label, AppColors.accent);
    }
    // Multi-condition: build inline summary
    final parts = <String>[];
    for (int i = 0; i < rule.conditions.length; i++) {
      final c = rule.conditions[i];
      if (i > 0) {
        parts.add(rule.operators[i - 1] == ConditionOp.and ? 'AND' : 'OR');
      }
      parts.add(c.negate ? 'NOT ${c.trigger.label}' : c.trigger.label);
    }
    return _infoChip('WHEN', parts.join('  '), AppColors.accent);
  }

  Widget _infoChip(String tag, String text, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            margin: const EdgeInsets.only(top: 1, right: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
      );

  Widget _miniSwitch(bool value, void Function(bool) onChanged) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 16,
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.borderColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 150),
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(2),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

// ─── Copy Rules Dialog ────────────────────────────────────────────────────────

class _CopyRulesDialog extends StatefulWidget {
  final EditorState editorState;

  const _CopyRulesDialog({required this.editorState});

  static Future<void> show(BuildContext context, EditorState es) {
    return showDialog(
      context: context,
      builder: (_) => _CopyRulesDialog(editorState: es),
    );
  }

  @override
  State<_CopyRulesDialog> createState() => _CopyRulesDialogState();
}

class _CopyRulesDialogState extends State<_CopyRulesDialog> {
  String? _selectedMapId;
  final Set<String> _checked = {};

  EditorState get _es => widget.editorState;

  List<ProjectMap> get _otherMaps =>
      _es.project.maps.where((m) => m.id != _es.currentMapId).toList();

  List<GameRule> _rulesForMap(String mapId) {
    final json = _es.mapCache[mapId];
    if (json == null) return [];
    try {
      return (json['rules'] as List? ?? [])
          .map((r) => GameRule.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _mapInCache(String mapId) => _es.mapCache.containsKey(mapId);

  void _selectMap(String mapId) {
    if (!_mapInCache(mapId)) return;
    setState(() {
      _selectedMapId = mapId;
      _checked
        ..clear()
        ..addAll(_rulesForMap(mapId).map((r) => r.id));
    });
  }

  void _confirm() {
    if (_selectedMapId == null || _checked.isEmpty) return;
    final rules = _rulesForMap(_selectedMapId!);
    for (final r in rules.where((r) => _checked.contains(r.id))) {
      _es.mapData.rules.add(GameRule(
        name: r.name,
        conditions: r.conditions.map((c) => RuleCondition(trigger: c.trigger, negate: c.negate)).toList(),
        operators: List.from(r.operators),
        actions: r.actions
            .map((a) => RuleAction(type: a.type, params: Map.from(a.params)))
            .toList(),
        enabled: r.enabled,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRules =
        _selectedMapId != null ? _rulesForMap(_selectedMapId!) : <GameRule>[];
    final allChecked =
        selectedRules.isNotEmpty && _checked.length == selectedRules.length;

    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy_all,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('Copy Rules from Map',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // Left: map list
                  Container(
                    width: 150,
                    decoration: const BoxDecoration(
                      border: Border(
                          right:
                              BorderSide(color: AppColors.borderColor)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _otherMaps.map((m) {
                        final sel = _selectedMapId == m.id;
                        final inCache = _mapInCache(m.id);
                        return GestureDetector(
                          onTap: () => _selectMap(m.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.accent.withOpacity(0.12)
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: sel
                                      ? AppColors.accent
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.map_outlined,
                                    size: 12,
                                    color: inCache
                                        ? AppColors.textMuted
                                        : AppColors.borderColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: TextStyle(
                                      color: inCache
                                          ? (sel
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary)
                                          : AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: sel
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Right: rules list
                  Expanded(
                    child: _selectedMapId == null
                        ? const Center(
                            child: Text(
                              '← Select a map',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12),
                            ),
                          )
                        : !_mapInCache(_selectedMapId!)
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Switch to this map in the editor first to load its rules.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12),
                                  ),
                                ),
                              )
                            : selectedRules.isEmpty
                                ? const Center(
                                    child: Text(
                                      'This map has no rules',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      // Select all row
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: AppColors
                                                      .borderColor)),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${selectedRules.length} rule${selectedRules.length == 1 ? '' : 's'}',
                                              style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 11),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () => setState(() {
                                                if (allChecked) {
                                                  _checked.clear();
                                                } else {
                                                  _checked.addAll(
                                                      selectedRules.map(
                                                          (r) => r.id));
                                                }
                                              }),
                                              child: Text(
                                                allChecked
                                                    ? 'Deselect all'
                                                    : 'Select all',
                                                style: const TextStyle(
                                                    color: AppColors.accent,
                                                    fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          children:
                                              selectedRules.map((r) {
                                            final checked =
                                                _checked.contains(r.id);
                                            return GestureDetector(
                                              onTap: () => setState(() {
                                                if (checked) {
                                                  _checked.remove(r.id);
                                                } else {
                                                  _checked.add(r.id);
                                                }
                                              }),
                                              child: Container(
                                                margin: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 3),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: checked
                                                      ? AppColors.surfaceBg
                                                      : AppColors.surfaceBg
                                                          .withOpacity(0.4),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          7),
                                                  border: Border.all(
                                                    color: checked
                                                        ? AppColors.borderColor
                                                        : AppColors.borderColor
                                                            .withOpacity(0.4),
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Checkbox
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 1, right: 8),
                                                      child: Container(
                                                        width: 15,
                                                        height: 15,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: checked
                                                              ? AppColors.accent
                                                              : Colors
                                                                  .transparent,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                          border: Border.all(
                                                            color: checked
                                                                ? AppColors
                                                                    .accent
                                                                : AppColors
                                                                    .borderColor,
                                                          ),
                                                        ),
                                                        child: checked
                                                            ? const Icon(
                                                                Icons.check,
                                                                size: 10,
                                                                color: Colors
                                                                    .white)
                                                            : null,
                                                      ),
                                                    ),
                                                    // Rule info
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            r.name,
                                                            style: TextStyle(
                                                              color: checked
                                                                  ? AppColors
                                                                      .textPrimary
                                                                  : AppColors
                                                                      .textMuted,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          _ruleChip(
                                                              'WHEN',
                                                              r.trigger.label,
                                                              AppColors.accent),
                                                          const SizedBox(
                                                              height: 2),
                                                          _ruleChip(
                                                              'THEN',
                                                              r.summary,
                                                              AppColors
                                                                  .success),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                  ),
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _checked.isNotEmpty ? _confirm : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _checked.isNotEmpty
                            ? AppColors.accent
                            : AppColors.accent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _checked.isEmpty
                            ? 'Copy Rules'
                            : 'Copy ${_checked.length} Rule${_checked.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: _checked.isNotEmpty
                              ? Colors.white
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleChip(String tag, String text, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.only(top: 1, right: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
          ),
        ],
      );
}

// ─── Effects Tab ──────────────────────────────────────────────────────────────

class _EffectsTab extends StatefulWidget {
  final EditorState editorState;
  const _EffectsTab({required this.editorState});

  @override
  State<_EffectsTab> createState() => _EffectsTabState();
}

class _EffectsTabState extends State<_EffectsTab> {
  List<GameEffect> get _effects => widget.editorState.project.effects;

  // null = list view; int = editing that index; -1 = adding new
  int? _editingIndex;

  static const _typeEmojis = {
    'blast': '💥',
    'fire': '🔥',
    'snow': '❄',
    'electric': '⚡',
    'smoke': '💨',
    'rain': '🌧',
  };

  void _startAdd() {
    _effects.add(GameEffect(name: 'Effect ${_effects.length + 1}'));
    setState(() => _editingIndex = _effects.length - 1);
    widget.editorState.notifyProjectChanged();
  }

  void _startEdit(int index) => setState(() => _editingIndex = index);

  void _deleteEffect(int index) {
    if (_editingIndex == index) _editingIndex = null;
    setState(() => _effects.removeAt(index));
    widget.editorState.notifyProjectChanged();
  }

  void _onEditorCancel(int index) {
    // If this was a brand-new effect that was never saved, remove it
    setState(() => _editingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_editingIndex != null) {
      final idx = _editingIndex!;
      if (idx < _effects.length) {
        return _InlineEffectEditor(
          key: ValueKey(idx),
          effect: _effects[idx],
          editorState: widget.editorState,
          onSave: (updated) {
            setState(() {
              _effects[idx] = updated;
              _editingIndex = null;
            });
            widget.editorState.notifyProjectChanged();
          },
          onCancel: () => _onEditorCancel(idx),
        );
      }
      _editingIndex = null;
    }

    // ── List view ──
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Saved Effects',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ),
              GestureDetector(
                onTap: _startAdd,
                child: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: _effects.isEmpty
              ? const Center(
                  child: Text('No effects saved.\nTap + to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _effects.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.borderColor),
                  itemBuilder: (_, i) {
                    final fx = _effects[i];
                    final emoji = _typeEmojis[fx.type] ?? '✨';
                    final subtitle = switch (fx.type) {
                      'blast' => '${fx.blastColor} blast · ${fx.count}p · r${fx.radius} · ${fx.duration}s',
                      'fire' => 'fire · intensity ${fx.intensity} · spread ${fx.spread}t · ${fx.duration < 0 ? "loop" : "${fx.duration}s"}',
                      'snow' => 'snow · density ${fx.intensity} · area ${fx.spread}t · ${fx.duration < 0 ? "loop" : "${fx.duration}s"}',
                      'electric' => 'electric · ${fx.intensity} arcs · range ${fx.spread}t · ${fx.duration}s',
                      'smoke' => 'smoke · density ${fx.intensity} · spread ${fx.spread}t · ${fx.duration < 0 ? "loop" : "${fx.duration}s"}',
                      'rain' => 'rain · density ${fx.intensity} · ${fx.radius}° · ${fx.duration < 0 ? "loop" : "${fx.duration}s"}',
                      _ => fx.type,
                    };
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Text(emoji, style: const TextStyle(fontSize: 18)),
                      title: Text(fx.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _startEdit(i),
                            child: const Icon(Icons.edit_outlined,
                                size: 15, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _deleteEffect(i),
                            child: const Icon(Icons.delete_outline,
                                size: 15, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      onTap: () => _startEdit(i),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Inline Effect Editor (no dialog — lives inside the panel) ─────────────────

class _InlineEffectEditor extends StatefulWidget {
  final GameEffect effect;
  final EditorState editorState;
  final void Function(GameEffect) onSave;
  final VoidCallback onCancel;

  const _InlineEffectEditor({
    super.key,
    required this.effect,
    required this.editorState,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_InlineEffectEditor> createState() => _InlineEffectEditorState();
}

class _InlineEffectEditorState extends State<_InlineEffectEditor> {
  late final TextEditingController _nameCtrl;
  late String _type;
  // Blast
  late String _blastColor;
  late int _count;
  late int _radius;
  // Shared
  late int _intensity;
  late int _spread;
  late double _speed;
  late double _duration;
  late double _particleSize;
  late int _maxParticles;
  bool _loop = false;

  // (id, icon, label, accent color)
  static const _types = [
    ('blast', Icons.flare,                  'Blast',    Color(0xFFFF7043)),
    ('fire',  Icons.local_fire_department,  'Fire',     Color(0xFFFF6B00)),
    ('snow',  Icons.ac_unit,                'Snow',     Color(0xFF64B5F6)),
    ('electric', Icons.bolt,               'Electric', Color(0xFFFFEE58)),
    ('smoke', Icons.cloud,                  'Smoke',    Color(0xFF90A4AE)),
    ('rain',  Icons.water_drop,             'Rain',     Color(0xFF42A5F5)),
  ];

  // (id, swatch color, label) — shown as colored circle
  static const _blastColors = [
    ('fire',     Color(0xFFFF5722), 'Orange'),
    ('ice',      Color(0xFF29B6F6), 'Blue'),
    ('electric', Color(0xFFFFEE58), 'Yellow'),
    ('smoke',    Color(0xFF90A4AE), 'Gray'),
  ];

  @override
  void initState() {
    super.initState();
    final fx = widget.effect;
    _nameCtrl = TextEditingController(text: fx.name);
    _type = fx.type;
    _blastColor = fx.blastColor;
    _count = fx.count;
    _radius = fx.radius;
    _intensity = fx.intensity;
    _spread = fx.spread;
    _speed = fx.speed;
    _particleSize = fx.particleSize;
    _maxParticles = fx.maxParticles;
    _duration = fx.duration < 0 ? 3.0 : fx.duration;
    _loop = fx.duration < 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _preview() {
    final md = widget.editorState.mapData;
    final ts = md.tileSize.toDouble();
    final worldX = md.width * ts / 2;
    final worldY = md.height * ts / 2;
    widget.editorState.game.previewEffect(worldX, worldY, _buildEffect());
  }

  GameEffect _buildEffect() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Effect' : _nameCtrl.text.trim();
    return GameEffect(
      name: name,
      type: _type,
      duration: _loop ? -1 : _duration,
      blastColor: _blastColor,
      count: _count,
      radius: _radius,
      intensity: _intensity,
      spread: _spread,
      speed: _speed,
      particleSize: _particleSize,
      maxParticles: _maxParticles,
    );
  }

  void _save() => widget.onSave(_buildEffect());

  Widget _row({
    required String label,
    required String display,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) =>
      Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Icon(Icons.remove, size: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(display,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: const Icon(Icons.add, size: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );

  // Chip row for effect types — shows a colored Material icon
  Widget _typeChipRow(
      List<(String, IconData, String, Color)> items,
      String selected,
      void Function(String) onSelect) {
    return Row(
      children: items.map((item) {
        final (id, icon, label, color) = item;
        final sel = selected == id;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => onSelect(id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.18) : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: sel ? color : AppColors.borderColor, width: sel ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 14, color: sel ? color : AppColors.textMuted),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          color: sel ? color : AppColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Chip row for blast color swatches — shows a filled color circle
  Widget _colorChipRow(
      List<(String, Color, String)> items,
      String selected,
      void Function(String) onSelect) {
    return Row(
      children: items.map((item) {
        final (id, swatch, label) = item;
        final sel = selected == id;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => onSelect(id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.only(right: 3),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: sel ? swatch.withOpacity(0.15) : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: sel ? swatch : AppColors.borderColor, width: sel ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      boxShadow: sel
                          ? [BoxShadow(color: swatch.withOpacity(0.5), blurRadius: 4)]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(label,
                      style: TextStyle(
                          color: sel ? swatch : AppColors.textMuted,
                          fontSize: 8,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sizeRow(String label) => _row(
        label: label,
        display: _particleSize.toStringAsFixed(1),
        onDecrement: () =>
            setState(() => _particleSize = (_particleSize - 0.1).clamp(0.3, 4.0)),
        onIncrement: () =>
            setState(() => _particleSize = (_particleSize + 0.1).clamp(0.3, 4.0)),
      );

  Widget _maxParticlesRow() => _row(
        label: 'Max Parts.',
        display: '$_maxParticles',
        onDecrement: () =>
            setState(() => _maxParticles = (_maxParticles - 10).clamp(10, 1000)),
        onIncrement: () =>
            setState(() => _maxParticles = (_maxParticles + 10).clamp(10, 1000)),
      );

  List<Widget> _typeSettings() {
    switch (_type) {
      case 'blast':
        return [
          _label('COLOR'),
          _colorChipRow(_blastColors, _blastColor, (v) => _blastColor = v),
          const SizedBox(height: 12),
          _row(
            label: 'Particles',
            display: '$_count',
            onDecrement: () => setState(() => _count = (_count - 5).clamp(5, 200)),
            onIncrement: () => setState(() => _count = (_count + 5).clamp(5, 200)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Radius (t)',
            display: '$_radius',
            onDecrement: () => setState(() => _radius = (_radius - 1).clamp(1, 20)),
            onIncrement: () => setState(() => _radius = (_radius + 1).clamp(1, 20)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Particle Size'),
          const SizedBox(height: 8),
          _row(
            label: 'Duration',
            display: '${_duration.toStringAsFixed(1)}s',
            onDecrement: () =>
                setState(() => _duration = (_duration - 0.1).clamp(0.1, 10.0)),
            onIncrement: () =>
                setState(() => _duration = (_duration + 0.1).clamp(0.1, 10.0)),
          ),
        ];

      case 'fire':
        return [
          _row(
            label: 'Intensity',
            display: '$_intensity',
            onDecrement: () => setState(() => _intensity = (_intensity - 1).clamp(1, 10)),
            onIncrement: () => setState(() => _intensity = (_intensity + 1).clamp(1, 10)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Width (t)',
            display: '$_spread',
            onDecrement: () => setState(() => _spread = (_spread - 1).clamp(1, 20)),
            onIncrement: () => setState(() => _spread = (_spread + 1).clamp(1, 20)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Rise Speed',
            display: '${_speed.toStringAsFixed(1)} t/s',
            onDecrement: () => setState(() => _speed = (_speed - 0.5).clamp(0.5, 20.0)),
            onIncrement: () => setState(() => _speed = (_speed + 0.5).clamp(0.5, 20.0)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Flame Size'),
          const SizedBox(height: 8),
          _maxParticlesRow(),
          ..._durationRow(),
        ];

      case 'snow':
        return [
          _row(
            label: 'Density',
            display: '$_intensity',
            onDecrement: () => setState(() => _intensity = (_intensity - 1).clamp(1, 10)),
            onIncrement: () => setState(() => _intensity = (_intensity + 1).clamp(1, 10)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Area (t)',
            display: '$_spread',
            onDecrement: () => setState(() => _spread = (_spread - 1).clamp(1, 30)),
            onIncrement: () => setState(() => _spread = (_spread + 1).clamp(1, 30)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Fall Speed',
            display: '${_speed.toStringAsFixed(1)} t/s',
            onDecrement: () => setState(() => _speed = (_speed - 0.5).clamp(0.5, 20.0)),
            onIncrement: () => setState(() => _speed = (_speed + 0.5).clamp(0.5, 20.0)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Flake Size'),
          const SizedBox(height: 8),
          _maxParticlesRow(),
          ..._durationRow(),
        ];

      case 'electric':
        return [
          _row(
            label: 'Arc Count',
            display: '$_intensity',
            onDecrement: () => setState(() => _intensity = (_intensity - 1).clamp(1, 12)),
            onIncrement: () => setState(() => _intensity = (_intensity + 1).clamp(1, 12)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Range (t)',
            display: '$_spread',
            onDecrement: () => setState(() => _spread = (_spread - 1).clamp(1, 20)),
            onIncrement: () => setState(() => _spread = (_spread + 1).clamp(1, 20)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Arc Thickness'),
          const SizedBox(height: 8),
          _row(
            label: 'Duration',
            display: '${_duration.toStringAsFixed(2)}s',
            onDecrement: () =>
                setState(() => _duration = (_duration - 0.05).clamp(0.1, 2.0)),
            onIncrement: () =>
                setState(() => _duration = (_duration + 0.05).clamp(0.1, 2.0)),
          ),
        ];

      case 'smoke':
        return [
          _row(
            label: 'Density',
            display: '$_intensity',
            onDecrement: () => setState(() => _intensity = (_intensity - 1).clamp(1, 10)),
            onIncrement: () => setState(() => _intensity = (_intensity + 1).clamp(1, 10)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Spread (t)',
            display: '$_spread',
            onDecrement: () => setState(() => _spread = (_spread - 1).clamp(1, 20)),
            onIncrement: () => setState(() => _spread = (_spread + 1).clamp(1, 20)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Rise Speed',
            display: '${_speed.toStringAsFixed(1)} t/s',
            onDecrement: () => setState(() => _speed = (_speed - 0.5).clamp(0.5, 10.0)),
            onIncrement: () => setState(() => _speed = (_speed + 0.5).clamp(0.5, 10.0)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Puff Size'),
          const SizedBox(height: 8),
          _maxParticlesRow(),
          ..._durationRow(),
        ];

      case 'rain':
        return [
          _row(
            label: 'Density',
            display: '$_intensity',
            onDecrement: () => setState(() => _intensity = (_intensity - 1).clamp(1, 10)),
            onIncrement: () => setState(() => _intensity = (_intensity + 1).clamp(1, 10)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Fall Speed',
            display: '${_speed.toStringAsFixed(1)} t/s',
            onDecrement: () => setState(() => _speed = (_speed - 0.5).clamp(1.0, 30.0)),
            onIncrement: () => setState(() => _speed = (_speed + 0.5).clamp(1.0, 30.0)),
          ),
          const SizedBox(height: 8),
          _row(
            label: 'Angle °',
            display: '$_radius°',
            onDecrement: () => setState(() => _radius = (_radius - 5).clamp(-60, 60)),
            onIncrement: () => setState(() => _radius = (_radius + 5).clamp(-60, 60)),
          ),
          const SizedBox(height: 8),
          _sizeRow('Drop Size'),
          const SizedBox(height: 8),
          _maxParticlesRow(),
          ..._durationRow(),
        ];

      default:
        return [];
    }
  }

  List<Widget> _durationRow() => [
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(_loop ? 'Duration' : 'Duration',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ),
            GestureDetector(
              onTap: _loop ? null : () => setState(() => _duration = (_duration - 0.5).clamp(0.5, 60.0)),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _loop ? AppColors.panelBg : AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Icon(Icons.remove, size: 12,
                    color: _loop ? AppColors.textMuted : AppColors.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                _loop ? 'loop' : '${_duration.toStringAsFixed(1)}s',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _loop ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            GestureDetector(
              onTap: _loop ? null : () => setState(() => _duration = (_duration + 0.5).clamp(0.5, 60.0)),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _loop ? AppColors.panelBg : AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Icon(Icons.add, size: 12,
                    color: _loop ? AppColors.textMuted : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _loop = !_loop);
                // Stop running preview when loop is turned off
                if (!_loop) widget.editorState.game.clearEffectPreview();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _loop ? AppColors.accent.withOpacity(0.2) : AppColors.surfaceBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: _loop ? AppColors.accent.withOpacity(0.6) : AppColors.borderColor),
                ),
                child: Text('Loop',
                    style: TextStyle(
                        fontSize: 9,
                        color: _loop ? AppColors.accent : AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onCancel,
                child: const Icon(Icons.arrow_back_ios, size: 13,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.accent),
              const SizedBox(width: 5),
              const Expanded(
                child: Text('Edit Effect',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Form
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Name field
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle:
                      const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.borderColor)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.borderColor)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppColors.accent)),
                ),
              ),
              const SizedBox(height: 14),
              // Effect type selector
              _label('EFFECT TYPE'),
              _typeChipRow(_types, _type, (v) {
                _type = v;
                // Reset loop for types that don't support it
                if (v == 'blast' || v == 'electric') _loop = false;
              }),
              const SizedBox(height: 14),
              // Type-specific settings
              ..._typeSettings(),
              const SizedBox(height: 14),
              // Preview button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.play_circle_outline, size: 15),
                  label: const Text('Preview in Editor',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Save / Cancel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Code Tab ─────────────────────────────────────────────────────────────────

class _CodeTab extends StatelessWidget {
  const _CodeTab();

  static const _generated = '''// GENERATED — do not edit
// OMA Engine v0.1

class MyGame extends OmaGame {
  @override
  void onLoad() {
    loadMap('untitled_map');
  }
}
''';

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _codeSection('GENERATED', _generated, editable: false),
          const Divider(color: AppColors.borderColor, height: 1),
          _codeSection('YOUR CODE', '// Write custom logic here\n', editable: true),
        ],
      ),
    );
  }

  Widget _codeSection(String label, String code, {required bool editable}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: AppColors.surfaceBg,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!editable) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('read-only',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ]
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
