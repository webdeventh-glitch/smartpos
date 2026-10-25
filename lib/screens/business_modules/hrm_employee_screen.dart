import 'package:flutter/material.dart';
import '../../models/models.dart';

class HrmEmployeeScreen extends StatefulWidget {
  final BusinessSettings settings;

  const HrmEmployeeScreen({super.key, required this.settings});

  @override
  State<HrmEmployeeScreen> createState() => _HrmEmployeeScreenState();
}

class _HrmEmployeeScreenState extends State<HrmEmployeeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final List<Map<String, dynamic>> _staff = [
    {
      'empId': 'EMP-01',
      'name': 'Muhammad Irfan',
      'role': 'Senior Pharmacist / Manager',
      'phone': '+92 300 1234567',
      'salary': 75000.0,
      'attendance': 'Present',
      'joining': '12 Jan 2024',
    },
    {
      'empId': 'EMP-02',
      'name': 'Saad Tariq',
      'role': 'Head Cashier / POS Operator',
      'phone': '+92 321 8887766',
      'salary': 45000.0,
      'attendance': 'Present',
      'joining': '01 Mar 2025',
    },
    {
      'empId': 'EMP-03',
      'name': 'Zubair Ahmed',
      'role': 'Warehouse & Stock Supervisor',
      'phone': '+92 333 4441122',
      'salary': 40000.0,
      'attendance': 'On Leave',
      'joining': '15 Jun 2025',
    },
    {
      'empId': 'EMP-04',
      'name': 'Waqas Ali',
      'role': 'Delivery Rider & Helper',
      'phone': '+92 312 9993344',
      'salary': 30000.0,
      'attendance': 'Present',
      'joining': '10 Aug 2025',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showAddEmployeeModal() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Add New Staff Member', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Staff Full Name*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Designation / Role*',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Mobile Phone Number',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Monthly Basic Salary',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _staff.add({
                      'empId': 'EMP-0${_staff.length + 1}',
                      'name': nameCtrl.text.trim(),
                      'role': roleCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'salary': double.tryParse(salCtrl.text) ?? 35000.0,
                      'attendance': 'Present',
                      'joining': 'Today',
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Employee'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.badge_rounded, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 10),
            Text(
              'HR & Employee Management (Attendance & Payroll)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Staff & Daily Attendance'),
            Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Monthly Payroll & Salaries'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: _showAddEmployeeModal,
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Add Employee'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Tab 1: Staff & Daily Attendance
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(label: Text('EMPLOYEE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataColumn(label: Text('DESIGNATION', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataColumn(label: Text('MOBILE', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataColumn(label: Text('JOINED', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataColumn(label: Text('TODAY STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                      DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
                    ],
                    rows: _staff.map((s) {
                      final att = s['attendance'] as String;
                      final isPresent = att == 'Present';

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  child: Text((s['name'] as String).substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                    Text(s['empId'] as String, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(s['role'] as String, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
                          DataCell(Text(s['phone'] as String, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
                          DataCell(Text(s['joining'] as String, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPresent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                att,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPresent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      s['attendance'] = isPresent ? 'Absent' : 'Present';
                                    });
                                  },
                                  child: Text(isPresent ? 'Mark Absent' : 'Mark Present', style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Monthly Payroll
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Month Payroll Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Salary Pay Slips generated for all staff.')),
                        );
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print All Pay Slips'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _staff.length,
                  itemBuilder: (context, idx) {
                    final e = _staff[idx];
                    final basic = e['salary'] as double;
                    final net = basic;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text('${e['role']} • Basic Salary: $currency${basic.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                          Row(
                            children: [
                              Text('Net Pay: $currency${net.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), fontSize: 15)),
                              const SizedBox(width: 14),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Slip downloaded for ${e['name']}')),
                                  );
                                },
                                child: const Text('Slip', style: TextStyle(fontSize: 11)),
                              ),
                            ],
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
