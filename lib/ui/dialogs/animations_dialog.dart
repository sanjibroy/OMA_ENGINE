import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_object.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';
import '../../theme/app_theme.dart';

class AnimationsDialog extends StatefulWidget {
  final GameObjectType type;
  final SpriteCache spriteCache;
  final MapData mapData;
  final VoidCallback onChanged;

  const AnimationsDialog._({
    required this.type,
    required this.spriteCache,
    required this.mapData,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required GameObjectType type,
    required SpriteCache spriteCache,
    required MapData mapData,
    required VoidCallback onChanged,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AnimationsDialog._(
        type: type,
        spriteCache: spriteCache,
        mapData: mapData,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<AnimationsDialog> createState() => _AnimationsDialogState();
}

class _AnimationsDialogState extends State<AnimationsDialog> {
  String? _selectedAnim;
  // Tracks which animations are in "sheet" display mode, independent of whether
  // a def has been applied yet (isSheetAnim() only returns true after Apply).
  final Map<String, bool> _isSheetMode = {};

  SpriteCache get _cache => widget.spriteCache;
  GameObjectType get _type => widget.type;
  MapData get _mapData => widget.mapData;

  @override
  void initState() {
    super.initState();
    final names = _cache.animNames(_type);
    for (final name in names) {
      _isSheetMode[name] = _cache.isSheetAnim(_type, name);
    }
    _selectedAnim = names.isNotEmpty ? names.first : null;
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  Future<void> _addAnimation() async {
    final name = await _promptName(context, title: 'New Animation', hint: 'e.g. walk_right');
    if (name == null || name.isEmpty) return;
    _cache.addAnimation(_type, name);
    _mapData.animPaths.putIfAbsent(_type.name, () => {})[name] = [];
    _mapData.animFps.putIfAbsent(_type.name, () => {})[name] = 8;
    _isSheetMode[name] = false;
    setState(() => _selectedAnim = name);
    widget.onChanged();
  }

  void _removeAnimation(String name) {
    _cache.removeAnimation(_type, name);
    _mapData.animPaths[_type.name]?.remove(name);
    _mapData.animFps[_type.name]?.remove(name);
    _mapData.animSheets[_type.name]?.remove(name);
    if (_mapData.animPaths[_type.name]?.isEmpty == true) {
      _mapData.animPaths.remove(_type.name);
    }
    if (_mapData.animFps[_type.name]?.isEmpty == true) {
      _mapData.animFps.remove(_type.name);
    }
    if (_mapData.animSheets[_type.name]?.isEmpty == true) {
      _mapData.animSheets.remove(_type.name);
    }
    if (_mapData.animDefaults[_type.name] == name) {
      _mapData.animDefaults.remove(_type.name);
    }
    final names = _cache.animNames(_type);
    setState(() => _selectedAnim = names.isNotEmpty ? names.first : null);
    widget.onChanged();
  }

  void _setDefault(String name) {
    _cache.setDefaultAnim(_type, name);
    _mapData.animDefaults[_type.name] = name;
    setState(() {});
    widget.onChanged();
  }

  Future<void> _addFrames(String animName) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      await _cache.addAnimFrame(_type, animName, f.path!);
      _mapData.animPaths.putIfAbsent(_type.name, () => {}).putIfAbsent(animName, () => []).add(f.path!);
    }
    setState(() {});
    widget.onChanged();
  }

  void _removeFrame(String animName, int index) {
    _cache.removeAnimFrame(_type, animName, index);
    final paths = _mapData.animPaths[_type.name]?[animName];
    if (paths != null && index < paths.length) paths.removeAt(index);
    setState(() {});
    widget.onChanged();
  }

  void _setFps(String animName, int fps) {
    _cache.setAnimFps(_type, animName, fps);
    _mapData.animFps.putIfAbsent(_type.name, () => {})[animName] = fps;
    widget.onChanged();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final names = _cache.animNames(_type);
    final defaultName = _cache.defaultAnim(_type);

    return Dialog(
      backgroundColor: const Color(0xFF201E1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 720,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            _buildTitleBar(),
            const Divider(height: 1, color: AppColors.borderColor),

            // Body
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: animation list
                  SizedBox(
                    width: 200,
                    child: _buildAnimList(names, defaultName),
                  ),
                  const VerticalDivider(width: 1, color: AppColors.borderColor),
                  // Right: frame editor
                  Expanded(
                    child: _selectedAnim != null
                        ? _buildFrameEditor(_selectedAnim!, defaultName)
                        : _buildEmptyState(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _type.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _type.symbol,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Animations: ${_type.label}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      );

  Widget _buildAnimList(List<String> names, String defaultName) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text('ANIMATIONS',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0)),
          ),
          Expanded(
            child: names.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No animations yet.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: names.map((name) {
                      final isSelected = name == _selectedAnim;
                      final isDefault = name == defaultName;
                      final isSheet = _isSheetMode[name] ?? _cache.isSheetAnim(_type, name);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAnim = name),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (isDefault)
                                const Tooltip(
                                  message: 'Default animation',
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.star,
                                        size: 12,
                                        color: Color(0xFFFBBF24)),
                                  ),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    if (isSheet)
                                      const Text('sheet',
                                          style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF60A5FA))),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeAnimation(name),
                                child: const Icon(Icons.close,
                                    size: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          // Add animation button
          Padding(
            padding: const EdgeInsets.all(10),
            child: GestureDetector(
              onTap: _addAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.5),
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text('Add Animation',
                        style: TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildFrameEditor(String animName, String defaultName) {
    final isSheet = _isSheetMode[animName] ?? _cache.isSheetAnim(_type, animName);
    final fps = _cache.getAnimFps(_type, animName);
    final isDefault = animName == defaultName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                animName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DEFAULT',
                      style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                )
              else
                GestureDetector(
                  onTap: () => _setDefault(animName),
                  child: const Tooltip(
                    message: 'Set as default animation',
                    child: Icon(Icons.star_border,
                        size: 16, color: AppColors.textMuted),
                  ),
                ),
              const Spacer(),
              // FPS control
              const Text('FPS',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 28,
                child: TextFormField(
                  key: ValueKey('fps_$animName'),
                  initialValue: '$fps',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide:
                          const BorderSide(color: AppColors.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide:
                          const BorderSide(color: AppColors.borderColor),
                    ),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) _setFps(animName, n);
                  },
                ),
              ),
            ],
          ),
        ),

        // Source type toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SourceToggle(
            isSheet: isSheet,
            onToggle: (toSheet) => _toggleSource(animName, toSheet),
          ),
        ),

        const Divider(height: 1, color: AppColors.borderColor),

        // Content area
        Expanded(
          child: isSheet
              ? _SpritesheetEditor(
                  key: ValueKey('sheet_$animName'),
                  type: _type,
                  animName: animName,
                  cache: _cache,
                  mapData: _mapData,
                  onChanged: () {
                    setState(() {});
                    widget.onChanged();
                  },
                )
              : _buildFramesContent(animName),
        ),
      ],
    );
  }

  Future<void> _toggleSource(String animName, bool toSheet) async {
    if (toSheet) {
      // Confirm if existing frames will be lost
      final count = _cache.animFrameCount(_type, animName);
      if (count > 0) {
        final ok = await _confirmDialog(
          context,
          title: 'Switch to Spritesheet?',
          message: 'This will clear $count existing frame${count == 1 ? '' : 's'} for "$animName".',
        );
        if (ok != true) return;
        // User confirmed — clear existing frame data now
        _cache.clearSheetAnim(_type, animName);
        _mapData.animPaths[_type.name]?.remove(animName);
        widget.onChanged();
      }
      // Mark as sheet mode locally — no def stored until user clicks Apply
      setState(() => _isSheetMode[animName] = true);
    } else {
      // Switch back to frames mode
      _cache.clearSheetAnim(_type, animName);
      _mapData.animSheets[_type.name]?.remove(animName);
      if (_mapData.animSheets[_type.name]?.isEmpty == true) {
        _mapData.animSheets.remove(_type.name);
      }
      setState(() => _isSheetMode[animName] = false);
      widget.onChanged();
    }
  }

  Widget _buildFramesContent(String animName) {
    final framePaths = _cache.getAnimPaths(_type, animName);

    return Column(
      children: [
        Expanded(
          child: framePaths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      const Text('No frames yet',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      _addFramesBtn(animName),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < framePaths.length; i++)
                        _frameTile(animName, i, framePaths[i]),
                      // Add frame tile
                      GestureDetector(
                        onTap: () => _addFrames(animName),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.accent.withOpacity(0.4),
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  size: 20, color: AppColors.accent),
                              SizedBox(height: 2),
                              Text('Add',
                                  style: TextStyle(
                                      color: AppColors.accent, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        // Bottom bar: frame count + add button
        if (framePaths.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.borderColor)),
            ),
            child: Row(
              children: [
                Text(
                  '${framePaths.length} frame${framePaths.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
                const Spacer(),
                _addFramesBtn(animName),
              ],
            ),
          ),
      ],
    );
  }

  Widget _frameTile(String animName, int index, String path) => Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
          ),
          // Frame index label
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _removeFrame(animName, index),
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  Widget _buildEmptyState() => const Center(
        child: Text(
          'Add an animation to get started.',
          style:
              TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );

  Widget _addFramesBtn(String animName) => GestureDetector(
        onTap: () => _addFrames(animName),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
                color: AppColors.accent.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 14, color: AppColors.accent),
              SizedBox(width: 6),
              Text('Add Frames',
                  style: TextStyle(
                      color: AppColors.accent, fontSize: 12)),
            ],
          ),
        ),
      );

  // ── Utility ───────────────────────────────────────────────────────────────

  static Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String hint = '',
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF201E1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.borderColor),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  const BorderSide(color: AppColors.borderColor),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF201E1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.borderColor),
          ),
          title: Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14)),
          content: Text(message,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
}

// ─── Source type toggle widget ────────────────────────────────────────────

class _SourceToggle extends StatelessWidget {
  final bool isSheet;
  final void Function(bool toSheet) onToggle;

  const _SourceToggle({required this.isSheet, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('Frames', !isSheet, () => onToggle(false)),
          _tab('Spritesheet', isSheet, () => onToggle(true)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: active ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      );
}

// ─── Spritesheet editor widget ────────────────────────────────────────────

class _SpritesheetEditor extends StatefulWidget {
  final GameObjectType type;
  final String animName;
  final SpriteCache cache;
  final MapData mapData;
  final VoidCallback onChanged;

  const _SpritesheetEditor({
    super.key,
    required this.type,
    required this.animName,
    required this.cache,
    required this.mapData,
    required this.onChanged,
  });

  @override
  State<_SpritesheetEditor> createState() => _SpritesheetEditorState();
}

class _SpritesheetEditorState extends State<_SpritesheetEditor> {
  String? _sheetPath;
  ui.Image? _sheetImage; // for preview sizing
  final _fwCtrl = TextEditingController(text: '32');
  final _fhCtrl = TextEditingController(text: '32');
  final _fcCtrl = TextEditingController(text: '0');
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate from existing def
    final def = widget.cache.getSheetDef(widget.type, widget.animName);
    if (def != null) {
      _sheetPath = def.path;
      _fwCtrl.text = '${def.frameWidth}';
      _fhCtrl.text = '${def.frameHeight}';
      _fcCtrl.text = '${def.frameCount}';
      _loadPreview(def.path);
    }
  }

  @override
  void dispose() {
    _fwCtrl.dispose();
    _fhCtrl.dispose();
    _fcCtrl.dispose();
    _sheetImage?.dispose();
    super.dispose();
  }

  Future<void> _loadPreview(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _sheetImage?.dispose();
          _sheetImage = frame.image;
        });
      } else {
        frame.image.dispose();
      }
    } catch (_) {}
  }

  Future<void> _pickSheet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.first.path == null) return;
    final path = result.files.first.path!;
    setState(() {
      _sheetPath = path;
      _sheetImage?.dispose();
      _sheetImage = null;
    });
    await _loadPreview(path);
  }

  Future<void> _apply() async {
    final path = _sheetPath;
    if (path == null) return;
    final fw = int.tryParse(_fwCtrl.text) ?? 0;
    final fh = int.tryParse(_fhCtrl.text) ?? 0;
    final fc = int.tryParse(_fcCtrl.text) ?? 0;
    if (fw <= 0 || fh <= 0) return;

    setState(() => _applying = true);
    final def = AnimSheetDef(
        path: path, frameWidth: fw, frameHeight: fh, frameCount: fc);
    await widget.cache.setSheetAnim(widget.type, widget.animName, def);

    // Persist to mapData
    widget.mapData.animSheets
        .putIfAbsent(widget.type.name, () => {})[widget.animName] = def.toJson();
    widget.mapData.animPaths[widget.type.name]?.remove(widget.animName);

    setState(() => _applying = false);
    widget.onChanged();
  }

  int get _detectedFrames {
    final img = _sheetImage;
    if (img == null) return 0;
    final fw = int.tryParse(_fwCtrl.text) ?? 0;
    final fh = int.tryParse(_fhCtrl.text) ?? 0;
    if (fw <= 0 || fh <= 0) return 0;
    final cols = img.width ~/ fw;
    final rows = img.height ~/ fh;
    final total = cols * rows;
    final fc = int.tryParse(_fcCtrl.text) ?? 0;
    return (fc > 0 && fc <= total) ? fc : total;
  }

  @override
  Widget build(BuildContext context) {
    final hasPath = _sheetPath != null;
    final frameCount = _detectedFrames;
    final img = _sheetImage;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pick button
          GestureDetector(
            onTap: _pickSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_on_outlined,
                      size: 15, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    hasPath
                        ? _sheetPath!.replaceAll('\\', '/').split('/').last
                        : 'Pick Spritesheet…',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Frame size + count inputs
          Row(
            children: [
              _numField('Frame W', _fwCtrl),
              const SizedBox(width: 8),
              _numField('Frame H', _fhCtrl),
              const SizedBox(width: 8),
              _numField('Count (0=auto)', _fcCtrl, width: 110),
            ],
          ),

          const SizedBox(height: 12),

          // Detected count label
          if (hasPath)
            Text(
              '$frameCount frame${frameCount == 1 ? '' : 's'} detected',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11),
            ),

          const SizedBox(height: 12),

          // Apply button
          GestureDetector(
            onTap: (_applying || !hasPath) ? null : _apply,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: (!hasPath || _applying) ? 0.4 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_applying)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.accent),
                      )
                    else
                      const Icon(Icons.check,
                          size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    const Text('Apply',
                        style: TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Preview with grid overlay
          if (img != null)
            _SheetPreview(
              image: img,
              frameWidth: int.tryParse(_fwCtrl.text) ?? 0,
              frameHeight: int.tryParse(_fhCtrl.text) ?? 0,
            ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl,
      {double width = 80}) =>
      SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(height: 4),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      );
}

// ─── Sheet preview with grid overlay ─────────────────────────────────────

class _SheetPreview extends StatelessWidget {
  final ui.Image image;
  final int frameWidth;
  final int frameHeight;

  const _SheetPreview({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  Widget build(BuildContext context) {
    const maxW = 400.0;
    const maxH = 200.0;
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = (maxW / iw).clamp(0.0, maxH / ih).clamp(0.0, 1.0);
    final dispW = iw * scale;
    final dispH = ih * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Preview',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: dispW,
          height: dispH,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(
              painter: _GridPainter(
                image: image,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                scale: scale,
              ),
              size: Size(dispW, dispH),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final ui.Image image;
  final int frameWidth;
  final int frameHeight;
  final double scale;

  _GridPainter({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
    required this.scale,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Draw the sheet image
    final src = ui.Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = ui.Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, ui.Paint());

    // Draw grid lines
    if (frameWidth <= 0 || frameHeight <= 0) return;
    final paint = ui.Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 1.0;

    final scaledFw = frameWidth * scale;
    final scaledFh = frameHeight * scale;

    // Vertical lines
    for (double x = scaledFw; x < size.width; x += scaledFw) {
      canvas.drawLine(
          ui.Offset(x, 0), ui.Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = scaledFh; y < size.height; y += scaledFh) {
      canvas.drawLine(
          ui.Offset(0, y), ui.Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.image != image ||
      old.frameWidth != frameWidth ||
      old.frameHeight != frameHeight ||
      old.scale != scale;
}
