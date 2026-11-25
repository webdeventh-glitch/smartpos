import 'package:flutter/material.dart';

/// Generic Searchable Select Dialog for fast searching and selection of entities
/// (Brands, Categories, Subcategories, Units, etc.) with real-time filtering,
/// quick creation, and full keyboard navigation support.
class SearchableSelectDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T) labelBuilder;
  final String Function(T)? subtitleBuilder;
  final Widget Function(T)? leadingBuilder;
  final Widget Function(T)? trailingBuilder;
  final bool Function(T item, String query)? filter;
  final VoidCallback? onAddNew;
  final String? addNewLabel;
  final bool allowClear;
  final String clearLabel;
  final ValueChanged<T?> onSelected;
  final T Function(String customInput)? onCustomAdd;

  const SearchableSelectDialog({
    super.key,
    required this.title,
    required this.searchHint,
    required this.items,
    this.selectedItem,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.leadingBuilder,
    this.trailingBuilder,
    this.filter,
    this.onAddNew,
    this.addNewLabel,
    this.allowClear = true,
    this.clearLabel = 'None / Clear Selection',
    required this.onSelected,
    this.onCustomAdd,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String searchHint,
    required List<T> items,
    T? selectedItem,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
    Widget Function(T)? leadingBuilder,
    Widget Function(T)? trailingBuilder,
    bool Function(T item, String query)? filter,
    VoidCallback? onAddNew,
    String? addNewLabel,
    bool allowClear = true,
    String clearLabel = 'None / Clear Selection',
    T Function(String customInput)? onCustomAdd,
  }) {
    return showDialog<T?>(
      context: context,
      builder: (ctx) => SearchableSelectDialog<T>(
        title: title,
        searchHint: searchHint,
        items: items,
        selectedItem: selectedItem,
        labelBuilder: labelBuilder,
        subtitleBuilder: subtitleBuilder,
        leadingBuilder: leadingBuilder,
        trailingBuilder: trailingBuilder,
        filter: filter,
        onAddNew: onAddNew,
        addNewLabel: addNewLabel,
        allowClear: allowClear,
        clearLabel: clearLabel,
        onSelected: (val) => Navigator.pop(ctx, val),
        onCustomAdd: onCustomAdd,
      ),
    );
  }

  @override
  State<SearchableSelectDialog<T>> createState() =>
      _SearchableSelectDialogState<T>();
}

class _SearchableSelectDialogState<T> extends State<SearchableSelectDialog<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<T> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) {
          if (widget.filter != null) {
            return widget.filter!(item, query);
          }
          final label = widget.labelBuilder(item).toLowerCase();
          final sub = widget.subtitleBuilder?.call(item).toLowerCase() ?? '';
          return label.contains(query) || sub.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _searchCtrl.text.trim();
    final hasExactMatch = _filteredItems.any(
      (item) =>
          widget.labelBuilder(item).trim().toLowerCase() == query.toLowerCase(),
    );

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.search_rounded,
                            size: 19, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (widget.onAddNew != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: Text(
                            widget.addNewLabel ?? '+ Add New',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onAddNew!();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: const Color(0xFF94A3B8),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle:
                      const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFF64748B)),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilter('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: _applyFilter,
                onSubmitted: (val) {
                  if (_filteredItems.isNotEmpty) {
                    widget.onSelected(_filteredItems.first);
                  } else if (widget.onCustomAdd != null &&
                      val.trim().isNotEmpty) {
                    widget.onSelected(widget.onCustomAdd!(val.trim()));
                  }
                },
              ),
            ),

            // Clear Selection Option
            if (widget.allowClear && widget.selectedItem != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.onSelected(null),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.clear_all_rounded,
                            size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(
                          widget.clearLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Item Counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available (${_filteredItems.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  if (query.isNotEmpty)
                    Text(
                      'Matching "$query"',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40,
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 10),
                            Text(
                              'No matches found for "$query"',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            if (widget.onCustomAdd != null &&
                                query.isNotEmpty &&
                                !hasExactMatch) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: Text('Use "$query"'),
                                onPressed: () {
                                  final item = widget.onCustomAdd!(query);
                                  widget.onSelected(item);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      itemCount: _filteredItems.length +
                          (widget.onCustomAdd != null &&
                                  query.isNotEmpty &&
                                  !hasExactMatch
                              ? 1
                              : 0),
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 8, endIndent: 8),
                      itemBuilder: (ctx, idx) {
                        if (idx == _filteredItems.length) {
                          // Quick add option at the bottom of the list
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.add,
                                  size: 16, color: Color(0xFF4F46E5)),
                            ),
                            title: Text(
                              'Add & Select "$query"',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            onTap: () {
                              final item = widget.onCustomAdd!(query);
                              widget.onSelected(item);
                            },
                          );
                        }

                        final item = _filteredItems[idx];
                        final label = widget.labelBuilder(item);
                        final subtitle = widget.subtitleBuilder?.call(item);
                        final isSelected = widget.selectedItem != null &&
                            widget.labelBuilder(widget.selectedItem as T) ==
                                label;

                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          tileColor: isSelected
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                              : null,
                          leading: widget.leadingBuilder != null
                              ? widget.leadingBuilder!(item)
                              : Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    label.isNotEmpty
                                        ? label.substring(0, 1).toUpperCase()
                                        : '-',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF4F46E5)
                                  : (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                            ),
                          ),
                          subtitle: (subtitle != null && subtitle.isNotEmpty)
                              ? Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.trailingBuilder != null)
                                widget.trailingBuilder!(item),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle_rounded,
                                    size: 18, color: Color(0xFF4F46E5)),
                              ],
                            ],
                          ),
                          onTap: () => widget.onSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sleek, modern form field that triggers a SearchableSelectDialog when tapped.
class SearchSelectField extends StatelessWidget {
  final String? label;
  final bool isRequired;
  final String? valueText;
  final String placeholder;
  final IconData prefixIcon;
  final VoidCallback onTap;
  final VoidCallback? onAdd;
  final String? tooltip;

  const SearchSelectField({
    super.key,
    this.label,
    this.isRequired = false,
    this.valueText,
    required this.placeholder,
    required this.prefixIcon,
    required this.onTap,
    this.onAdd,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = valueText != null && valueText!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              if (isRequired)
                const Text(' *',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: tooltip ?? 'Click to search & select $label',
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasValue
                            ? (isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFF94A3B8))
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1)),
                        width: hasValue ? 1.2 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(prefixIcon,
                            size: 18,
                            color: hasValue
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasValue ? valueText! : placeholder,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasValue
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: hasValue
                                  ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))
                                  : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.search_rounded,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF4F46E5)),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down_rounded,
                            size: 20, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                width: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004EEB),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onAdd,
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
