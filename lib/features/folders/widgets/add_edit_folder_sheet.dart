import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:wallzy/common/icon_picker/icon_picker_sheet.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/features/transaction/provider/meta_provider.dart';
import 'package:wallzy/features/folders/models/folder.dart';

class AddEditFolderSheet extends StatefulWidget {
  const AddEditFolderSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddEditFolderSheet(),
    );
  }

  @override
  State<AddEditFolderSheet> createState() => _AddEditFolderSheetState();
}

class _AddEditFolderSheetState extends State<AddEditFolderSheet> {
  final TextEditingController _nameController = TextEditingController();
  Color? _selectedColor;
  String _selectedIconKey = 'folder';

  final List<Color> _tagColors = Tag.defaultTagColors;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "NEW FOLDER",
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                  color: colors.outline,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1st Row: Icon Picker & Folder Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => GoalIconPickerSheet(
                      selectedIconKey: _selectedIconKey,
                      onIconSelected: (key) =>
                          setState(() => _selectedIconKey = key),
                    ),
                  );
                },
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              (_selectedColor ?? colors.primaryContainer)
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                (_selectedColor ?? colors.primary)
                                    .withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: HugeIcon(
                            icon: GoalIconRegistry.getFolderIcon(
                              _selectedIconKey,
                            ),
                            size: 24,
                            color: _selectedColor ?? colors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: "eg. Paris trip",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: TextStyle(
                      fontFamily: 'geologica',
                      color: colors.outlineVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 2nd Row: Folder Colors
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tagColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final color = _tagColors[index];
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 60,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(40),
                      border: isSelected
                          ? Border.all(
                              color: colors.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color:
                                ThemeData.estimateBrightnessForColor(color) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 40),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;
                await Provider.of<MetaProvider>(
                  context,
                  listen: false,
                ).addTag(
                  name,
                  color: _selectedColor?.value,
                  iconKey: _selectedIconKey,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Create Folder"),
            ),
          ),
        ],
      ),
    );
  }
}
