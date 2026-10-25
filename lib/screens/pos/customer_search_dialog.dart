import 'package:flutter/material.dart';
import '../../models/models.dart';
import 'quick_customer_dialog.dart';

class CustomerSearchDialog extends StatefulWidget {
  final List<Contact> customers;
  final Contact? selectedCustomer;
  final ValueChanged<Contact> onCustomerSelected;
  final String currencySymbol;

  const CustomerSearchDialog({
    super.key,
    required this.customers,
    required this.selectedCustomer,
    required this.onCustomerSelected,
    this.currencySymbol = 'Rs',
  });

  @override
  State<CustomerSearchDialog> createState() => _CustomerSearchDialogState();
}

class _CustomerSearchDialogState extends State<CustomerSearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Contact> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.customers;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final q = val.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.customers;
      } else {
        _filtered = widget.customers.where((c) {
          final nameMatch = c.name.toLowerCase().contains(q);
          final phoneMatch = c.phone.isNotEmpty && c.phone.toLowerCase().contains(q);
          final bizMatch = c.businessName != null && c.businessName!.toLowerCase().contains(q);
          final addressMatch = c.address.isNotEmpty && c.address.toLowerCase().contains(q);
          return nameMatch || phoneMatch || bizMatch || addressMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 580,
        height: 600,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black54 : const Color(0x26000000),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Customer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quick search across name, phone, or medical store',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Add New Customer Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 15),
                    label: const Text('Add Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => QuickCustomerDialog(
                          onCustomerAdded: (newCustomer) {
                            widget.onCustomerSelected(newCustomer);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Live Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: inputBorder),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search customer by name, mobile (0300...) or store...',
                    hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 16, color: textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Results count badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${_filtered.length} customers',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  if (widget.selectedCustomer != null)
                    Text(
                      'Currently: ${widget.selectedCustomer!.name}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Customers List
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off_outlined, size: 48, color: textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No matching customers found',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "+ Add Customer" above to create one instantly.',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                      itemBuilder: (context, index) {
                        final c = _filtered[index];
                        final isSelected = widget.selectedCustomer?.id == c.id;

                        return Material(
                          color: isSelected
                              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () {
                              widget.onCustomerSelected(c);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : const Color(0xFF475569)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              c.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                                    : textPrimary,
                                              ),
                                            ),
                                            if (c.businessName != null && c.businessName!.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  c.businessName!,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            if (c.phone.isNotEmpty) ...[
                                              Icon(Icons.phone_outlined, size: 11, color: textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                c.phone,
                                                style: TextStyle(fontSize: 11, color: textSecondary),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            if (c.address.isNotEmpty) ...[
                                              Icon(Icons.location_on_outlined, size: 11, color: textSecondary),
                                              const SizedBox(width: 2),
                                              Text(
                                                c.address,
                                                style: TextStyle(fontSize: 11, color: textSecondary),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Due balance badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${widget.currencySymbol} ${c.balance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: c.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.balance > 0 ? 'Due Balance' : 'No Due',
                                        style: TextStyle(fontSize: 9, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 18),
                                  ],
                                ],
                              ),
                            ),
                          ),
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
