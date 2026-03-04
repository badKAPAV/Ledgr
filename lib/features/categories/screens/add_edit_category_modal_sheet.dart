import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:wallzy/features/categories/models/category.dart';
import 'package:wallzy/features/categories/provider/category_provider.dart';
import 'package:wallzy/common/icon_picker/icons.dart';
import 'package:wallzy/common/icon_picker/icon_picker_sheet.dart';
import 'package:wallzy/features/transaction/provider/transaction_provider.dart';
import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

class AddEditCategoryModalSheet extends StatefulWidget {
  final CategoryModel? category;

  const AddEditCategoryModalSheet({super.key, this.category});

  @override
  State<AddEditCategoryModalSheet> createState() =>
      _AddEditCategoryModalSheetState();
}

class _AddEditCategoryModalSheetState extends State<AddEditCategoryModalSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late TransactionMode _mode;
  late String _iconKey;
  late List<String> _keywords;
  bool _isDefault = false;
  bool _isLoading = false;

  bool get isEditing => widget.category != null;
  bool get isSystemCategory =>
      widget.category?.type == CategoryType.defaultType;

  @override
  void initState() {
    super.initState();
    _name = widget.category?.name ?? '';
    _mode = widget.category?.mode ?? TransactionMode.expense;
    _iconKey = widget.category?.iconKey ?? 'target';
    _keywords = List.from(widget.category?.keywords ?? []);
    _isDefault = widget.category?.isDefault ?? false;
  }

  // --- NEW KEYWORD LOGIC ---
  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
    });
    HapticFeedback.selectionClick();
  }

  void _showAddKeywordSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddKeywordSheet(
        existingKeywords: _keywords,
        onAdd: (newKeyword) {
          setState(() {
            _keywords.add(newKeyword);
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    final provider = Provider.of<CategoryProvider>(context, listen: false);

    try {
      if (isSystemCategory) {
        // System categories only save default status and keywords
        final updatedCategory = widget.category!.copyWith(
          keywords: _keywords,
          isDefault: _isDefault, // Uses the updated state correctly
        );

        await provider.editCategory(updatedCategory);
      } else if (!isEditing) {
        // New Custom Category
        await provider.addCategory(
          name: _name,
          mode: _mode,
          iconKey: _iconKey,
          keywords: _keywords,
          isDefault: _isDefault,
        );
      } else {
        // Edit Custom Category
        final updatedCategory = widget.category!.copyWith(
          name: _name,
          mode: _mode,
          iconKey: _iconKey,
          keywords: _keywords,
          isDefault: _isDefault, // Uses the updated state correctly
        );

        await provider.editCategory(updatedCategory);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving category: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    if (widget.category == null || isSystemCategory) return;
    setState(() => _isLoading = true);
    try {
      final txProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final count = txProvider.getTransactionCountForCategory(
        widget.category!.id,
      );
      if (count > 0) {
        final replacementCategory = await _showSafeDeleteDialog(count);
        if (replacementCategory != null) {
          await txProvider.batchUpdateTransactionsCategory(
            widget.category!.id,
            replacementCategory.id,
          );
          await _performDelete();
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Category"),
            content: const Text(
              "Are you sure you want to delete this custom category?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
        if (confirm == true)
          await _performDelete();
        else
          setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking transactions: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performDelete() async {
    try {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      await provider.deleteCategory(widget.category!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error deleting category: $e")));
    }
  }

  Future<CategoryModel?> _showSafeDeleteDialog(int count) async {
    return showDialog<CategoryModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final catProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );
        final availableCategories = catProvider.categories
            .where(
              (c) =>
                  c.mode == _mode &&
                  c.id != widget.category!.id &&
                  !c.isDeleted,
            )
            .toList();
        CategoryModel? selectedReplacement = availableCategories.isNotEmpty
            ? availableCategories.first
            : null;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Safe Delete"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "This category is linked to $count transactions.",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Select a fallback category for them:"),
                  const SizedBox(height: 8),
                  if (availableCategories.isNotEmpty)
                    DropdownButtonFormField<CategoryModel>(
                      value: selectedReplacement,
                      items: availableCategories
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedReplacement = val),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    )
                  else
                    const Text(
                      "No other categories available.",
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: selectedReplacement != null
                      ? () => Navigator.pop(context, selectedReplacement)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text("Migrate & Delete"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIconPicker() {
    if (isSystemCategory) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalIconPickerSheet(
        selectedIconKey: _iconKey,
        onIconSelected: (key) => setState(() => _iconKey = key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Handle & Header ---
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colors.outlineVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? (isSystemCategory
                                    ? 'SYSTEM CATEGORY'
                                    : 'EDIT CATEGORY')
                              : 'NEW CATEGORY',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 1,
                          ),
                        ),
                        if (isSystemCategory) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Name and icon cannot be edited",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSystemCategory)
                    Icon(
                      Icons.lock_outline_rounded,
                      color: colors.outlineVariant,
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Animated Segmented Control ---
              _AnimatedModeSelector(
                currentMode: _mode,
                isDisabled: isSystemCategory,
                onModeChanged: (newMode) {
                  if (isSystemCategory) return;
                  HapticFeedback.selectionClick();
                  setState(() => _mode = newMode);
                },
              ),
              const SizedBox(height: 24),

              // --- Icon & Name Single Input ---
              TextFormField(
                initialValue: _name,
                readOnly: isSystemCategory,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSystemCategory ? colors.outline : colors.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  filled: true,
                  fillColor: isSystemCategory
                      ? colors.surfaceContainerHighest.withOpacity(0.5)
                      : colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16, 20, 8, 20),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: _showIconPicker,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSystemCategory
                              ? Colors.transparent
                              : colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: isSystemCategory
                              ? null
                              : Border.all(
                                  color: colors.outlineVariant.withOpacity(0.5),
                                ),
                        ),
                        child: HugeIcon(
                          icon: GoalIconRegistry.getIcon(_iconKey),
                          color: isSystemCategory
                              ? colors.outline
                              : colors.primary,
                          size: 24,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                validator: (value) {
                  if (!isSystemCategory &&
                      (value == null || value.trim().isEmpty))
                    return 'Please enter a name';
                  return null;
                },
                onSaved: (value) => _name = value?.trim() ?? _name,
              ),
              const SizedBox(height: 24),

              // --- KEYWORDS PILLS UI ---
              Text(
                "Auto-Match Keywords",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Keywords Wrap with integrated Add Pill
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ..._keywords.map((keyword) {
                    return Container(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 8,
                        top: 6,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: colors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            keyword,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _removeKeyword(keyword),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // The 'Add' Pill
                  GestureDetector(
                    onTap: _showAddKeywordSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _keywords.isEmpty ? "Add Keyword" : "Add",
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // --- Unboxed Default Toggle ---
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Set as Default',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Auto-selected for ${_mode.name}s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                value: _isDefault,
                activeColor: colors.primary,
                onChanged: (value) {
                  if (widget.category?.isDefault == true && value == false) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "A default category cannot be turned off. To replace it, set another category as default.",
                        ),
                      ),
                    );
                    return;
                  }
                  HapticFeedback.lightImpact();
                  setState(() => _isDefault = value);
                },
              ),
              const SizedBox(height: 32),

              // --- ACTION BUTTONS ---
              Row(
                children: [
                  if (isEditing && !isSystemCategory)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(
                            color: colors.error.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (isEditing && !isSystemCategory) const SizedBox(width: 16),

                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Create Category',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW WIDGET: ADD KEYWORD SHEET ---
class _AddKeywordSheet extends StatefulWidget {
  final List<String> existingKeywords;
  final ValueChanged<String> onAdd;

  const _AddKeywordSheet({required this.existingKeywords, required this.onAdd});

  @override
  State<_AddKeywordSheet> createState() => _AddKeywordSheetState();
}

class _AddKeywordSheetState extends State<_AddKeywordSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim().toLowerCase();

    if (text.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (widget.existingKeywords.contains(text)) {
      setState(() {
        _errorText = "Keyword already exists";
      });
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.lightImpact();
    widget.onAdd(text);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 10,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 5,
            width: 50,
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., swiggy, uber, mall',
              errorText: _errorText,
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onChanged: (val) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: Size(double.infinity, 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: const Text(
              "Add keyword",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ... [_AnimatedModeSelector remains the same]
class _AnimatedModeSelector extends StatelessWidget {
  final TransactionMode currentMode;
  final bool isDisabled;
  final ValueChanged<TransactionMode> onModeChanged;

  const _AnimatedModeSelector({
    required this.currentMode,
    required this.isDisabled,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isExpense = currentMode == TransactionMode.expense;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(
          isDisabled ? 0.3 : 0.8,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: isExpense ? 0 : tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? colors.surfaceContainer
                        : colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDisabled
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () => onModeChanged(TransactionMode.expense),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: isExpense
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isExpense
                                ? (isDisabled
                                      ? colors.outline
                                      : colors.onSurface)
                                : colors.onSurfaceVariant.withOpacity(
                                    isDisabled ? 0.5 : 1.0,
                                  ),
                          ),
                          child: const Text("Expense"),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () => onModeChanged(TransactionMode.income),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelLarge!.copyWith(
                            fontWeight: !isExpense
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: !isExpense
                                ? (isDisabled
                                      ? colors.outline
                                      : colors.onSurface)
                                : colors.onSurfaceVariant.withOpacity(
                                    isDisabled ? 0.5 : 1.0,
                                  ),
                          ),
                          child: const Text("Income"),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
