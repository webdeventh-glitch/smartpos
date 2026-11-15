import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/universal_print_preview_dialog.dart';

class HrmEmployeeScreen extends StatefulWidget {
  final BusinessSettings settings;

  const HrmEmployeeScreen({super.key, required this.settings});

  @override
  State<HrmEmployeeScreen> createState() => _HrmEmployeeScreenState();
}

class _HrmEmployeeScreenState extends State<HrmEmployeeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _staff = [];
  DateTime _selectedAttendanceDate = DateTime.now();
  Map<String, Map<String, dynamic>> _dailyAttendance = {};
  List<PaymentAccount> _paymentAccounts = [];
  final TextEditingController _quickScanCtrl = TextEditingController();

  static const List<Map<String, dynamic>> _seedStaff = [
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
    _loadStaff();
    _loadPaymentAccounts();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _quickScanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentAccounts() async {
    final db = await DatabaseService.initialize();
    final accs = await db.getPaymentAccounts();
    if (mounted) {
      setState(() => _paymentAccounts = accs);
    }
  }

  Future<void> _loadStaff() async {
    final db = await DatabaseService.initialize();
    var rows = await db.getModuleRecords('hrm', recordType: 'employee');
    if (rows.isEmpty) {
      for (final emp in _seedStaff) {
        await db.saveModuleRecord(
          moduleKey: 'hrm',
          recordType: 'employee',
          title: '${emp['empId']} • ${emp['name']}',
          status: emp['attendance'] as String,
          data: emp,
        );
      }
      rows = await db.getModuleRecords('hrm', recordType: 'employee');
    }
    if (mounted) {
      setState(() => _staff = rows);
      await _loadDailyAttendance();
    }
  }

  Future<void> _loadDailyAttendance() async {
    final db = await DatabaseService.initialize();
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedAttendanceDate);
    final rows =
        await db.getModuleRecords('hrm', recordType: 'attendance_$dateKey');

    final map = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final empId =
          (r['empId'] ?? r['_title']?.split(' • ')?.first) as String? ?? '';
      if (empId.isNotEmpty) {
        map[empId] = r;
      }
    }

    // Ensure all employees have an attendance entry in state
    for (final emp in _staff) {
      final id = emp['empId'] as String;
      if (!map.containsKey(id)) {
        map[id] = {
          'empId': id,
          'name': emp['name'],
          'status': emp['attendance'] ?? 'Present',
          'clockIn': '09:00 AM',
          'clockOut': '06:00 PM',
          'workHours': 9.0,
          'date': dateKey,
          'note': 'Standard shift',
        };
      }
    }

    if (mounted) {
      setState(() => _dailyAttendance = map);
    }
  }

  Future<void> _saveAttendanceEntry(String empId,
      {required String status,
      String? clockIn,
      String? clockOut,
      double? workHours,
      String? note}) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedAttendanceDate);
    final emp = _staff.firstWhere((e) => e['empId'] == empId,
        orElse: () => {'name': empId});

    final current = _dailyAttendance[empId] ?? {};
    final updated = <String, dynamic>{
      'empId': empId,
      'name': emp['name'],
      'status': status,
      'clockIn': clockIn ?? current['clockIn'] ?? '09:00 AM',
      'clockOut': clockOut ?? current['clockOut'] ?? '06:00 PM',
      'workHours': workHours ?? current['workHours'] ?? 9.0,
      'date': dateKey,
      'note': note ?? current['note'] ?? '',
    };

    final db = await DatabaseService.initialize();
    final existingDbId = current['_dbId'] as int?;

    final dbId = await db.saveModuleRecord(
      id: existingDbId,
      moduleKey: 'hrm',
      recordType: 'attendance_$dateKey',
      title: '$empId • ${emp['name']}',
      status: status,
      data: updated,
    );
    updated['_dbId'] = dbId;

    if (mounted) {
      setState(() {
        _dailyAttendance[empId] = updated;
      });
    }
  }

  void _quickBarcodePunch() {
    final query = _quickScanCtrl.text.trim();
    if (query.isEmpty) return;

    final match = _staff.cast<Map<String, dynamic>?>().firstWhere(
          (e) =>
              e!['empId'].toString().toLowerCase() == query.toLowerCase() ||
              e['name'].toString().toLowerCase().contains(query.toLowerCase()),
          orElse: () => null,
        );

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff ID or name "$query" not found!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final empId = match['empId'] as String;
    final current = _dailyAttendance[empId];
    final currentStatus = current?['status'] as String? ?? 'Absent';
    final newStatus = currentStatus == 'Present' ? 'Absent' : 'Present';
    final nowTime = DateFormat('hh:mm a').format(DateTime.now());

    _saveAttendanceEntry(
      empId,
      status: newStatus,
      clockIn: newStatus == 'Present' ? nowTime : current?['clockIn'],
      clockOut: newStatus == 'Absent' ? nowTime : current?['clockOut'],
      note: 'Quick Scan Punch at $nowTime',
    );

    _quickScanCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${match['name']} ($empId) punched as $newStatus at $nowTime'),
        backgroundColor: newStatus == 'Present'
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
      ),
    );
  }

  void _showPunchDialog(Map<String, dynamic> emp) {
    final empId = emp['empId'] as String;
    final current = _dailyAttendance[empId] ?? {};
    String status = current['status'] as String? ?? 'Present';
    final inCtrl =
        TextEditingController(text: current['clockIn'] ?? '09:00 AM');
    final outCtrl =
        TextEditingController(text: current['clockOut'] ?? '06:00 PM');
    final noteCtrl = TextEditingController(text: current['note'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  const Icon(Icons.alarm_on_rounded,
                      color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 10),
                  Text('Punch Attendance • ${emp['name']}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A))),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Attendance Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Present',
                            child: Text('Present (Full Day)')),
                        DropdownMenuItem(
                            value: 'Late', child: Text('Late Arrival')),
                        DropdownMenuItem(
                            value: 'Half Day', child: Text('Half Day Shift')),
                        DropdownMenuItem(
                            value: 'Absent', child: Text('Absent / Unpaid')),
                        DropdownMenuItem(
                            value: 'On Leave', child: Text('Approved Leave')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => status = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: inCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Clock-In Time',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: outCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Clock-Out Time',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Shift Note',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _saveAttendanceEntry(
                      empId,
                      status: status,
                      clockIn: inCtrl.text.trim(),
                      clockOut: outCtrl.text.trim(),
                      note: noteCtrl.text.trim(),
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Punch'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEmployeeModal() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final salCtrl = TextEditingController(text: '40000');

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Add New Staff Member',
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Staff Full Name*',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Designation / Role*',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Phone Number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Basic Salary',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final emp = <String, dynamic>{
                    'empId': 'EMP-0${_staff.length + 1}',
                    'name': nameCtrl.text.trim(),
                    'role': roleCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'salary': double.tryParse(salCtrl.text) ?? 35000.0,
                    'attendance': 'Present',
                    'joining': DateFormat('dd MMM yyyy').format(DateTime.now()),
                  };
                  final db = await DatabaseService.initialize();
                  final dbId = await db.saveModuleRecord(
                    moduleKey: 'hrm',
                    recordType: 'employee',
                    title: '${emp['empId']} • ${emp['name']}',
                    status: 'Present',
                    data: emp,
                  );
                  emp['_dbId'] = dbId;
                  if (mounted) {
                    setState(() => _staff.add(emp));
                    _loadDailyAttendance();
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Add Employee'),
            ),
          ],
        );
      },
    );
  }

  void _showProcessPayrollDialog() {
    final currency = widget.settings.currencySymbol;
    String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    PaymentAccount? selectedAccount =
        _paymentAccounts.isNotEmpty ? _paymentAccounts.first : null;

    final allowancesMap = <String, double>{};
    final deductionsMap = <String, double>{};

    for (final emp in _staff) {
      final id = emp['empId'] as String;
      allowancesMap[id] = 2000.0; // Default Medical / Conveyance
      deductionsMap[id] = 0.0;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            double totalBasic = 0;
            double totalAllowances = 0;
            double totalDeductions = 0;

            for (final emp in _staff) {
              final id = emp['empId'] as String;
              final basic = (emp['salary'] as num?)?.toDouble() ?? 30000.0;
              final alw = allowancesMap[id] ?? 0.0;
              final ded = deductionsMap[id] ?? 0.0;
              totalBasic += basic;
              totalAllowances += alw;
              totalDeductions += ded;
            }
            final netDisbursal = totalBasic + totalAllowances - totalDeductions;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Process & Disburse Monthly Payroll',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A))),
                        Text(
                            'Generates expense & updates bank/cash balance automatically',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedMonth,
                              decoration: const InputDecoration(
                                labelText: 'Salary Month & Year',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DateFormat('MMMM yyyy').format(DateTime.now()),
                                DateFormat('MMMM yyyy').format(DateTime.now()
                                    .subtract(const Duration(days: 30))),
                              ]
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setDlgState(() => selectedMonth = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<PaymentAccount>(
                              initialValue: selectedAccount,
                              decoration: const InputDecoration(
                                labelText: 'Disbursal Payment Account',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _paymentAccounts.map((a) {
                                return DropdownMenuItem(
                                  value: a,
                                  child: Text(
                                      '${a.name} (Bal: $currency${a.currentBalance.toStringAsFixed(0)})',
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setDlgState(() => selectedAccount = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Staff Salary Breakdown:',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _staff.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final emp = _staff[idx];
                            final id = emp['empId'] as String;
                            final basic =
                                (emp['salary'] as num?)?.toDouble() ?? 30000.0;
                            final alw = allowancesMap[id] ?? 0.0;
                            final ded = deductionsMap[id] ?? 0.0;
                            final net = basic + alw - ded;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(emp['name'] as String,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text(
                                            '${emp['role']} • Basic: $currency${basic.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: alw.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: '+ Allowances',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        setDlgState(() {
                                          allowancesMap[id] =
                                              double.tryParse(v) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: ded.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: '- Deductions',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        setDlgState(() {
                                          deductionsMap[id] =
                                              double.tryParse(v) ?? 0.0;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('$currency${net.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Net Payable ($selectedMonth):',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    'Basic: $currency${totalBasic.toStringAsFixed(0)}  •  Allowances: +$currency${totalAllowances.toStringAsFixed(0)}  •  Deductions: -$currency${totalDeductions.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            Text('$currency${netDisbursal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirm & Disburse Salaries'),
                  onPressed: () async {
                    final db = await DatabaseService.initialize();

                    // 1. Save Disbursal Run Record
                    final runData = {
                      'month': selectedMonth,
                      'disbursalDate': DateTime.now().toIso8601String(),
                      'totalAmount': netDisbursal,
                      'accountId': selectedAccount?.id,
                      'accountName': selectedAccount?.name ?? 'Cash in Hand',
                      'employeeCount': _staff.length,
                    };

                    await db.saveModuleRecord(
                      moduleKey: 'hrm',
                      recordType: 'payroll_disbursal',
                      title: 'Payroll Disbursed • $selectedMonth',
                      status: 'disbursed',
                      data: runData,
                    );

                    // 2. Insert into Expenses table for double-entry P&L integration
                    await db.db.insert('expenses', {
                      'category': 'Salary & Wages',
                      'amount': netDisbursal,
                      'ref_no':
                          'PAY-${DateFormat('yyyyMM').format(DateTime.now())}',
                      'note':
                          'Staff Salary Disbursal for $selectedMonth (${_staff.length} employees)',
                      'date': DateTime.now().toIso8601String(),
                      'payment_method': selectedAccount?.name ?? 'cash',
                    });

                    // 3. Deduct from selected Bank or Cash Payment Account
                    if (selectedAccount?.id != null) {
                      await db.db.rawUpdate(
                        'UPDATE payment_accounts SET current_balance = current_balance - ? WHERE id = ?',
                        [netDisbursal, selectedAccount!.id],
                      );
                      await _loadPaymentAccounts();
                    }

                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Salaries of $currency${netDisbursal.toStringAsFixed(0)} disbursed and posted to accounts!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDetailedPaySlip(Map<String, dynamic> emp) {
    final currency = widget.settings.currencySymbol;
    final basic = (emp['salary'] as num?)?.toDouble() ?? 40000.0;
    const medicalAlw = 2000.0;
    const conveyanceAlw = 1500.0;
    const grossEarnings = 43500.0;
    const leaveDed = 0.0;
    const taxDed = 500.0;
    const totalDed = 500.0;
    final netPay = basic + medicalAlw + conveyanceAlw - totalDed;
    final monthStr = DateFormat('MMMM yyyy').format(DateTime.now());

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Pay Slip - ${emp['name']}</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; color: #1e293b; }
    .header { text-align: center; border-bottom: 2px solid #0284c7; padding-bottom: 12px; margin-bottom: 18px; }
    .header h2 { margin: 0; font-size: 22px; color: #0369a1; }
    .header p { margin: 3px 0; font-size: 13px; color: #64748b; }
    .title-pill { display: inline-block; background: #e0f2fe; color: #0284c7; padding: 4px 14px; border-radius: 12px; font-weight: bold; font-size: 13px; margin-top: 6px; }
    .info-table { width: 100%; margin-bottom: 16px; font-size: 13px; border-collapse: collapse; }
    .info-table td { padding: 6px 4px; }
    .breakdown-table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 18px; }
    .breakdown-table th, .breakdown-table td { border: 1px solid #cbd5e1; padding: 8px 10px; }
    .breakdown-table th { background: #f8fafc; font-weight: bold; }
    .net-box { background: #ecfdf5; border: 2px solid #10b981; border-radius: 8px; padding: 12px 18px; text-align: right; margin-bottom: 30px; }
    .net-title { font-size: 14px; color: #065f46; font-weight: bold; }
    .net-amount { font-size: 24px; color: #047857; font-weight: 900; margin: 4px 0; }
    .signatures { width: 100%; margin-top: 40px; font-size: 12px; }
    .sig-line { border-top: 1px dashed #64748b; width: 180px; margin-top: 50px; text-align: center; padding-top: 4px; }
  </style>
</head>
<body>
  <div class="header">
    <h2>${widget.settings.businessName}</h2>
    <p>${widget.settings.address} • Phone: ${widget.settings.phone}</p>
    <div class="title-pill">CONFIDENTIAL SALARY PAY SLIP — $monthStr</div>
  </div>

  <table class="info-table">
    <tr>
      <td><strong>Employee Name:</strong> ${emp['name']}</td>
      <td><strong>Employee ID:</strong> ${emp['empId']}</td>
    </tr>
    <tr>
      <td><strong>Designation:</strong> ${emp['role']}</td>
      <td><strong>Mobile:</strong> ${emp['phone']}</td>
    </tr>
    <tr>
      <td><strong>Joining Date:</strong> ${emp['joining']}</td>
      <td><strong>Pay Period:</strong> $monthStr</td>
    </tr>
  </table>

  <table class="breakdown-table">
    <thead>
      <tr>
        <th width="50%">EARNINGS & ALLOWANCES</th>
        <th width="50%">DEDUCTIONS & ADJUSTMENTS</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <table width="100%">
            <tr><td>Basic Salary:</td><td align="right">$currency${basic.toStringAsFixed(0)}</td></tr>
            <tr><td>Medical Allowance:</td><td align="right">$currency${medicalAlw.toStringAsFixed(0)}</td></tr>
            <tr><td>Conveyance Allowance:</td><td align="right">$currency${conveyanceAlw.toStringAsFixed(0)}</td></tr>
            <tr><td><strong>Gross Earnings:</strong></td><td align="right"><strong>$currency${grossEarnings.toStringAsFixed(0)}</strong></td></tr>
          </table>
        </td>
        <td valign="top">
          <table width="100%">
            <tr><td>Unpaid Leaves / Absences:</td><td align="right">$currency${leaveDed.toStringAsFixed(0)}</td></tr>
            <tr><td>Income Tax / Deductions:</td><td align="right">$currency${taxDed.toStringAsFixed(0)}</td></tr>
            <tr><td><strong>Total Deductions:</strong></td><td align="right"><strong>$currency${totalDed.toStringAsFixed(0)}</strong></td></tr>
          </table>
        </td>
      </tr>
    </tbody>
  </table>

  <div class="net-box">
    <div class="net-title">NET TAKE-HOME PAYABLE SALARY</div>
    <div class="net-amount">$currency${netPay.toStringAsFixed(0)}</div>
    <div style="font-size: 11px; color: #047857;">Status: Certified & Processed for Disbursal</div>
  </div>

  <table class="signatures">
    <tr>
      <td width="50%">
        <div class="sig-line">Employee Signature</div>
      </td>
      <td width="50%" align="right">
        <div class="sig-line" style="display: inline-block;">Authorized HR / Director Stamp</div>
      </td>
    </tr>
  </table>
</body>
</html>
''';

    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: 'Salary Pay Slip • ${emp['name']}',
        htmlContent: html,
        defaultPaperSize: 'a4',
        settings: widget.settings,
      ),
    );
  }

  void _openPayrollPrint(List<Map<String, dynamic>> employees,
      {String? singleTitle}) {
    final currency = widget.settings.currencySymbol;
    final headers = const [
      'Emp ID',
      'Name',
      'Role',
      'Attendance',
      'Net Salary'
    ];
    final rows = employees
        .map((e) => <String>[
              '${e['empId']}',
              '${e['name']}',
              '${e['role']}',
              '${e['attendance']}',
              '$currency${(e['salary'] as num).toStringAsFixed(0)}',
            ])
        .toList();
    final html = StringBuffer()
      ..write('<h2>${singleTitle ?? 'Payroll Pay Slips'}</h2>')
      ..write('<table border="1" cellspacing="0" cellpadding="6" width="100%">')
      ..write('<tr>${headers.map((h) => '<th>$h</th>').join()}</tr>');
    for (final r in rows) {
      html.write('<tr>${r.map((c) => '<td>$c</td>').join()}</tr>');
    }
    html.write('</table>');
    showDialog(
      context: context,
      builder: (_) => UniversalPrintPreviewDialog(
        title: singleTitle ?? 'All Staff Salary Pay Slips',
        htmlContent: html.toString(),
        defaultPaperSize: 'a4',
        settings: widget.settings,
        pdfGenerator: (_) => PdfExportService.generateReportPdf(
          title: singleTitle ?? 'Payroll Salary Register',
          subtitle:
              '${widget.settings.businessName} • ${employees.length} employees',
          headers: headers,
          rows: rows,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.settings.currencySymbol;
    final formattedDate =
        DateFormat('dd MMM yyyy').format(_selectedAttendanceDate);

    // KPI computations
    int totalStaff = _staff.length;
    int presentCount = 0;
    int absentCount = 0;
    int onLeaveCount = 0;
    int lateCount = 0;

    for (final emp in _staff) {
      final id = emp['empId'] as String;
      final att = _dailyAttendance[id];
      final st = (att?['status'] as String? ?? 'Present').toLowerCase();
      if (st == 'present') {
        presentCount++;
      } else if (st == 'absent') {
        absentCount++;
      } else if (st.contains('leave')) {
        onLeaveCount++;
      } else if (st == 'late' || st.contains('half')) {
        lateCount++;
      }
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
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
          unselectedLabelColor:
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          tabs: const [
            Tab(
                icon: Icon(Icons.people_alt_rounded, size: 18),
                text: 'Staff & Daily Attendance'),
            Tab(
                icon: Icon(Icons.payments_rounded, size: 18),
                text: 'Monthly Payroll & Salaries'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white),
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
                // Top Date Navigator & Quick Barcode Punch Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Date Selector
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous Day',
                        onPressed: () {
                          setState(() {
                            _selectedAttendanceDate = _selectedAttendanceDate
                                .subtract(const Duration(days: 1));
                          });
                          _loadDailyAttendance();
                        },
                      ),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedAttendanceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedAttendanceDate = picked);
                            _loadDailyAttendance();
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next Day',
                        onPressed: () {
                          setState(() {
                            _selectedAttendanceDate = _selectedAttendanceDate
                                .add(const Duration(days: 1));
                          });
                          _loadDailyAttendance();
                        },
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(
                              () => _selectedAttendanceDate = DateTime.now());
                          _loadDailyAttendance();
                        },
                        child:
                            const Text('Today', style: TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      // Barcode Quick Punch Input
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _quickScanCtrl,
                          onSubmitted: (_) => _quickBarcodePunch(),
                          decoration: InputDecoration(
                            hintText: 'Scan Staff Barcode / ID (e.g. EMP-01)',
                            prefixIcon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send_rounded, size: 18),
                              onPressed: _quickBarcodePunch,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // KPI Stat Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard('Total Staff', '$totalStaff',
                          Icons.group_rounded, const Color(0xFF2563EB), isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                          'Present Today',
                          '$presentCount',
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                          isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                          'Absent',
                          '$absentCount',
                          Icons.cancel_rounded,
                          const Color(0xFFEF4444),
                          isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                          'On Leave',
                          '$onLeaveCount',
                          Icons.beach_access_rounded,
                          const Color(0xFFF59E0B),
                          isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                          'Late / Half Day',
                          '$lateCount',
                          Icons.schedule_rounded,
                          const Color(0xFF8B5CF6),
                          isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Staff Attendance Table
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(
                          label: Text('EMPLOYEE',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                      DataColumn(
                          label: Text('DESIGNATION',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                      DataColumn(
                          label: Text('CLOCK IN',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                      DataColumn(
                          label: Text('CLOCK OUT',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                      DataColumn(
                          label: Text('STATUS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                      DataColumn(
                          label: Text('ACTIONS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF475569)))),
                    ],
                    rows: _staff.map((s) {
                      final empId = s['empId'] as String;
                      final att = _dailyAttendance[empId] ?? {};
                      final statusStr = att['status'] as String? ?? 'Present';
                      final isPresent = statusStr.toLowerCase() == 'present';
                      final clockIn = att['clockIn'] as String? ?? '09:00 AM';
                      final clockOut = att['clockOut'] as String? ?? '06:00 PM';

                      Color badgeColor = const Color(0xFF10B981);
                      if (statusStr.toLowerCase() == 'absent') {
                        badgeColor = const Color(0xFFEF4444);
                      } else if (statusStr.toLowerCase().contains('leave')) {
                        badgeColor = const Color(0xFFF59E0B);
                      } else if (statusStr.toLowerCase() == 'late') {
                        badgeColor = const Color(0xFF8B5CF6);
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                      (s['name'] as String).substring(0, 1),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB))),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s['name'] as String,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A))),
                                    Text(empId,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(s['role'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155)))),
                          DataCell(Text(clockIn,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155)))),
                          DataCell(Text(clockOut,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155)))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusStr,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor),
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isPresent
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    final next =
                                        isPresent ? 'Absent' : 'Present';
                                    _saveAttendanceEntry(empId, status: next);
                                  },
                                  child: Text(
                                      isPresent
                                          ? 'Mark Absent'
                                          : 'Mark Present',
                                      style: const TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact),
                                  onPressed: () => _showPunchDialog(s),
                                  child: const Text('Punch',
                                      style: TextStyle(fontSize: 11)),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Month Payroll Register',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        const Text(
                            'Process, post salaries to accounts & generate individual payslips',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white),
                          onPressed: _showProcessPayrollDialog,
                          icon: const Icon(Icons.account_balance_wallet_rounded,
                              size: 16),
                          label: const Text('Process Monthly Payroll'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white),
                          onPressed: () => _openPayrollPrint(_staff),
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print All Pay Slips'),
                        ),
                      ],
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
                    final basic = (e['salary'] as num?)?.toDouble() ?? 40000.0;
                    final net = basic;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['name'] as String,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text(
                                  '${e['role']} • Basic Salary: $currency${basic.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B))),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                  'Net Pay: $currency${net.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF10B981),
                                      fontSize: 15)),
                              const SizedBox(width: 14),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact),
                                onPressed: () => _openDetailedPaySlip(e),
                                icon: const Icon(Icons.receipt_long_rounded,
                                    size: 14),
                                label: const Text('Pay Slip',
                                    style: TextStyle(fontSize: 11)),
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

  Widget _buildKpiCard(
      String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
