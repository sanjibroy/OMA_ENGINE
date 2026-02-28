import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_project.dart';
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
      backgroundColor: const Color(0xFF201E1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 420,
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

            Padding(
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
            dropdownColor: const Color(0xFF201E1C),
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
