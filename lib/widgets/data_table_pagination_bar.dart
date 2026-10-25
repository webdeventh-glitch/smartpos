import 'dart:math';
import 'package:flutter/material.dart';

class DataTablePaginationBar extends StatelessWidget {
  final int currentPage;
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizeOptions;

  const DataTablePaginationBar({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 25, 50, 100],
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = max(1, (totalItems / pageSize).ceil());
    final startItem = (currentPage - 1) * pageSize + 1;
    final endItem = min(totalItems, currentPage * pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;

          final infoWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing $startItem to $endItem of $totalItems entries',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 14),
              // Page size dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: pageSizeOptions.contains(pageSize) ? pageSize : pageSizeOptions.first,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                    items: pageSizeOptions.map((sz) {
                      return DropdownMenuItem<int>(
                        value: sz,
                        child: Text('$sz / page'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onPageSizeChanged(val);
                    },
                  ),
                ),
              ),
            ],
          );

          // Pagination buttons
          final paginationButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              _buildNavButton(
                context: context,
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous Page',
                enabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
              ),
              const SizedBox(width: 4),

              // Page pills
              ..._buildPageNumbers(context, totalPages),

              const SizedBox(width: 4),
              // Next button
              _buildNavButton(
                context: context,
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next Page',
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                infoWidget,
                const SizedBox(height: 10),
                paginationButtons,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              infoWidget,
              paginationButtons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled
                ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? (isDark ? Colors.white : const Color(0xFF334155))
                : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPageNumbers(BuildContext context, int totalPages) {
    final List<Widget> widgets = [];

    // Visible window around current page
    int start = max(1, currentPage - 2);
    int end = min(totalPages, currentPage + 2);

    if (start > 1) {
      widgets.add(_buildPagePill(context, 1));
      if (start > 2) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ));
      }
    }

    for (int p = start; p <= end; p++) {
      widgets.add(_buildPagePill(context, p));
    }

    if (end < totalPages) {
      if (end < totalPages - 1) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ));
      }
      widgets.add(_buildPagePill(context, totalPages));
    }

    return widgets;
  }

  Widget _buildPagePill(BuildContext context, int pageNum) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = pageNum == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onPageChanged(pageNum),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Text(
              '$pageNum',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
