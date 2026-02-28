import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../editor/editor_state.dart';
import '../../models/game_object.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../theme/app_theme.dart';
import '../dialogs/rule_editor_dialog.dart';

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
    const tabs = ['Properties', 'Rules', 'Code'];
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
      1 => _RulesTab(editorState: widget.editorState),
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
  @override
  void initState() {
    super.initState();
    widget.editorState.mapChanged.addListener(_rebuild);
    widget.editorState.projectChanged.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.editorState.mapChanged.removeListener(_rebuild);
    widget.editorState.projectChanged.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

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
        // ── Map properties ─────────────────────────────
        _sectionLabel('MAP'),
        const SizedBox(height: 8),
        _propertyRow('Name', map.name),
        _propertyRow('Width', '${map.width} tiles'),
        _propertyRow('Height', '${map.height} tiles'),
        _propertyRow('Tile Size', '${map.tileSize} px'),
        _propertyRow('Total Tiles', '${map.width * map.height}'),

        const SizedBox(height: 16),

        // ── Project settings ────────────────────────────
        _sectionLabel('PROJECT SETTINGS'),
        const SizedBox(height: 10),

        // HUD Position toggle
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

        const SizedBox(height: 16),

        // ── Player settings ─────────────────────────────
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

        const SizedBox(height: 16),

        // ── Selected object ─────────────────────────────
        _sectionLabel('SELECTED OBJECT'),
        const SizedBox(height: 8),
        ValueListenableBuilder<GameObject?>(
          valueListenable: widget.editorState.selectedObject,
          builder: (_, obj, __) {
            if (obj == null) {
              return const Center(
                child: Text('Nothing selected',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              );
            }
            return _ObjectPropsForm(
              key: ValueKey(obj.id),
              obj: obj,
              editorState: widget.editorState,
            );
          },
        ),
      ],
    );
  }

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
  void _set(String key, dynamic value) {
    setState(() => widget.obj.properties[key] = value);
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
          ],
        ),
        const SizedBox(height: 8),
        _propRow('Tile X', '${obj.tileX}'),
        _propRow('Tile Y', '${obj.tileY}'),
        const SizedBox(height: 8),
        // Type-specific editable fields
        ..._buildTypeFields(obj, es),
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
        ];
      case GameObjectType.npc:
        return [_textareaField('Dialog',
            obj.properties['dialog'] as String? ?? 'Hello!',
            onChanged: (v) => _set('dialog', v))];
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
      case GameObjectType.playerSpawn:
        return [];
    }
  }

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
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600));

  InputDecoration _inputDeco() => InputDecoration(
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

  @override
  Widget build(BuildContext context) {
    final hasOtherMaps = widget.editorState.project.maps.length > 1;
    return Column(
      children: [
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
        trigger: r.trigger,
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
      backgroundColor: const Color(0xFF201E1C),
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
