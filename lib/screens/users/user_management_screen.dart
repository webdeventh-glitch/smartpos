import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  final BusinessSettings settings;

  const UserManagementScreen({super.key, required this.settings});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<User> _users = [];
  bool _loading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final db = await DatabaseService.initialize();
      final list = await db.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<User> get _filteredUsers {
    return _users.where((u) {
      if (_selectedRoleFilter != 'All' && u.role.toLowerCase() != _selectedRoleFilter.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = u.name.toLowerCase().contains(q);
        final matchesUsername = u.username.toLowerCase().contains(q);
        final matchesEmail = u.email.toLowerCase().contains(q);
        final matchesPhone = u.phone.toLowerCase().contains(q);
        final matchesRole = u.role.toLowerCase().contains(q);
        if (!matchesName && !matchesUsername && !matchesEmail && !matchesPhone && !matchesRole) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // =========================================================================
  // 1. ADD NEW USER
  // =========================================================================
  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'password');
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'salesman';
    String branch = widget.settings.branchName.isNotEmpty ? widget.settings.branchName : 'Main Branch HQ';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              ContainerIcon(icon: Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 10),
              Text('Create New Staff / Salesman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name * (e.g. Ali Raza)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(labelText: 'Username (Login ID) *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password *', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(labelText: 'Role / Designation', isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'salesman', child: Text('Salesman (Counter / Field)')),
                            DropdownMenuItem(value: 'cashier', child: Text('Cashier (Front Desk)')),
                            DropdownMenuItem(value: 'manager', child: Text('Store Manager / Supervisor')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin (Operations)')),
                            DropdownMenuItem(value: 'superadmin', child: Text('Owner / Super Admin')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => role = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Mobile Phone', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF4F46E5), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Permissions will be auto-configured based on the selected role. You can customize fine-grained authorizations at any time.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF3730A3), height: 1.3),
                          ),
                        ),
                      ],
                    ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final username = usernameCtrl.text.trim();
                final pass = passwordCtrl.text.trim();

                if (name.isEmpty || username.isEmpty || pass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter name, username, and password!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                // Check for duplicate username
                if (_users.any((u) => u.username.toLowerCase() == username.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This username is already taken! Choose another.'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final isAdm = role == 'superadmin' || role == 'admin';
                final isMgr = role == 'manager';

                final newUser = User(
                  name: name,
                  username: username,
                  password: AuthService.hashPassword(pass),
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  role: role,
                  status: 'active',
                  branchId: 1,
                  branchName: branch,
                  canEditPrice: isAdm || isMgr,
                  canGiveDiscount: true,
                  maxDiscountPercent: isAdm ? 100.0 : (isMgr ? 20.0 : 5.0),
                  canViewCostPrice: isAdm || isMgr,
                  canDeleteSale: isAdm || isMgr,
                  canProcessReturn: isAdm || isMgr,
                  canAccessKhata: true,
                  canAccessInventory: isAdm || isMgr,
                  canAccessReports: isAdm || isMgr,
                  canAccessSettings: isAdm,
                  canManageUsers: isAdm,
                );

                final db = await DatabaseService.initialize();
                await db.addUser(newUser);
                Navigator.pop(ctx);
                _loadUsers();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Staff account for "$name" created successfully!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
              child: const Text('Save & Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. EDIT USER DETAILS & RESET PASSWORD
  // =========================================================================
  void _showEditUserDialog(User user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone);
    final newPassCtrl = TextEditingController();
    String role = user.role;
    String status = user.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const ContainerIcon(icon: Icons.edit_note_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Text('Edit User: ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(labelText: 'Role', isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'salesman', child: Text('Salesman')),
                            DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                            DropdownMenuItem(value: 'manager', child: Text('Store Manager')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'superadmin', child: Text('Owner / Superadmin')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => role = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(labelText: 'Account Status', isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active (Can Login)')),
                            DropdownMenuItem(value: 'inactive', child: Text('Disabled / Suspended')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Mobile Phone', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Reset Password (leave blank to keep current)',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final updatedPass = newPassCtrl.text.trim().isNotEmpty
                    ? AuthService.hashPassword(newPassCtrl.text.trim())
                    : user.password;

                final updated = user.copyWith(
                  name: nameCtrl.text.trim(),
                  role: role,
                  status: status,
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  password: updatedPass,
                );

                final db = await DatabaseService.initialize();
                await db.updateUser(updated);
                Navigator.pop(ctx);
                _loadUsers();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User profile updated successfully!'), backgroundColor: Color(0xFF10B981)),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. DELETE USER
  // =========================================================================
  void _confirmDeleteUser(User user) {
    if (user.username == 'webdeventh' || user.username == 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete Primary Business Owner / Superadmin account!'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Account: ${user.name}?'),
        content: Text('Are you sure you want to permanently remove "@${user.username}"? They will no longer be able to log in to this terminal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (user.id != null) {
                final db = await DatabaseService.initialize();
                await db.deleteUser(user.id!);
                Navigator.pop(ctx);
                _loadUsers();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User ${user.name} removed.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. ⭐ STAR FEATURE: USER AUTHORIZATION & PERMISSIONS CONTROL CENTER
  // =========================================================================
  void _showPermissionsDialog(User user) {
    bool canEditPrice = user.canEditPrice;
    bool canGiveDiscount = user.canGiveDiscount;
    double maxDiscount = user.maxDiscountPercent;
    bool canViewCostPrice = user.canViewCostPrice;
    bool canDeleteSale = user.canDeleteSale;
    bool canProcessReturn = user.canProcessReturn;
    bool canAccessKhata = user.canAccessKhata;
    bool canAccessInventory = user.canAccessInventory;
    bool canAccessReports = user.canAccessReports;
    bool canAccessSettings = user.canAccessSettings;
    bool canManageUsers = user.canManageUsers;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Column(
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Salesman & Staff Authorization Matrix',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Owner Control: Grant or revoke specific permissions for ${user.name} (@${user.username})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _roleBadge(user.role),
                  ],
                ),
                const SizedBox(height: 12),
                // QUICK PRESETS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Text('Quick Role Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text('👑 Full Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFEEF2FF),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = true;
                                canGiveDiscount = true;
                                maxDiscount = 100.0;
                                canViewCostPrice = true;
                                canDeleteSale = true;
                                canProcessReturn = true;
                                canAccessKhata = true;
                                canAccessInventory = true;
                                canAccessReports = true;
                                canAccessSettings = true;
                                canManageUsers = true;
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('👔 Store Manager', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFECFDF5),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = true;
                                canGiveDiscount = true;
                                maxDiscount = 20.0;
                                canViewCostPrice = true;
                                canDeleteSale = true;
                                canProcessReturn = true;
                                canAccessKhata = true;
                                canAccessInventory = true;
                                canAccessReports = true;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('🛒 Standard Salesman', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = false;
                                canGiveDiscount = true;
                                maxDiscount = 5.0;
                                canViewCostPrice = false;
                                canDeleteSale = false;
                                canProcessReturn = false;
                                canAccessKhata = true;
                                canAccessInventory = false;
                                canAccessReports = false;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('🔒 Restricted Cashier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFFFEF2F2),
                            onPressed: () {
                              setDlgState(() {
                                canEditPrice = false;
                                canGiveDiscount = false;
                                maxDiscount = 0.0;
                                canViewCostPrice = false;
                                canDeleteSale = false;
                                canProcessReturn = false;
                                canAccessKhata = false;
                                canAccessInventory = false;
                                canAccessReports = false;
                                canAccessSettings = false;
                                canManageUsers = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 720,
              height: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: POS COUNTER & SALES CONTROLS
                    _sectionHeader('1. POS COUNTER & SALE CONTROLS (کاؤنٹر سیلز پر کنٹرول)'),
                    _permissionSwitch(
                      icon: Icons.price_change_outlined,
                      title: 'Allow Altering Unit Prices at Counter (سیلنگ پرائس تبدیل کرنے کا اختیار)',
                      subtitle: 'When OFF, the salesman CANNOT change item retail prices on the counter.',
                      value: canEditPrice,
                      activeColor: Colors.orange,
                      onChanged: (v) => setDlgState(() => canEditPrice = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.discount_outlined,
                      title: 'Allow Giving Discounts (ڈسکاؤنٹ دینے کا اختیار)',
                      subtitle: 'Enable or disable invoice & item discounts for this salesman.',
                      value: canGiveDiscount,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setDlgState(() => canGiveDiscount = v),
                    ),
                    if (canGiveDiscount)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.percent_rounded, size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 8),
                              const Text('Max Allowed Discount Rate: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Slider(
                                  value: maxDiscount.clamp(0.0, 100.0),
                                  min: 0,
                                  max: 50,
                                  divisions: 50,
                                  label: '${maxDiscount.toStringAsFixed(0)}%',
                                  onChanged: (val) => setDlgState(() => maxDiscount = val),
                                ),
                              ),
                              Container(
                                width: 50,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${maxDiscount.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _permissionSwitch(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Allow Voiding & Deleting Completed Sales (بل ڈیلیٹ یا کینسل کرنا)',
                      subtitle: 'Prevents salesmen from voiding invoices or erasing records without owner authorization.',
                      value: canDeleteSale,
                      activeColor: Colors.red,
                      onChanged: (v) => setDlgState(() => canDeleteSale = v),
                    ),

                    const SizedBox(height: 12),
                    // SECTION 2: PROFIT & FINANCIAL CONFIDENTIALITY
                    _sectionHeader('2. PROFIT & FINANCIAL CONFIDENTIALITY (خریداری قیمت اور منافع کا تحفظ)'),
                    _permissionSwitch(
                      icon: Icons.visibility_off_outlined,
                      title: 'View Purchase / Cost Price & Profit Margins (خریداری ریٹ اور نفع دیکھنا)',
                      subtitle: 'When OFF, purchase cost & profit margins are hidden (••••••) from the salesman.',
                      value: canViewCostPrice,
                      activeColor: const Color(0xFF059669),
                      onChanged: (v) => setDlgState(() => canViewCostPrice = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.keyboard_return_rounded,
                      title: 'Authorize Sales Returns & Cash Refunds (سیلز واپسی اور کیش ریفنڈ)',
                      subtitle: 'Requires manager approval for accepting product returns and paying out cash.',
                      value: canProcessReturn,
                      activeColor: const Color(0xFF0284C7),
                      onChanged: (v) => setDlgState(() => canProcessReturn = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.menu_book_rounded,
                      title: 'Access Customer Khata & Credit Ledgers (کسٹمر ادھار کھاتہ)',
                      subtitle: 'Allows salesman to view customer debit/credit balance & record ledger recoveries.',
                      value: canAccessKhata,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setDlgState(() => canAccessKhata = v),
                    ),

                    const SizedBox(height: 12),
                    // SECTION 3: BACK-OFFICE & ADMINISTRATIVE POWERS
                    _sectionHeader('3. BACK-OFFICE & SYSTEM POWERS (بیک آفس اور سسٹم کنٹرول)'),
                    _permissionSwitch(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventory Stock Transfers & Adjustments (اسٹاک ٹرانسفر اور آڈٹ)',
                      subtitle: 'Allows stock adjustments, warehouse transfers, and inventory balance changes.',
                      value: canAccessInventory,
                      activeColor: const Color(0xFF7C3AED),
                      onChanged: (v) => setDlgState(() => canAccessInventory = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.bar_chart_rounded,
                      title: 'View Sales, Tax & Profit/Loss Reports (رپورٹس اور منافع دیکھنا)',
                      subtitle: 'Access to business performance analytics, annual turnover, and tax summaries.',
                      value: canAccessReports,
                      activeColor: const Color(0xFF059669),
                      onChanged: (v) => setDlgState(() => canAccessReports = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.settings_suggest_rounded,
                      title: 'Access Store Settings & Configurations (سسٹم سیٹنگز)',
                      subtitle: 'Modify store profile, invoice templates, tax setup, and cloud sync parameters.',
                      value: canAccessSettings,
                      activeColor: const Color(0xFFD97706),
                      onChanged: (v) => setDlgState(() => canAccessSettings = v),
                    ),
                    _permissionSwitch(
                      icon: Icons.supervisor_account_rounded,
                      title: 'Manage Other Users & Staff Permissions (دیگر اسٹاف کے اختیارات)',
                      subtitle: 'Grant or revoke permissions for other employees.',
                      value: canManageUsers,
                      activeColor: Colors.redAccent,
                      onChanged: (v) => setDlgState(() => canManageUsers = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Apply & Save Authorization', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final updated = user.copyWith(
                    canEditPrice: canEditPrice,
                    canGiveDiscount: canGiveDiscount,
                    maxDiscountPercent: maxDiscount,
                    canViewCostPrice: canViewCostPrice,
                    canDeleteSale: canDeleteSale,
                    canProcessReturn: canProcessReturn,
                    canAccessKhata: canAccessKhata,
                    canAccessInventory: canAccessInventory,
                    canAccessReports: canAccessReports,
                    canAccessSettings: canAccessSettings,
                    canManageUsers: canManageUsers,
                  );

                  final db = await DatabaseService.initialize();
                  await db.updateUser(updated);

                  // Update currently logged-in user session if self
                  if (AuthService.currentUser?.id == user.id ||
                      AuthService.currentUser?.username == user.username) {
                    AuthService.currentUserNotifier.value = updated;
                  }

                  Navigator.pop(ctx);
                  _loadUsers();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Authorization updated! Restrictions are now actively enforced for ${user.name}.'),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: 0.5),
      ),
    );
  }

  Widget _permissionSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: SwitchListTile(
        dense: true,
        secondary: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (value ? activeColor : Colors.grey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: value ? activeColor : Colors.grey, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        activeThumbColor: activeColor,
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color bg;
    Color fg;
    String label;

    switch (role.toLowerCase()) {
      case 'superadmin':
      case 'owner':
        bg = const Color(0xFFEEF2FF);
        fg = const Color(0xFF4F46E5);
        label = 'Owner / Super Admin';
        break;
      case 'admin':
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF7C3AED);
        label = 'Admin';
        break;
      case 'manager':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        label = 'Store Manager';
        break;
      case 'cashier':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Cashier';
        break;
      case 'salesman':
      default:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF0284C7);
        label = 'Salesman';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  // =========================================================================
  // 5. MAIN BUILD METHOD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _users.length;
    final salesmanCount = _users.where((u) => u.isSalesman || u.role.toLowerCase() == 'salesman').length;
    final managerCount = _users.where((u) => u.isManager).length;
    final adminCount = _users.where((u) => u.isAdmin).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(105),
        child: Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.manage_accounts_rounded, color: Color(0xFF4F46E5), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'User Management & Authorization Control Center',
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Owner Controls: Set fine-grained permissions for salesmen, cashiers, supervisors & managers.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
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
                            label: const Text('Add Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: _showAddUserDialog,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4F46E5)),
                            tooltip: 'Refresh List',
                            onPressed: _loadUsers,
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
                  tabs: [
                    Tab(icon: const Icon(Icons.people_alt_rounded, size: 17), text: 'Staff & Salesmen Accounts ($totalCount)'),
                    const Tab(icon: Icon(Icons.admin_panel_settings_rounded, size: 17), text: 'Roles & Permissions Matrix'),
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
          // TAB 0: USERS LIST & AUTHORIZATION TABLE
          _buildUsersTab(isDark, totalCount, salesmanCount, managerCount, adminCount),

          // TAB 1: ROLES & PRESETS OVERVIEW
          _buildRolesMatrixTab(isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 0 IMPLEMENTATION: USERS TABLE & STATS
  // =========================================================================
  Widget _buildUsersTab(bool isDark, int total, int salesmen, int managers, int admins) {
    final filtered = _filteredUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STATS METRICS BAR
          Row(
            children: [
              _metricCard('Total Staff', total.toString(), Icons.people_outline, const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 14),
              _metricCard('Field & Counter Salesmen', salesmen.toString(), Icons.point_of_sale_rounded, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 14),
              _metricCard('Store Managers', managers.toString(), Icons.badge_outlined, const Color(0xFF059669), isDark),
              const SizedBox(width: 14),
              _metricCard('Super Administrators', admins.toString(), Icons.shield_rounded, const Color(0xFF7C3AED), isDark),
            ],
          ),
          const SizedBox(height: 20),

          // SEARCH & FILTER BAR
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search staff by name, username, email, phone, or role...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedRoleFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('Filter Role: All Roles')),
                    DropdownMenuItem(value: 'salesman', child: Text('Salesman Only')),
                    DropdownMenuItem(value: 'cashier', child: Text('Cashier Only')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager Only')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin Only')),
                    DropdownMenuItem(value: 'superadmin', child: Text('Super Admin / Owner Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRoleFilter = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // USERS TABLE
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: _loading
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('No users found matching query.', style: TextStyle(color: Colors.grey.shade500)),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Counter Authorization', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Branch / Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Authorization Control', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((u) {
                            return DataRow(cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFFEEF2FF),
                                      child: Text(
                                        u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (u.email.isNotEmpty)
                                          Text(u.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(u.username, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)))),
                              DataCell(_roleBadge(u.role)),
                              DataCell(
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: [
                                    _pill(
                                      u.canEditPrice ? 'Price Edit: ON' : 'Price Edit: OFF',
                                      u.canEditPrice ? Colors.orange : Colors.grey,
                                      u.canEditPrice ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                                    ),
                                    _pill(
                                      u.canGiveDiscount ? 'Max Disc: ${u.maxDiscountPercent.toInt()}%' : 'No Disc',
                                      u.canGiveDiscount ? const Color(0xFF4F46E5) : Colors.grey,
                                      u.canGiveDiscount ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                                    ),
                                    _pill(
                                      u.canViewCostPrice ? 'Cost: Visible' : 'Cost: Hidden',
                                      u.canViewCostPrice ? const Color(0xFF059669) : Colors.red,
                                      u.canViewCostPrice ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(u.branchName, style: const TextStyle(fontSize: 12)),
                                    if (u.phone.isNotEmpty)
                                      Text(u.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: u.status == 'active' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    u.status == 'active' ? 'Active' : 'Suspended',
                                    style: TextStyle(
                                      color: u.status == 'active' ? const Color(0xFF059669) : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.shield_outlined, size: 14),
                                      label: const Text('Authorization', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _showPermissionsDialog(u),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0284C7)),
                                      tooltip: 'Edit Profile',
                                      onPressed: () => _showEditUserDialog(u),
                                    ),
                                    if (u.username != 'webdeventh' && u.username != 'superadmin')
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        tooltip: 'Remove User',
                                        onPressed: () => _confirmDeleteUser(u),
                                      ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1 IMPLEMENTATION: ROLES & PERMISSIONS MATRIX
  // =========================================================================
  Widget _buildRolesMatrixTab(bool isDark) {
    final roles = [
      {
        'role': 'Owner / Super Admin',
        'desc': 'Complete, unrestricted ownership of business data, bank balances, owner passwords, and tax returns.',
        'rights': ['Full POS Sales', 'Edit Counter Prices', 'Unlimited Discounts (100%)', 'View Cost Prices & Profit Margins', 'Void / Delete Invoices', 'Process Returns & Refunds', 'Khata Ledgers', 'Manage Inventory & Audits', 'View All Reports', 'Change Settings', 'Manage Staff Authorizations'],
        'color': const Color(0xFF4F46E5),
      },
      {
        'role': 'Store Manager / Supervisor',
        'desc': 'Oversees daily store operations, inventory transfers, shift audits, and handles customer disputes.',
        'rights': ['Full POS Sales', 'Edit Counter Prices', 'Discounts up to 20%', 'View Cost Prices & Margins', 'Void / Cancel Sales', 'Process Returns & Refunds', 'Khata Ledgers', 'Manage Inventory & Audits', 'Daily Sales Reports'],
        'color': const Color(0xFF059669),
      },
      {
        'role': 'Standard Salesman (Counter & Field)',
        'desc': 'Frontline selling: creates orders and receives payments. Prices and costs are protected.',
        'rights': ['POS Sales Terminal', 'Hold / Resume Orders', 'Discounts up to 5%', 'View Customer Khata Ledgers', 'Cash Register Drawer'],
        'color': const Color(0xFF0284C7),
      },
      {
        'role': 'Restricted Cashier',
        'desc': 'Fast-checkout clerk strictly scanning barcodes and collecting cash. No price editing or discounts.',
        'rights': ['POS Sales Terminal', 'Barcode Scanning', 'Cash Drawer Integration', 'Receipt Printing'],
        'color': const Color(0xFFD97706),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: roles.map((r) {
          final rights = r['rights'] as List<String>;
          final col = r['color'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                            color: col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.verified_user_rounded, color: col, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['role'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(r['desc'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${rights.length} Rights Authorized', style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: rights.map((rt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: col, size: 14),
                          const SizedBox(width: 5),
                          Text(rt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ContainerIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const ContainerIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
