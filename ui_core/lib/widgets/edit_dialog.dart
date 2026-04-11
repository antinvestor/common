import 'package:flutter/material.dart';

/// Field definition for [showEditDialog].
class DialogField {
  const DialogField({
    required this.key,
    required this.label,
    this.hint,
    this.initialValue = '',
    this.type = DialogFieldType.text,
    this.options = const [],
    this.maxLines = 1,
    this.required = false,
  });

  final String key;
  final String label;
  final String? hint;
  final String initialValue;
  final DialogFieldType type;
  final List<String> options;
  final int maxLines;
  final bool required;
}

enum DialogFieldType { text, textarea, dropdown, searchableDropdown }

/// Shows a modal dialog with form fields. Returns the values map on save,
/// or null on cancel.
Future<Map<String, String>?> showEditDialog({
  required BuildContext context,
  required String title,
  required List<DialogField> fields,
  String saveLabel = 'Save',
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => _EditDialogContent(
      title: title,
      fields: fields,
      saveLabel: saveLabel,
    ),
  );
}

class _EditDialogContent extends StatefulWidget {
  const _EditDialogContent({
    required this.title,
    required this.fields,
    required this.saveLabel,
  });

  final String title;
  final List<DialogField> fields;
  final String saveLabel;

  @override
  State<_EditDialogContent> createState() => _EditDialogContentState();
}

class _EditDialogContentState extends State<_EditDialogContent> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _dropdownValues = {};
    for (final field in widget.fields) {
      if (field.type == DialogFieldType.dropdown ||
          field.type == DialogFieldType.searchableDropdown) {
        _dropdownValues[field.key] = field.options.contains(field.initialValue)
            ? field.initialValue
            : '';
      } else {
        _controllers[field.key] =
            TextEditingController(text: field.initialValue);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collectValues() {
    final values = <String, String>{};
    for (final field in widget.fields) {
      if (field.type == DialogFieldType.dropdown ||
          field.type == DialogFieldType.searchableDropdown) {
        values[field.key] = _dropdownValues[field.key] ?? '';
      } else {
        values[field.key] = _controllers[field.key]?.text ?? '';
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields) ...[
                _buildField(field),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_collectValues()),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }

  Widget _buildField(DialogField field) {
    switch (field.type) {
      case DialogFieldType.dropdown:
        return DropdownButtonFormField<String>(
          initialValue: _dropdownValues[field.key]?.isNotEmpty == true
              ? _dropdownValues[field.key]
              : null,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint ?? 'Select...',
          ),
          items: field.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) =>
              setState(() => _dropdownValues[field.key] = v ?? ''),
        );
      case DialogFieldType.searchableDropdown:
        return Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return field.options;
            }
            final query = textEditingValue.text.toLowerCase();
            return field.options
                .where((o) => o.toLowerCase().contains(query));
          },
          initialValue: (_dropdownValues[field.key]?.isNotEmpty == true)
              ? TextEditingValue(text: _dropdownValues[field.key]!)
              : null,
          onSelected: (value) =>
              setState(() => _dropdownValues[field.key] = value),
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: field.hint ?? 'Type to search...',
                suffixIcon: textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          textController.clear();
                          setState(
                              () => _dropdownValues[field.key] = '');
                        },
                      )
                    : const Icon(Icons.search, size: 18),
              ),
              onChanged: (value) {
                // Allow clearing
                if (value.isEmpty) {
                  _dropdownValues[field.key] = '';
                }
              },
            );
          },
        );
      case DialogFieldType.textarea:
        return TextField(
          controller: _controllers[field.key],
          maxLines: field.maxLines > 1 ? field.maxLines : 4,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
            alignLabelWithHint: true,
          ),
        );
      case DialogFieldType.text:
        return TextField(
          controller: _controllers[field.key],
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hint,
          ),
        );
    }
  }
}

/// Shows a confirmation dialog. Returns true on confirm, false on cancel.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  Color? confirmColor,
}) async {
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
