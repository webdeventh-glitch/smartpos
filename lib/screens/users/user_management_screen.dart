import 'package:flutter/material.dart';
import '../../models/models.dart';

class UserManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UserManagementScreen({super.key, required this.settings});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final List<Map<String, dynamic>> _users = [
    {
      'id': 1,
      'name': 'Admin User',
      'username': 'admin',
      'email': 'admin@awesomeshop.com',
      'role': 'Admin',
      'status': 'Active',
      'locations': 'Awesome Shop, Warehouse 1',
    },
    {
      'id': 2,
      'name': 'Cashier 1',
      'username': 'cashier1',
      'email': 'cashier1@awesomeshop.com',
      'role': 'Cashier',
      'status': 'Active',
      'locations': 'Awesome Shop',
    },
    {
      'id': 3,
      'name': 'Store Manager',
      'username': 'manager',
      'email': 'manager@awesomeshop.com',
      'role': 'Manager',
      'status': 'Active',
      'locations': 'Awesome Shop',
    },
  ];

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Cashier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name*')),
                const SizedBox(height: 12),
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username*')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address*')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'Admin', child: Text('Admin (All permissions)')),
                    DropdownMenuItem(value: 'Manager', child: Text('Manager (Catalog & Reports)')),
                    DropdownMenuItem(value: 'Cashier', child: Text('Cashier (POS Only)')),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004EEB), foregroundColor: Colors.white),
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
                      'locations': 'Awesome Shop',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Manage system users, login credentials, and POS cash registers permissions.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004EEB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showAddUserDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Locations', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _users.map((u) {
                  return DataRow(cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Color(0xFF004EEB)),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF3FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(u['role'], style: const TextStyle(color: Color(0xFF004EEB), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    DataCell(Text(u['email'])),
                    DataCell(Text(u['locations'])),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(u['status'], style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
