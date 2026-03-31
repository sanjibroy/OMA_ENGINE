import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_effect.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../theme/app_theme.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

class RulesManagerV2 extends StatefulWidget {
  final List<GameRule> rules;
  final List<ProjectMap> availableMaps;
  final List<GameEffect> availableEffects;
  final List<String> availableAnimations;
  final Map<String, String> keyBindings;
  final VoidCallback onChanged;

  const RulesManagerV2({
    super.key,
    required this.rules,
    required this.availableMaps,
    required this.availableEffects,
    required this.availableAnimations,
    required this.keyBindings,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required List<GameRule> rules,
    required List<ProjectMap> availableMaps,
    required List<GameEffect> availableEffects,
    required List<String> availableAnimations,
    required Map<String, String> keyBindings,
    required VoidCallback onChanged,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => RulesManagerV2(
        rules: rules,
        availableMaps: availableMaps,
        availableEffects: availableEffects,
        availableAnimations: availableAnimations,
        keyBindings: keyBindings,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RulesManagerV2> createState() => _RulesManagerV2State();
}

// ─── State ────────────────────────────────────────────────────────────────────

class _RulesManagerV2State extends State<RulesManagerV2> {
  int _selectedIndex = -1;
  // Working copy of selected rule being edited
  _RuleEdit? _editing;

  List<GameRule> get _rules => widget.rules;

  @override
  void initState() {
    super.initState();
    if (_rules.isNotEmpty) _selectRule(0);
  }

  void _selectRule(int index) {
    if (index < 0 || index >= _rules.length) return;
    final r = _rules[index];
    setState(() {
      _selectedIndex = index;
      _editing = _RuleEdit.fromRule(r);
    });
  }

  void _addRule() {
    final rule = GameRule(
      name: TriggerType.gameStart.label,
      conditions: [RuleCondition(trigger: TriggerType.gameStart)],
    );
    setState(() {
      _rules.add(rule);
      _selectRule(_rules.length - 1);
    });
    widget.onChanged();
  }

  void _duplicateRule(int index) {
    _saveEditing();
    final source = _rules[index];
    final copy = GameRule(
      name: '${source.name} (copy)',
      conditions: source.conditions
          .map((c) => RuleCondition(trigger: c.trigger, negate: c.negate))
          .toList(),
      operators: List.from(source.operators),
      actions: source.actions
          .map((a) => RuleAction(type: a.type, params: Map.from(a.params)))
          .toList(),
      enabled: source.enabled,
      triggerParams: Map.from(source.triggerParams),
    );
    setState(() {
      _rules.insert(index + 1, copy);
      _selectRule(index + 1);
    });
    widget.onChanged();
  }

  void _deleteRule(int index) {
    setState(() {
      _rules.removeAt(index);
      if (_selectedIndex >= _rules.length) {
        _selectedIndex = _rules.length - 1;
      }
      if (_selectedIndex >= 0) {
        _selectRule(_selectedIndex);
      } else {
        _editing = null;
      }
    });
    widget.onChanged();
  }

  void _saveEditing() {
    final e = _editing;
    if (e == null || _selectedIndex < 0) return;
    _rules[_selectedIndex] = e.toRule(
        existingId: _rules[_selectedIndex].id,
        existingEnabled: _rules[_selectedIndex].enabled);
    widget.onChanged();
    setState(() {});
  }

  void _toggleRule(int index) {
    setState(() => _rules[index].enabled = !_rules[index].enabled);
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
        width: 900,
        height: 600,
        child: Column(
          children: [
            _buildTitleBar(),
            const Divider(height: 1, color: AppColors.borderColor),
            Expanded(
              child: Row(
                children: [
                  // ── Left: rules list ──────────────────────
                  SizedBox(
                    width: 220,
                    child: _buildRulesList(),
                  ),
                  const VerticalDivider(
                      width: 1, color: AppColors.borderColor),
                  // ── Right: rule editor ────────────────────
                  Expanded(
                    child: _editing != null
                        ? _buildRuleEditor()
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

  // ── Title bar ─────────────────────────────────────────────────────────────

  Widget _buildTitleBar() => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            const Text('Rules Manager',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('${_rules.length} rule${_rules.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const Spacer(),
            // Add rule button
            GestureDetector(
              onTap: _addRule,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 13, color: AppColors.accent),
                    SizedBox(width: 5),
                    Text('New Rule',
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
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.textMuted),
            ),
          ],
        ),
      );

  // ── Rules list ────────────────────────────────────────────────────────────

  Widget _buildRulesList() => Column(
        children: [
          Expanded(
            child: _rules.isEmpty
                ? const Center(
                    child: Text('No rules yet\nTap New Rule to start',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _rules.length,
                    itemBuilder: (_, i) => _buildRuleListItem(i),
                  ),
          ),
        ],
      );

  Widget _buildRuleListItem(int index) {
    final rule = _rules[index];
    final isSelected = index == _selectedIndex;
    return GestureDetector(
      onTap: () {
        // Auto-save current before switching
        _saveEditing();
        _selectRule(index);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withOpacity(0.6)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // Enable toggle dot
            GestureDetector(
              onTap: () => _toggleRule(index),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rule.enabled
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : rule.enabled
                              ? AppColors.textSecondary
                              : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rule.trigger.shortLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            // Duplicate button
            GestureDetector(
              onTap: () => _duplicateRule(index),
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.copy_outlined,
                    size: 12, color: AppColors.textMuted),
              ),
            ),
            // Delete button
            GestureDetector(
              onTap: () => _deleteRule(index),
              child: const Icon(Icons.close,
                  size: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rule editor ───────────────────────────────────────────────────────────

  Widget _buildRuleEditor() {
    final e = _editing!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name ────────────────────────────────────
                _sectionLabel('RULE NAME'),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: e.nameCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: _inputDeco(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 20),

                // ── WHEN section ─────────────────────────────
                Row(
                  children: [
                    _badge('WHEN', AppColors.accent),
                    const Spacer(),
                    _addBtn('Add Condition', () {
                      setState(() {
                        e.conditions.add(_CondEdit(
                            trigger: TriggerType.gameStart));
                        if (e.conditions.length > 1) {
                          e.operators.add(ConditionOp.and);
                        }
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(e.conditions.length, (i) {
                  return Column(
                    children: [
                      if (i > 0) _buildOperatorRow(e, i - 1),
                      _buildConditionRow(e, i),
                      const SizedBox(height: 4),
                    ],
                  );
                }),

                // Timer interval
                if (e.conditions.isNotEmpty &&
                    e.conditions[0].trigger ==
                        TriggerType.onTimer) ...[
                  const SizedBox(height: 8),
                  _buildTimerRow(e),
                ],

                const SizedBox(height: 20),

                // ── THEN section ─────────────────────────────
                Row(
                  children: [
                    _badge('THEN', AppColors.success),
                    const Spacer(),
                    _addBtn('Add Action', () {
                      setState(() => e.actions.add(
                          _ActionEdit(type: ActionType.showMessage)));
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                if (e.actions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No actions — tap Add Action',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12)),
                  )
                else
                  ...List.generate(e.actions.length,
                      (i) => _buildActionRow(e, i)),
              ],
            ),
          ),
        ),

        // ── Save bar ─────────────────────────────────────────
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border:
                Border(top: BorderSide(color: AppColors.borderColor)),
          ),
          child: Row(
            children: [
              // Enabled toggle
              GestureDetector(
                onTap: () {
                  if (_selectedIndex >= 0) {
                    _toggleRule(_selectedIndex);
                  }
                },
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 18,
                      decoration: BoxDecoration(
                        color: (_selectedIndex >= 0 &&
                                _rules[_selectedIndex].enabled)
                            ? AppColors.success
                            : AppColors.borderColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 150),
                        alignment: (_selectedIndex >= 0 &&
                                _rules[_selectedIndex].enabled)
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Enabled',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _saveEditing,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Save Rule',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Condition row ─────────────────────────────────────────────────────────

  Widget _buildConditionRow(_RuleEdit e, int i) {
    final cond = e.conditions[i];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          // NOT toggle (secondary conditions only)
          if (i > 0) ...[
            GestureDetector(
              onTap: () =>
                  setState(() => cond.negate = !cond.negate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: cond.negate
                      ? AppColors.error.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: cond.negate
                        ? AppColors.error
                        : AppColors.borderColor,
                  ),
                ),
                child: Text('NOT',
                    style: TextStyle(
                      color: cond.negate
                          ? AppColors.error
                          : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Trigger dropdown
          Expanded(
            child: _TriggerDropdown(
              value: cond.trigger,
              onChanged: (t) {
                setState(() {
                  // Auto-update name if it matches old trigger label or is default
                  final oldLabel = cond.trigger.label;
                  final currentName = e.nameCtrl.text.trim();
                  if (currentName.isEmpty ||
                      currentName == oldLabel ||
                      currentName == 'New Rule') {
                    e.nameCtrl.text = t.label;
                  }
                  cond.trigger = t;
                });
              },
            ),
          ),

          // Remove button (if more than 1)
          if (e.conditions.length > 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  e.conditions.removeAt(i);
                  if (i > 0 && e.operators.length >= i) {
                    e.operators.removeAt(i - 1);
                  } else if (e.operators.isNotEmpty) {
                    e.operators.removeAt(0);
                  }
                });
              },
              child: const Icon(Icons.close,
                  size: 14, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatorRow(_RuleEdit e, int opIndex) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(width: 10),
            _opChip('AND', e.operators[opIndex] == ConditionOp.and,
                () => setState(
                    () => e.operators[opIndex] = ConditionOp.and)),
            const SizedBox(width: 6),
            _opChip('OR', e.operators[opIndex] == ConditionOp.or,
                () => setState(
                    () => e.operators[opIndex] = ConditionOp.or)),
          ],
        ),
      );

  Widget _buildTimerRow(_RuleEdit e) => Row(
        children: [
          const Icon(Icons.timer,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          const Text('Every',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            height: 30,
            child: TextField(
              controller: e.intervalCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))
              ],
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: _inputDeco(hint: '1.0'),
              onChanged: (v) {
                final n = double.tryParse(v);
                if (n != null && n > 0) e.timerInterval = n;
              },
            ),
          ),
          const SizedBox(width: 8),
          const Text('seconds',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      );

  // ── Action row ────────────────────────────────────────────────────────────

  Widget _buildActionRow(_RuleEdit e, int i) {
    final action = e.actions[i];
    final paramDefs = action.type.params;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Action type dropdown
              Expanded(
                child: _ActionDropdown(
                  value: action.type,
                  onChanged: (t) => setState(() {
                    e.actions[i] =
                        _ActionEdit(type: t, params: {});
                  }),
                ),
              ),
              const SizedBox(width: 8),
              // Remove button
              GestureDetector(
                onTap: () =>
                    setState(() => e.actions.removeAt(i)),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          // Params
          if (paramDefs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: paramDefs
                  .where((p) {
                    if (p.key == 'objectName')
                      return action.params['target'] == 'named';
                    if (p.key == 'tag')
                      return action.params['target'] == 'tag';
                    return true;
                  })
                  .map((p) => _buildParamField(action, p))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParamField(_ActionEdit action, ActionParam p) {
    if (p.type == ActionParamType.choice && p.choices != null) {
      final choices = p.choices!;
      final cur =
          action.params[p.key] as String? ?? choices.keys.first;
      final safeVal =
          choices.containsKey(cur) ? cur : choices.keys.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.label}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: safeVal,
              dropdownColor: AppColors.surfaceBg,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: _inputDeco(),
              items: choices.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null)
                  setState(() => action.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Effect name dropdown
    if ((p.key == 'effectName' || p.key == 'landEffectName') &&
        widget.availableEffects.isNotEmpty) {
      final cur = action.params[p.key] as String? ?? '';
      final names =
          widget.availableEffects.map((e) => e.name).toList();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.label}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              value: names.contains(cur) ? cur : null,
              dropdownColor: AppColors.surfaceBg,
              hint: const Text('Pick effect',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: _inputDeco(),
              items: names
                  .map((n) =>
                      DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) {
                if (v != null)
                  setState(() => action.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Animation name dropdown
    if (p.key == 'animName' &&
        widget.availableAnimations.isNotEmpty) {
      final cur = action.params[p.key] as String? ?? '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.label}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              value: widget.availableAnimations.contains(cur)
                  ? cur
                  : null,
              dropdownColor: AppColors.surfaceBg,
              hint: const Text('Pick animation',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: _inputDeco(),
              items: widget.availableAnimations
                  .map((n) =>
                      DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) {
                if (v != null)
                  setState(() => action.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Map name dropdown
    if (p.key == 'mapName' && widget.availableMaps.isNotEmpty) {
      final cur = action.params[p.key] as String? ?? '';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.label}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              value: widget.availableMaps
                      .any((m) => m.name == cur)
                  ? cur
                  : null,
              dropdownColor: AppColors.surfaceBg,
              hint: const Text('Pick map',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: _inputDeco(),
              items: widget.availableMaps
                  .map((m) => DropdownMenuItem(
                        value: m.name,
                        child: Text(m.name,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null)
                  setState(() => action.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Number / text field
    final isNum = p.type == ActionParamType.number;
    final ctrl = TextEditingController(
        text: action.params[p.key]?.toString() ?? '');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${p.label}:',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(width: 6),
        SizedBox(
          width: isNum ? 62 : 120,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(signed: true)
                : TextInputType.text,
            inputFormatters: isNum
                ? [FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*'))]
                : null,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: _inputDeco(hint: p.hint),
            onChanged: (v) {
              if (isNum) {
                action.params[p.key] = int.tryParse(v) ?? 0;
              } else {
                action.params[p.key] = v;
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: AppColors.textMuted, size: 40),
            SizedBox(height: 10),
            Text('Select a rule to edit',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 14)),
            SizedBox(height: 4),
            Text('or tap New Rule to create one',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.13),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );

  Widget _addBtn(String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline,
                size: 13, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.accent, fontSize: 12)),
          ],
        ),
      );

  Widget _opChip(
          String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.borderColor,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                color: selected
                    ? AppColors.accent
                    : AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
        ),
      );

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        filled: true,
        fillColor: AppColors.dialogBg,
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textMuted, fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 7),
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
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      );
}

Widget _sectionLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );
}

// ─── Trigger dropdown ─────────────────────────────────────────────────────────

class _TriggerDropdown extends StatefulWidget {
  final TriggerType value;
  final void Function(TriggerType) onChanged;

  const _TriggerDropdown(
      {required this.value, required this.onChanged});

  @override
  State<_TriggerDropdown> createState() => _TriggerDropdownState();
}

class _TriggerDropdownState extends State<_TriggerDropdown> {
  static const _catColors = <TriggerCategory, Color>{
    TriggerCategory.input: Color(0xFF5B8DEF),
    TriggerCategory.player: Color(0xFF4CAF50),
    TriggerCategory.enemy: Color(0xFFEF5350),
    TriggerCategory.game: Color(0xFFAB47BC),
  };

  static const _catIcons = <TriggerCategory, IconData>{
    TriggerCategory.input: Icons.keyboard,
    TriggerCategory.player: Icons.person,
    TriggerCategory.enemy: Icons.smart_toy,
    TriggerCategory.game: Icons.videogame_asset,
  };

  static const _triggerIcons = <TriggerType, IconData>{
    TriggerType.keyUpPressed: Icons.keyboard_arrow_up,
    TriggerType.keyDownPressed: Icons.keyboard_arrow_down,
    TriggerType.keyLeftPressed: Icons.keyboard_arrow_left,
    TriggerType.keyRightPressed: Icons.keyboard_arrow_right,
    TriggerType.keySpacePressed: Icons.space_bar,
    TriggerType.keyUpReleased: Icons.keyboard_arrow_up,
    TriggerType.keyDownReleased: Icons.keyboard_arrow_down,
    TriggerType.keyLeftReleased: Icons.keyboard_arrow_left,
    TriggerType.keyRightReleased: Icons.keyboard_arrow_right,
    TriggerType.keySpaceReleased: Icons.space_bar,
    TriggerType.playerTouchesEnemy: Icons.dangerous,
    TriggerType.playerTouchesCollectible: Icons.star_outline,
    TriggerType.playerTouchesDoor: Icons.meeting_room,
    TriggerType.playerTouchesNpc: Icons.chat_bubble_outline,
    TriggerType.playerHealthZero: Icons.heart_broken,
    TriggerType.playerEntersWater: Icons.water,
    TriggerType.playerExitsWater: Icons.water_drop_outlined,
    TriggerType.playerFishes: Icons.set_meal,
    TriggerType.playerTouchesHazard: Icons.warning_amber,
    TriggerType.playerActivatesCheckpoint: Icons.flag,
    TriggerType.enemyNearPlayer: Icons.track_changes,
    TriggerType.enemyDefeated: Icons.emoji_events,
    TriggerType.playerAttacks: Icons.sports_martial_arts,
    TriggerType.gameStart: Icons.play_circle_outline,
    TriggerType.onTimer: Icons.timer,
  };

  TriggerCategory? _selectedCat;

  @override
  Widget build(BuildContext context) {
    final color = _catColors[widget.value.category] ??
        AppColors.accent;
    final icon = _triggerIcons[widget.value] ?? Icons.bolt;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.value.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
            Icon(Icons.unfold_more, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) async {
    final picked = await showDialog<TriggerType>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _TriggerPickerDialog(
        current: widget.value,
        catColors: _catColors,
        catIcons: _catIcons,
        triggerIcons: _triggerIcons,
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }
}

class _TriggerPickerDialog extends StatefulWidget {
  final TriggerType current;
  final Map<TriggerCategory, Color> catColors;
  final Map<TriggerCategory, IconData> catIcons;
  final Map<TriggerType, IconData> triggerIcons;

  const _TriggerPickerDialog({
    required this.current,
    required this.catColors,
    required this.catIcons,
    required this.triggerIcons,
  });

  @override
  State<_TriggerPickerDialog> createState() =>
      _TriggerPickerDialogState();
}

class _TriggerPickerDialogState
    extends State<_TriggerPickerDialog> {
  TriggerCategory? _selectedCat;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCat = null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TriggerType> get _filtered {
    final triggers = _selectedCat != null
        ? TriggerType.values
            .where((t) => t.category == _selectedCat)
            .toList()
        : TriggerType.values.toList();
    if (_search.isEmpty) return triggers;
    return triggers
        .where((t) =>
            t.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('Select Condition',
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
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search conditions…',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // Category filter
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip(null, 'All', Icons.apps,
                        AppColors.textSecondary),
                    ...TriggerCategory.values.map((cat) {
                      final color = widget.catColors[cat] ??
                          AppColors.accent;
                      final icon = widget.catIcons[cat] ??
                          Icons.circle;
                      return _catChip(cat,
                          cat.name[0].toUpperCase() +
                              cat.name.substring(1),
                          icon, color);
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.borderColor),
            // Triggers list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: _filtered.map((t) {
                  final color =
                      widget.catColors[t.category] ??
                          AppColors.accent;
                  final icon =
                      widget.triggerIcons[t] ?? Icons.bolt;
                  final isSelected = t == widget.current;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, t),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? color.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Icon(icon,
                                size: 14, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(t.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? color
                                      : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                          ),
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.category.name[0].toUpperCase() +
                                  t.category.name.substring(1),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
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
    );
  }

  Widget _catChip(TriggerCategory? cat, String label,
      IconData icon, Color color) {
    final selected = _selectedCat == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCat = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? color : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color:
                    selected ? color : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? color
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}


// ─── Action dropdown ──────────────────────────────────────────────────────────

class _ActionDropdown extends StatefulWidget {
  final ActionType value;
  final void Function(ActionType) onChanged;

  const _ActionDropdown(
      {required this.value, required this.onChanged});

  @override
  State<_ActionDropdown> createState() => _ActionDropdownState();
}

class _ActionDropdownState extends State<_ActionDropdown> {
  static const _catColors = <ActionCategory, Color>{
    ActionCategory.player: Color(0xFF4CAF50),
    ActionCategory.enemy: Color(0xFFEF5350),
    ActionCategory.world: Color(0xFF26A69A),
    ActionCategory.game: Color(0xFFAB47BC),
    ActionCategory.audio: Color(0xFFFF7043),
    ActionCategory.effects: Color(0xFF7C4DFF),
  };

  static const _catIcons = <ActionCategory, IconData>{
    ActionCategory.player: Icons.person,
    ActionCategory.enemy: Icons.smart_toy,
    ActionCategory.world: Icons.public,
    ActionCategory.game: Icons.videogame_asset,
    ActionCategory.audio: Icons.music_note,
    ActionCategory.effects: Icons.auto_awesome,
  };

  static const _actionIcons = <ActionType, IconData>{
    ActionType.movePlayer: Icons.open_with,
    ActionType.enemyChasePlayer: Icons.directions_run,
    ActionType.enemyPatrol: Icons.sync_alt,
    ActionType.enemyStopMoving: Icons.stop,
    ActionType.adjustHealth: Icons.favorite,
    ActionType.adjustScore: Icons.star,
    ActionType.destroyTriggerObject: Icons.delete_outline,
    ActionType.showMessage: Icons.chat_bubble_outline,
    ActionType.loadMap: Icons.map,
    ActionType.gameOver: Icons.cancel,
    ActionType.winGame: Icons.emoji_events,
    ActionType.playMusic: Icons.music_note,
    ActionType.playSfx: Icons.volume_up,
    ActionType.stopMusic: Icons.music_off,
    ActionType.setScale: Icons.photo_size_select_small,
    ActionType.setRotation: Icons.rotate_right,
    ActionType.adjustRotation: Icons.rotate_right,
    ActionType.flipH: Icons.flip,
    ActionType.flipV: Icons.flip,
    ActionType.setFlipH: Icons.flip,
    ActionType.setFlipV: Icons.flip,
    ActionType.hideObject: Icons.visibility_off,
    ActionType.showObject: Icons.visibility,
    ActionType.fadeIn: Icons.gradient,
    ActionType.fadeOut: Icons.gradient,
    ActionType.setAlpha: Icons.opacity,
    ActionType.launchProjectile: Icons.rocket_launch,
    ActionType.stopProjectile: Icons.cancel_schedule_send,
    ActionType.playEffect: Icons.auto_fix_high,
    ActionType.shakeCamera: Icons.vibration,
    ActionType.playAnimation: Icons.play_circle_outline,
    ActionType.stopAnimation: Icons.stop_circle_outlined,
    ActionType.dealDamage: Icons.gavel,
    ActionType.enemyAttackPlayer: Icons.auto_fix_normal,
  };

  @override
  Widget build(BuildContext context) {
    final color =
        _catColors[widget.value.category] ?? AppColors.accent;
    final icon =
        _actionIcons[widget.value] ?? Icons.bolt;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.value.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
            Icon(Icons.unfold_more, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) async {
    final picked = await showDialog<ActionType>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _ActionPickerDialog(
        current: widget.value,
        catColors: _catColors,
        catIcons: _catIcons,
        actionIcons: _actionIcons,
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }
}

class _ActionPickerDialog extends StatefulWidget {
  final ActionType current;
  final Map<ActionCategory, Color> catColors;
  final Map<ActionCategory, IconData> catIcons;
  final Map<ActionType, IconData> actionIcons;

  const _ActionPickerDialog({
    required this.current,
    required this.catColors,
    required this.catIcons,
    required this.actionIcons,
  });

  @override
  State<_ActionPickerDialog> createState() =>
      _ActionPickerDialogState();
}

class _ActionPickerDialogState
    extends State<_ActionPickerDialog> {
  ActionCategory? _selectedCat;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCat = null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ActionType> get _filtered {
    final actions = _selectedCat != null
        ? ActionType.values
            .where((a) => a.category == _selectedCat)
            .toList()
        : ActionType.values.toList();
    if (_search.isEmpty) return actions;
    return actions
        .where((a) =>
            a.label.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderColor),
      ),
      child: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('Select Action',
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
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search actions…',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // Category filter
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip(null, 'All', Icons.apps,
                        AppColors.textSecondary),
                    ...ActionCategory.values.map((cat) {
                      final color = widget.catColors[cat] ??
                          AppColors.accent;
                      final icon =
                          widget.catIcons[cat] ?? Icons.circle;
                      return _catChip(
                          cat,
                          cat.name[0].toUpperCase() +
                              cat.name.substring(1),
                          icon,
                          color);
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.borderColor),
            // Actions list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: _filtered.map((a) {
                  final color =
                      widget.catColors[a.category] ??
                          AppColors.accent;
                  final icon =
                      widget.actionIcons[a] ?? Icons.bolt;
                  final isSelected = a == widget.current;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, a),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? color.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Icon(icon,
                                size: 14, color: color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(a.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? color
                                      : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                )),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.category.name[0].toUpperCase() +
                                  a.category.name.substring(1),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600),
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
    );
  }

  Widget _catChip(ActionCategory? cat, String label,
      IconData icon, Color color) {
    final selected = _selectedCat == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCat = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? color
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ─── Edit models ──────────────────────────────────────────────────────────────

class _CondEdit {
  TriggerType trigger;
  bool negate;
  _CondEdit({required this.trigger, this.negate = false});
}

class _ActionEdit {
  ActionType type;
  Map<String, dynamic> params;
  _ActionEdit({required this.type, Map<String, dynamic>? params})
      : params = params ?? {};
}

class _RuleEdit {
  final TextEditingController nameCtrl;
  final TextEditingController intervalCtrl;
  List<_CondEdit> conditions;
  List<ConditionOp> operators;
  List<_ActionEdit> actions;
  double timerInterval;

  _RuleEdit({
    required this.nameCtrl,
    required this.intervalCtrl,
    required this.conditions,
    required this.operators,
    required this.actions,
    required this.timerInterval,
  });

  factory _RuleEdit.fromRule(GameRule r) {
    return _RuleEdit(
      nameCtrl: TextEditingController(text: r.name),
      intervalCtrl: TextEditingController(
          text: (r.triggerParams['interval'] as num?)
                  ?.toString() ??
              '1.0'),
      conditions: r.conditions
          .map((c) =>
              _CondEdit(trigger: c.trigger, negate: c.negate))
          .toList(),
      operators: List.from(r.operators),
      actions: r.actions
          .map((a) => _ActionEdit(
              type: a.type,
              params: Map<String, dynamic>.from(a.params)))
          .toList(),
      timerInterval:
          (r.triggerParams['interval'] as num?)?.toDouble() ??
              1.0,
    );
  }

  GameRule toRule(
      {required String existingId,
      required bool existingEnabled}) {
    final triggerParams = <String, dynamic>{};
    if (conditions.isNotEmpty &&
        conditions[0].trigger == TriggerType.onTimer) {
      triggerParams['interval'] = timerInterval;
    }
    return GameRule(
      id: existingId,
      name: nameCtrl.text.trim().isEmpty
          ? 'New Rule'
          : nameCtrl.text.trim(),
      conditions: conditions
          .map((c) =>
              RuleCondition(trigger: c.trigger, negate: c.negate))
          .toList(),
      operators: List.from(operators),
      actions: actions
          .map((a) =>
              RuleAction(type: a.type, params: Map.from(a.params)))
          .toList(),
      enabled: existingEnabled,
      triggerParams: triggerParams,
    );
  }

  void dispose() {
    nameCtrl.dispose();
    intervalCtrl.dispose();
  }
}