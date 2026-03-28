import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_effect.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../theme/app_theme.dart';

// ── Category UI metadata ─────────────────────────────────────────────────────

class _CatInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _CatInfo(this.label, this.icon, this.color);
}

const _tCats = <TriggerCategory, _CatInfo>{
  TriggerCategory.input:  _CatInfo('Input',  Icons.keyboard,        Color(0xFF5B8DEF)),
  TriggerCategory.player: _CatInfo('Player', Icons.person,          Color(0xFF4CAF50)),
  TriggerCategory.enemy:  _CatInfo('Enemy',  Icons.smart_toy,       Color(0xFFEF5350)),
  TriggerCategory.game:   _CatInfo('Game',   Icons.videogame_asset, Color(0xFFAB47BC)),
};

const _aCats = <ActionCategory, _CatInfo>{
  ActionCategory.player:  _CatInfo('Player',  Icons.person,          Color(0xFF4CAF50)),
  ActionCategory.enemy:   _CatInfo('Enemy',   Icons.smart_toy,       Color(0xFFEF5350)),
  ActionCategory.world:   _CatInfo('World',   Icons.public,          Color(0xFF26A69A)),
  ActionCategory.game:    _CatInfo('Game',    Icons.videogame_asset, Color(0xFFAB47BC)),
  ActionCategory.audio:   _CatInfo('Audio',   Icons.music_note,      Color(0xFFFF7043)),
  ActionCategory.effects: _CatInfo('Effects', Icons.auto_awesome,    Color(0xFF7C4DFF)),
};

// ── Per-item UI metadata ─────────────────────────────────────────────────────

extension _TriggerUI on TriggerType {
  IconData get icon => switch (this) {
        TriggerType.keyUpPressed             => Icons.keyboard_arrow_up,
        TriggerType.keyDownPressed           => Icons.keyboard_arrow_down,
        TriggerType.keyLeftPressed           => Icons.keyboard_arrow_left,
        TriggerType.keyRightPressed          => Icons.keyboard_arrow_right,
        TriggerType.keySpacePressed          => Icons.space_bar,
        TriggerType.keyUpReleased    => Icons.keyboard_arrow_up,
        TriggerType.keyDownReleased  => Icons.keyboard_arrow_down,
        TriggerType.keyLeftReleased  => Icons.keyboard_arrow_left,
        TriggerType.keyRightReleased => Icons.keyboard_arrow_right,
        TriggerType.keySpaceReleased => Icons.space_bar,
        TriggerType.playerTouchesEnemy       => Icons.dangerous,
        TriggerType.playerTouchesCollectible => Icons.star_outline,
        TriggerType.playerTouchesDoor        => Icons.meeting_room,
        TriggerType.playerTouchesNpc         => Icons.chat_bubble_outline,
        TriggerType.enemyNearPlayer          => Icons.track_changes,
        TriggerType.playerHealthZero         => Icons.heart_broken,
        TriggerType.gameStart                => Icons.play_circle_outline,
        TriggerType.onTimer                  => Icons.timer,
        TriggerType.playerEntersWater        => Icons.water,
        TriggerType.playerExitsWater         => Icons.water_drop_outlined,
        TriggerType.playerFishes             => Icons.set_meal,
        TriggerType.playerTouchesHazard      => Icons.warning_amber,
        TriggerType.playerActivatesCheckpoint => Icons.flag,
        TriggerType.enemyDefeated            => Icons.emoji_events,
        TriggerType.playerAttacks            => Icons.sports_martial_arts

      };

  String get shortLabel => switch (this) {
        TriggerType.keyUpPressed             => 'Up Key',
        TriggerType.keyDownPressed           => 'Down Key',
        TriggerType.keyLeftPressed           => 'Left Key',
        TriggerType.keyRightPressed          => 'Right Key',
        TriggerType.keySpacePressed          => 'Space Key',
        TriggerType.keyUpReleased    => 'Up Released',
        TriggerType.keyDownReleased  => 'Down Released',
        TriggerType.keyLeftReleased  => 'Left Released',
        TriggerType.keyRightReleased => 'Right Released',
        TriggerType.keySpaceReleased => 'Space Released',
        TriggerType.playerTouchesEnemy       => 'Touches Enemy',
        TriggerType.playerTouchesCollectible => 'Picks up Item',
        TriggerType.playerTouchesDoor        => 'Enters Door',
        TriggerType.playerTouchesNpc         => 'Talks to NPC',
        TriggerType.enemyNearPlayer          => 'Enemy Nearby',
        TriggerType.playerHealthZero         => 'Health = 0',
        TriggerType.gameStart                => 'Game Starts',
        TriggerType.onTimer                  => 'Timer',
        TriggerType.playerEntersWater        => 'Enters Water',
        TriggerType.playerExitsWater         => 'Exits Water',
        TriggerType.playerFishes             => 'Fishes',
        TriggerType.playerTouchesHazard      => 'Touches Hazard',
        TriggerType.playerActivatesCheckpoint => 'Activates Checkpoint',
        TriggerType.enemyDefeated            => 'Enemy Defeated',
        TriggerType.playerAttacks => 'Player attacks',
      };

  Color get catColor => _tCats[category]!.color;
}

extension _ActionUI on ActionType {
  IconData get icon => switch (this) {
        ActionType.movePlayer            => Icons.open_with,
        ActionType.enemyChasePlayer      => Icons.directions_run,
        ActionType.enemyPatrol           => Icons.sync_alt,
        ActionType.enemyStopMoving       => Icons.stop,
        ActionType.adjustHealth          => Icons.favorite,
        ActionType.adjustScore           => Icons.star,
        ActionType.destroyTriggerObject  => Icons.delete_outline,
        ActionType.showMessage           => Icons.chat_bubble_outline,
        ActionType.loadMap               => Icons.map,
        ActionType.gameOver              => Icons.cancel,
        ActionType.winGame               => Icons.emoji_events,
        ActionType.playMusic             => Icons.music_note,
        ActionType.playSfx               => Icons.volume_up,
        ActionType.stopMusic             => Icons.music_off,
        ActionType.setScale              => Icons.photo_size_select_small,
        ActionType.setRotation           => Icons.rotate_right,
        ActionType.adjustRotation        => Icons.rotate_right,
        ActionType.flipH                 => Icons.flip,
        ActionType.flipV                 => Icons.flip,
        ActionType.setFlipH              => Icons.flip,
        ActionType.setFlipV              => Icons.flip,
        ActionType.hideObject            => Icons.visibility_off,
        ActionType.showObject            => Icons.visibility,
        ActionType.fadeIn                => Icons.gradient,
        ActionType.fadeOut               => Icons.gradient,
        ActionType.setAlpha              => Icons.opacity,
        ActionType.launchProjectile      => Icons.rocket_launch,
        ActionType.stopProjectile        => Icons.cancel_schedule_send,
        ActionType.playEffect            => Icons.auto_fix_high,
        ActionType.shakeCamera           => Icons.vibration,
        ActionType.playAnimation => Icons.play_circle_outline,
        ActionType.stopAnimation => Icons.stop_circle_outlined,
        ActionType.dealDamage    => Icons.gavel,
      };

  String get shortLabel => switch (this) {
        ActionType.movePlayer            => 'Move Player',
        ActionType.enemyChasePlayer      => 'Chase Player',
        ActionType.enemyPatrol           => 'Patrol',
        ActionType.enemyStopMoving       => 'Stop Moving',
        ActionType.adjustHealth          => 'Adjust Health',
        ActionType.adjustScore           => 'Adjust Score',
        ActionType.destroyTriggerObject  => 'Destroy Object',
        ActionType.showMessage           => 'Show Message',
        ActionType.loadMap               => 'Load Map',
        ActionType.gameOver              => 'Game Over',
        ActionType.winGame               => 'Win Game',
        ActionType.playMusic             => 'Play Music',
        ActionType.playSfx               => 'Play SFX',
        ActionType.stopMusic             => 'Stop Music',
        ActionType.setScale              => 'Set Scale',
        ActionType.setRotation           => 'Set Rotation',
        ActionType.adjustRotation        => 'Adjust Rotation',
        ActionType.flipH                 => 'Flip Horizontal',
        ActionType.flipV                 => 'Flip Vertical',
        ActionType.setFlipH              => 'Set Flip H',
        ActionType.setFlipV              => 'Set Flip V',
        ActionType.hideObject            => 'Hide Object',
        ActionType.showObject            => 'Show Object',
        ActionType.fadeIn                => 'Fade In',
        ActionType.fadeOut               => 'Fade Out',
        ActionType.setAlpha              => 'Set Opacity',
        ActionType.launchProjectile      => 'Launch Projectile',
        ActionType.stopProjectile        => 'Stop Projectile',
        ActionType.playEffect            => 'Play Effect',
        ActionType.shakeCamera           => 'Shake Camera',
        ActionType.playAnimation => 'Play Animation',
        ActionType.stopAnimation => 'Stop Animation',
        ActionType.dealDamage => 'Deal damage to enemies',
      };

  Color get catColor => _aCats[category]!.color;
}

// ── Picker data types ─────────────────────────────────────────────────────────

class _PickerItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final Color color;
  const _PickerItem(this.value, this.icon, this.label, this.color);
}

class _PickerSection<T> {
  final String catLabel;
  final IconData catIcon;
  final Color catColor;
  final List<_PickerItem<T>> items;
  const _PickerSection(this.catLabel, this.catIcon, this.catColor, this.items);
}

List<_PickerSection<TriggerType>> _triggerSections() {
  return TriggerCategory.values.map((cat) {
    final info = _tCats[cat]!;
    /* final items = TriggerType.values
        .where((t) => t.category == cat)
        .map((t) => _PickerItem<TriggerType>(t, t.icon, t.shortLabel, info.color))
        .toList(); */
    final items = TriggerType.values
        .where((t) => t.category == cat)
        .map((t) => _PickerItem<TriggerType>(t, t.icon, "", info.color))
        .toList();
    return _PickerSection<TriggerType>(info.label, info.icon, info.color, items);
  }).toList();
}

List<_PickerSection<ActionType>> _actionSections() {
  return ActionCategory.values.map((cat) {
    final info = _aCats[cat]!;
    final items = ActionType.values
        .where((a) => a.category == cat)
        .map((a) => _PickerItem<ActionType>(a, a.icon, a.shortLabel, info.color))
        .toList();
    return _PickerSection<ActionType>(info.label, info.icon, info.color, items);
  }).toList();
}

// ── Category picker dialog ────────────────────────────────────────────────────

class _CategoryPickerDialog<T> extends StatefulWidget {
  final List<_PickerSection<T>> sections;
  final T currentValue;

  const _CategoryPickerDialog({
    required this.sections,
    required this.currentValue,
    super.key,
  });

  @override
  State<_CategoryPickerDialog<T>> createState() =>
      _CategoryPickerDialogState<T>();
}

class _CategoryPickerDialogState<T> extends State<_CategoryPickerDialog<T>> {
  late int _catIdx;

  @override
  void initState() {
    super.initState();
    _catIdx = 0;
    for (int i = 0; i < widget.sections.length; i++) {
      if (widget.sections[i].items.any((it) => it.value == widget.currentValue)) {
        _catIdx = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.sections[_catIdx];
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.dialogBorder),
      ),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCategoryRow(),
            _buildGrid(section),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.dialogBorder)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: widget.sections.asMap().entries.map((e) {
          final idx = e.key;
          final sec = e.value;
          final selected = idx == _catIdx;
          return GestureDetector(
            onTap: () => setState(() => _catIdx = idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? sec.catColor.withOpacity(0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? sec.catColor : AppColors.dialogBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sec.catIcon,
                      size: 13,
                      color: selected
                          ? sec.catColor
                          : AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    sec.catLabel,
                    style: TextStyle(
                      color: selected
                          ? sec.catColor
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(_PickerSection<T> section) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: section.items.map((item) {
          final selected = item.value == widget.currentValue;
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(item.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 200,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? item.color.withOpacity(0.14)
                    : AppColors.dialogSurface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected ? item.color : AppColors.dialogBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(item.icon,
                      size: 16,
                      color: selected ? item.color : AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: selected ? item.color : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Rule Editor Dialog ────────────────────────────────────────────────────────

class RuleEditorDialog extends StatefulWidget {
  final GameRule? existing;
  final List<ProjectMap> availableMaps;
  final List<GameEffect> availableEffects;
  final Map<String, String> keyBindings;

  const RuleEditorDialog({
    super.key,
    this.existing,
    this.availableMaps = const [],
    this.availableEffects = const [],
    this.keyBindings = const {},
  });

  static Future<GameRule?> show(BuildContext context,
      {GameRule? existing,
      List<ProjectMap> availableMaps = const [],
      List<GameEffect> availableEffects = const [],
      Map<String, String> keyBindings = const {}}) {
    return showDialog<GameRule>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => RuleEditorDialog(
        existing: existing,
        availableMaps: availableMaps,
        availableEffects: availableEffects,
        keyBindings: keyBindings,
      ),
    );
  }

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _intervalCtrl;
  late List<_ConditionEntry> _conditions;
  late List<ConditionOp> _operators;
  late List<_ActionEntry> _actions;
  late Map<String, dynamic> _triggerParams;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _nameCtrl = TextEditingController(text: r?.name ?? 'New Rule');
    _triggerParams = r != null ? Map<String, dynamic>.from(r.triggerParams) : {};
    _intervalCtrl = TextEditingController(
        text: (_triggerParams['interval'] as num?)?.toString() ?? '1.0');
    if (r != null) {
      _conditions = r.conditions
          .map((c) => _ConditionEntry(trigger: c.trigger, negate: c.negate))
          .toList();
      _operators = List.from(r.operators);
    } else {
      _conditions = [_ConditionEntry(trigger: TriggerType.playerTouchesEnemy)];
      _operators = [];
    }
    _actions = r == null
        ? []
        : r.actions
            .map((a) => _ActionEntry(
                  type: a.type,
                  params: Map<String, dynamic>.from(a.params),
                ))
            .toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  void _addCondition() {
    setState(() {
      _conditions.add(_ConditionEntry(trigger: TriggerType.playerTouchesEnemy));
      _operators.add(ConditionOp.and);
    });
  }

  void _removeCondition(int i) {
    setState(() {
      _conditions.removeAt(i);
      if (i > 0) _operators.removeAt(i - 1);
      else if (_operators.isNotEmpty) _operators.removeAt(0);
    });
  }

  void _addAction() {
    setState(() {
      _actions.add(_ActionEntry(type: ActionType.adjustHealth, params: {}));
    });
  }

  void _removeAction(int i) => setState(() => _actions.removeAt(i));

  Future<void> _pickCondition(int index) async {
    final picked = await showDialog<TriggerType>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _CategoryPickerDialog<TriggerType>(
        sections: _triggerSections(),
        currentValue: _conditions[index].trigger,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _conditions[index].trigger = picked);
    }
  }

  Future<void> _pickAction(int index) async {
    final picked = await showDialog<ActionType>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _CategoryPickerDialog<ActionType>(
        sections: _actionSections(),
        currentValue: _actions[index].type,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _actions[index] = _ActionEntry(type: picked, params: {}));
    }
  }

  void _save() {
    final name =
        _nameCtrl.text.trim().isEmpty ? 'New Rule' : _nameCtrl.text.trim();
    // Ensure interval is committed from the text field
    if (_conditions[0].trigger == TriggerType.onTimer) {
      final v = double.tryParse(_intervalCtrl.text);
      if (v != null && v > 0) _triggerParams['interval'] = v;
      _triggerParams.putIfAbsent('interval', () => 1.0);
    }
    final rule = GameRule(
      id: widget.existing?.id,
      name: name,
      conditions: _conditions
          .map((c) => RuleCondition(trigger: c.trigger, negate: c.negate))
          .toList(),
      operators: List.from(_operators),
      enabled: widget.existing?.enabled ?? true,
      actions: _actions
          .map((e) => RuleAction(type: e.type, params: Map.from(e.params)))
          .toList(),
      triggerParams: Map.from(_triggerParams),
    );
    Navigator.of(context).pop(rule);
  }

  /// Returns display label for a trigger, appending the bound key if remapped.
  String _triggerLabel(TriggerType t) {
    final base = "";
    //final base = t.shortLabel;
    final bound = widget.keyBindings[t.name];
    if (bound == null || bound.isEmpty) return base;
    return '$base [${bound.toUpperCase()}]';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.dialogBorder),
      ),
      child: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 14),
                    _buildTriggerSection(),
                    const SizedBox(height: 14),
                    _buildActionsSection(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.dialogBorder)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 16),
            const SizedBox(width: 8),
            Text(
              widget.existing == null ? 'New Rule' : 'Edit Rule',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close,
                  color: AppColors.textSecondary, size: 16),
            ),
          ],
        ),
      );

  // ── Name ────────────────────────────────────────────────────────────────

  Widget _buildNameField() => TextField(
        controller: _nameCtrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Rule name…',
          hintStyle:
              const TextStyle(color: AppColors.textMuted, fontSize: 12),
          filled: true,
          fillColor: AppColors.dialogSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.dialogBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.dialogBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      );

  // ── WHEN ────────────────────────────────────────────────────────────────

  Widget _buildTriggerSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('WHEN', AppColors.accent),
              const Spacer(),
              GestureDetector(
                onTap: _addCondition,
                child: const Row(
                  children: [
                    Icon(Icons.add_circle_outline, size: 13, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text('Add Condition',
                        style: TextStyle(color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.dialogSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.dialogBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: List.generate(_conditions.length, (i) {
                  return Column(
                    children: [
                      if (i > 0) _buildOperatorRow(i - 1),
                      _buildConditionRow(i),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (_conditions[0].trigger == TriggerType.onTimer) ...[
            const SizedBox(height: 8),
            _buildTimerIntervalRow(),
          ],
        ],
      );

  Widget _buildTimerIntervalRow() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.dialogSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.dialogBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
            const Text('Every',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              height: 30,
              child: TextField(
                controller: _intervalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: '1.0',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.dialogBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
                onChanged: (v) {
                  final n = double.tryParse(v);
                  if (n != null && n > 0) setState(() => _triggerParams['interval'] = n);
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('seconds',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _buildConditionRow(int i) {
    final cond = _conditions[i];
    final isPrimary = i == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      child: Row(
        children: [
          if (!isPrimary) ...[
            GestureDetector(
              onTap: () => setState(() => cond.negate = !cond.negate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: cond.negate
                      ? AppColors.error.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: cond.negate ? AppColors.error : AppColors.dialogBorder,
                  ),
                ),
                child: Text(
                  'NOT',
                  style: TextStyle(
                    color: cond.negate ? AppColors.error : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _pickerButton(
              icon: cond.trigger.icon,
              label: _triggerLabel(cond.trigger),
              color: cond.trigger.catColor,
              onTap: () => _pickCondition(i),
            ),
          ),
          if (_conditions.length > 1) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeCondition(i),
              child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatorRow(int opIndex) {
    final op = _operators[opIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.dialogBorder),
          bottom: BorderSide(color: AppColors.dialogBorder),
        ),
        color: AppColors.dialogBg,
      ),
      child: Row(
        children: [
          _opChip('AND', op == ConditionOp.and,
              onTap: () => setState(() => _operators[opIndex] = ConditionOp.and)),
          const SizedBox(width: 6),
          _opChip('OR', op == ConditionOp.or,
              onTap: () => setState(() => _operators[opIndex] = ConditionOp.or)),
        ],
      ),
    );
  }

  Widget _opChip(String label, bool selected, {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.dialogBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      );

  // ── THEN ────────────────────────────────────────────────────────────────

  Widget _buildActionsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('THEN', AppColors.success),
              const Spacer(),
              GestureDetector(
                onTap: _addAction,
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        size: 13, color: AppColors.accent),
                    const SizedBox(width: 4),
                    const Text('Add Action',
                        style: TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_actions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No actions — tap Add Action',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.dialogSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.dialogBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: _actions.asMap().entries.expand((e) {
                    final rows = <Widget>[];
                    if (e.key > 0) {
                      rows.add(const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.dialogBorder));
                    }
                    rows.add(_buildActionRow(e.key, e.value));
                    return rows;
                  }).toList(),
                ),
              ),
            ),
        ],
      );

  Widget _buildActionRow(int index, _ActionEntry entry) {
    final paramDefs = entry.type.params;
    final hasInline = paramDefs.length == 1;
    final hasExtra = paramDefs.length > 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 7, 10, hasExtra ? 8 : 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _pickerButton(
                  icon: entry.type.icon,
                  label: entry.type.shortLabel,
                  color: entry.type.catColor,
                  onTap: () => _pickAction(index),
                ),
              ),
              if (hasInline) ...[
                const SizedBox(width: 8),
                _compactParam(index, entry, paramDefs[0]),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeAction(index),
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
          if (hasExtra) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: paramDefs
                  .where((p) {
                    if (p.key == 'objectName') return entry.params['target'] == 'named';
                    if (p.key == 'tag') return entry.params['target'] == 'tag';
                    return true;
                  })
                  .map((p) => _compactParam(index, entry, p))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _compactParam(int index, _ActionEntry entry, ActionParam p) {
    // Conditional fields — only shown when target matches
    if (p.key == 'objectName') {
      final target = entry.params['target'] as String? ?? '';
      if (target != 'named') return const SizedBox.shrink();
    }
    if (p.key == 'tag') {
      final target = entry.params['target'] as String? ?? '';
      if (target != 'tag') return const SizedBox.shrink();
    }

    // Choice param: render as a compact dropdown
    if (p.type == ActionParamType.choice && p.choices != null) {
      final choices = p.choices!;
      final cur = entry.params[p.key] as String? ?? choices.keys.first;
      final safeVal = choices.containsKey(cur) ? cur : choices.keys.first;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${p.label}:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: safeVal,
              dropdownColor: AppColors.dialogSurface,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.dialogBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              ),
              items: choices.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => entry.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Effect name: show dropdown of saved effect names
    if ((p.key == 'effectName' || p.key == 'landEffectName') &&
        widget.availableEffects.isNotEmpty) {
      final cur = entry.params[p.key] as String? ?? '';
      final names = widget.availableEffects.map((e) => e.name).toList();
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
              dropdownColor: AppColors.dialogSurface,
              hint: const Text('Pick effect',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.dialogBg,
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
              items: names
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => entry.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Map name: use a compact dropdown
    if (p.key == 'mapName' && widget.availableMaps.isNotEmpty) {
      final cur = entry.params[p.key] as String? ?? '';
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
              value:
                  widget.availableMaps.any((m) => m.name == cur) ? cur : null,
              dropdownColor: AppColors.dialogSurface,
              hint: const Text('Pick map',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11)),
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              isDense: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.dialogBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
              ),
              items: widget.availableMaps
                  .map((m) => DropdownMenuItem(
                        value: m.name,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => entry.params[p.key] = v);
              },
            ),
          ),
        ],
      );
    }

    // Number / text inline field
    final ctrl =
        TextEditingController(text: entry.params[p.key]?.toString() ?? '');
    final isNum = p.type == ActionParamType.number;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${p.label}:',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(width: 6),
        SizedBox(
          width: isNum ? 58 : 110,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(signed: true)
                : TextInputType.text,
            inputFormatters: isNum
                ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
                : null,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: p.hint,
              hintStyle:
                  const TextStyle(color: AppColors.textMuted, fontSize: 11),
              filled: true,
              fillColor: AppColors.dialogBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
            ),
            onChanged: (v) {
              if (isNum) {
                entry.params[p.key] = int.tryParse(v) ?? 0;
              } else {
                entry.params[p.key] = v;
              }
            },
          ),
        ),
      ],
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.dialogBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _btn('Cancel',
                outlined: true, onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 8),
            _btn('Save Rule', onTap: _save),
          ],
        ),
      );

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.dialogBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.dialogBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.unfold_more,
                  size: 13, color: AppColors.textMuted),
            ],
          ),
        ),
      );

  Widget _btn(String label,
          {required VoidCallback onTap, bool outlined = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : AppColors.accent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: outlined ? AppColors.dialogBorder : AppColors.accent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: outlined ? AppColors.textSecondary : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}

class _ActionEntry {
  ActionType type;
  Map<String, dynamic> params;
  _ActionEntry({required this.type, required this.params});
}

class _ConditionEntry {
  TriggerType trigger;
  bool negate;
  _ConditionEntry({required this.trigger, this.negate = false});
}
