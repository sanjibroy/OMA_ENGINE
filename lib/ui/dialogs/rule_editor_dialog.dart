import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_project.dart';
import '../../models/game_rule.dart';
import '../../theme/app_theme.dart';

class RuleEditorDialog extends StatefulWidget {
  final GameRule? existing;
  final List<ProjectMap> availableMaps;

  const RuleEditorDialog({
    super.key,
    this.existing,
    this.availableMaps = const [],
  });

  static Future<GameRule?> show(BuildContext context,
      {GameRule? existing, List<ProjectMap> availableMaps = const []}) {
    return showDialog<GameRule>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => RuleEditorDialog(
        existing: existing,
        availableMaps: availableMaps,
      ),
    );
  }

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  late final TextEditingController _nameCtrl;
  late TriggerType _trigger;
  late List<_ActionEntry> _actions;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _nameCtrl = TextEditingController(text: r?.name ?? 'New Rule');
    _trigger = r?.trigger ?? TriggerType.playerTouchesEnemy;
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
    super.dispose();
  }

  void _addAction() {
    setState(() {
      _actions.add(_ActionEntry(type: ActionType.adjustHealth, params: {}));
    });
  }

  void _removeAction(int i) => setState(() => _actions.removeAt(i));

  void _save() {
    final name = _nameCtrl.text.trim().isEmpty ? 'New Rule' : _nameCtrl.text.trim();
    final rule = GameRule(
      id: widget.existing?.id,
      name: name,
      trigger: _trigger,
      enabled: widget.existing?.enabled ?? true,
      actions: _actions
          .map((e) => RuleAction(type: e.type, params: Map.from(e.params)))
          .toList(),
    );
    Navigator.of(context).pop(rule);
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
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 20),
                    _buildTriggerSection(),
                    const SizedBox(height: 20),
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

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.dialogBorder)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 18),
            const SizedBox(width: 10),
            Text(
              widget.existing == null ? 'New Rule' : 'Edit Rule',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close,
                  color: AppColors.textSecondary, size: 18),
            ),
          ],
        ),
      );

  Widget _buildNameField() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('RULE NAME'),
          const SizedBox(height: 6),
          _textField(_nameCtrl, hint: 'e.g. Player takes damage'),
        ],
      );

  Widget _buildTriggerSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('WHEN'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dialogSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.dialogBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('WHEN',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
                const SizedBox(width: 10),
                Expanded(child: _dropdown<TriggerType>(
                  value: _trigger,
                  items: TriggerType.values,
                  labelOf: (t) => t.label,
                  onChanged: (t) => setState(() => _trigger = t!),
                )),
              ],
            ),
          ),
        ],
      );

  Widget _buildActionsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('THEN'),
          const SizedBox(height: 8),
          if (_actions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text('No actions yet',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ..._actions.asMap().entries.map((e) => _buildActionRow(e.key, e.value)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _addAction,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.accent.withOpacity(0.4),
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 14, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text('Add Action',
                      style:
                          TextStyle(color: AppColors.accent, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _buildActionRow(int index, _ActionEntry entry) {
    final paramDefs = entry.type.params;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dialogSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.dialogBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('THEN',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              const SizedBox(width: 10),
              Expanded(child: _dropdown<ActionType>(
                value: entry.type,
                items: ActionType.values,
                labelOf: (a) => a.label,
                onChanged: (t) => setState(() {
                  _actions[index] = _ActionEntry(type: t!, params: {});
                }),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeAction(index),
                child: const Icon(Icons.close,
                    size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          if (paramDefs.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...paramDefs.map((p) => _buildParamField(index, entry, p)),
          ],
        ],
      ),
    );
  }

  Widget _buildParamField(int index, _ActionEntry entry, ActionParam p) {
    // Special case: loadMap → mapName shows a map dropdown if maps are available
    if (p.key == 'mapName' && widget.availableMaps.isNotEmpty) {
      final currentVal = entry.params[p.key] as String? ?? '';
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(p.label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: widget.availableMaps
                        .any((m) => m.name == currentVal)
                    ? currentVal
                    : null,
                dropdownColor: AppColors.dialogSurface,
                hint: const Text('Select map…',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.dialogBg,
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
                items: widget.availableMaps
                    .map((m) => DropdownMenuItem(
                          value: m.name,
                          child: Text(m.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) entry.params[p.key] = v;
                },
              ),
            ),
          ],
        ),
      );
    }

    final ctrl = TextEditingController(
        text: entry.params[p.key]?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(p.label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: p.type == ActionParamType.number
                  ? const TextInputType.numberWithOptions(signed: true)
                  : TextInputType.text,
              inputFormatters: p.type == ActionParamType.number
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
                  : null,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: p.hint,
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppColors.dialogBg,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
              onChanged: (v) {
                if (p.type == ActionParamType.number) {
                  entry.params[p.key] = int.tryParse(v) ?? 0;
                } else {
                  entry.params[p.key] = v;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.dialogBorder)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _btn('Cancel', outlined: true,
                onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: 10),
            _btn('Save Rule', onTap: _save),
          ],
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _textField(TextEditingController ctrl, {String hint = ''}) =>
      TextField(
        controller: ctrl,
        style:
            const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textMuted, fontSize: 12),
          filled: true,
          fillColor: AppColors.dialogSurface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        dropdownColor: AppColors.dialogSurface,
        style:
            const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.dialogBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.dialogBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.dialogBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
        items: items
            .map((t) => DropdownMenuItem(value: t, child: Text(labelOf(t))))
            .toList(),
        onChanged: onChanged,
      );

  Widget _btn(String label, {required VoidCallback onTap, bool outlined = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
              fontSize: 13,
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
