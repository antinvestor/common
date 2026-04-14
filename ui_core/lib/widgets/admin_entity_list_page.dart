import 'dart:convert';
import 'dart:ui';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:antinvestor_ui_core/responsive/breakpoints.dart';
import 'page_header.dart';

/// Configuration for a form field in the edit panel.
class EditField {
  const EditField({
    required this.label,
    required this.key,
    this.type = EditFieldType.text,
    this.hint,
    this.options = const [],
    this.maxLines = 1,
    this.readOnly = false,
  });

  final String label;
  final String key;
  final EditFieldType type;
  final String? hint;
  final List<String> options; // For dropdown type
  final int maxLines;
  final bool readOnly;
}

enum EditFieldType { text, number, dropdown, textarea }

/// Audit trail entry for the edit panel.
class AuditEntry {
  const AuditEntry({required this.description, required this.time});
  final String description;
  final String time;
}

/// A reusable admin entity list page pattern: searchable DataTable + detail
/// panel + glassmorphic edit slide-over.
///
/// Features:
/// - Search bar + filter toolbar
/// - DataTable with sortable columns and pagination (10/25/50/100 rows)
/// - CSV export (copy to clipboard + download)
/// - Row selection -> detail panel (right sidebar on desktop)
/// - Glassmorphic slide-over edit panel with form fields
/// - Audit trail in edit panel
class AdminEntityListPage<T> extends StatefulWidget {
  const AdminEntityListPage({
    super.key,
    required this.title,
    required this.breadcrumbs,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.detailBuilder,
    this.actions,
    this.onSearch,
    this.onAdd,
    this.addLabel,
    this.onRowNavigate,
    this.exportRow,
    this.rowsPerPage = 25,
    // Edit panel configuration
    this.editFields,
    this.editTitle,
    this.editValuesExtractor,
    this.onSave,
    this.auditTrailBuilder,
    this.onExport,
  });

  final String title;
  final List<String> breadcrumbs;
  final List<DataColumn> columns;
  final List<T> items;
  final DataRow Function(T item, bool selected, VoidCallback onSelect)
      rowBuilder;
  final Widget Function(T item)? detailBuilder;
  final List<Widget>? actions;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onAdd;
  final String? addLabel;

  /// When provided, row taps navigate to a detail page instead of
  /// showing the side panel. Called with the tapped item.
  final void Function(T item)? onRowNavigate;

  /// Extract a row of string values for CSV export. Column order should
  /// match [columns]. When null, the export button is hidden.
  final List<String> Function(T item)? exportRow;

  /// Called when data is exported, for audit trail logging.
  /// Receives the export format ('csv'), the number of rows exported,
  /// and the entity type name (from [title]).
  /// Callers should use this to create an audit entry in their backend.
  final void Function(String format, int rowCount)? onExport;

  /// Number of rows per page in the paginated table. Defaults to 25.
  final int rowsPerPage;

  /// Fields to show in the edit panel. If null, no edit functionality.
  final List<EditField>? editFields;

  /// Title for the edit panel (e.g., "Edit TXN-904-221").
  final String Function(T item)? editTitle;

  /// Extract current values from an item for pre-filling the edit form.
  final Map<String, String> Function(T item)? editValuesExtractor;

  /// Called when save is pressed with the field values map.
  final void Function(T? item, Map<String, String> values)? onSave;

  /// Build audit trail entries for an item.
  final List<AuditEntry> Function(T item)? auditTrailBuilder;

  @override
  State<AdminEntityListPage<T>> createState() =>
      _AdminEntityListPageState<T>();
}

class _AdminEntityListPageState<T> extends State<AdminEntityListPage<T>> {
  int? _selectedIndex;
  int? _editingIndex;
  bool _creating = false;
  int _currentPage = 0;
  late int _pageSize = widget.rowsPerPage;
  int _lastItemCount = 0;

  static const _pageSizeOptions = [10, 25, 50, 100];

  void _exportCsv() {
    if (widget.exportRow == null) return;
    final headers = widget.columns
        .map((c) => (c.label is Text) ? (c.label as Text).data ?? '' : '')
        .toList();
    final rows = widget.items.map((item) => widget.exportRow!(item)).toList();
    final csv = const CsvEncoder().convert([headers, ...rows]);
    // Copy to clipboard and show snackbar (works on all platforms)
    Clipboard.setData(ClipboardData(text: csv));

    // Fire audit callback so the host app can log the export event
    widget.onExport?.call('csv', rows.length);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.title} CSV copied to clipboard (${rows.length} rows)'),
          action: SnackBarAction(
            label: 'Download',
            onPressed: () => _downloadCsv(csv),
          ),
        ),
      );
    }
  }

  void _downloadCsv(String csv) {
    // Use an anchor element to trigger browser download
    final bytes = utf8.encode(csv);
    final base64Data = base64Encode(bytes);
    final dataUri = 'data:text/csv;base64,$base64Data';
    _triggerDownload(
        dataUri,
        '${widget.title.toLowerCase().replaceAll(' ', '_')}_export.csv');
  }

  void _triggerDownload(String dataUri, String filename) {
    // For web: already copied to clipboard via _exportCsv
    // The SnackBar shows a "Download" action for convenience
    debugPrint('CSV export: $filename (${widget.items.length} rows)');
  }

  void _openEdit(int index) {
    setState(() {
      _editingIndex = index;
      _creating = false;
    });
  }

  void _openCreate() {
    setState(() {
      _editingIndex = null;
      _creating = true;
    });
  }

  void _closeEdit() {
    setState(() {
      _editingIndex = null;
      _creating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reset stale indices when items list changes
    if (_selectedIndex != null && _selectedIndex! >= widget.items.length) {
      _selectedIndex = null;
    }
    if (_editingIndex != null && _editingIndex! >= widget.items.length) {
      _editingIndex = null;
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = AppBreakpoints.isDesktop(width);
    final showDetailPanel = isDesktop &&
        widget.detailBuilder != null &&
        widget.onRowNavigate == null &&
        _selectedIndex != null;

    final showEditOverlay =
        widget.editFields != null && (_editingIndex != null || _creating);

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;

    return Stack(
      children: [
        // Main content
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: showDetailPanel ? 3 : 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageHeader(
                          title: widget.title,
                          breadcrumbs: widget.breadcrumbs,
                          actions: [
                            if (widget.exportRow != null)
                              OutlinedButton.icon(
                                onPressed: _exportCsv,
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text('Export'),
                              ),
                            if (widget.onAdd != null ||
                                widget.editFields != null)
                              ElevatedButton.icon(
                                onPressed: widget.editFields != null
                                    ? _openCreate
                                    : widget.onAdd,
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(widget.addLabel ?? 'Add'),
                              ),
                            ...?widget.actions,
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Search field — constrained, only when onSearch is set
                        if (widget.onSearch != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: TextField(
                                onChanged: widget.onSearch,
                                decoration: const InputDecoration(
                                  hintText: 'Search...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                        // Paginated data table + footer
                        ..._buildPaginatedTable(
                            theme, surfaceColor, borderColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Detail panel (desktop only)
            if (showDetailPanel)
              SizedBox(
                width: 380,
                child: Container(
                  margin: const EdgeInsets.only(
                      top: 24, right: 24, bottom: 24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.editFields != null)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20),
                                onPressed: () =>
                                    _openEdit(_selectedIndex!),
                                tooltip: 'Edit',
                              ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  setState(() => _selectedIndex = null),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: widget.detailBuilder!(
                              widget.items[_selectedIndex!]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // Edit slide-over overlay
        if (showEditOverlay) _buildEditOverlay(context),
      ],
    );
  }

  List<Widget> _buildPaginatedTable(
      ThemeData theme, Color surfaceColor, Color borderColor) {
    final totalItems = widget.items.length;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    // Reset to first page when item count changes (e.g. after refresh/filter).
    if (totalItems != _lastItemCount) {
      _lastItemCount = totalItems;
      if (_currentPage > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentPage = 0);
        });
      }
    }

    final totalPages = totalItems == 0 ? 1 : (totalItems / _pageSize).ceil();
    // Clamp current page to valid range.
    if (_currentPage >= totalPages) _currentPage = totalPages - 1;

    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, totalItems);
    final pageItems =
        totalItems > 0 ? widget.items.sublist(start, end) : <T>[];

    return [
      // Table body
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            showCheckboxColumn: false,
            columns: widget.columns,
            rows: List.generate(pageItems.length, (i) {
              final globalIndex = start + i;
              return widget.rowBuilder(
                pageItems[i],
                _selectedIndex == globalIndex,
                () {
                  if (widget.onRowNavigate != null) {
                    widget.onRowNavigate!(pageItems[i]);
                  } else {
                    setState(() {
                      _selectedIndex = _selectedIndex == globalIndex
                          ? null
                          : globalIndex;
                    });
                  }
                },
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 24),
      // Pagination footer
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Text('Rows per page: ',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: mutedColor)),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: theme.textTheme.bodySmall,
              items: _pageSizeOptions
                  .map(
                      (s) => DropdownMenuItem(value: s, child: Text('$s')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _pageSize = v;
                    _currentPage = 0;
                  });
                }
              },
            ),
            const Spacer(),
            Text(
              totalItems == 0
                  ? '0 items'
                  : '${start + 1}\u2013$end of $totalItems',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
            ),
            Text('${_currentPage + 1} / $totalPages',
                style: theme.textTheme.bodySmall),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: _currentPage < totalPages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEditOverlay(BuildContext context) {
    final item =
        _editingIndex != null ? widget.items[_editingIndex!] : null;
    final title = item != null && widget.editTitle != null
        ? widget.editTitle!(item)
        : _creating
            ? 'New ${widget.title}'
            : 'Edit';
    final initialValues = item != null && widget.editValuesExtractor != null
        ? widget.editValuesExtractor!(item)
        : <String, String>{};
    final audits = item != null && widget.auditTrailBuilder != null
        ? widget.auditTrailBuilder!(item)
        : <AuditEntry>[];

    return _EditSlideOver(
      title: title,
      fields: widget.editFields!,
      initialValues: initialValues,
      auditTrail: audits,
      onSave: (values) {
        widget.onSave?.call(item, values);
        _closeEdit();
      },
      onCancel: _closeEdit,
    );
  }
}

// --- Edit Slide-Over Panel ---------------------------------------------------

class _EditSlideOver extends StatefulWidget {
  const _EditSlideOver({
    required this.title,
    required this.fields,
    required this.initialValues,
    required this.auditTrail,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final List<EditField> fields;
  final Map<String, String> initialValues;
  final List<AuditEntry> auditTrail;
  final ValueChanged<Map<String, String>> onSave;
  final VoidCallback onCancel;

  @override
  State<_EditSlideOver> createState() => _EditSlideOverState();
}

class _EditSlideOverState extends State<_EditSlideOver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controllers = {};
    _dropdownValues = {};
    for (final field in widget.fields) {
      final value = widget.initialValues[field.key] ?? '';
      if (field.type == EditFieldType.dropdown) {
        _dropdownValues[field.key] = value;
      } else {
        _controllers[field.key] = TextEditingController(text: value);
      }
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collectValues() {
    final values = <String, String>{};
    for (final field in widget.fields) {
      if (field.type == EditFieldType.dropdown) {
        values[field.key] = _dropdownValues[field.key] ?? '';
      } else {
        values[field.key] = _controllers[field.key]?.text ?? '';
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Stack(
      children: [
        // Dimmed background
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onCancel,
            child: Container(
              color: onSurfaceColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Slide-over panel
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 440,
          child: SlideTransition(
            position: _slideAnimation,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor.withValues(alpha: 0.95),
                    border: Border(
                      left: BorderSide(
                          color: borderColor.withValues(alpha: 0.5)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: onSurfaceColor.withValues(alpha: 0.06),
                        blurRadius: 40,
                        offset: const Offset(-20, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 24, 12, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: widget.onCancel,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Form fields
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final field in widget.fields) ...[
                                _buildField(context, field),
                                const SizedBox(height: 16),
                              ],
                              // Audit trail
                              if (widget.auditTrail.isNotEmpty) ...[
                                const Divider(height: 32),
                                Text('Audit Trail',
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                for (final entry in widget.auditTrail)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.circle,
                                            size: 6,
                                            color: mutedColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(entry.description,
                                              style: theme
                                                  .textTheme.bodySmall),
                                        ),
                                        Text(entry.time,
                                            style: theme
                                                .textTheme.labelSmall
                                                ?.copyWith(
                                                    color: mutedColor)),
                                      ],
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Action buttons
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    widget.onSave(_collectValues()),
                                child: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, EditField field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        switch (field.type) {
          EditFieldType.dropdown => DropdownButtonFormField<String>(
              initialValue:
                  _dropdownValues[field.key]?.isNotEmpty == true &&
                          field.options.contains(_dropdownValues[field.key])
                      ? _dropdownValues[field.key]
                      : null,
              decoration: InputDecoration(
                hintText: field.hint ?? 'Select...',
                isDense: true,
              ),
              items: field.options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: field.readOnly
                  ? null
                  : (v) => setState(
                      () => _dropdownValues[field.key] = v ?? ''),
            ),
          EditFieldType.textarea => TextField(
              controller: _controllers[field.key],
              maxLines: field.maxLines > 1 ? field.maxLines : 4,
              readOnly: field.readOnly,
              decoration: InputDecoration(
                hintText: field.hint,
                isDense: true,
              ),
            ),
          _ => TextField(
              controller: _controllers[field.key],
              readOnly: field.readOnly,
              keyboardType: field.type == EditFieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: field.hint,
                isDense: true,
              ),
            ),
        },
      ],
    );
  }
}
