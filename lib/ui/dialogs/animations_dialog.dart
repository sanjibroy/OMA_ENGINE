import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_object.dart';
import '../../models/map_data.dart';
import '../../services/sprite_cache.dart';
import '../../theme/app_theme.dart';

// ─── Dialog entry point ───────────────────────────────────────────────────────

class AnimationsDialog extends StatefulWidget {
  final GameObjectType type;
  final int variantIndex;
  final SpriteCache spriteCache;
  final MapData mapData;
  final VoidCallback onChanged;

  const AnimationsDialog._({
    required this.type,
    required this.variantIndex,
    required this.spriteCache,
    required this.mapData,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required GameObjectType type,
    int variantIndex = 0,
    required SpriteCache spriteCache,
    required MapData mapData,
    required VoidCallback onChanged,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AnimationsDialog._(
        type: type,
        variantIndex: variantIndex,
        spriteCache: spriteCache,
        mapData: mapData,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<AnimationsDialog> createState() => _AnimationsDialogState();
}

// ─── Dialog state ─────────────────────────────────────────────────────────────

class _AnimationsDialogState extends State<AnimationsDialog> {
  String? _selectedAnim;

  int _previewFrame = 0;
  DateTime _lastFrameTime = DateTime.now();
  bool _previewRunning = false;

  SpriteCache get _cache => widget.spriteCache;
  GameObjectType get _type => widget.type;
  int get _vi => widget.variantIndex;
  String get _animKey => '${_type.name}:$_vi';
  MapData get _mapData => widget.mapData;

  @override
  void initState() {
    super.initState();
    final names = _cache.animNames(_type, _vi);
    _selectedAnim = names.isNotEmpty ? names.first : null;
    _startPreviewTicker();
  }


  //animation preview

  void _startPreviewTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 16)); // ~60fps tick
      if (!mounted) return false;
      _tickPreview();
      return true;
    });
  }

  void _tickPreview() {
    if (_selectedAnim == null) return;
    final fps = _cache.getAnimFps(_type, _vi, _selectedAnim!);
    final frameCount = _cache.animFrameCount(_type, _vi, _selectedAnim!);
    if (frameCount == 0) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameTime).inMilliseconds;
    final frameDuration = (1000 / fps).round();
    if (elapsed >= frameDuration) {
      setState(() {
        _previewFrame = (_previewFrame + 1) % frameCount;
        _lastFrameTime = now;
      });
    }
  }

  void _selectAnim(String name) {
    setState(() {
      _selectedAnim = name;
      _previewFrame = 0;
      _lastFrameTime = DateTime.now();
    });
  }
  
  // ── Animation list management ─────────────────────────────────────────────

  void _removeAnimation(String name) {
    _cache.removeAnimation(_type, _vi, name);
    _mapData.animPaths[_animKey]?.remove(name);
    _mapData.animFps[_animKey]?.remove(name);
    _mapData.animSheets[_animKey]?.remove(name);
    if (_mapData.animPaths[_animKey]?.isEmpty == true)
      _mapData.animPaths.remove(_animKey);
    if (_mapData.animFps[_animKey]?.isEmpty == true)
      _mapData.animFps.remove(_animKey);
    if (_mapData.animSheets[_animKey]?.isEmpty == true)
      _mapData.animSheets.remove(_animKey);
    if (_mapData.animDefaults[_animKey] == name)
      _mapData.animDefaults.remove(_animKey);
    final names = _cache.animNames(_type, _vi);
    setState(() =>
        _selectedAnim = names.isNotEmpty ? names.first : null);
    widget.onChanged();
  }

  void _setDefault(String name) {
    _cache.setDefaultAnim(_type, _vi, name);
    _mapData.animDefaults[_animKey] = name;
    setState(() {});
    widget.onChanged();
  }

  // Called by spritesheet editor when a new animation is created
  void _onAnimCreated(String name) {
    _selectAnim(name);
    widget.onChanged();
  }

  // Called by frames editor when frames change
  void _onFramesChanged() {
    setState(() {});
    widget.onChanged();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final names = _cache.animNames(_type, _vi);
    final defaultName = _cache.defaultAnim(_type, _vi);

    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 860,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitleBar(),
            const Divider(height: 1, color: AppColors.borderColor),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left: animation list ──────────────────────────
                  SizedBox(
                    width: 180,
                    child: _buildAnimList(names, defaultName),
                  ),
                  const VerticalDivider(
                      width: 1, color: AppColors.borderColor),
                  // ── Right: tabbed editor ──────────────────────────
                  Expanded(
                    child: _buildRightPanel(defaultName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Title bar ─────────────────────────────────────────────────────────────

  Widget _buildTitleBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration:
                  BoxDecoration(color: _type.color, shape: BoxShape.circle),
              child: Center(
                child: Text(_type.symbol,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Animations — ${_type.label} Variant ${_vi + 1}',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
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

  // ── Animation list (left panel) ───────────────────────────────────────────

  Widget _buildAnimList(List<String> names, String defaultName) {
    return Column(
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
        // ── Scrollable animation list ──────────────────────
        Expanded(
          child: names.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'No animations yet.\nCreate one via\nSpritesheet or Frames tab.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: names.map((name) {
                    final isSelected = name == _selectedAnim;
                    final isDefault = name == defaultName;
                    final isSheet = _cache.isSheetAnim(_type, _vi, name);
                    return GestureDetector(
                      onTap: () => _selectAnim(name),
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
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(Icons.star,
                                      size: 11,
                                      color: Color(0xFFFBBF24)),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                  Text(
                                    isSheet ? 'sheet' : 'frames',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isSheet
                                          ? const Color(0xFF60A5FA)
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isDefault)
                              GestureDetector(
                                onTap: () => _setDefault(name),
                                child: const Tooltip(
                                  message: 'Set as default',
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.star_border,
                                        size: 12,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () => _removeAnimation(name),
                              child: const Icon(Icons.close,
                                  size: 12,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),

        // ── Fixed preview at bottom ────────────────────────
        const Divider(height: 1, color: AppColors.borderColor),
        _buildPreview(),
      ],
    );
  }

  Widget _buildPreview() {
  final anim = _selectedAnim;
  final frameCount = anim != null
      ? _cache.animFrameCount(_type, _vi, anim)
      : 0;
  final fps = anim != null
      ? _cache.getAnimFps(_type, _vi, anim)
      : 8;
  final frame = frameCount > 0
      ? _cache.getAnimFrame(
          _type, _vi, anim!, _previewFrame % frameCount)
      : null;

  return LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.maxWidth - 16; // full width minus padding
      return Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkerboard + sprite preview
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CustomPaint(
                  painter: _CheckerPainter(),
                  child: frame != null
                      ? RawImage(
                          image: frame,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        )
                      : Center(
                          child: Icon(
                            _type.icon,
                            color: _type.color.withOpacity(0.3),
                            size: size * 0.4,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Info row
            if (anim != null && frameCount > 0) ...[
              Text(
                anim,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${fps}fps',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Frame ${(_previewFrame % frameCount) + 1}/$frameCount',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ] else
              const Text(
                'No preview',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10),
              ),

            const SizedBox(height: 4),
          ],
        ),
      );
    },
  );
}

  // ── Right panel with tabs ─────────────────────────────────────────────────

  Widget _buildRightPanel(String defaultName) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab bar
          Container(
            color: AppColors.dialogBg,
            child: TabBar(
              tabs: const [
                Tab(text: 'Spritesheet'),
                Tab(text: 'Frames'),
              ],
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              indicatorColor: AppColors.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.borderColor,
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                // ── Spritesheet tab ────────────────────────────
                _SpritesheetTab(
                  key: ValueKey('sheet_${_type.name}_$_vi'),
                  type: _type,
                  variantIndex: _vi,
                  cache: _cache,
                  mapData: _mapData,
                  animKey: _animKey,
                  onAnimCreated: _onAnimCreated,
                  onChanged: widget.onChanged,
                ),
                // ── Frames tab ─────────────────────────────────
                _FramesTab(
                  key: ValueKey('frames_${_type.name}_$_vi'),
                  type: _type,
                  variantIndex: _vi,
                  cache: _cache,
                  mapData: _mapData,
                  animKey: _animKey,
                  selectedAnim: _selectedAnim,
                  defaultName: defaultName,
                  onSetDefault: _setDefault,
                  onChanged: _onFramesChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spritesheet Tab ──────────────────────────────────────────────────────────
// Pick sheet once, click rows to create named animations

class _SpritesheetTab extends StatefulWidget {
  final GameObjectType type;
  final int variantIndex;
  final SpriteCache cache;
  final MapData mapData;
  final String animKey;
  final void Function(String name) onAnimCreated;
  final VoidCallback onChanged;

  const _SpritesheetTab({
    super.key,
    required this.type,
    required this.variantIndex,
    required this.cache,
    required this.mapData,
    required this.animKey,
    required this.onAnimCreated,
    required this.onChanged,
  });

  @override
  State<_SpritesheetTab> createState() => _SpritesheetTabState();
}

class _SpritesheetTabState extends State<_SpritesheetTab> {
  String? _sheetPath;
  ui.Image? _sheetImage;
  final _fwCtrl = TextEditingController(text: '32');
  final _fhCtrl = TextEditingController(text: '32');
  final _nameCtrl = TextEditingController();
  final _fpsCtrl = TextEditingController(text: '8');
  int _selectedRow = 0;
  double _zoom = 1.0;
  bool _creating = false;

  int get _fw => int.tryParse(_fwCtrl.text) ?? 0;
  int get _fh => int.tryParse(_fhCtrl.text) ?? 0;

  int get _totalRows {
    final img = _sheetImage;
    if (img == null || _fh <= 0) return 0;
    return img.height ~/ _fh;
  }

  int get _cols {
    final img = _sheetImage;
    if (img == null || _fw <= 0) return 0;
    return img.width ~/ _fw;
  }

  @override
  void dispose() {
    _fwCtrl.dispose();
    _fhCtrl.dispose();
    _nameCtrl.dispose();
    _fpsCtrl.dispose();
    _sheetImage?.dispose();
    super.dispose();
  }

  Future<void> _pickSheet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.first.path == null) return;
    final path = result.files.first.path!;
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) { frame.image.dispose(); return; }
    setState(() {
      _sheetPath = path;
      _sheetImage?.dispose();
      _sheetImage = frame.image;
      _selectedRow = 0;
    });
  }

  Future<void> _createAnimation() async {
    final path = _sheetPath;
    final name = _nameCtrl.text.trim();
    if (path == null || name.isEmpty || _fw <= 0 || _fh <= 0) return;

    if (widget.cache.animNames(widget.type, widget.variantIndex)
        .contains(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Animation "$name" already exists'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }

    setState(() => _creating = true);

    final fps = int.tryParse(_fpsCtrl.text) ?? 8;
    final def = AnimSheetDef(
      path: path,
      frameWidth: _fw,
      frameHeight: _fh,
      frameCount: 0,
      startRow: _selectedRow,
      endRow: _selectedRow,
    );

    widget.cache.addAnimation(widget.type, widget.variantIndex, name);
    await widget.cache.setSheetAnim(
        widget.type, widget.variantIndex, name, def);
    widget.cache.setAnimFps(widget.type, widget.variantIndex, name, fps);

    widget.mapData.animSheets
        .putIfAbsent(widget.animKey, () => {})[name] = def.toJson();
    widget.mapData.animFps
        .putIfAbsent(widget.animKey, () => {})[name] = fps;
    widget.mapData.animPaths[widget.animKey]?.remove(name);

    setState(() {
      _creating = false;
      _nameCtrl.clear();
    });

    widget.onChanged();
    widget.onAnimCreated(name);
  }

  @override
  Widget build(BuildContext context) {
    final img = _sheetImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Scrollable top section ──────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: pick + frame size + zoom
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _pickBtn(),
                    const SizedBox(width: 10),
                    _numField('W', _fwCtrl, width: 52),
                    const SizedBox(width: 6),
                    _numField('H', _fhCtrl, width: 52),
                    const Spacer(),
                    if (img != null) ...[
                      _zoomBtn(Icons.remove, () => setState(
                          () => _zoom = (_zoom - 0.25).clamp(0.25, 4.0))),
                      const SizedBox(width: 6),
                      Text('${(_zoom * 100).round()}%',
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 12)),
                      const SizedBox(width: 6),
                      _zoomBtn(Icons.add, () => setState(
                          () => _zoom = (_zoom + 0.25).clamp(0.25, 4.0))),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _zoom = 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: const Text('Reset',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 10)),
                        ),
                      ),
                    ],
                  ],
                ),

                if (img == null) ...[
                  const SizedBox(height: 50),
                  const Center(
                    child: Text('Pick a spritesheet to get started',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Click a row to select it, then name and create the animation',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),

                  // Sheet preview
                  _buildSheetPreview(img),

                  const SizedBox(height: 8),

                  // Selected row info
                  if (_totalRows > 0)
                    Text(
                      'Row $_selectedRow selected  ·  $_cols frame${_cols == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                ],
              ],
            ),
          ),
        ),

        // ── Fixed bottom bar: name + fps + create ───────────────
        if (img != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.dialogBg,
              border: Border(top: BorderSide(color: AppColors.borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Animation name (e.g. idle, walk_right)',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                        filled: true,
                        fillColor: AppColors.surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide:
                              const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      onSubmitted: (_) => _createAnimation(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // FPS inline — no label above, just prefix text
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('FPS',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 44,
                      height: 34,
                      child: TextFormField(
                        controller: _fpsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
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
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _creating ? null : _createAnimation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    height:34,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.5)),
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.accent),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: AppColors.accent),
                              SizedBox(width: 4),
                              Text('Create',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSheetPreview(ui.Image img) {
    if (_fw <= 0 || _fh <= 0) return const SizedBox.shrink();
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    const maxW = 500.0;
    final baseScale = (maxW / iw).clamp(0.1, 3.0);
    final scale = baseScale * _zoom;
    final dispW = iw * scale;
    final dispH = ih * scale;
    final scaledRowH = _fh * scale;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: GestureDetector(
          onTapDown: (d) {
            if (_totalRows == 0) return;
            final row = (d.localPosition.dy / scaledRowH)
                .floor()
                .clamp(0, _totalRows - 1);
            setState(() => _selectedRow = row);
          },
          child: Container(
            width: dispW,
            height: dispH,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CustomPaint(
                painter: _RowSheetPainter(
                  image: img,
                  frameWidth: _fw,
                  frameHeight: _fh,
                  scale: scale,
                  selectedRow: _selectedRow,
                  totalRows: _totalRows,
                ),
                size: Size(dispW, dispH),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickBtn() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spacer matching the label height in _numField
        const Text(' ', style: TextStyle(fontSize: 10)),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: _pickSheet,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_on_outlined,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(
                  _sheetPath != null
                      ? _sheetPath!.replaceAll('\\', '/').split('/').last
                      : 'Pick Spritesheet…',
                  style: const TextStyle(
                      color: AppColors.accent, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.surfaceBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Icon(icon, size: 12, color: AppColors.textSecondary),
        ),
      );

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
            const SizedBox(height: 2),
            SizedBox(
              height: 30,
              child: TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      );
}

// ─── Frames Tab ───────────────────────────────────────────────────────────────
// Select animation from list, add individual frame images

class _FramesTab extends StatefulWidget {
  final GameObjectType type;
  final int variantIndex;
  final SpriteCache cache;
  final MapData mapData;
  final String animKey;
  final String? selectedAnim;
  final String defaultName;
  final void Function(String name) onSetDefault;
  final VoidCallback onChanged;

  const _FramesTab({
    super.key,
    required this.type,
    required this.variantIndex,
    required this.cache,
    required this.mapData,
    required this.animKey,
    required this.selectedAnim,
    required this.defaultName,
    required this.onSetDefault,
    required this.onChanged,
  });

  @override
  State<_FramesTab> createState() => _FramesTabState();
}

class _FramesTabState extends State<_FramesTab> {
  // Local selected anim — synced from parent but can be changed within tab
  String? _localSelected;

  SpriteCache get _cache => widget.cache;
  GameObjectType get _type => widget.type;
  int get _vi => widget.variantIndex;

  @override
  void initState() {
    super.initState();
    _localSelected = widget.selectedAnim;
  }

  @override
  void didUpdateWidget(_FramesTab old) {
    super.didUpdateWidget(old);
    // If parent changes selected (e.g. new anim created in sheet tab), sync
    if (widget.selectedAnim != old.selectedAnim &&
        widget.selectedAnim != _localSelected) {
      _localSelected = widget.selectedAnim;
    }
  }

  Future<void> _addAnimation() async {
    final name = await _promptName(context,
        title: 'New Animation', hint: 'e.g. walk_left');
    if (name == null || name.isEmpty) return;
    _cache.addAnimation(_type, _vi, name);
    widget.mapData.animPaths
        .putIfAbsent(widget.animKey, () => {})[name] = [];
    widget.mapData.animFps
        .putIfAbsent(widget.animKey, () => {})[name] = 8;
    setState(() => _localSelected = name);
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
      await _cache.addAnimFrame(_type, _vi, animName, f.path!);
      widget.mapData.animPaths
          .putIfAbsent(widget.animKey, () => {})
          .putIfAbsent(animName, () => [])
          .add(f.path!);
    }
    setState(() {});
    widget.onChanged();
  }

  void _removeFrame(String animName, int index) {
    _cache.removeAnimFrame(_type, _vi, animName, index);
    final paths =
        widget.mapData.animPaths[widget.animKey]?[animName];
    if (paths != null && index < paths.length) paths.removeAt(index);
    setState(() {});
    widget.onChanged();
  }

  void _setFps(String animName, int fps) {
    _cache.setAnimFps(_type, _vi, animName, fps);
    widget.mapData.animFps
        .putIfAbsent(widget.animKey, () => {})[animName] = fps;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final names = _cache.animNames(_type, _vi);
    final sel = _localSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Animation selector row ────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              const Text('Animation:',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: names.isEmpty
                    ? const Text('No animations yet',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: names.contains(sel) ? sel : null,
                          isExpanded: true,
                          dropdownColor: AppColors.dialogBg,
                          hint: const Text('Select animation…',
                              style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12)),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12),
                          items: names
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text(n),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _localSelected = v),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // FPS field
              if (sel != null && names.contains(sel)) ...[
                const Text('FPS:',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 52,
                  height: 28,
                  child: TextFormField(
                    key: ValueKey('fps_$sel'),
                    initialValue:
                        '${_cache.getAnimFps(_type, _vi, sel)}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(
                            color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(
                            color: AppColors.borderColor),
                      ),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) _setFps(sel, n);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Set default button
                if (sel != widget.defaultName)
                  GestureDetector(
                    onTap: () => widget.onSetDefault(sel),
                    child: const Tooltip(
                      message: 'Set as default animation',
                      child: Icon(Icons.star_border,
                          size: 16, color: AppColors.textMuted),
                    ),
                  )
                else
                  const Tooltip(
                    message: 'Default animation',
                    child: Icon(Icons.star,
                        size: 16, color: Color(0xFFFBBF24)),
                  ),
              ],
              const SizedBox(width: 8),
              // Add new animation button
              GestureDetector(
                onTap: _addAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 13, color: AppColors.accent),
                      SizedBox(width: 4),
                      Text('New',
                          style: TextStyle(
                              color: AppColors.accent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Frames grid ───────────────────────────────────────
        Expanded(
          child: sel == null || !names.contains(sel)
              ? const Center(
                  child: Text(
                    'Select or create an animation above',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                )
              : _buildFramesGrid(sel),
        ),
      ],
    );
  }

  Widget _buildFramesGrid(String animName) {
    final framePaths = _cache.getAnimPaths(_type, _vi, animName);
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
                              color: AppColors.textMuted,
                              fontSize: 12)),
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
                      GestureDetector(
                        onTap: () => _addFrames(animName),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.accent
                                    .withOpacity(0.4),
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add,
                                  size: 20,
                                  color: AppColors.accent),
                              SizedBox(height: 2),
                              Text('Add',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (framePaths.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.borderColor)),
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

  Widget _frameTile(String animName, int index, String path) =>
      Stack(
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
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
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
                child: const Icon(Icons.close,
                    size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      );

  Widget _addFramesBtn(String animName) => GestureDetector(
        onTap: () => _addFrames(animName),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border:
                Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 14, color: AppColors.accent),
              SizedBox(width: 6),
              Text('Add Frames',
                  style:
                      TextStyle(color: AppColors.accent, fontSize: 12)),
            ],
          ),
        ),
      );

  static Future<String?> _promptName(BuildContext context,
      {required String title, String hint = ''}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBg,
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
            hintStyle: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
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
                style:
                    TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Create',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet painter with row highlight ────────────────────────────────────────

class _RowSheetPainter extends CustomPainter {
  final ui.Image image;
  final int frameWidth;
  final int frameHeight;
  final double scale;
  final int selectedRow;
  final int totalRows;

  const _RowSheetPainter({
    required this.image,
    required this.frameWidth,
    required this.frameHeight,
    required this.scale,
    required this.selectedRow,
    required this.totalRows,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Draw image
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(
          0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint(),
    );

    if (frameWidth <= 0 || frameHeight <= 0) return;

    final scaledFw = frameWidth * scale;
    final scaledFh = frameHeight * scale;

    // Grid lines
    final gridPaint = ui.Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1.0;
    for (double x = scaledFw; x < size.width; x += scaledFw) {
      canvas.drawLine(
          ui.Offset(x, 0), ui.Offset(x, size.height), gridPaint);
    }
    for (double y = scaledFh; y < size.height; y += scaledFh) {
      canvas.drawLine(
          ui.Offset(0, y), ui.Offset(size.width, y), gridPaint);
    }

    // Selected row highlight
    final rowTop = selectedRow * scaledFh;
    final rowRect =
        ui.Rect.fromLTWH(0, rowTop, size.width, scaledFh);

    canvas.drawRect(rowRect,
        ui.Paint()..color = const Color(0x446C63FF));
    canvas.drawRect(
      rowRect,
      ui.Paint()
        ..color = const Color(0xFF6C63FF)
        ..strokeWidth = 2.0
        ..style = ui.PaintingStyle.stroke,
    );

    // Row label
    final tp = TextPainter(
      text: TextSpan(
        text: 'Row $selectedRow',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [ui.Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        ui.Offset(6, rowTop + (scaledFh - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_RowSheetPainter old) =>
      old.image != image ||
      old.frameWidth != frameWidth ||
      old.frameHeight != frameHeight ||
      old.scale != scale ||
      old.selectedRow != selectedRow;
}

class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 8.0;
    final paint1 = Paint()..color = const Color(0xFF2A2A2A);
    final paint2 = Paint()..color = const Color(0xFF1A1A1A);
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final paint = (r + c) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(
              c * cellSize, r * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => false;
}