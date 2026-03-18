import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../theme/app_theme.dart';

class ProjectSettingsDialog extends StatefulWidget {
  final GameProject project;
  final VoidCallback onChanged;

  const ProjectSettingsDialog._({required this.project, required this.onChanged});

  static Future<void> show(
    BuildContext context, {
    required GameProject project,
    required VoidCallback onChanged,
  }) =>
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => ProjectSettingsDialog._(
          project: project,
          onChanged: onChanged,
        ),
      );

  @override
  State<ProjectSettingsDialog> createState() => _ProjectSettingsDialogState();
}

// ─── Presets ─────────────────────────────────────────────────────────────────

class _VpPreset {
  final String label;
  final int w, h;
  const _VpPreset(this.label, this.w, this.h);
}

const _kPresets = [
  _VpPreset('Fullscreen (adaptive)', 0, 0),
  _VpPreset('320 × 180  (pixel art)', 320, 180),
  _VpPreset('480 × 270', 480, 270),
  _VpPreset('640 × 360  (recommended)', 640, 360),
  _VpPreset('960 × 540', 960, 540),
  _VpPreset('Custom…', -1, -1),
];

class _ProjectSettingsDialogState extends State<ProjectSettingsDialog> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;
  late _VpPreset _selected;

  GameProject get _proj => widget.project;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(text: '${_proj.viewportWidth}');
    _hCtrl = TextEditingController(text: '${_proj.viewportHeight}');
    _selected = _matchPreset(_proj.viewportWidth, _proj.viewportHeight);
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  _VpPreset _matchPreset(int w, int h) {
    for (final p in _kPresets) {
      if (p.w == -1) continue;
      if (p.w == w && p.h == h) return p;
    }
    return _kPresets.last; // Custom
  }

  void _applyPreset(_VpPreset p) {
    if (p.w == -1) return; // Custom — leave inputs as-is
    setState(() {
      _wCtrl.text = '${p.w}';
      _hCtrl.text = '${p.h}';
      _proj.viewportWidth = p.w;
      _proj.viewportHeight = p.h;
    });
    widget.onChanged();
  }

  void _applyCustom() {
    final w = int.tryParse(_wCtrl.text) ?? 0;
    final h = int.tryParse(_hCtrl.text) ?? 0;
    setState(() {
      _proj.viewportWidth = w;
      _proj.viewportHeight = h;
      _selected = _matchPreset(w, h);
    });
    widget.onChanged();
  }

  void _setOrientation(String value) {
    setState(() => _proj.androidOrientation = value);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 420,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Title bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  const Text(
                    'Project Settings',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderColor),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Viewport ────────────────────────────────────────────
                  _sectionLabel('VIEWPORT'),
                  const SizedBox(height: 4),
                  const Text(
                    'Virtual resolution the game renders at. Scaled to fit the screen with letterboxing.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),

                  _buildDropdown(),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _numField('Width', _wCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _numField('Height', _hCtrl)),
                      const SizedBox(width: 12),
                      _applyBtn(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _proj.viewportWidth == 0
                        ? 'Current: Fullscreen (adaptive zoom)'
                        : 'Current: ${_proj.viewportWidth} × ${_proj.viewportHeight}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),

                  const SizedBox(height: 24),

                  // ── Game Options ─────────────────────────────────────────
                  _sectionLabel('GAME OPTIONS'),
                  const SizedBox(height: 10),
                  _buildToggleRow(
                    label: 'Pixel art mode',
                    description: 'Nearest-neighbor filtering — keeps sprites crisp (recommended for pixel art)',
                    value: _proj.pixelArt,
                    onChanged: (v) {
                      setState(() => _proj.pixelArt = v);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildToggleRow(
                    label: 'Camera follows player',
                    description: 'Camera tracks the player during gameplay',
                    value: _proj.cameraFollow,
                    onChanged: (v) {
                      setState(() => _proj.cameraFollow = v);
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildToggleRow(
                    label: 'Allow player to zoom',
                    description: 'Scroll wheel zooms in/out during gameplay',
                    value: _proj.allowZoom,
                    onChanged: (v) {
                      setState(() => _proj.allowZoom = v);
                      widget.onChanged();
                    },
                  ),

                  if (_proj.allowZoom) ...[
                    const SizedBox(height: 14),
                    _buildZoomSlider(),
                  ],

                  const SizedBox(height: 24),

                  // ── Android Orientation ─────────────────────────────────
                  _sectionLabel('ANDROID ORIENTATION'),
                  const SizedBox(height: 4),
                  const Text(
                    'Screen orientation when running on Android.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _orientBtn(
                        icon: Icons.screen_lock_landscape,
                        label: 'Landscape',
                        selected: _proj.androidOrientation == 'landscape',
                        onTap: () => _setOrientation('landscape'),
                      ),
                      const SizedBox(width: 10),
                      _orientBtn(
                        icon: Icons.screen_lock_portrait,
                        label: 'Portrait',
                        selected: _proj.androidOrientation == 'portrait',
                        onTap: () => _setOrientation('portrait'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Key Bindings ─────────────────────────────────────────
                  _sectionLabel('KEY BINDINGS'),
                  const SizedBox(height: 4),
                  const Text(
                    'Remap action keys. Arrow keys always work for movement.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _KeyBindingsSection(project: _proj, onChanged: widget.onChanged),

                  const SizedBox(height: 24),

                  // ── Collectible Labels ───────────────────────────────────
                  _sectionLabel('COLLECTIBLE LABELS'),
                  const SizedBox(height: 4),
                  const Text(
                    'Rename collectible types shown in the HUD.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  _labelField('Coin label', _proj.coinLabel,
                      (v) { _proj.coinLabel = v; widget.onChanged(); }),
                  const SizedBox(height: 8),
                  _labelField('Gem label', _proj.gemLabel,
                      (v) { _proj.gemLabel = v; widget.onChanged(); }),
                  const SizedBox(height: 8),
                  _labelField('Collectible label', _proj.collectibleLabel,
                      (v) { _proj.collectibleLabel = v; widget.onChanged(); }),

                  const SizedBox(height: 24),

                  // ── Done ────────────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.accent.withOpacity(0.4)),
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                color: AppColors.accent, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      );

  Widget _labelField(String label, String current, void Function(String) onChanged) =>
      Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: TextEditingController(text: current),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                    borderSide: const BorderSide(color: AppColors.borderColor),
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      );

  Widget _buildDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_VpPreset>(
            value: _selected,
            isExpanded: true,
            dropdownColor: AppColors.dialogBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            items: _kPresets
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.label,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ))
                .toList(),
            onChanged: (p) {
              if (p == null) return;
              setState(() => _selected = p);
              _applyPreset(p);
            },
          ),
        ),
      );

  Widget _numField(String label, TextEditingController ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          ),
        ],
      );

  Widget _applyBtn() => GestureDetector(
        onTap: _applyCustom,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          child: const Text('Apply',
              style: TextStyle(color: AppColors.accent, fontSize: 12)),
        ),
      );

  Widget _buildZoomSlider() => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Max zoom level',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
                const SizedBox(height: 2),
                const Text('How far the player can zoom in',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.borderColor,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withOpacity(0.2),
              ),
              child: Slider(
                value: _proj.maxZoom.clamp(1.2, 4.0),
                min: 1.2,
                max: 4.0,
                divisions: 14,
                onChanged: (v) {
                  setState(() => _proj.maxZoom = double.parse(v.toStringAsFixed(1)));
                  widget.onChanged();
                },
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${_proj.maxZoom.toStringAsFixed(1)}×',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );

  Widget _buildToggleRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 20,
              decoration: BoxDecoration(
                color: value ? AppColors.accent : AppColors.borderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _orientBtn({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.surfaceBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? AppColors.accent.withOpacity(0.6)
                    : AppColors.borderColor,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textMuted),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─── Key Bindings Section ─────────────────────────────────────────────────────

class _KeyBindingsSection extends StatefulWidget {
  final GameProject project;
  final VoidCallback onChanged;

  const _KeyBindingsSection({required this.project, required this.onChanged});

  @override
  State<_KeyBindingsSection> createState() => _KeyBindingsSectionState();
}

class _KeyBindingsSectionState extends State<_KeyBindingsSection> {
  // Which trigger is currently waiting for a key press (null = none)
  TriggerType? _capturing;

  static const _bindable = [
    TriggerType.keyUpPressed,
    TriggerType.keyDownPressed,
    TriggerType.keyLeftPressed,
    TriggerType.keyRightPressed,
    TriggerType.keySpacePressed,
  ];

  static const _defaultKeys = {
    TriggerType.keyUpPressed:    'W',
    TriggerType.keyDownPressed:  'S',
    TriggerType.keyLeftPressed:  'A',
    TriggerType.keyRightPressed: 'D',
    TriggerType.keySpacePressed: 'Space',
  };

  static const _labels = {
    TriggerType.keyUpPressed:    'Move Up',
    TriggerType.keyDownPressed:  'Move Down',
    TriggerType.keyLeftPressed:  'Move Left',
    TriggerType.keyRightPressed: 'Move Right',
    TriggerType.keySpacePressed: 'Action',
  };

  String _displayKey(TriggerType t) {
    final bound = widget.project.keyBindings[t.name];
    if (bound == null || bound.isEmpty) return _defaultKeys[t]!;
    return bound.toUpperCase();
  }

  bool _isDefault(TriggerType t) {
    final bound = widget.project.keyBindings[t.name];
    return bound == null || bound.isEmpty;
  }

  void _startCapture(TriggerType t) => setState(() => _capturing = t);

  void _cancelCapture() => setState(() => _capturing = null);

  void _applyCapture(TriggerType t, String keyId) {
    setState(() {
      widget.project.keyBindings[t.name] = keyId;
      _capturing = null;
    });
    widget.onChanged();
  }

  void _resetBinding(TriggerType t) {
    setState(() => widget.project.keyBindings.remove(t.name));
    widget.onChanged();
  }

  /// Convert a LogicalKeyboardKey to a short lowercase identifier string.
  /// Returns null if the key is not bindable (e.g. modifier-only, escape).
  String? _keyToId(LogicalKeyboardKey key) {
    // Letters
    if (key.keyId >= 0x00000061 && key.keyId <= 0x0000007a) {
      return String.fromCharCode(key.keyId);
    }
    // Digits
    if (key.keyId >= 0x00000030 && key.keyId <= 0x00000039) {
      return String.fromCharCode(key.keyId);
    }
    if (key == LogicalKeyboardKey.space) return 'space';
    if (key == LogicalKeyboardKey.enter) return 'enter';
    if (key == LogicalKeyboardKey.tab) return 'tab';
    if (key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight) return 'shift';
    if (key == LogicalKeyboardKey.controlLeft || key == LogicalKeyboardKey.controlRight) return 'ctrl';
    if (key == LogicalKeyboardKey.f1) return 'f1';
    if (key == LogicalKeyboardKey.f2) return 'f2';
    if (key == LogicalKeyboardKey.f3) return 'f3';
    if (key == LogicalKeyboardKey.f4) return 'f4';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: _capturing != null,
      onKeyEvent: (event) {
        if (_capturing == null) return;
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelCapture();
          return;
        }
        final id = _keyToId(event.logicalKey);
        if (id != null) _applyCapture(_capturing!, id);
      },
      child: Column(
        children: _bindable.map((t) {
          final capturing = _capturing == t;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(_labels[t]!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                // Current / default key chip
                Expanded(
                  child: GestureDetector(
                    onTap: () => capturing ? _cancelCapture() : _startCapture(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: capturing
                            ? AppColors.accent.withOpacity(0.18)
                            : AppColors.surfaceBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: capturing ? AppColors.accent : AppColors.borderColor,
                          width: capturing ? 1.5 : 1,
                        ),
                      ),
                      child: capturing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard, size: 13, color: AppColors.accent),
                                SizedBox(width: 6),
                                Text('Press a key…',
                                    style: TextStyle(
                                        color: AppColors.accent, fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _displayKey(t),
                                  style: TextStyle(
                                    color: _isDefault(t)
                                        ? AppColors.textSecondary
                                        : AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                // Reset button (only shown when custom binding set)
                if (!_isDefault(t)) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _resetBinding(t),
                    child: Tooltip(
                      message: 'Reset to default',
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: const Icon(Icons.refresh,
                            size: 13, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
