import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/item_def.dart';
import '../../theme/app_theme.dart';

class ItemsDialog extends StatefulWidget {
  final List<ItemDef> items;
  final VoidCallback onChanged;

  const ItemsDialog._({required this.items, required this.onChanged});

  static Future<void> show(
    BuildContext context, {
    required List<ItemDef> items,
    required VoidCallback onChanged,
  }) =>
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => ItemsDialog._(items: items, onChanged: onChanged),
      );

  @override
  State<ItemsDialog> createState() => _ItemsDialogState();
}

// ─── Presets ──────────────────────────────────────────────────────────────────

class _Preset {
  final String name;
  final IconData icon;
  final ItemDef Function(String id) build;
  const _Preset(this.name, this.icon, this.build);
}

final _kPresets = [
  _Preset('Sword', Icons.sports_martial_arts, (id) => ItemDef(
    id: id, name: 'Sword', category: WeaponCategory.melee,
    combatDamage: 3.0, combatRange: 1.5, cooldown: 0.6, reach: 1.5,
  )),
  _Preset('Knife', Icons.content_cut, (id) => ItemDef(
    id: id, name: 'Knife', category: WeaponCategory.melee,
    combatDamage: 1.5, combatRange: 1.0, cooldown: 0.3, reach: 1.0,
  )),
  _Preset('Axe', Icons.forest, (id) => ItemDef(
    id: id, name: 'Axe', category: WeaponCategory.melee,
    combatDamage: 4.0, combatRange: 1.2, cooldown: 0.9,
    toolType: ToolType.axe, toolPower: 2.0, reach: 1.2,
  )),
  _Preset('Hammer', Icons.handyman, (id) => ItemDef(
    id: id, name: 'Hammer', category: WeaponCategory.melee,
    combatDamage: 5.0, combatRange: 1.0, cooldown: 1.2,
    toolType: ToolType.hammer, toolPower: 3.0, reach: 1.0,
  )),
  _Preset('Pickaxe', Icons.hardware, (id) => ItemDef(
    id: id, name: 'Pickaxe', category: WeaponCategory.tool,
    combatDamage: 1.0, combatRange: 1.0, cooldown: 0.8,
    toolType: ToolType.pickaxe, toolPower: 2.5, reach: 1.2,
  )),
  _Preset('Shovel', Icons.landscape, (id) => ItemDef(
    id: id, name: 'Shovel', category: WeaponCategory.tool,
    combatDamage: 0.5, combatRange: 1.0, cooldown: 0.8,
    toolType: ToolType.shovel, toolPower: 2.0, reach: 1.0,
  )),
  _Preset('Bow', Icons.adjust, (id) => ItemDef(
    id: id, name: 'Bow', category: WeaponCategory.ranged,
    combatDamage: 2.0, combatRange: 8.0, cooldown: 0.8,
    isProjectile: true, projectileSpeed: 280.0, ammo: -1, reach: 1.0,
  )),
  _Preset('Gun', Icons.radio_button_checked, (id) => ItemDef(
    id: id, name: 'Gun', category: WeaponCategory.ranged,
    combatDamage: 3.0, combatRange: 10.0, cooldown: 0.4,
    isProjectile: true, projectileSpeed: 500.0, ammo: 12, reach: 1.0,
  )),
  _Preset('Bomb', Icons.local_fire_department, (id) => ItemDef(
    id: id, name: 'Bomb', category: WeaponCategory.ranged,
    combatDamage: 6.0, combatRange: 4.0, cooldown: 2.0,
    isProjectile: true, projectileSpeed: 180.0, ammo: 3, reach: 1.0,
  )),
];

// ─── Dialog State ─────────────────────────────────────────────────────────────

class _ItemsDialogState extends State<ItemsDialog> {
  int _selected = -1;

  List<ItemDef> get _items => widget.items;

  void _addPreset(_Preset preset) {
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _items.add(preset.build(id));
      _selected = _items.length - 1;
    });
    widget.onChanged();
  }

  void _addBlank() {
    final id = 'item_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _items.add(ItemDef(id: id, name: 'New Item'));
      _selected = _items.length - 1;
    });
    widget.onChanged();
  }

  void _remove(int idx) {
    setState(() {
      _items.removeAt(idx);
      _selected = _items.isEmpty ? -1 : (_selected >= _items.length ? _items.length - 1 : _selected);
    });
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
        width: 620,
        height: MediaQuery.of(context).size.height * 0.80,
        child: Column(
          children: [
            // ── Title bar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_martial_arts,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  const Text('Items & Weapons',
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

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Row(
                children: [
                  // Left: item list
                  Container(
                    width: 180,
                    decoration: const BoxDecoration(
                      border: Border(
                          right: BorderSide(color: AppColors.borderColor)),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _items.isEmpty
                              ? const Center(
                                  child: Text('Pick a preset\nor add blank',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                )
                              : ListView.builder(
                                  itemCount: _items.length,
                                  itemBuilder: (_, i) {
                                    final item = _items[i];
                                    final sel = _selected == i;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _selected = i),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 9),
                                        color: sel
                                            ? AppColors.accent.withOpacity(0.12)
                                            : Colors.transparent,
                                        child: Row(
                                          children: [
                                            Icon(item.category.icon,
                                                size: 14,
                                                color: sel
                                                    ? AppColors.accent
                                                    : AppColors.textMuted),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: TextStyle(
                                                  color: sel
                                                      ? AppColors.textPrimary
                                                      : AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1, color: AppColors.borderColor),
                        // Presets grid
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Add preset:',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 10)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: _kPresets.map((p) => GestureDetector(
                              onTap: () => _addPreset(p),
                              child: Tooltip(
                                message: p.name,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBg,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppColors.borderColor),
                                  ),
                                  child: Icon(p.icon, size: 14, color: AppColors.textSecondary),
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.borderColor),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: GestureDetector(
                            onTap: _addBlank,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 13, color: AppColors.textMuted),
                                  SizedBox(width: 4),
                                  Text('Blank Item',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: edit form
                  Expanded(
                    child: _selected < 0 || _selected >= _items.length
                        ? const Center(
                            child: Text('Select an item to edit',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                          )
                        : _ItemEditForm(
                            key: ValueKey(_items[_selected].id),
                            item: _items[_selected],
                            onChanged: widget.onChanged,
                            onDelete: () => _remove(_selected),
                          ),
                  ),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item Edit Form ───────────────────────────────────────────────────────────

class _ItemEditForm extends StatefulWidget {
  final ItemDef item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ItemEditForm({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ItemEditForm> createState() => _ItemEditFormState();
}

class _ItemEditFormState extends State<_ItemEditForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _damageCtrl;
  late final TextEditingController _rangeCtrl;
  late final TextEditingController _cooldownCtrl;
  late final TextEditingController _speedCtrl;
  late final TextEditingController _toolPowerCtrl;
  late final TextEditingController _reachCtrl;
  late final TextEditingController _ammoCtrl;

  ItemDef get _item => widget.item;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController(text: _item.name);
    _damageCtrl   = TextEditingController(text: _item.combatDamage.toString());
    _rangeCtrl    = TextEditingController(text: _item.combatRange.toString());
    _cooldownCtrl = TextEditingController(text: _item.cooldown.toString());
    _speedCtrl    = TextEditingController(text: _item.projectileSpeed.toString());
    _toolPowerCtrl = TextEditingController(text: _item.toolPower.toString());
    _reachCtrl    = TextEditingController(text: _item.reach.toString());
    _ammoCtrl     = TextEditingController(text: _item.ammo.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _damageCtrl.dispose();
    _rangeCtrl.dispose();
    _cooldownCtrl.dispose();
    _speedCtrl.dispose();
    _toolPowerCtrl.dispose();
    _reachCtrl.dispose();
    _ammoCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + delete
          Row(
            children: [
              Expanded(
                child: _field('Name', _nameCtrl, onChanged: (v) {
                  _item.name = v;
                  _notify();
                }),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: AppColors.error.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category
          _sectionLabel('CATEGORY'),
          const SizedBox(height: 8),
          Row(
            children: WeaponCategory.values.map((cat) {
              final sel = _item.category == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    _item.category = cat;
                    _notify();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.surfaceBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sel
                            ? AppColors.accent.withOpacity(0.6)
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(cat.icon,
                            size: 13,
                            color: sel
                                ? AppColors.accent
                                : AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text(cat.label,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Combat section ────────────────────────────────────────────────
          _sectionLabel('COMBAT'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _field('Damage', _damageCtrl,
                      isDecimal: true,
                      onChanged: (v) =>
                          _item.combatDamage = double.tryParse(v) ?? _item.combatDamage)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('Range (tiles)', _rangeCtrl,
                      isDecimal: true,
                      onChanged: (v) =>
                          _item.combatRange = double.tryParse(v) ?? _item.combatRange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('Cooldown (s)', _cooldownCtrl,
                      isDecimal: true,
                      onChanged: (v) =>
                          _item.cooldown = double.tryParse(v) ?? _item.cooldown)),
            ],
          ),

          if (_item.category == WeaponCategory.ranged) ...[
            const SizedBox(height: 12),
            _toggle('Fires projectile', _item.isProjectile, (v) {
              _item.isProjectile = v;
              _notify();
            }),
            if (_item.isProjectile) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _field('Speed (px/s)', _speedCtrl,
                          isDecimal: true,
                          onChanged: (v) =>
                              _item.projectileSpeed =
                                  double.tryParse(v) ?? _item.projectileSpeed)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _toggle(
                        'Piercing', _item.piercing, (v) {
                      _item.piercing = v;
                      _notify();
                    }),
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 16),

          // ── Tool section ──────────────────────────────────────────────────
          _sectionLabel('TOOL'),
          const SizedBox(height: 4),
          const Text(
            'What this item can break or build in the world.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _toolTypeRow(),
          if (_item.toolType != ToolType.none) ...[
            const SizedBox(height: 10),
            _field('Tool Power', _toolPowerCtrl,
                isDecimal: true,
                onChanged: (v) =>
                    _item.toolPower = double.tryParse(v) ?? _item.toolPower),
          ],

          const SizedBox(height: 16),

          // ── Shared ────────────────────────────────────────────────────────
          _sectionLabel('SHARED'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _field('Reach (tiles)', _reachCtrl,
                      isDecimal: true,
                      onChanged: (v) =>
                          _item.reach = double.tryParse(v) ?? _item.reach)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field('Ammo (-1 = ∞)', _ammoCtrl,
                      isNumber: true,
                      onChanged: (v) =>
                          _item.ammo = int.tryParse(v) ?? _item.ammo)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolTypeRow() => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: ToolType.values.map((t) {
          final sel = _item.toolType == t;
          return GestureDetector(
            onTap: () {
              _item.toolType = t;
              _notify();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.accent.withOpacity(0.15)
                    : AppColors.surfaceBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: sel
                      ? AppColors.accent.withOpacity(0.6)
                      : AppColors.borderColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(t.icon,
                      size: 12,
                      color: sel ? AppColors.accent : AppColors.textMuted),
                  const SizedBox(width: 5),
                  Text(t.label,
                      style: TextStyle(
                        color:
                            sel ? AppColors.accent : AppColors.textSecondary,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          );
        }).toList(),
      );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
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
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool isDecimal = false,
    bool isNumber = false,
    required ValueChanged<String> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: TextField(
              controller: ctrl,
              keyboardType: (isDecimal || isNumber)
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              inputFormatters: isNumber
                  ? [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))]
                  : isDecimal
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                      : null,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                filled: true,
                fillColor: AppColors.surfaceBg,
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
              onChanged: onChanged,
            ),
          ),
        ],
      );
}
