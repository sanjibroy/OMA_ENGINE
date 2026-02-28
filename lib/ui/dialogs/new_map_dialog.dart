import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class NewMapConfig {
  final String projectName;
  final String name;
  final int width;
  final int height;
  final int tileSize;
  const NewMapConfig({
    required this.projectName,
    required this.name,
    required this.width,
    required this.height,
    required this.tileSize,
  });
}

class NewMapDialog extends StatefulWidget {
  const NewMapDialog({super.key});

  /// Shows the dialog and returns [NewMapConfig] or null if cancelled.
  static Future<NewMapConfig?> show(BuildContext context) {
    return showDialog<NewMapConfig>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const NewMapDialog(),
    );
  }

  @override
  State<NewMapDialog> createState() => _NewMapDialogState();
}

class _NewMapDialogState extends State<NewMapDialog> {
  final _projectNameCtrl = TextEditingController(text: 'Untitled Game');
  final _nameCtrl = TextEditingController(text: 'Level 1');
  final _widthCtrl = TextEditingController(text: '20');
  final _heightCtrl = TextEditingController(text: '15');
  final _tileSizeCtrl = TextEditingController(text: '32');

  @override
  void dispose() {
    _projectNameCtrl.dispose();
    _nameCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _tileSizeCtrl.dispose();
    super.dispose();
  }

  void _create() {
    final width = int.tryParse(_widthCtrl.text) ?? 20;
    final height = int.tryParse(_heightCtrl.text) ?? 15;
    final tileSize = int.tryParse(_tileSizeCtrl.text) ?? 32;

    if (width < 1 || width > 200 || height < 1 || height > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Width and height must be between 1 and 200')),
      );
      return;
    }
    if (tileSize < 8 || tileSize > 128) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tile size must be between 8 and 128')),
      );
      return;
    }

    final projName = _projectNameCtrl.text.trim().isEmpty
        ? 'Untitled Game'
        : _projectNameCtrl.text.trim();
    Navigator.of(context).pop(NewMapConfig(
      projectName: projName,
      name: _nameCtrl.text.trim().isEmpty ? 'Level 1' : _nameCtrl.text.trim(),
      width: width,
      height: height,
      tileSize: tileSize,
    ));
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
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.dialogBorder)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_box_outlined,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'New Map',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ],
              ),
            ),

            // Fields
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field('Project Name', _projectNameCtrl, hint: 'Untitled Game'),
                  const SizedBox(height: 12),
                  _field('Map Name', _nameCtrl, hint: 'Level 1'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _field('Width', _widthCtrl,
                              hint: '20', isNumber: true, suffix: 'tiles')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field('Height', _heightCtrl,
                              hint: '15', isNumber: true, suffix: 'tiles')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field('Tile Size', _tileSizeCtrl,
                      hint: '32', isNumber: true, suffix: 'px'),
                  const SizedBox(height: 6),
                  const _Hint('Max map: 200×200 tiles. Tile size: 8–128 px.'),
                ],
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _dialogBtn('Cancel', outlined: true,
                      onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  _dialogBtn('Create', onTap: _create),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    bool isNumber = false,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            suffixText: suffix,
            suffixStyle:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
        ),
      ],
    );
  }

  Widget _dialogBtn(String label,
      {required VoidCallback onTap, bool outlined = false}) {
    return GestureDetector(
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
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      );
}
