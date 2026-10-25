import 'package:flutter/material.dart';
import '../../models/models.dart';

class UserManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UserManagementScreen({super.key, required this.settings});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _users = [
    {
      'id': 1,
      'name': 'Irfan Khan',
      'username': 'webdeventh',
      'email': 'admin@smartpos.com',
      'role': 'Admin',
      'status': 'Active',
      'locations': 'Main Branch HQ, Downtown Warehouse',
    },
    {
      'id': 2,
      'name': 'Hamza Ali',
      'username': 'cashier1',
      'email': 'hamza@smartpos.com',
      'role': 'Cashier',
      'status': 'Active',
      'locations': 'Main Branch HQ',
    },
    {
      'id': 3,
      'name': 'Saeed Anwar',
      'username': 'manager',
      'email': 'saeed@smartpos.com',
      'role': 'Store Manager',
      'status': 'Active',
      'locations': 'Main Branch HQ',
    },
  ];

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 1,
      'roleName': 'Admin',
      'description': 'Full unrestricted access to all modules, financial data, and configurations.',
      'permissions': ['POS Sales', 'Purchases', 'Inventory & Stock Transfers', 'Financial Accounts', 'All Reports', 'Settings & Licensing', 'User Authorization'],
    },
    {
      'id': 2,
      'roleName': 'Store Manager',
      'description': 'Inventory management, view purchases and daily sales, register audits.',
      'permissions': ['POS Sales', 'Purchases', 'Inventory & Stock Transfers', 'Daily Sales Reports', 'Contacts Management'],
    },
    {
      'id': 3,
      'roleName': 'Cashier',
      'description': 'Dedicated front-counter checkout terminal and receipt printing.',
      'permissions': ['POS Sales Terminal', 'Hold / Resume Orders', 'Cash Register Drawer'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Cashier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Create New User Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username (login ID) *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Assign Role & Access Rights', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Admin', child: Text('Admin (All permissions)')),
                    DropdownMenuItem(value: 'Store Manager', child: Text('Store Manager (Inventory & Reports)')),
                    DropdownMenuItem(value: 'Cashier', child: Text('Cashier (Front-desk POS only)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => role = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty && usernameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _users.add({
                      'id': _users.length + 1,
                      'name': nameCtrl.text.trim(),
                      'username': usernameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': role,
                      'status': 'Active',
                      'locations': 'Main Branch HQ',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoleDialog() {
    final roleNameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final List<String> selectedPerms = ['POS Sales'];

    final availablePerms = [
      'POS Sales Terminal',
      'Hold / Resume Orders',
      'Cash Register Drawer',
      'Product Catalog & Price Groups',
      'Inventory Stock Transfers',
      'Stock Adjustments',
      'Purchases & Vendors',
      'Customers & Credit Ledgers',
      'Expenses Management',
      'Payment Accounts & Banking',
      'Financial Reports & Profit/Loss',
      'Settings & Store Setup',
      'User Authorization & Roles',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Create Role & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: roleNameCtrl,
                    decoration: const InputDecoration(labelText: 'Role Name * (e.g. Supervisor)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('Permissions Matrix:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availablePerms.map((perm) {
                      final isChecked = selectedPerms.contains(perm);
                      return FilterChip(
                        selected: isChecked,
                        label: Text(perm, style: TextStyle(fontSize: 12, fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal)),
                        selectedColor: const Color(0xFFEEF2FF),
                        checkmarkColor: const Color(0xFF4F46E5),
                        onSelected: (val) {
                          setDlgState(() {
                            if (val) {
                              selectedPerms.add(perm);
                            } else {
                              selectedPerms.remove(perm);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (roleNameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _roles.add({
                      'id': _roles.length + 1,
                      'roleName': roleNameCtrl.text.trim(),
                      'description': descCtrl.text.trim().isEmpty ? 'Custom user role' : descCtrl.text.trim(),
                      'permissions': List<String>.from(selectedPerms),
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create Role'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('User Management & Roles Authorization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          SizedBox(height: 2),
                          Text('Manage cashier operators, branch managers, credentials, and fine-grained permissions.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.person_add_rounded, size: 16),
                            label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showAddUserDialog,
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text('New Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showAddRoleDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF4F46E5),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.people_alt_rounded, size: 17), text: 'Users List'),
                    Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 17), text: 'Roles & Permissions Matrix'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Users Table
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Assigned Locations', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _users.map((u) {
                    final roleColor = u['role'] == 'Admin'
                        ? const Color(0xFF4F46E5)
                        : (u['role'] == 'Store Manager' ? const Color(0xFF059669) : const Color(0xFF0284C7));
                    final roleBg = u['role'] == 'Admin'
                        ? const Color(0xFFEEF2FF)
                        : (u['role'] == 'Store Manager' ? const Color(0xFFECFDF5) : const Color(0xFFF0F9FF));

                    return DataRow(cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
                              tooltip: 'Edit User',
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() => _users.removeWhere((item) => item['id'] == u['id']));
                              },
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(u['username'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(u['name'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(u['role'], style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      DataCell(Text(u['email'])),
                      DataCell(Text(u['locations'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                          child: Text(u['status'], style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),

          // Tab 1: Roles & Permissions Matrix
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    final perms = (role['permissions'] as List<dynamic>?) ?? [];

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF4F46E5), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(role['roleName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                      Text(role['description'], style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${perms.length} Permissions Allowed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: perms.map((p) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14),
                                    const SizedBox(width: 4),
                                    Text(p.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
